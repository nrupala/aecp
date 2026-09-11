"""AECP streaming harness (L3): Pulsar ingestion for the fabric pipeline.

The e2e streaming proof uses two lanes:
1. This module: direct Python client produce/consume through Pulsar
   (proves the pubsub engine with precise timing evidence).
2. A Flink SQL job (deploy/provision writes the job script) consuming the
   same topic into a windowed filesystem sink (proves stateful processing).
"""

from __future__ import annotations

import json
import time
from collections.abc import Callable
from typing import Any

try:
    import pulsar  # type: ignore[import-not-found]
except ImportError as exc:  # pragma: no cover
    pulsar = None  # type: ignore[assignment]
    _IMPORT_ERROR: Exception | None = exc
else:
    _IMPORT_ERROR = None


def require_client() -> None:
    if pulsar is None:
        raise RuntimeError(
            "pulsar-client is not installed. Install with: pip install aecp[streaming]. "
            f"Original import error: {_IMPORT_ERROR}"
        )


def produce(service_url: str, topic: str, messages: list[dict[str, Any]],
            send_timeout_ms: int = 10_000) -> dict[str, Any]:
    """Produce JSON messages; returns measured evidence (msgs, elapsed, rate)."""
    require_client()
    client = pulsar.Client(
        service_url, operation_timeout_seconds=15,
        io_threads=2, message_listener_threads=2,
    )
    try:
        producer = client.create_producer(
            topic,
            send_timeout_millis=send_timeout_ms,
            batching_enabled=True,
            batching_max_messages=500,
        )
        t0 = time.perf_counter()
        for m in messages:
            producer.send(json.dumps(m).encode("utf-8"))
        elapsed = time.perf_counter() - t0
    finally:
        client.close()
    return {
        "topic": topic,
        "sent": len(messages),
        "elapsed_s": round(elapsed, 4),
        "msgs_per_sec": round(len(messages) / elapsed, 1),
    }


def consume(service_url: str, topic: str, subscription: str,
            expected: int, timeout_s: float = 30.0) -> dict[str, Any]:
    """Consume exactly `expected` messages; returns rows and timing evidence."""
    require_client()
    client = pulsar.Client(service_url, operation_timeout_seconds=15)
    rows: list[dict[str, Any]] = []
    try:
        consumer = client.subscribe(
            topic, subscription, initial_position=pulsar.InitialPosition.Earliest,
        )
        t0 = time.perf_counter()
        deadline = t0 + timeout_s
        while len(rows) < expected and time.perf_counter() < deadline:
            msg = consumer.receive(timeout_millis=500)
            rows.append(json.loads(msg.data().decode("utf-8")))
            consumer.acknowledge(msg)
        elapsed = time.perf_counter() - t0
        consumer.close()
    finally:
        client.close()
    return {
        "topic": topic,
        "received": len(rows),
        "expected": expected,
        "complete": len(rows) == expected,
        "elapsed_s": round(elapsed, 4),
        "msgs_per_sec": round(len(rows) / max(elapsed, 1e-9), 1),
        "rows": rows[:100],
    }


def message_batch(count: int, seed: int = 42) -> list[dict[str, Any]]:
    """Deterministic telemetry batch: host, metric, ts_ms."""
    out: list[dict[str, Any]] = []
    hosts = ["ae-node-1", "ae-node-2", "ae-node-3", "ae-node-4"]
    for i in range(count):
        out.append({
            "ts_ms": 1_700_000_000_000 + i,
            "host": hosts[i % len(hosts)],
            "metric": round(50.0 + ((i * 37 + seed) % 1000) / 10.0, 2),
        })
    return out


def wait_for_service(service_url: str, timeout_s: float = 60.0) -> bool:
    """True when Pulsar accepts a client connection (fail-fast for e2e)."""
    require_client()
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        try:
            client = pulsar.Client(service_url, operation_timeout_seconds=3)
            client.close()
            return True
        except Exception:
            time.sleep(1.0)
    return False


def topic_stats_url(service_url: str, topic: str) -> str:
    """Best-effort REST URL for the topic stats (standalone default port)."""
    base = service_url.replace("pulsar://", "http://").rsplit(":", 1)[0] + ":8091"
    return f"{base}/admin/v2/persistent/public/default/{topic}/stats"


def consumer_loop_until(service_url: str, topic: str, subscription: str,
                        predicate: Callable[[dict[str, Any]], bool],
                        timeout_s: float) -> list[dict[str, Any]]:
    """Consume until predicate matches or timeout; used by e2e verifications."""
    require_client()
    client = pulsar.Client(service_url, operation_timeout_seconds=15)
    seen: list[dict[str, Any]] = []
    try:
        consumer = client.subscribe(topic, subscription,
                                    initial_position=pulsar.InitialPosition.Earliest)
        deadline = time.time() + timeout_s
        while time.time() < deadline:
            msg = consumer.receive(timeout_millis=500)
            row = json.loads(msg.data().decode("utf-8"))
            consumer.acknowledge(msg)
            seen.append(row)
            if predicate(row):
                consumer.close()
                return seen
        consumer.close()
    finally:
        client.close()
    return seen
