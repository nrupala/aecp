#!/bin/bash
export TERM=dumb OZONE_HOME=/opt/aecp/apps/ozone JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
OZ=/opt/aecp/apps/ozone/bin/ozone
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ admin datanode list 2>&1 | head -14
echo '--- scm heartbeat log ---'
sudo grep -aE 'Heartbeat|HEARTBEAT|node report|Registered' /var/lib/aecp/ozone/log/ozone-aecp-scm-aetheris-free-tier.log 2>/dev/null | tail -3
echo '--- dn main log tail ---'
sudo tail -6 /var/lib/aecp/ozone/log/ozone-aecp-datanode-aetheris-free-tier.log 2>/dev/null