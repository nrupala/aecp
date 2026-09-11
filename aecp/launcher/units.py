"""AECP daemonless orchestration.

Every AECP component runs as a systemd unit in the dedicated
``aecp.slice`` cgroup slice: no Docker daemon, no container runtime - direct
Linux kernel primitives (cgroups/namespaces), the exact isolation mechanism
the AECP specification calls for (ADR-0001, ADR-0003).
"""

from __future__ import annotations

import os
from dataclasses import dataclass

from aecp.spec import Component, deployment_components


@dataclass(frozen=True)
class Paths:
    """Filesystem layout used on the target host (overridable via env)."""

    repo: str = "/opt/aecp/aecp-repo"
    apps: str = "/opt/aecp/apps"
    data: str = "/var/lib/aecp"
    venv: str = "/opt/aecp/venv"
    user: str = "aecp"
    java_home: str = "/usr/lib/jvm/java-17-openjdk-arm64"


def paths_from_env() -> Paths:
    """Build Paths from AECP_* environment variables with arch-aware default."""
    import glob
    import os

    default_java = os.getenv("AECP_JAVA_HOME")
    if not default_java:
        candidates = sorted(glob.glob("/usr/lib/jvm/java-17-openjdk-*"))
        default_java = candidates[0] if candidates else Paths.java_home
    return Paths(
        repo=os.getenv("AECP_REPO", Paths.repo),
        apps=os.getenv("AECP_APPS", Paths.apps),
        data=os.getenv("AECP_DATA", Paths.data),
        venv=os.getenv("AECP_VENV", Paths.venv),
        user=os.getenv("AECP_USER", Paths.user),
        java_home=default_java,
    )


SLICE_UNIT = """\
[Unit]
Description=AECP root cgroup slice (kernel-primitive isolation)
Before=slices.target

[Slice]
CPUAccounting=yes
MemoryAccounting=yes
TasksMax=4096
"""

_UNIT_ORDER = [
    "pulsar", "flink-jm", "flink-tm",
    "ozone-scm", "ozone-om", "ozone-dn", "ozone-s3g", "ozone-recon",
    "solr", "arrow-flight", "gateway",
    "zeppelin", "superset", "guacd", "guacamole",
]


def _svc(comp: Component, after: str, jenv: str, env_lines: str,
         exec_start: str, exec_stop: str | None, workdir: str,
         service_type: str = "simple") -> str:
    body = (
        "[Unit]\n"
        f"Description={comp.name} (AECP L{comp.layer.value})\n"
        "Wants=network-online.target\n"
        f"After={after}\n"
        "PartOf=aecp.target\n"
        "\n"
        "[Service]\n"
        f"User=aecp\n"
        f"Type={service_type}\n"
        "Slice=aecp.slice\n"
        f"MemoryMax={comp.memory_max}\n"
        "LimitNOFILE=65536\n"
        "Restart=on-failure\n"
        "RestartSec=5\n"
        + jenv
        + env_lines
        + f"ExecStart={exec_start}\n"
    )
    if exec_stop:
        body += f"ExecStop={exec_stop}\n"
    body += f"WorkingDirectory={workdir}\n\n[Install]\nWantedBy=multi-user.target\n"
    return body


def render_units(paths: Paths | None = None,
                 components: dict[str, Component] | None = None) -> dict[str, str]:
    """Render the full systemd unit catalog as {unit_name: file_contents}."""
    p = paths or Paths()
    comps = components or deployment_components()
    units: dict[str, str] = {"aecp.slice": SLICE_UNIT}
    _wants = " ".join(comps[k].unit for k in _UNIT_ORDER)
    units["aecp.target"] = (
        "[Unit]\n"
        "Description=AECP full stack target\n"
        "Requires=aecp.slice\n"
        "After=aecp.slice\n"
        f"Wants={_wants}\n"
        "\n"
        "[Install]\n"
        "WantedBy=multi-user.target\n"
    )

    apps, data, venv = p.apps, p.data, p.venv
    jenv = (
        f"Environment=JAVA_HOME={p.java_home}\n"
        "Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\n"
    )

    u = comps["pulsar"]
    units[u.unit] = _svc(
        u, "network-online.target", jenv,
        "Environment=PULSAR_GC=-XX:+UseG1GC\n"
        "Environment=PULSAR_MEM=-Xmx512m -XX:MaxDirectMemorySize=256m\n",
        f"{apps}/pulsar/bin/pulsar standalone --no-functions-worker",
        None, f"{data}/pulsar",
    )

    u = comps["flink-jm"]
    units[u.unit] = _svc(
        u, "network-online.target", jenv,
        f"Environment=FLINK_HOME={apps}/flink\n",
        f"{apps}/flink/bin/jobmanager.sh start-foreground",
        None, apps + "/flink",
    )

    u = comps["flink-tm"]
    units[u.unit] = _svc(
        u, "network-online.target aecp-flink-jobmanager.service", jenv,
        f"Environment=FLINK_HOME={apps}/flink\n",
        f"{apps}/flink/bin/taskmanager.sh start-foreground",
        None, apps + "/flink",
    )

    ozone_env = (
        f"Environment=OZONE_HOME={apps}/ozone\n"
        f"Environment=OZONE_LOG_DIR={data}/ozone/log\n"
    )
    ozone_env = (
        f"Environment=OZONE_HOME={apps}/ozone\n"
        f"Environment=OZONE_LOG_DIR={data}/ozone/log\n"
    )
    prefer_v4 = "-Djava.net.preferIPv4Stack=true"
    u = comps["ozone-scm"]
    units[u.unit] = _svc(
        u, "network-online.target", jenv,
        ozone_env + f"Environment=OZONE_OPTS=-Xmx256m {prefer_v4}\n",
        f"{apps}/ozone/bin/ozone scm",
        None, apps + "/ozone",
    )

    u = comps["ozone-om"]
    units[u.unit] = _svc(
        u, "network-online.target aecp-ozone-scm.service", jenv,
        ozone_env + f"Environment=OZONE_OPTS=-Xmx256m {prefer_v4}\n",
        f"{apps}/ozone/bin/ozone om",
        None, apps + "/ozone",
    )

    for key, svc, heap in (
        ("ozone-dn", "datanode", "-Xmx512m"),
        ("ozone-s3g", "s3g", "-Xmx192m"),
        ("ozone-recon", "recon", "-Xmx192m"),
    ):
        u = comps[key]
        after = "aecp-ozone-om.service" if key == "ozone-s3g" else "aecp-ozone-scm.service"
        units[u.unit] = _svc(
            u, f"network-online.target {after}", jenv,
            ozone_env + f"Environment=OZONE_OPTS={heap} {prefer_v4}\n",
            f"{apps}/ozone/bin/ozone {svc}",
            None, apps + "/ozone",
        )

    u = comps["solr"]
    units[u.unit] = _svc(
        u, "network-online.target", jenv,
        "Environment=SOLR_HEAP=512m\n"
        f"Environment=SOLR_LOGS_DIR={data}/solr/log\n",
        f"{apps}/solr/bin/solr start -f -s {data}/solr/server -p 8983",
        None, f"{data}/solr",
    )

    u = comps["arrow-flight"]
    units[u.unit] = _svc(
        u, "network-online.target", jenv,
        "",
        f"{venv}/bin/python -m aecp.memory.flight --serve --host 127.0.0.1 "
        f"--port 8815 --max-threads 4",
        None, data,
    )

    u = comps["gateway"]
    units[u.unit] = _svc(
        u, "network-online.target aecp-solr.service", jenv,
        "Environment=AECP_SOLR_URL=http://127.0.0.1:8983\n"
        "Environment=AECP_GATEWAY_PORT=8847\n"
        f"Environment=PYTHONPATH={p.repo}\n",
        f"{venv}/bin/uvicorn aecp.gateway.app:app --host 0.0.0.0 --port 8847 "
        f"--workers 1",
        None, data,
    )

    u = comps["zeppelin"]
    units[u.unit] = _svc(
        u, "network-online.target", jenv,
        f"Environment=ZEPPELIN_PORT=8083\n"
        f"Environment=ZEPPELIN_MEM=-Xmx512m\n"
        f"Environment=ZEPPELIN_LOG_DIR={data}/zeppelin/log\n"
        f"Environment=ZEPPELIN_PID_DIR={data}/zeppelin/pid\n",
        f"{apps}/zeppelin/bin/zeppelin-daemon.sh start",
        f"{apps}/zeppelin/bin/zeppelin-daemon.sh stop", apps + "/zeppelin",
        service_type="forking",
    )

    u = comps["superset"]
    svenv = os.environ.get("AECP_SUPERSET_VENV", p.venv)
    units[u.unit] = _svc(
        u, "network-online.target", jenv,
        f"Environment=SUPERSET_CONFIG_PATH={data}/superset/superset_config.py\n"
        f"Environment=FLASK_APP=superset.app:create_app()\n"
        f"Environment=PYTHONPATH={p.repo}\n",
        f"{svenv}/bin/gunicorn --workers 2 --timeout 120 --bind 0.0.0.0:8087 "
        f"\"superset.app:create_app()\"",
        None, f"{data}/superset",
    )

    u = comps["guacd"]
    units[u.unit] = _svc(
        u, "network-online.target", jenv,
        f"Environment=GUACD_HOME={data}/guacd\n",
        f"{apps}/bin/guacd -f -b 127.0.0.1 -l 4822",
        None, f"{data}/guacd",
    )

    u = comps["guacamole"]
    units[u.unit] = _svc(
        u, "network-online.target aecp-guacd.service", jenv,
        f"Environment=GUACAMOLE_HOME={data}/guacamole/.guacamole\n"
        f"Environment=CATALINA_BASE={apps}/tomcat-base\n",
        f"{apps}/tomcat/bin/catalina.sh run",
        None, f"{data}/guacamole",
    )

    return units


def unit_order() -> list[str]:
    return _UNIT_ORDER
