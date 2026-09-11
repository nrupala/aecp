#!/bin/bash
export TERM=dumb OZONE_HOME=/opt/aecp/apps/ozone JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
OZ=/opt/aecp/apps/ozone/bin/ozone
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ admin datanode list -ip 2>&1 | head -12
echo '--- dn logs present ---'
ls /var/lib/aecp/ozone/log/ | grep -a dn | head -4
echo '--- dn log register lines ---'
sudo grep -acE 'Registered' /var/lib/aecp/ozone/log/ozone-aecp-datanode-aetheris-free-tier.log 2>/dev/null
sudo grep -aE 'Node.*report|pipeline|Pipeline' /var/lib/aecp/ozone/log/ozone-aecp-datanode-aetheris-free-tier.log 2>/dev/null | tail -2