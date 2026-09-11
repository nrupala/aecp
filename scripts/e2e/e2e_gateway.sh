#!/usr/bin/env bash
# E2E L6: gateway RAG loop + Zeppelin/Superset/Guacamole interface health.
set -euo pipefail

GW="http://127.0.0.1:8847"

echo "== [L6.1] gateway health =="
curl -fsS "$GW/healthz" | tee /tmp/aecp_gw_health.json
echo

echo "== [L6.2] gateway RAG roundtrip (index -> chat) =="
sudo -u aecp python3 - <<'PY'
import json
import urllib.request

GW = "http://127.0.0.1:8847"

def post(path, payload):
    req = urllib.request.Request(
        f"{GW}{path}", json.dumps(payload).encode(),
        {"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())

docs = {"docs": [
    {"id": "gw-1", "title": "Onboarding: streaming",
     "body": "AECP ingests telemetry through Apache Pulsar and processes it "
             "with Apache Flink in sub-second windows."},
    {"id": "gw-2", "title": "Onboarding: storage",
     "body": "Results land as Apache Iceberg ACID tables on Apache Ozone "
             "object storage with time travel."},
]}
r = post("/v1/index", docs)
print("indexed:", r)

q = {"question": "where do streaming results get stored?"}
c = post("/v1/chat", q)
print("EVIDENCE_CHAT:", json.dumps(c))
assert "storage" in c["answer"].lower() or "Onboarding" in c["answer"], c["answer"]
PY

echo "== [L6.3] interfaces HTTP health =="
check() {  # check <name> <url>
  code="$(curl -s -o /dev/null -w '%{http_code}' -m 10 "$2" || true)"
  echo "$1: HTTP $code ($2)"
  [ "$code" -ge 200 ] && [ "$code" -lt 500 ]
}
check "zeppelin"  "http://127.0.0.1:8083/"
check "superset"  "http://127.0.0.1:8087/health"
check "guacamole" "http://127.0.0.1:8090/guacamole/"

echo "L6 PASS: gateway RAG loop + all three interfaces up"