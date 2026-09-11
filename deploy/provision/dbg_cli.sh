#!/bin/bash
export OZONE_HOME=/opt/aecp/apps/ozone JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
OZ=/opt/aecp/apps/ozone/bin/ozone
$OZ --help 2>&1 | head -12
echo '--- admin try ---'
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ admin volume create s3 2>&1 | tail -2
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ admin volume create s3v 2>&1 | tail -1
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ admin bucket create s3v/aecpiceberg 2>&1 | tail -1
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ admin bucket list /s3v 2>&1 | tail -2