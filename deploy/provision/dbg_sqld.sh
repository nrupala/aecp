#!/bin/bash
sudo -H timeout 40 /opt/aecp/apps/flink/bin/sql-client.sh -Dsql-gateway.endpoint.rest.enabled=false -f /dev/stdin <<'SQL' 2>&1 | tail -3
SHOW TABLES;
SQL