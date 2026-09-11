#!/bin/bash
export OZONE_HOME=/opt/aecp/apps/ozone JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
OZ=/opt/aecp/apps/ozone/bin/ozone
$OZ namespace --help 2>&1 | head -18
echo '--- namespace volume create ---'
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ namespace volume create s3 2>&1 | tail -1
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ namespace bucket create s3/aecpiceberg 2>&1 | tail -1
echo '--- verify ---'
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ namespace bucket list s3 2>&1 | tail -3
/opt/aecp/venv/bin/python -c "
import s3fs
fs = s3fs.S3FileSystem(key='aecp', secret='aecp-secret', client_kwargs={'endpoint_url':'http://127.0.0.1:9878'})
print('S3G buckets:', fs.ls('/'))"