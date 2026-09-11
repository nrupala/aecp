#!/bin/bash
/opt/aecp/venv/bin/pip install --quiet "flask-caching==2.3.1" 2>&1 | tail -3
echo "--- retry superset app ---"
export SUPERSET_CONFIG_PATH=/var/lib/aecp/superset/superset_config.py
/opt/aecp/venv/bin/python -c "
from superset.app import create_app
app = create_app()
print('CREATE_APP_OK')
" 2>&1 | tail -5