#!/bin/bash
sudo -u aecp /opt/aecp/venv/bin/python - <<'PY'
import s3fs
fs = s3fs.S3FileSystem(key='aecp', secret='aecp-secret',
                       client_kwargs={'endpoint_url': 'http://127.0.0.1:9878'})
try:
    fs.create_bucket('aecpiceberg')
    print('bucket created')
except Exception as e:
    print('create:', type(e).__name__, str(e)[:200])
print('buckets:', fs.ls('/'))
PY