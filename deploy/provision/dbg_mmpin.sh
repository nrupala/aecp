#!/bin/bash
export SUPERSET_CONFIG_PATH=/var/lib/aecp/superset/superset_config.py
cd /opt/aecp
UV=/opt/aecp/venv/bin/uv
$UV pip install --python /opt/aecp/venv-superset/bin/python "marshmallow<4" "marshmallow-sqlalchemy<1.0" 2>&1 | tail -4
/opt/aecp/venv-superset/bin/superset db upgrade 2>&1 | tail -4