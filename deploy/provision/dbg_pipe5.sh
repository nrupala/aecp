#!/bin/bash
export TERM=dumb OZONE_HOME=/opt/aecp/apps/ozone JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
OZ=/opt/aecp/apps/ozone/bin/ozone
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ sh volume create /s3v 2>&1 | tail -1
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ sh bucket create /s3v/aecpiceberg 2>&1 | tail -1
sleep 5
echo '--- pipeline check ---'
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ admin pipeline list 2>&1 | grep -acE 'RATIS|STANDALONE'
echo '--- write test ---'
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ sh key put /s3v/aecpiceberg/pipeprobe2.txt /etc/hostname 2>&1 | tail -2
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ sh key list /s3v/aecpiceberg 2>&1 | grep -ac pipeprobe2
echo '--- s3fs write ---'
sudo -u aecp /opt/aecp/venv/bin/python -c "
import s3fs
fs = s3fs.S3FileSystem(key='aecp', secret='aecp-secret', client_kwargs={'endpoint_url': 'http://127.0.0.1:9878'})
with fs.open('/aecpiceberg/probe_small.txt', 'w') as f:
    f.write('hello aecp')
print('S3FS SMALL WRITE OK')"