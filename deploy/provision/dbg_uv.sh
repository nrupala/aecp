#!/bin/bash
export PATH="$HOME/.local/bin:$PATH"
command -v uv || curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"
uv venv --python 3.11 /opt/aecp/venv-superset 2>&1 | tail -2
uv pip install --python /opt/aecp/venv-superset/bin/python "apache-superset==5.0.0" 2>&1 | tail -12