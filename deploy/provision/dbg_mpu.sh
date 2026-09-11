#!/bin/bash
sudo -u aecp /opt/aecp/venv/bin/python - <<'PY'
import inspect
import s3fs
sig = inspect.signature(s3fs.S3FileSystem.__init__)
names = [p for p in sig.parameters if 'part' in p or 'multipart' in p or 'block' in p]
print("s3fs ctor params:", names)
# how does pyiceberg map properties to storage options?
from pyiceberg.io import fsspec
src = inspect.getsource(fsspec.FsspecFileIO._initialize_fs) if hasattr(fsspec, 'FsspecFileIO') else 'no fsspec module'
print(src[:400])
PY
# larger multipart test now that pipelines exist
sudo -u aecp /opt/aecp/venv/bin/python - <<'PY'
import os
import s3fs
fs = s3fs.S3FileSystem(key='aecp', secret='aecp-secret', client_kwargs={'endpoint_url': 'http://127.0.0.1:9878'})
try:
    with fs.open('/aecpiceberg/probe_10mb.bin', 'wb') as f:
        f.write(os.urandom(10 * 1024 * 1024))
    print('10MB MULTIPART OK')
except Exception as e:
    print('10MB FAIL:', str(e)[:140])
PY