#!/bin/bash
export TERM=dumb OZONE_HOME=/opt/aecp/apps/ozone JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
OZ=/opt/aecp/apps/ozone/bin/ozone
echo 'attempt write via OM (sh key put)'
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ sh key put /s3v/aecpiceberg/probe2.txt /etc/hostname 2>&1 | tail -2
echo '--- scm log LAST 4 lines ---'
sudo tail -4 /var/lib/aecp/ozone/log/ozone-aecp-scm-aetheris-free-tier.log 2>/dev/null
echo '--- s3g log LAST 2 errors ---'
sudo tail -6 /var/lib/aecp/ozone/log/ozone-aecp-s3g-aetheris-free-tier.log 2>/dev/null | grep -aE 'ERROR|Exception' | tail -2
echo '--- datanode view ---'
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ admin datanode list 2>&1 | head -8