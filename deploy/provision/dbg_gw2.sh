#!/bin/bash
sudo -u aecp env OZONE_HOME=/opt/aecp/apps/ozone JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64 \
  nohup /opt/aecp/apps/flink/bin/sql-gateway.sh start \
  -Dsql-gateway.endpoint.rest.address=127.0.0.1 \
  -Dsql-gateway.endpoint.rest.port=8085 \
  > /var/lib/aecp/flink/sqlgw.log 2>&1 &
echo "gateway starting pid $!"
sleep 12
echo '--- info ---'
curl -s -m 5 http://127.0.0.1:8085/v1/info
echo
echo '--- session ---'
curl -s -m 5 -X POST http://127.0.0.1:8085/v1/sessions -H 'Content-Type: application/json' -d '{}'
echo