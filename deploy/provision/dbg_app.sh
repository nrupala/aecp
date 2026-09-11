#!/bin/bash
export SUPERSET_CONFIG_PATH=/var/lib/aecp/superset/superset_config.py
cd /opt/aecp
/opt/aecp/venv-superset/bin/python -c "
from superset.app import create_app
app = create_app()
print('CREATE_APP_OK')
" 2>&1 | tail -8