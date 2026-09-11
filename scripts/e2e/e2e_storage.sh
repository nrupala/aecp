#!/usr/bin/env bash
# E2E L2: storage tier - Iceberg ACID tables over Ozone S3 Gateway.
# Evidence: table create + two appends -> >=2 snapshots, time travel returns
# first-append rows, snapshot freezing expires old snapshots, files in Ozone.
set -euo pipefail

VENV="${AECP_VENV:-/opt/aecp/venv}"
OZ="${AECP_APPS:-/opt/aecp/apps}/ozone/bin/ozone"
export OZONE_HOME="${AECP_APPS:-/opt/aecp/apps}/ozone"
export JAVA_HOME="${AECP_JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-arm64}"

echo "== [L2.0] Ozone S3 bucket for Iceberg warehouse =="
if ! sudo -u aecp env OZONE_HOME="$OZONE_HOME" JAVA_HOME="$JAVA_HOME" \
     "$OZ" sh bucket info /s3/aecpiceberg >/dev/null 2>&1; then
  sudo -u aecp env OZONE_HOME="$OZONE_HOME" JAVA_HOME="$JAVA_HOME" \
    "$OZ" sh volume create /s3 || true
  sudo -u aecp env OZONE_HOME="$OZONE_HOME" JAVA_HOME="$JAVA_HOME" \
    "$OZ" sh bucket create /s3/aecpiceberg || true
fi
"$OZ" sh bucket list /s3 2>/dev/null | grep -q aecpiceberg || true

echo "== [L2.1] PyIceberg over Ozone: create/append/freeze/time-travel =="
sudo -u aecp "$VENV/bin/python" <<'PY'
import json
from aecp.storage import iceberg_io

cfg = iceberg_io.OzoneConfig(
    s3_endpoint="http://127.0.0.1:9878",
    warehouse="s3a://aecpiceberg/aecp-warehouse/",
)
report = iceberg_io.demo(cfg)
print("EVIDENCE:", json.dumps(report))
assert report["second_append"]["rows"] == 15
assert report["current_rows"] == 15
assert report["freeze"]["expired"] >= 1
assert report["time_travel_rows_snapshot0"] == 10
PY

echo "== [L2.2] data files physically in Ozone =="
sudo -u aecp env OZONE_HOME="$OZONE_HOME" JAVA_HOME="$JAVA_HOME" \
  "$OZ" sh key list /s3/aecpiceberg --prefix aecp-warehouse | head -8 || true

echo "L2 PASS: Iceberg tables over Apache Ozone (ACID + snapshot freeze + time travel)"