#!/bin/bash
export FLINK_PROPERTIES="sql-gateway.endpoint.rest.port: 8086"
timeout 40 /opt/aecp/apps/flink/bin/sql-client.sh -f /dev/stdin <<'SQL' 2>&1 | tail -3
SET 'execution.checkpointing.interval' = '2s';
SHOW TABLES;
SQL