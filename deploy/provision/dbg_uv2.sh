#!/bin/bash
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
command -v uv || echo "NO UV"
uv pip install --python /opt/aecp/venv-superset/bin/python "apache-superset==5.0.0" "gunicorn" 2>&1 | tail -8