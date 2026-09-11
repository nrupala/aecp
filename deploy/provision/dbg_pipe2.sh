#!/bin/bash
export TERM=dumb OZONE_HOME=/opt/aecp/apps/ozone JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
OZ=/opt/aecp/apps/ozone/bin/ozone
echo '--- recent scm pipeline lines ---'
sudo grep -aE 'Pipeline|pipeline' /var/lib/aecp/ozone/log/ozone-aecp-scm-aetheris-free-tier.log 2>/dev/null | tail -4
echo '--- recent scm errors ---'
sudo grep -aE 'ERROR' /var/lib/aecp/ozone/log/ozone-aecp-scm-aetheris-free-tier.log 2>/dev/null | tail -3
echo '--- pipeline list ---'
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ admin pipeline list 2>&1 | head -8