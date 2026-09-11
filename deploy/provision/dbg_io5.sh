#!/bin/bash
grep -c FsspecFileIO /opt/aecp/aecp-repo/aecp/storage/iceberg_io.py
sudo -u aecp /opt/aecp/venv/bin/python - <<'PY'
from aecp.storage import iceberg_io
cfg = iceberg_io.OzoneConfig(warehouse="s3a://aecpiceberg/aecp-warehouse8/")
cat = iceberg_io.make_catalog(cfg)
io = cat._load_file_io(cat.properties, "s3a://x/y")
print("fileio module:", type(io).__module__, type(io).__name__)
PY