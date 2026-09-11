#!/bin/bash
export TERM=dumb OZONE_HOME=/opt/aecp/apps/ozone JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
OZ=/opt/aecp/apps/ozone/bin/ozone
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ admin pipeline create --replication-factor 1 2>&1 | tail -3
sleep 5
echo '--- pipeline list ---'
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ admin pipeline list 2>&1 | grep -aE 'Pipeline|FACTOR|OPEN|CLOSED' | head -6
echo '--- write test via OM ---'
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ sh key put /s3v/aecpiceberg/pipeprobe.txt /etc/hostname 2>&1 | tail -2
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ sh key list /s3v/aecpiceberg 2>&1 | grep -a pipeprobe | head -1