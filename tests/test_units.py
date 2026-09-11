"""Launcher unit rendering tests: kernel-primitive isolation contract (ADR-0003)."""

from aecp.launcher.units import Paths, render_units
from aecp.spec import deployment_components


def test_all_components_render():
    units = render_units()
    comps = deployment_components()
    for name, comp in comps.items():
        assert comp.unit in units, f"missing unit {comp.unit} for {name}"
    assert "aecp.slice" in units
    assert "aecp.target" in units


def test_slice_contract():
    slice_unit = render_units()["aecp.slice"]
    assert "[Slice]" in slice_unit
    assert "MemoryAccounting=yes" in slice_unit
    assert "CPUAccounting=yes" in slice_unit


def test_no_docker_anywhere():
    units = render_units()
    joined = "\n".join(units.values()).lower()
    for forbidden in ("docker", "podman", "containerd"):
        assert forbidden not in joined


def test_every_service_uses_aecp_slice_and_restart():
    units = render_units()
    for name, text in units.items():
        if name in ("aecp.slice", "aecp.target"):
            continue
        assert "Slice=aecp.slice" in text, name
        assert "MemoryMax=" in text, name
        assert "Restart=on-failure" in text, name
        assert "User=aecp" in text, name


def test_service_dependencies():
    units = render_units()
    tm = units["aecp-flink-taskmanager.service"]
    assert "aecp-flink-jobmanager.service" in tm
    s3g = units["aecp-ozone-s3g.service"]
    assert "aecp-ozone-om.service" in s3g
    gw = units["aecp-gateway.service"]
    assert "aecp-solr.service" in gw
    guac = units["aecp-guacamole.service"]
    assert "aecp-guacd.service" in guac


def test_target_wants_all_services():
    units = render_units()
    target = units["aecp.target"]
    comps = deployment_components()
    for comp in comps.values():
        assert comp.unit in target, comp.unit


def test_zeppelin_port_8083_env():
    units = render_units()
    assert "ZEPPELIN_PORT=8083" in units["aecp-zeppelin.service"]
    assert "8083" not in units["aecp-pulsar.service"]


def test_flight_and_gateway_ports():
    units = render_units()
    assert "--port 8815" in units["aecp-arrow-flight.service"]
    assert "--port 8847" in units["aecp-gateway.service"]


def test_custom_paths():
    p = Paths(apps="/x/apps", data="/x/data", venv="/x/venv", java_home="/x/jdk")
    units = render_units(paths=p)
    assert "/x/apps/pulsar/bin/pulsar" in units["aecp-pulsar.service"]
    assert "/x/venv/bin/python" in units["aecp-arrow-flight.service"]
