#!/bin/bash
sudo -u aecp /opt/aecp/venv/bin/python - <<'PY'
import s3fs
fs = s3fs.S3FileSystem(key='aecp', secret='aecp-secret', client_kwargs={'endpoint_url': 'http://127.0.0.1:9878'})
# small single-put write
with fs.open('/aecpiceberg/probe_small.txt', 'w') as f:
    f.write('hello aecp')
print('small write OK:', fs.ls('/aecpiceberg')[:3])
# multipart write (10MB)
import os
data = os.urandom(10 * 1024 * 1024)
try:
    with fs.open('/aecpiceberg/probe_10mb.bin', 'wb') as f:
        f.write(data)
    print('multipart write OK')
except Exception as e:
    print('multipart FAIL:', type(e).__name__, str(e)[:150])
PY