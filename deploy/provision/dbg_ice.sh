#!/bin/bash
grep -c 'py-io-impl' /opt/aecp/aecp-repo/aecp/storage/iceberg_io.py || echo 'py-io-impl MISSING in deployed code'
sudo -u aecp /opt/aecp/venv/bin/python - <<'PY' 2>&1 | tail -6
from aecp.storage import iceberg_io
cfg = iceberg_io.OzoneConfig(warehouse="s3a://aecpiceberg/aecp-warehouse2/")
cat = iceberg_io.make_catalog(cfg)
iceberg_io.ensure_namespace(cat, "telemetry")
t = iceberg_io.create_metrics_table(cat, "telemetry", "probe_table")
t.append(iceberg_io.sample_metrics_table(3))
print("APPEND OK rows:", t.scan().to_arrow().num_rows)
PY