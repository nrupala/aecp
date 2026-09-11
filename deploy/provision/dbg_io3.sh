#!/bin/bash
sudo -u aecp /opt/aecp/venv/bin/python - <<'PY'
from aecp.storage import iceberg_io
cfg = iceberg_io.OzoneConfig(warehouse="s3a://aecpiceberg/aecp-warehouse5/")
cat = iceberg_io.make_catalog(cfg)
print("catalog props:", dict(cat.properties))
t = iceberg_io.create_metrics_table(cat, "telemetry", "probe_io5")
print("table fileio:", type(t.io).__name__)
PY