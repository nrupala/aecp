#!/bin/bash
ls /opt/aecp/venv-superset/lib/python3.11/site-packages/ | grep -iE 'appbuilder|marshmallow|superset' | head -8
/opt/aecp/venv-superset/bin/python - <<'PY'
import importlib.metadata as m
for pkg in ("apache-superset", "flask-appbuilder", "marshmallow", "apispec"):
    try:
        print(pkg := pkg, m.version(pkg))
    except Exception as e:
        print(pkg, "MISSING")
PY
/opt/aecp/venv-superset/bin/python -c "
import importlib.metadata as m
print([r for r in (m.requires('flask-appbuilder') or []) if 'arshmallow' in r])"