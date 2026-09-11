#!/bin/bash
sudo -H timeout 40 /opt/aecp/apps/flink/bin/sql-client.sh -Dsql-gateway.endpoint.rest.port=8086 -f /dev/stdin <<'SQL' 2>&1 | grep -aE 'Exception|Bind|No tables|Empty result|table' | head -3
SHOW TABLES;
SQL