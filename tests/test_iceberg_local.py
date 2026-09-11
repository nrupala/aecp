"""Iceberg storage tier tests against a local SqlCatalog + filesystem fileio.

Proves: table create, two appends -> >=2 snapshots, time travel returns the
first append's rows, snapshot freezing removes old snapshots, data lands in
the warehouse location (Ozone S3G in production; file:// here).
"""

import pathlib

import pytest

pyiceberg = pytest.importorskip("pyiceberg", reason="pip install aecp[storage]")

from aecp.storage import iceberg_io  # noqa: E402


def make_local_config(tmp_path: pathlib.Path) -> iceberg_io.OzoneConfig:
    return iceberg_io.OzoneConfig(
        s3_endpoint="http://127.0.0.1:9878",
        warehouse=f"file://{tmp_path.as_posix()}/warehouse/",
        catalog_db=str(tmp_path / "catalog.db"),
    )


def test_full_lifecycle(tmp_path):
    cfg = make_local_config(tmp_path)
    catalog = iceberg_io.make_catalog(cfg)
    iceberg_io.ensure_namespace(catalog, "telemetry")
    table = iceberg_io.create_metrics_table(catalog, "telemetry", "metrics_t")

    r1 = iceberg_io.append_and_count(table, iceberg_io.sample_metrics_table(10, 0))
    assert r1["rows"] == 10
    assert r1["snapshots"] == 1

    r2 = iceberg_io.append_and_count(table, iceberg_io.sample_metrics_table(5, 100))
    assert r2["rows"] == 15
    assert r2["snapshots"] == 2

    past = iceberg_io.time_travel_rows(table, snapshot_index=0)
    assert past.num_rows == 10

    current = iceberg_io.current_rows(table)
    assert current.num_rows == 15


def test_snapshot_freeze(tmp_path):
    cfg = make_local_config(tmp_path)
    catalog = iceberg_io.make_catalog(cfg)
    iceberg_io.ensure_namespace(catalog, "telemetry")
    table = iceberg_io.create_metrics_table(catalog, "telemetry", "metrics_f")
    iceberg_io.append_and_count(table, iceberg_io.sample_metrics_table(10, 0))
    iceberg_io.append_and_count(table, iceberg_io.sample_metrics_table(5, 100))
    assert len(table.snapshots()) == 2

    freeze = iceberg_io.freeze_snapshots(table, keep=1)
    assert freeze["expired"] == 1
    assert len(table.snapshots()) == 1
    assert iceberg_io.current_rows(table).num_rows == 15


def test_format_version_property(tmp_path):
    cfg = make_local_config(tmp_path)
    catalog = iceberg_io.make_catalog(cfg)
    iceberg_io.ensure_namespace(catalog, "telemetry")
    table = iceberg_io.create_metrics_table(catalog, "telemetry", "metrics_v")
    fv = iceberg_io.format_version(table)
    assert fv in ("2", "3")


def test_demo_end_to_end(tmp_path):
    cfg = make_local_config(tmp_path)
    report = iceberg_io.demo(cfg)
    assert report["second_append"]["rows"] == 15
    assert report["current_rows"] == 15
    assert report["freeze"]["expired"] >= 1
    assert report["time_travel_rows_snapshot0"] == 10
    assert report["location"].startswith("file://")
