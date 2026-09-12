"""Flink SQL Gateway REST driver (Flink 1.20)."""
from __future__ import annotations

import json
import time
import urllib.error
import urllib.request

GW = "http://127.0.0.1:8085"
JM = "http://127.0.0.1:8082"


def _req(method: str, path: str, payload: dict | None = None, timeout: int = 30):
    data = json.dumps(payload).encode() if payload is not None else None
    r = urllib.request.Request(
        GW + path, data=data, method=method,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(r, timeout=timeout) as resp:
            body = resp.read()
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as e:
        return {"_error": e.code, "_body": e.read().decode(errors="replace")}


def open_session() -> str:
    return _req("POST", "/v1/sessions")["sessionHandle"]


def submit(sid: str, statement: str) -> dict:
    return _req("POST", f"/v1/sessions/{sid}/statements", {"statement": statement})


def status(sid: str, op: str) -> dict:
    return _req("GET", f"/v1/sessions/{sid}/operations/{op}/status")


def result(sid: str, op: str, token: int = 0) -> dict:
    return _req("GET", f"/v1/sessions/{sid}/operations/{op}/result/{token}")


def jobs() -> list[dict]:
    try:
        with urllib.request.urlopen(f"{JM}/jobs", timeout=10) as r:
            return json.loads(r.read()).get("jobs", [])
    except Exception:  # noqa: BLE001
        return []


def running_job() -> dict | None:
    for j in jobs():
        if j.get("status") == "RUNNING":
            return j
    return None


def submit_insert(sid: str, statement: str, timeout: int = 60) -> str:
    op = submit(sid, statement)
    opid = op.get("operationHandle", op)
    deadline = time.time() + timeout
    while time.time() < deadline:
        s = status(sid, opid)
        if s.get("status") == "FINISHED":
            break
        if s.get("status") in ("ERROR", "CANCELED"):
            raise RuntimeError(f"insert {s}")
        if running_job():
            return running_job()["id"]
        time.sleep(2)
    return running_job()["id"] if running_job() else "done"
