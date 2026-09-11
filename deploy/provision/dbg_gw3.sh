#!/bin/bash
pgrep -fa 'SqlGateway' | head -2
ls -t /opt/aecp/apps/flink/log/ 2>/dev/null | head -4
sudo tail -8 /opt/aecp/apps/flink/log/flink-*-sql-gateway-*.log 2>/dev/null | grep -aE 'ERROR|Exception|Started|Bind|register' | head -5