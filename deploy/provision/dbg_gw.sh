#!/bin/bash
export TERM=dumb
sudo -u aecp env OZONE_HOME=/opt/aecp/apps/ozone JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64 \
  timeout 25 /opt/aecp/apps/flink/bin/sql-gateway.sh start -Dsql-gateway.endpoint.rest.address=127.0.0.1 \
  -Dsql-gateway.endpoint.rest.port=8085 2>&1 | tail -3
sleep 6
curl -s -m 5 http://127.0.0.1:8085/v1/info | head -3
echo
curl -s -m 5 -X POST http://127.0.0.1:8085/v1/sessions -H 'Content-Type: application/json' -d '{}' | head -3