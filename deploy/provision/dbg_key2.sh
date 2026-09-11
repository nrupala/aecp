#!/bin/bash
export TERM=dumb OZONE_HOME=/opt/aecp/apps/ozone JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
OZ=/opt/aecp/apps/ozone/bin/ozone
echo '--- key list via om ---'
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ sh key list /s3v/aecpiceberg 2>&1 | grep -aE 'omtest|keyName|name' | head -3
echo '--- s3fs write now ---'
sudo -u aecp /opt/aecp/venv/bin/python - <<'PY'
import s3fs
fs = s3fs.S3FileSystem(key='aecp', secret='aecp-secret', client_kwargs={'endpoint_url': 'http://127.0.0.1:9878'})
try:
    with fs.open('/aecpiceberg/probe_small.txt', 'w') as f:
        f.write('hello aecp')
    print('SMALL WRITE OK:', fs.ls('/aecpiceberg'))
except Exception as e:
    print('SMALL WRITE FAIL:', type(e).__name__, str(e)[:120])
PY