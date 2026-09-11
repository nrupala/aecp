#!/usr/bin/env bash
# AECP full-stack E2E evidence run (execute on the target host).
# Usage: sudo bash scripts/e2e/run_all.sh
set -uo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
SUMMARY="/tmp/aecp_e2e_summary.json"
START="$(date +%s)"
declare -A RESULTS

run() {  # run <id> <script>
  local id="$1" script="$2"
  echo "=================================================================="
  echo " E2E $id"
  echo "=================================================================="
  if bash "$script"; then RESULTS[$id]="PASS"; else RESULTS[$id]="FAIL"; fi
  echo
}

run L2 "$DIR/e2e_storage.sh"
run L3 "$DIR/e2e_streaming.sh"
run L4 "$DIR/e2e_memory.sh"
run L5 "$DIR/e2e_aimesh.sh"
run L6 "$DIR/e2e_gateway.sh"

echo
echo "================= AECP E2E SUMMARY ================="
fails=0
for id in L2 L3 L4 L5 L6; do
  echo "  $id: ${RESULTS[$id]}"
  [ "${RESULTS[$id]}" = "FAIL" ] && fails=$((fails + 1))
done
echo "===================================================="
printf '{"L2":"%s","L3":"%s","L4":"%s","L5":"%s","L6":"%s","elapsed_s":%d}\n' \
  "${RESULTS[L2]}" "${RESULTS[L3]}" "${RESULTS[L4]}" "${RESULTS[L5]}" \
  "${RESULTS[L6]}" "$(( $(date +%s) - START ))" | tee "${AECP_DATA:-/var/lib/aecp}/e2e_summary.json"
[ "$fails" -eq 0 ]