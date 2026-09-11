#!/bin/bash
sudo -H timeout 60 /opt/aecp/apps/flink/bin/sql-client.sh -Drest.bind-port=8086 -Drest.port=8086 -Drest.address=127.0.0.1 -Drest.bind-address=127.0.0.1 -f /dev/stdin <<'SQL' 2>&1 | grep -aE 'Exception|Caused|No tables|Empty|Schema|table name' | head -4
SHOW TABLES;
SQL