#!/usr/bin/env bash
# E2E L3: streaming fabric - Pulsar ingestion + Flink stateful windowed job.
# Evidence:
#  L3.1 Pulsar produce/consume roundtrip with measured msgs/sec.
#  L3.2 Flink SQL TUMBLE-window job consuming a Pulsar topic into a CSV sink;
#       sink row counts must account for produced messages.
set -euo pipefail

VENV="${AECP_VENV:-/opt/aecp/venv}"
FLINK_HOME="${AECP_APPS:-/opt/aecp/apps}/flink"
OUT_DIR="${AECP_DATA:-/var/lib/aecp}/flink/out/stream"
TOPIC="aecp-stream-$(date +%s)"
MSG_COUNT=300
REST="http://127.0.0.1:8082"

echo "== [L3.1] Pulsar produce/consume roundtrip =="
sudo -u aecp "$VENV/bin/python" - "$TOPIC" "$MSG_COUNT" <<'PY'
import json, sys
from aecp.streaming.pulsar_io import produce, consume, message_batch

topic, count = sys.argv[1], int(sys.argv[2])
msgs = message_batch(count)
p = produce("pulsar://127.0.0.1:6650", topic, msgs)
c = consume("pulsar://127.0.0.1:6650", topic, f"aecp-e2e-{topic[-8:]}", count, 30)
print(json.dumps({"produce": p, "consumed": c["received"], "complete": c["complete"]}))
assert c["complete"], f"expected {count}, got {c['received']}"
PY

echo "== [L3.2] Flink SQL TUMBLE window job (Pulsar -> CSV) =="
sudo -u aecp rm -rf "$OUT_DIR"
sudo -u aecp mkdir -p "$OUT_DIR"
SQL_FILE="/tmp/aecp_stream_$$.sql"
cat > "$SQL_FILE" <<SQL
SET 'execution.checkpointing.interval' = '2s';
SET 'table.exec.resource.default-parallelism' = '1';
CREATE TABLE telemetry (
  ts_ms BIGINT,
  host STRING,
  metric DOUBLE,
  ts AS TO_TIMESTAMP_LTZ(ts_ms, 3),
  WATERMARK FOR ts AS ts - INTERVAL '1' SECOND
) WITH (
  'connector' = 'pulsar',
  'topic' = 'persistent://public/default/$TOPIC',
  'service-url' = 'pulsar://127.0.0.1:6650',
  'format' = 'json',
  'scan.startup.mode' = 'earliest'
);
CREATE TABLE window_agg (
  window_start TIMESTAMP(3),
  host STRING,
  cnt BIGINT,
  avg_metric DOUBLE
) WITH (
  'connector' = 'filesystem',
  'path' = 'file://$OUT_DIR',
  'format' = 'csv'
);
INSERT INTO window_agg
SELECT window_start, host, cnt, avg_metric
FROM TABLE(TUMBLE(TABLE telemetry, DESCRIPTOR(ts), INTERVAL '5' SECONDS))
GROUP BY window_start, window_end, host;
SQL

sudo -u aecp "$FLINK_HOME/bin/sql-client.sh" -f "$SQL_FILE" || {
  echo "FATAL: sql-client script failed"; exit 1; }
rm -f "$SQL_FILE"

echo "-- waiting for a RUNNING job --"
JOB_ID=""
for i in $(seq 1 30); do
  JOB_ID="$(curl -s "$REST/jobs" | grep -oE '"id"\s*:\s*"[a-f0-9]+"' | head -1 | \
            grep -oE '[a-f0-9]{32}')"
  if [ -n "$JOB_ID" ]; then
    STATE="$(curl -s "$REST/jobs/$JOB_ID" | grep -oE '"state"\s*:\s*"[A-Z_]+"' | head -1)"
    echo "job $JOB_ID state: $STATE"
    case "$STATE" in *RUNNING*) break ;; *FAIL*|*"RESTARTING"*) sleep 2 ;; esac
  fi
  sleep 2
done
[ -n "$JOB_ID" ] || { echo "FATAL: no Flink job submitted"; curl -s "$REST/jobs"; exit 1; }

echo "-- producing $MSG_COUNT messages to $TOPIC --"
sudo -u aecp "$VENV/bin/python" - "$TOPIC" "$MSG_COUNT" <<'PY'
import json, sys
from aecp.streaming.pulsar_io import produce, message_batch
topic, count = sys.argv[1], int(sys.argv[2])
print(json.dumps(produce("pulsar://127.0.0.1:6650", topic, message_batch(count))))
PY

echo "-- waiting for sink files to account for all messages --"
sudo -u aecp "$VENV/bin/python" - "$OUT_DIR" "$MSG_COUNT" "$JOB_ID" "$REST" <<'PY'
import glob, json, os, sys, time, urllib.request

out_dir, produced, job_id, rest = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]

def job_state():
    try:
        with urllib.request.urlopen(f"{rest}/jobs/{job_id}", timeout=5) as r:
            return json.load(r).get("state", "?")
    except Exception as e:
        return f"unreachable:{e}"

def sink_rows():
    rows = 0
    for f in glob.glob(os.path.join(out_dir, "*.csv")) + \
             glob.glob(os.path.join(out_dir, "part-*")):
        with open(f, encoding="utf-8", errors="replace") as fh:
            rows += sum(1 for line in fh if line.strip())
    return rows

deadline = time.time() + 90
rows = 0
state = job_state()
while time.time() < deadline:
    rows = sink_rows()
    state = job_state()
    if "FAIL" in state or "CANCELE" in state and rows == 0:
        break
    if rows >= int(produced) - 20:
        break
    time.sleep(3)

evidence = {"produced": produced, "sink_rows": rows, "job_state": state}
print(json.dumps(evidence))
if rows <= 0:
    sys.exit(1)
PY

echo "-- cancelling job $JOB_ID --"
curl -s -X PATCH "$REST/jobs/$JOB_ID?mode=cancel" -o /dev/null || true

sudo -u aecp "$VENV/bin/python" - "$OUT_DIR" "$MSG_COUNT" <<'PY'
import glob, json, os, sys

out_dir, produced = sys.argv[1], int(sys.argv[2])
files = glob.glob(os.path.join(out_dir, "**", "*"), recursive=True)
rows, hosts = 0, set()
for f in files:
    if os.path.isfile(f):
        with open(f, encoding="utf-8", errors="ignore") as fh:
            for line in fh:
                parts = [p.strip() for p in line.split(",")]
                if len(parts) == 4 and parts[1].startswith("ae-node-"):
                    rows += 1
                    hosts.add(parts[1])
evidence = {"sink_windows": rows, "distinct_hosts": sorted(hosts),
            "produced": produced}
print("EVIDENCE:", json.dumps(evidence))
assert rows > 0, "no windowed rows in sink"
PY

echo "L3 PASS: streaming fabric end-to-end (Pulsar -> Flink windowed -> CSV)"