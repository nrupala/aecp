"""Flink SQL Gateway REST driver: submit statements, poll results.

Used by e2e_streaming (L3.2): creates the Pulsar source table, windowed
filesystem sink, and submits the INSERT; returns the job id.
"""

from __future__ import annotations

import json
import time
import urllib.request

GW = "http://127.0.0.1:8085"


def _post(path: str, payload: dict | None = None, timeout: int = 30) -> dict:
    data = json.dumps(payload).encode() if payload is not None else b"{}"
    req = urllib.request.Request(f"{GW}{path}", data,
                                 {"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())


def open_session() -> str:
    return _post("/v1/sessions")["sessionHandle"]


def submit(sid: str, statement: str) -> str:
    """Submit a statement; returns operationHandle for queries/DDL or job id."""
    r = _post(f"/v2/sessions/{sid}/statements", {"statement": statement})
    return r["operationHandle"]


def fetch_result(sid: str, op: str, token: int = 0, timeout: int = 120) -> dict:
    deadline = time.time() + timeout
    last: dict = {}
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(
                f"{GW}/v2/sessions/{sid}/operations/{sid}?token=0", timeout=10
            ) as r:
                last = json.loads(r.read())
                break
        except Exception as e:  # noqa: BLE001
            last = {"error": str(e)}
            time.sleep(1)
    return last


def fetch_rows(sid: str, oid: str, token: int = 0) -> dict:
    with urllib.request.urlopen(
        f"/v1/sessions/{sid}/operations/{sid}/result/{token}", timeout=30
    ) as r:
        return json.loads(r.read())


def submit_job(sid: str, statement: str, timeout: int = 60) -> str:
    """Submit an INSERT and return the Flink job id once submitted."""
    oid = submit(sid, statement)
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(
                f"/v1/sessions/{sid}/operations/{oid}/status", timeout=10
            ) as r:
                status = json.loads(r.read()).get("status")
            if status in ("FINISHED", "CANCELED", "ERROR"):
                raise RuntimeError(f"insert finished early: {status}")
            # poll flink REST for the running job
            with urllib.request.urlopen("http://127.0.0.1:8082/jobs", timeout=10) as r:
                jobs = json.loads(r.read()).get("jobs", [])
            running = [j for j in jobs if j.get("status") == "RUNNING"]
            if running:
                return running[0]["id"]
        except RuntimeError:
            raise
        except Exception:
            pass
        time.sleep(2)
    raise RuntimeError("job did not reach RUNNING state in time")