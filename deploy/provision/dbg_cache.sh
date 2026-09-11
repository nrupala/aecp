#!/bin/bash
sed -n '200,235p' /opt/aecp/venv/lib/python3.12/site-packages/superset/utils/cache_manager.py
echo '=== metastore_cache.py ==='
sed -n '40,80p' /opt/aecp/venv/lib/python3.12/site-packages/superset/extensions/metastore_cache.py
echo '=== superset_config.py ==='
cat /var/lib/aecp/superset/superset_config.py