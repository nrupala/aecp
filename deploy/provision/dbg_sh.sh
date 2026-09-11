#!/bin/bash
export TERM=dumb
export OZONE_HOME=/opt/aecp/apps/ozone JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
OZ=/opt/aecp/apps/ozone/bin/ozone
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ sh volume create /s3 2>&1 | tail -1
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ sh bucket create /s3/aecpiceberg 2>&1 | tail -1
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ sh bucket list /s3 2>&1 | tail -2
/opt/aecp/venv/bin/python -c "
import s3fs
fs = s3fs.S3FileSystem(key='aecp', secret='aecp-secret', client_kwargs={'endpoint_url':'http://127.0.0.1:9878'})
print('S3G buckets:', fs.ls('/'))"