#!/bin/bash
grep -c 'py-io-impl' /opt/aecp/aecp-repo/aecp/storage/iceberg_io.py
sudo -u aecp /opt/aecp/venv/bin/python - <<'PY'
import pyiceberg
print("pyiceberg", pyiceberg.__version__)
from aecp.storage import iceberg_io
cat = iceberg_io.make_catalog(iceberg_io.OzoneConfig(warehouse="s3a://aecpiceberg/aecp-warehouse2/"))
print("fileio:", type(cat.io).__name__)
PY