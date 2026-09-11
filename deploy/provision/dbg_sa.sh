#!/bin/bash
grep -iE '^Requires-Dist: (sqlalchemy|SQLAlchemy)' /opt/aecp/venv/lib/python3.12/site-packages/apache_superset-*.dist-info/METADATA
/opt/aecp/venv/bin/pip list 2>/dev/null | grep -iE '^SQLAlchemy|Flask-Caching'
echo '--- pip check summary (first conflicts) ---'
/opt/aecp/venv/bin/pip check 2>/dev/null | head -6