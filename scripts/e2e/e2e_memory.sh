#!/usr/bin/env bash
# E2E L4: memory plane - measured Arrow zero-copy evidence + Flight roundtrip.
set -euo pipefail

VENV="${AECP_VENV:-/opt/aecp/venv}"
REPORT="${AECP_DATA:-/var/lib/aecp}/memory_plane_report.json"

echo "== [L4.1] Arrow IPC throughput + O(1) slice proof =="
sudo -u aecp "$VENV/bin/python" -m aecp.memory.bench --rows 2000000 --out "$REPORT"
sudo -u aecp "$VENV/bin/python" - "$REPORT" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
print(f"arrow_ipc: {r['arrow_ipc_gbps']} GB/s | json: {r['json_roundtrip_gbps']} GB/s | "
      f"speedup: {round(r['arrow_ipc_gbps']/r['json_roundtrip_gbps'],1)}x | "
      f"O(1) slice: {r['slice_o1_small_ms']}ms vs {r['slice_o1_large_ms']}ms")
assert r["arrow_ipc_gbps"] >= 0.5, "arrow throughput below floor"
assert r["o1_ratio"] < 100, "slice latency not constant-time"
PY

echo "== [L4.2] Arrow Flight data plane roundtrip (service aecp-arrow-flight) =="
for i in $(seq 1 30); do
  if sudo -u aecp "$VENV/bin/python" -m aecp.memory.flight --roundtrip-test \
       --host 127.0.0.1 --port 8815 2>/dev/null; then
    echo "L4 PASS: zero-copy memory plane + Flight roundtrip"
    exit 0
  fi
  sleep 2
done
echo "FATAL: Flight roundtrip failed"
exit 1