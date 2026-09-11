#!/bin/bash
grep -c 'FsspecFileIO' /opt/aecp/aecp-repo/aecp/storage/iceberg_io.py
sudo -u aecp /opt/aecp/venv/bin/python - <<'PY'
from aecp.storage import iceberg_io
cfg = iceberg_io.OzoneConfig(warehouse="s3a://aecpiceberg/aecp-warehouse4/")
cat = iceberg_io.make_catalog(cfg)
iceberg_io.ensure_namespace(cat, "telemetry")
t = iceberg_io.create_metrics_table(cat, "telemetry", "probe_io4")
print("table fileio:", type(t.io).__name__)
print("catalog props py-io-impl:", cat.properties.get("py-io-impl"))
PY