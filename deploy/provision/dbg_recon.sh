#!/bin/bash
sudo journalctl -u aecp-ozone-recon --since '-3 min' --no-pager | grep -aE 'ERROR|Exception|Started|Caused' | head -6
sudo ss -tlnp | grep 9891
curl -s -m 6 -o /dev/null -w 'v6:%{http_code}\n' 'http://[::1]:9891/api/summary'
curl -s -m 6 -o /dev/null -w 'v4:%{http_code}\n' 'http://127.0.0.1:9891/api/summary'