#!/bin/bash
grep -iE '^Requires-Dist: (marshmallow|flask-appbuilder)' /opt/aecp/venv-superset/lib/python3.11/site-packages/apache_superset-5.0.0.dist-info/METADATA
/opt/aecp/venv-superset/bin/pip list 2>/dev/null | grep -iE 'marshmallow|appbuilder|apispec'
echo '--- flask-appbuilder metadata ---'
grep -iE '^Requires-Dist: marshmallow' /opt/aecp/venv-superset/lib/python3.11/site-packages/flask_appbuilder-*.dist-info/METADATA