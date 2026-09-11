#!/bin/bash
sudo tail -25 /var/lib/aecp/ozone/log/ozone-aecp-om-*.log 2>/dev/null | grep -aE 'ERROR|Exception|Caused|error' | head -6
echo '--- recon probe again ---'
sudo ss -tlnp | grep 9891
curl -s -m 4 -o /dev/null -w 'v6:%{http_code}\n' 'http://[::1]:9891/'
echo '--- superset python link ---'
ls -l /opt/aecp/venv-superset/bin/python
ls -ld /opt/aecp/uv-python 2>/dev/null || echo "uv-python missing"
sudo -u aecp /opt/aecp/venv-superset/bin/gunicorn --version 2>&1 | head -1