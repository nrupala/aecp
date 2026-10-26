#!/bin/bash
sudo -u aecp /opt/aecp/venv/bin/python - <<'PY'
import os
import s3fs
fs = s3fs.S3FileSystem(key='aecp', secret=os.environ['AECP_S3_SECRET_KEY'], client_kwargs={'endpoint_url': 'http://127.0.0.1:9878'})
try:
    with fs.open('/aecpiceberg/probe_s3fs_small.txt', 'w') as f:
        f.write('hello')
    print('S3FS SMALL OK')
except Exception as e:
    print('S3FS SMALL FAIL:', str(e)[:130])
import pyarrow.fs as pfs
s3 = pfs.S3FileSystem(endpoint_override='http://127.0.0.1:9878',
                      access_key='aecp', secret_key=os.environ['AECP_S3_SECRET_KEY'], region='us-east-1')
try:
    with s3.open_output_stream('aecpiceberg/probe_pa_small.txt') as out:
        out.write(b'hello pyarrow')
    print('PYARROW SMALL OK')
except Exception as e:
    print('PYARROW SMALL FAIL:', str(e)[:200])
PY