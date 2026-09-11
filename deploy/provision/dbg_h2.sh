#!/bin/bash
for u in aecp-ozone-om aecp-ozone-recon aecp-superset; do echo "$u: $(systemctl is-active $u)"; done
sudo ss -tlnp | grep -E ':(9862|9860|9863|9865|9872|8087)' || echo "om/superset ports missing"
echo '-- recon v6 probe --'
curl -s -m 4 -o /dev/null -w 'v6:%{http_code}\n' 'http://[::1]:9891/api/summary'
curl -s -m 4 -o /dev/null -w 'v4:%{http_code}\n' 'http://127.0.0.1:9891/api/summary'
echo '-- om journal tail --'
sudo journalctl -u aecp-ozone-om -n 6 --no-pager | grep -avE '^--' | tail -4
echo '-- superset journal tail --'
sudo journalctl -u aecp-superset -n 8 --no-pager | grep -avE '^--' | tail -5
echo '-- pulsar health now --'
curl -s -m 5 -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8091/admin/v2/brokers/health