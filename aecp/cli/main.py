"""aecpctl: AECP control plane CLI.

Commands:
  plan        render the systemd unit catalog (--dir writes unit files)
  status      systemd states for all AECP units (Linux)
  health      HTTP-probe every component health endpoint (exit 1 on failure)
  benchmark   run the L4 memory-plane benchmark and print its JSON report
  selftest    run the local pytest suite
  versions    print pinned component versions (from deploy/versions.env)
  apply       write unit files to /etc/systemd/system + daemon-reload (Linux)
  start|stop  enable/start or stop the AECP target
  purge       remove all AECP units (rollback path)
"""

from __future__ import annotations

import argparse
import json
import platform
import sys
from collections.abc import Callable
from pathlib import Path

from aecp import __version__
from aecp.launcher import aecpd
from aecp.launcher.units import render_units
from aecp.spec import deployment_components, port_conflicts, sla_targets


def _repo_root() -> Path:
    here = Path(__file__).resolve()
    for parent in here.parents:
        if (parent / "pyproject.toml").exists():
            return parent
    return Path.cwd()


def _linux_guard() -> int:
    if platform.system() != "Linux":
        print("error: this command runs on Linux hosts only "
              "(dev machines use: aecpctl plan / selftest / benchmark)", file=sys.stderr)
        return 1
    return 0


def cmd_plan(args: argparse.Namespace) -> int:
    units = render_units()
    if args.dir:
        d = args.dir
        for name, text in units.items():
            (d / name).write_text(text, encoding="utf-8")
            print(f"wrote {d / name}")
    else:
        for name, text in sorted(units.items()):
            print(f"===== {name} =====")
            print(text)
    print(f"components: {len(deployment_components())}, "
          f"port conflicts: {port_conflicts() or 'none'}")
    return 0


def cmd_apply(_args: argparse.Namespace) -> int:
    if (rc := _linux_guard()) != 0:
        return rc
    written = aecpd.apply()
    for w in written:
        print(f"wrote {w}")
    return 0


def cmd_start(_args: argparse.Namespace) -> int:
    if (rc := _linux_guard()) != 0:
        return rc
    aecpd._run(["systemctl", "enable", "--now", "aecp.target"])
    return 0


def cmd_stop(_args: argparse.Namespace) -> int:
    if (rc := _linux_guard()) != 0:
        return rc
    aecpd._run(["systemctl", "stop", "aecp.target"], check=False)
    for unit in render_units():
        if unit not in ("aecp.slice", "aecp.target"):
            aecpd.stop(unit)
    return 0


def cmd_purge(_args: argparse.Namespace) -> int:
    if (rc := _linux_guard()) != 0:
        return rc
    aecpd.purge()
    print("purged")
    return 0


def cmd_status(_args: argparse.Namespace) -> int:
    if (rc := _linux_guard()) != 0:
        return rc
    for unit, state in aecpd.status().items():
        print(f"{state:>10}  {unit}")
    return 0


def cmd_health(args: argparse.Namespace) -> int:
    import os

    if platform.system() != "Linux":
        # allow dev probing when AECP_HOST_URLS is provided as JSON
        env = os.environ.get("AECP_HOST_URLS")
        if not env:
            print("error: health runs on Linux hosts (or set AECP_HOST_URLS JSON)",
                  file=sys.stderr)
            return 1
        results = {k: False for k in json.loads(env)}
    else:
        results = aecpd.health_checks(timeout=args.timeout)
    failed = sorted(n for n, ok in results.items() if not ok)
    for name, ok in sorted(results.items()):
        print(f"{'PASS' if ok else 'FAIL':>6}  {name}")
    if failed:
        print(f"health: {len(failed)} failed: {failed}", file=sys.stderr)
        return 1
    print("health: all components healthy")
    return 0


def cmd_benchmark(args: argparse.Namespace) -> int:
    from aecp.memory import bench

    report = bench.run(rows=args.rows)
    print(json.dumps(report, indent=2))
    target = sla_targets()["memory_plane_arrow_min_gbps"]
    if report["arrow_ipc_gbps"] < target:
        print(f"benchmark below SLA target ({report['arrow_ipc_gbps']} < {target} GB/s)",
              file=sys.stderr)
        return 1
    return 0


def cmd_selftest(_args: argparse.Namespace) -> int:
    import pytest

    raise SystemExit(pytest.main(["-m", "not integration", str(_repo_root())]))


def cmd_versions(_args: argparse.Namespace) -> int:
    env_file = _repo_root() / "deploy" / "versions.env"
    if env_file.exists():
        print(env_file.read_text(encoding="utf-8"), end="")
    else:
        print(f"no versions.env at {env_file}; using library {__version__}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="aecpctl", description="AECP control plane")
    p.add_argument("--version", action="version", version=f"aecpctl {__version__}")
    sub = p.add_subparsers(dest="command", required=True)

    plan = sub.add_parser("plan", help="render systemd unit catalog")
    plan.add_argument("--dir", type=str, default=None, help="write unit files here")
    plan.set_defaults(func=cmd_plan)
    sub.add_parser("apply", help="install units + daemon-reload (Linux)").set_defaults(
        func=cmd_apply)
    sub.add_parser("start", help="start AECP target").set_defaults(func=cmd_start)
    sub.add_parser("stop", help="stop AECP units").set_defaults(func=cmd_stop)
    sub.add_parser("purge", help="remove all AECP units").set_defaults(func=cmd_purge)
    sub.add_parser("status", help="show unit states").set_defaults(func=cmd_status)
    h = sub.add_parser("health", help="probe component health endpoints")
    h.add_argument("--timeout", type=float, default=4.0)
    h.set_defaults(func=cmd_health)
    b = sub.add_parser("benchmark", help="L4 memory-plane benchmark")
    b.add_argument("--rows", type=int, default=2_000_000)
    b.set_defaults(func=cmd_benchmark)
    sub.add_parser("selftest", help="run pytest (non-integration)").set_defaults(
        func=cmd_selftest)
    sub.add_parser("versions", help="print pinned versions").set_defaults(
        func=cmd_versions)
    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    func: Callable[[argparse.Namespace], int] = args.func
    return func(args)


if __name__ == "__main__":
    raise SystemExit(main())
