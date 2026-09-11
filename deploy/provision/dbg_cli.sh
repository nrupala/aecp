#!/bin/bash
export SUPERSET_CONFIG_PATH=/var/lib/aecp/superset/superset_config.py
cd /opt/aecp
/opt/aecp/venv-superset/bin/superset db upgrade 2>&1 | tail -6
echo "--- try 2: FLASK_APP set ---"
export FLASK_APP="superset.app:create_app()"
/opt/aecp/venv-superset/bin/superset db upgrade 2>&1 | tail -4