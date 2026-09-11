#!/bin/bash
export SUPERSET_CONFIG_PATH=/var/lib/aecp/superset/superset_config.py
export FLASK_APP="superset.app:create_app()"
cd /opt/aecp
/opt/aecp/venv-superset/bin/superset db upgrade 2>&1 | tail -3
echo "=== init ==="
/opt/aecp/venv-superset/bin/superset init 2>&1 | tail -3
echo "=== admin ==="
/opt/aecp/venv-superset/bin/superset fab create-admin -u admin -p dbgadminpass123 -f A -l E -e admin@aecp.local 2>&1 | tail -2