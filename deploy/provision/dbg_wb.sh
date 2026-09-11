#!/bin/bash
sudo -u aecp /opt/aecp/venv/bin/python - <<'PY'
import s3fs
fs = s3fs.S3FileSystem(key='aecp', secret='aecp-secret', client_kwargs={'endpoint_url': 'http://127.0.0.1:9878'})
# binary write via open('wb') exactly like pyiceberg
try:
    with fs.open('/aecpiceberg/probe_wb.bin', 'wb') as f:
        f.write(b'binary hello')
    print('S3FS WB OK')
except Exception as e:
    print('S3FS WB FAIL:', str(e)[:160])
# many small writes (parquet-like pattern)
try:
    with fs.open('/aecpiceberg/probe_many.bin', 'wb') as f:
        for i in range(50):
            f.write(b'x' * 20)
    print('S3FS MANY-WRITES OK')
except Exception as e:
    print('S3FS MANY-WRITES FAIL:', str(e)[:160])
PY