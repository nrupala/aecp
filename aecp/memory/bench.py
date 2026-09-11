"""AECP memory-plane benchmark: measured evidence for the zero-copy claim.

Measures on the actual host:
- Arrow IPC write+read throughput (GB/s) for columnar payloads
- JSON row-encode+decode throughput for the same data (the "serialization tax")
- O(1) slice latency at two payload sizes (constant time => O(1) transit)

Outputs a JSON report consumed by e2e scripts and GATES evidence.
"""

from __future__ import annotations

import json
import platform
import time
from typing import Any

import pyarrow as pa
import pyarrow.ipc as ipc

from aecp.memory.fabric import make_batch


def _ipc_stream_gbps(rows: int, columns: int, trials: int = 5) -> float:
    batch = make_batch(rows, columns)
    payload_bytes = batch.num_rows * columns * 8
    t0 = time.perf_counter()
    for _ in range(trials):
        sink = pa.BufferOutputStream()
        w = ipc.new_stream(sink, batch.schema)
        w.write_batch(batch)
        w.close()
        reader = ipc.open_stream(pa.BufferReader(sink.getvalue()))
        reader.read_all()
    elapsed = time.perf_counter() - t0
    moved = float(payload_bytes) * trials * 2.0
    return float(moved / elapsed / 1e9)


def _json_roundtrip_gbps(rows: int, columns: int, trials: int = 2) -> float:
    import json as _json

    batch = make_batch(rows, columns)
    names = batch.schema.names
    t0 = time.perf_counter()
    for _ in range(trials):
        rows_data = [
            {n: batch.column(j)[i].as_py() for j, n in enumerate(names)}
            for i in range(rows)
        ]
        blob = _json.dumps(rows_data).encode("utf-8")
        _json.loads(blob)
    elapsed = time.perf_counter() - t0
    payload_bytes = rows * columns * 8 * trials
    return payload_bytes / elapsed / 1e9


def _slice_latency_ms(rows: int, trials: int = 200) -> float:
    batch = make_batch(rows)
    t0 = time.perf_counter()
    for _ in range(trials):
        batch.slice(rows // 2, 10)
    return (time.perf_counter() - t0) / trials * 1000.0


def run(rows: int = 2_000_000, columns: int = 4) -> dict[str, Any]:
    rows = min(rows, 4_000_000)
    report: dict[str, Any] = {
        "benchmark": "aecp.memory.bench",
        "platform": {
            "system": platform.system(),
            "machine": platform.machine(),
            "python": platform.python_version(),
        },
        "rows": rows,
        "columns": columns,
    }
    report["arrow_ipc_gbps"] = round(_ipc_stream_gbps(rows, columns), 3)
    report["json_roundtrip_gbps"] = round(_json_roundtrip_gbps(min(rows, 200_000), columns), 4)
    report["slice_o1_small_ms"] = round(_slice_latency_ms(1_000), 4)
    report["slice_o1_large_ms"] = round(_slice_latency_ms(rows), 4)
    report["o1_ratio"] = round(
        max(report["slice_o1_small_ms"], report["slice_o1_large_ms"])
        / max(min(report["slice_o1_small_ms"], report["slice_o1_large_ms"]), 1e-6),
        3,
    )
    return report


if __name__ == "__main__":
    import argparse

    ap = argparse.ArgumentParser(description="AECP memory-plane benchmark")
    ap.add_argument("--rows", type=int, default=2_000_000)
    ap.add_argument("--out", type=str, default=None)
    args = ap.parse_args()
    rep = run(rows=args.rows)
    text = json.dumps(rep, indent=2)
    print(text)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text)
