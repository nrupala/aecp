#!/bin/bash
sudo journalctl -u aecp-ozone-om --since '-6 min' --no-pager | grep -aE 'Exception|ERROR|Caused by' | head -8
echo '--- superset venv check ---'
ls -ld /opt/aecp/uv-python 2>/dev/null || echo 'uv-python dir missing'
cd /home/ubuntu/aecp && git log --oneline -1