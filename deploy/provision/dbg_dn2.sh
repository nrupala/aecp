#!/bin/bash
sudo grep -aE 'ERROR|Exception|Caused' /var/lib/aecp/ozone/log/ozone-aecp-datanode-aetheris-free-tier.log 2>/dev/null | tail -5
echo '--- dn journal ---'
sudo journalctl -u aecp-ozone-datanode.service -n 10 --no-pager | grep -avE '^--|systemd' | tail -6
echo '--- dn volumes ---'
sudo grep -aE 'Volume|storage|data.dir|hdds.datanode.dir' /var/lib/aecp/ozone/log/ozone-aecp-datanode-aetheris-free-tier.log 2>/dev/null | head -3