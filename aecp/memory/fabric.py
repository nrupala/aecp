"""AECP Arrow memory plane: zero-copy IPC fabric.

Implements the L4 contract: O(1) transit between analytical tools by passing
direct memory references. Functions here prove the property with measurable
evidence (see bench.py and tests/test_fabric.py).
"""

from __future__ import annotations

import time
from typing import Any

import pyarrow as pa
import pyarrow.ipc as ipc


def make_batch(rows: int, columns: int = 4) -> pa.RecordBatch:
    """Build a deterministic float64 record batch (column-major)."""
    arrays = [
        pa.array([float(c * 1_000_000 + i) for i in range(rows)], type=pa.float64())
        for c in range(columns)
    ]
    return pa.RecordBatch.from_arrays(arrays, names=[f"col_{c}" for c in range(columns)])


def serialize_batch(batch: pa.RecordBatch) -> bytes:
    """Serialize a record batch to Arrow IPC bytes (off-heap friendly)."""
    sink = pa.BufferOutputStream()
    writer = ipc.new_stream(sink, batch.schema)
    writer.write_batch(batch)
    writer.close()
    buf = sink.getvalue()
    return bytes(buf)


def deserialize_zero_copy(data: bytes) -> pa.RecordBatch:
    """Deserialize IPC bytes without copying payloads (buffers are referenced)."""
    reader = ipc.open_stream(pa.BufferReader(data))
    table = reader.read_all()
    return table.to_batches()[0]


def o1_slice(batch: pa.RecordBatch, offset: int, length: int) -> pa.RecordBatch:
    """O(1) slice: zero-copy view over the same buffers."""
    return batch.slice(offset, length)


def measure_o1_slice(batch: pa.RecordBatch, trials: int = 1000) -> float:
    """Average ms for a slice over the full batch (statistically O(1))."""
    n = batch.num_rows
    t0 = time.perf_counter()
    for _ in range(trials):
        batch.slice(n // 2, 10)
    return (time.perf_counter() - t0) / trials * 1000.0


def roundtrip_ok(batch: pa.RecordBatch) -> bool:
    """True if IPC round-trip preserves values exactly."""
    back = deserialize_zero_copy(serialize_batch(batch))
    same = bool(back.num_rows == batch.num_rows and back.equals(batch))
    return same


def json_baseline_bytes(batch: pa.RecordBatch) -> bytes:
    """Row-major JSON encoding of the same data (the serialization tax)."""
    import json

    rows: list[dict[str, float]] = []
    names = batch.schema.names
    for i in range(batch.num_rows):
        rows.append({n: batch.column(j)[i].as_py() for j, n in enumerate(names)})
    return json.dumps(rows).encode("utf-8")


def as_table(batch: pa.RecordBatch) -> pa.Table:
    return pa.Table.from_batches([batch])


def record_overhead_report(batch: pa.RecordBatch) -> dict[str, Any]:
    ipc_bytes = len(serialize_batch(batch))
    json_bytes = len(json_baseline_bytes(batch))
    return {
        "rows": batch.num_rows,
        "columns": len(batch.schema.names),
        "ipc_bytes": ipc_bytes,
        "json_bytes": json_bytes,
        "compression_ratio": round(json_bytes / max(ipc_bytes, 1), 3),
    }
