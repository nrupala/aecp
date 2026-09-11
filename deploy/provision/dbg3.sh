#!/bin/bash
sed -n '260,290p' /opt/aecp/venv/lib/python3.12/site-packages/superset/utils/cache_manager.py
echo '=== metastore factory tail ==='
sed -n '80,100p' /opt/aecp/venv/lib/python3.12/site-packages/superset/extensions/metastore_cache.py