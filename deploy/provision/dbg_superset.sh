#!/bin/bash
export PATH="$HOME/.local/bin:$PATH"
if ! command -v rustc >/dev/null 2>&1 || [ "$(rustc --version 2>/dev/null | cut -d' ' -f2 | cut -d. -f1)" -lt 1 ] 2>/dev/null; then
  curl -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal 2>&1 | tail -2
fi
export PATH="$HOME/.cargo/bin:$PATH"
rustc --version
uv venv --python 3.11 --clear /opt/aecp/venv-superset 2>&1 | tail -1
uv pip install --python /opt/aecp/venv-superset/bin/python "apache-superset==5.0.0" "gunicorn" 2>&1 | tail -6