#!/bin/bash
systemctl status aecp-ozone-scm.service --no-pager -l | head -8
echo "--- scm out tail ---"
tail -25 /var/lib/aecp/ozone/log/ozone-aecp-scm-aetheris-free-tier.out 2>/dev/null
echo "--- scm log errors ---"
grep -aE 'ERROR|Exception' /var/lib/aecp/ozone/log/ozone-aecp-scm-aetheris-free-tier.log 2>/dev/null | head -6