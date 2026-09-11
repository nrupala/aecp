#!/bin/bash
sudo journalctl -u aecp-solr.service --since '-40 min' --no-pager | grep -avE '^--|Scheduled|systemd\[1\]' | head -12
echo '--- solr home ---'
ls /var/lib/aecp/solr/server/ | head -5