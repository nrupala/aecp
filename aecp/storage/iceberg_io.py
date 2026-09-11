"""AECP storage tier (L2): Iceberg ACID tables over Apache Ozone.

Catalog: PyIceberg SqlCatalog (SQLite metadata) with S3 fileio pointed at the
Ozone S3 Gateway. Data files land in Ozone; metadata commits are ACID.
Snapshot freezing (expire old snapshots) and time travel are first-class
operations here. REST-catalog upgrade path: ADR-0004.
"""

from __future__ import annotations

import contextlib
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any

import pyarrow as pa


@dataclass
class OzoneConfig:
    """Connection parameters for Ozone S3 Gateway-backed Iceberg."""

    s3_endpoint: str = "http://127.0.0.1:9878"
    warehouse: str = "s3a://aecp-iceberg/"
    catalog_db: str = "/var/lib/aecp/iceberg/catalog.db"
    access_key: str = "aecp"
    secret_key: str = "aecp-secret"
    region: str = "us-east-1"
    extra: dict[str, str] = field(default_factory=dict)

    def catalog_kwargs(self) -> dict[str, str]:
        return {
            "uri": f"sqlite:///{self.catalog_db}",
            "warehouse": self.warehouse,
            # fsspec/s3fs fileio pinned explicitly: single-put for small files.
            # (a) pyarrow S3 output streams always complete multipart uploads,
            # which Ozone S3 gateway rejects for zero-part payloads; (b) the
            # catalog DB persists py-io-impl, so the default must be overridden
            # explicitly to stay deterministic.
            "py-io-impl": "pyiceberg.io.fsspec.FsspecFileIO",
            "s3.endpoint": self.s3_endpoint,
            "s3.access-key-id": self.access_key,
            "s3.secret-access-key": self.secret_key,
            "s3.region": self.region,
            **self.extra,
        }


def make_catalog(config: OzoneConfig | None = None) -> Any:
    """Create a SqlCatalog (testable: file:// warehouse + local db)."""
    from pyiceberg.catalog.sql import SqlCatalog

    cfg = config or OzoneConfig()
    return SqlCatalog("aecp", **cfg.catalog_kwargs())


def ensure_namespace(catalog: Any, namespace: str = "telemetry") -> None:
    with contextlib.suppress(Exception):
        catalog.create_namespace(namespace)


METRICS_SCHEMA_FIELDS = [
    ("ts", pa.timestamp("us"), True),
    ("host", pa.string(), True),
    ("metric", pa.float64(), True),
]


def metrics_arrow_schema() -> pa.Schema:
    return pa.schema([
        pa.field("ts", pa.timestamp("us"), nullable=False),
        pa.field("host", pa.string(), nullable=False),
        pa.field("metric", pa.float64(), nullable=False),
    ])


def sample_metrics_table(count: int = 10, start_offset_s: int = 0) -> pa.Table:
    base = datetime(2026, 9, 10, 12, 0, 0)
    import datetime as _dt

    ts = [base + _dt.timedelta(seconds=start_offset_s + i) for i in range(count)]
    return pa.Table.from_arrays(
        [
            pa.array(ts, type=pa.timestamp("us")),
            pa.array([f"ae-node-{i % 4 + 1}" for i in range(count)]),
            pa.array([50.0 + i * 0.5 for i in range(count)], type=pa.float64()),
        ],
        schema=metrics_arrow_schema(),
    )


def format_version(table: Any) -> str:
    return str(table.metadata.format_version)


def create_metrics_table(catalog: Any, namespace: str = "telemetry",
                         table_name: str = "metrics",
                         format_version: int = 2) -> Any:
    from pyiceberg.schema import Schema
    from pyiceberg.types import DoubleType, NestedField, StringType, TimestampType

    schema = Schema(
        NestedField(1, "ts", TimestampType(), required=True),
        NestedField(2, "host", StringType(), required=True),
        NestedField(3, "metric", DoubleType(), required=True),
    )
    with contextlib.suppress(Exception):
        catalog.drop_table(f"{namespace}.{table_name}")
    return catalog.create_table(
        (namespace, table_name),
        schema=schema,
        properties={"format-version": str(format_version)},
    )


def append_and_count(table: Any, arrow_table: pa.Table) -> dict[str, int]:
    table.append(arrow_table)
    return {"rows": table.scan().to_arrow().num_rows,
            "snapshots": len(table.snapshots())}


def freeze_snapshots(table: Any, keep: int = 1) -> dict[str, Any]:
    """Expire all but the newest `keep` snapshots (snapshot freezing)."""
    snapshots = table.snapshots()
    if len(snapshots) <= keep:
        return {"expired": 0, "remaining": len(snapshots)}
    keep_ids = {s.snapshot_id for s in snapshots[-keep:]}
    expire_ids = [s.snapshot_id for s in snapshots if s.snapshot_id not in keep_ids]
    _expire(table, expire_ids)
    return {"expired": len(expire_ids), "remaining": len(table.snapshots())}


def _expire(table: Any, snapshot_ids: list[int]) -> None:
    """Version-tolerant snapshot expiry (pyiceberg 0.12 maintenance API, 0.8 legacy)."""
    try:
        exp = table.maintenance.expire_snapshots()
        exp.by_ids(snapshot_ids)
        exp.commit()
        return
    except AttributeError:
        pass
    try:
        exp = table.expire_snapshots()
        exp.snapshot_ids(snapshot_ids)  # type: ignore[attr-defined]
        exp.commit()
        return
    except (AttributeError, TypeError):
        pass
    try:
        table.expire_snapshots(snapshot_ids=snapshot_ids)
        return
    except (AttributeError, TypeError):
        pass
    raise RuntimeError("pyiceberg snapshot expiry API not matched; pin pyiceberg>=0.8")


def time_travel_rows(table: Any, snapshot_index: int = 0) -> pa.Table:
    """Read rows as of an earlier snapshot (proves time travel + cold blocks)."""
    snapshots = table.snapshots()
    if not snapshots:
        raise RuntimeError("table has no snapshots")
    snap = snapshots[max(0, min(snapshot_index, len(snapshots) - 1))]
    return table.scan(snapshot_id=snap.snapshot_id).to_arrow()


def current_rows(table: Any) -> pa.Table:
    return table.scan().to_arrow()


def demo(config: OzoneConfig | None = None) -> dict[str, Any]:
    """Full storage-tier demo used by e2e: create -> append x2 -> freeze -> travel."""
    catalog = make_catalog(config)
    ensure_namespace(catalog, "telemetry")
    table = create_metrics_table(catalog)
    r1 = append_and_count(table, sample_metrics_table(10, 0))
    r2 = append_and_count(table, sample_metrics_table(5, 100))
    before_rows = time_travel_rows(table, snapshot_index=0).num_rows
    freeze = freeze_snapshots(table, keep=1)
    after_rows = current_rows(table).num_rows
    return {
        "first_append": r1,
        "second_append": r2,
        "freeze": freeze,
        "time_travel_rows_snapshot0": before_rows,
        "current_rows": after_rows,
        "format_version": format_version(table),
        "location": str(table.location()),
    }
