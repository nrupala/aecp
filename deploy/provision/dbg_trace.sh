#!/bin/bash
sudo -u aecp /opt/aecp/venv/bin/python - <<'PY' 2>&1 | tail -25
import traceback
from aecp.storage import iceberg_io
cfg = iceberg_io.OzoneConfig(warehouse="s3a://aecpiceberg/aecp-warehouse3/")
try:
    cat = iceberg_io.make_catalog(cfg)
    iceberg_io.ensure_namespace(cat, "telemetry")
    t = iceberg_io.create_metrics_table(cat, "telemetry", "probe_tbl3")
    r = iceberg_io.append_and_count(t, iceberg_io.sample_metrics_table(3))
    print("APPEND OK:", r)
except Exception:
    traceback.print_exc()
PY