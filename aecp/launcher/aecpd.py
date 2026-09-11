"""aecpd: apply and control AECP systemd units (daemonless orchestration)."""

from __future__ import annotations

import platform
import subprocess
import sys
from pathlib import Path

from aecp.launcher.units import Paths, render_units
from aecp.spec import Component, deployment_components

SYSTEMCTL = "systemctl"
UNIT_DIR = Path("/etc/systemd/system")


def _require_linux() -> None:
    if platform.system() != "Linux":
        raise RuntimeError(
            "aecpd controls systemd units and only runs on Linux. "
            "On development machines use: aecpctl plan (render) / aecpctl selftest."
        )


def _run(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess[str]:
    proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if check and proc.returncode != 0:
        raise RuntimeError(
            f"command failed ({proc.returncode}): {' '.join(cmd)}\n"
            f"stdout: {proc.stdout}\nstderr: {proc.stderr}"
        )
    return proc


def apply(units: dict[str, str] | None = None, unit_dir: Path | None = None) -> list[str]:
    """Write unit files and reload systemd. Returns written paths."""
    _require_linux()
    from aecp.launcher.units import paths_from_env

    contents = units or render_units(paths_from_env())
    d = unit_dir or UNIT_DIR
    written: list[str] = []
    for name, text in contents.items():
        path = d / name
        path.write_text(text, encoding="utf-8")
        written.append(str(path))
    _run([SYSTEMCTL, "daemon-reload"])
    return written


def start(unit: str) -> None:
    _require_linux()
    _run([SYSTEMCTL, "enable", "--now", unit])


def stop(unit: str) -> None:
    _require_linux()
    _run([SYSTEMCTL, "stop", unit], check=False)


def is_active(unit: str) -> bool:
    _require_linux()
    proc = _run([SYSTEMCTL, "is-active", unit], check=False)
    return proc.stdout.strip() == "active"


def status() -> dict[str, str]:
    _require_linux()
    states: dict[str, str] = {}
    for name in render_units():
        if name in ("aecp.slice", "aecp.target"):
            continue
        proc = _run([SYSTEMCTL, "is-active", name], check=False)
        states[name] = proc.stdout.strip() or "unknown"
    return states


def purge() -> None:
    """Stop, disable and remove all AECP units (rollback path)."""
    _require_linux()
    contents = render_units()
    for name in contents:
        _run([SYSTEMCTL, "stop", name], check=False)
        _run([SYSTEMCTL, "disable", name], check=False)
        (UNIT_DIR / name).unlink(missing_ok=True)
    _run([SYSTEMCTL, "daemon-reload"])


def health_checks(components: dict[str, Component] | None = None,
                  timeout: float = 4.0) -> dict[str, bool]:
    """HTTP-probe every component with a health URL."""
    import requests

    comps = components or deployment_components()
    results: dict[str, bool] = {}
    for name, comp in comps.items():
        if not comp.health_url:
            results[name] = bool(is_active(comp.unit))
            continue
        try:
            r = requests.get(comp.health_url, timeout=timeout)
            results[name] = r.status_code < 500
        except requests.RequestException:
            results[name] = False
    return results


def main(argv: list[str] | None = None) -> int:
    argv = argv if argv is not None else sys.argv[1:]
    cmd = argv[0] if argv else "status"
    try:
        if cmd == "apply":
            paths = Paths()
            for d in (paths.data, ):
                Path(d).mkdir(parents=True, exist_ok=True)
            written = apply()
            for w in written:
                print(f"wrote {w}")
            return 0
        if cmd == "start":
            for name in render_units():
                _run([SYSTEMCTL, "enable", "--now", name], check=False)
            return 0
        if cmd == "stop":
            for name in render_units():
                _run([SYSTEMCTL, "stop", name], check=False)
            return 0
        if cmd == "status":
            for unit, state in status().items():
                print(f"{state:>8}  {unit}")
            return 0
        if cmd == "purge":
            purge()
            print("purged")
            return 0
        print(f"unknown command: {cmd}", file=sys.stderr)
        return 2
    except RuntimeError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
