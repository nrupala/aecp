#!/bin/bash
echo "=== bootstrap procs ==="
pgrep -fa 'bootstrap.sh' | head -3
echo "=== pip procs ==="
pgrep -fa 'pip install|python3 -m pip' | grep -v grep | head -3
echo "=== log last 6 ==="
tail -6 /var/log/aecp-bootstrap.log
echo "=== superset version ==="
/opt/aecp/venv/bin/pip list 2>/dev/null | grep -iE '^apache.superset|Flask-Caching'