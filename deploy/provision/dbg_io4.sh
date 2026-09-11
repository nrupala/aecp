#!/bin/bash
sudo -u aecp /opt/aecp/venv/bin/python - <<'PY'
from aecp.storage import iceberg_io
cfg = iceberg_io.OzoneConfig(warehouse="s3a://aecpiceberg/aecp-warehouse7/")
cat = iceberg_io.make_catalog(cfg)
print("fileio:", type(cat._load_file_io(cat.properties, "s3a://x/y")))
print("props py-io-impl:", cat.properties.get("py-io-impl"))
r = iceberg_io.demo(cfg)
print("DEMO:", {k: r[k] for k in ("current_rows", "freeze", "format_version")})
PY