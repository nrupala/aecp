#!/bin/bash
export PATH="$HOME/.local/bin:$PATH"
apt-get install -y -qq cargo rustc >/dev/null 2>&1 || echo "apt rust failed"
uv venv --python 3.11 --clear /opt/aecp/venv-superset 2>&1 | tail -1
uv pip install --python /opt/aecp/venv-superset/bin/python "python-geohash==0.9.2" 2>&1 | tail -8