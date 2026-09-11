#!/bin/bash
grep -a 'JAVA_HOME' /etc/systemd/system/aecp-solr.service
echo '--- solr journal full ---'
sudo journalctl -u aecp-solr.service -n 25 --no-pager | grep -avE '^--|Scheduled|systemd' | head -16