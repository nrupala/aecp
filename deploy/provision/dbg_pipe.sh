#!/bin/bash
export TERM=dumb OZONE_HOME=/opt/aecp/apps/ozone JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
OZ=/opt/aecp/apps/ozone/bin/ozone
sudo grep -aE 'pipeline|Pipeline' /var/lib/aecp/ozone/log/ozone-aecp-scm-aetheris-free-tier.log 2>/dev/null | grep -aiE 'creat|fail|error|limit|allocat' | tail -5
echo '--- scm pipeline list ---'
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ admin pipeline list 2>&1 | tail -4
echo '--- trigger creation: restart om ---'
sudo systemctl restart aecp-ozone-om
sleep 40
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ admin pipeline list 2>&1 | tail -4