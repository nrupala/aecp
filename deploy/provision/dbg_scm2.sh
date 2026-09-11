#!/bin/bash
export TERM=dumb OZONE_HOME=/opt/aecp/apps/ozone JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
OZ=/opt/aecp/apps/ozone/bin/ozone
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ admin safemode status 2>&1 | tail -2
echo '--- s3g log errors ---'
sudo grep -aE 'ERROR|Exception' /var/lib/aecp/ozone/log/s3g-*.log 2>/dev/null | tail -3
sudo tail -5 /var/lib/aecp/ozone/log/ozone-aecp-s3g-aetheris-free-tier.log 2>/dev/null | grep -aE 'ERROR|Exception|Caused' | tail -3
echo '--- datanode registered? ---'
sudo grep -aE 'Registered|Node reported|HEARTBEAT' /var/lib/aecp/ozone/log/ozone-aecp-datanode-aetheris-free-tier.log 2>/dev/null | tail -2
sudo grep -acE 'safemode' /var/lib/aecp/ozone/log/ozone-aecp-scm-aetheris-free-tier.log 2>/dev/null | head -1
sudo tail -5 /var/lib/aecp/ozone/log/ozone-aecp-scm-aetheris-free-tier.log | grep -aE 'SAFE|safemode|HEALTHY' | tail -2