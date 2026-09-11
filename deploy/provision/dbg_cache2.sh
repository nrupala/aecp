#!/bin/bash
sed -n '235,260p' /opt/aecp/venv/lib/python3.12/site-packages/superset/utils/cache_manager.py
echo '=== config defaults ==='
grep -rn "CACHE_CONFIG" /opt/aecp/venv/lib/python3.12/site-packages/superset/config.py | head -12