#!/bin/bash
grep -iE 'flask-caching|flask_caching' /opt/aecp/venv/lib/python3.12/site-packages/apache_superset-*.dist-info/METADATA | head -3
/opt/aecp/venv/bin/pip list 2>/dev/null | grep -iE 'flask|superset|pyarrow' | head -12