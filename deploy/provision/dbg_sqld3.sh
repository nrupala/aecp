#!/bin/bash
sudo -H timeout 40 /opt/aecp/apps/flink/bin/sql-client.sh -Drest.bind-port=8086 -Drest.bind-port-range=8086-8090 -f /dev/stdin <<'SQL' 2>&1 | grep -aE 'Exception|Caused|No tables|Empty|0 rows' | head -3
SHOW TABLES;
SQL