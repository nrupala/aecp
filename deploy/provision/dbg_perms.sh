#!/bin/bash
ls -ld /home/ubuntu /home/ubuntu/aecp
echo '--- import test as aecp ---'
sudo -u aecp /opt/aecp/venv/bin/python -c 'import aecp; print("OK", aecp.__version__)' 2>&1 | tail -2
echo '--- uv python target perms ---'
readlink -f /opt/aecp/venv-superset/bin/python
ls -ld "$(dirname "$(readlink -f /opt/aecp/venv-superset/bin/python)")" 2>/dev/null
sudo -u aecp /opt/aecp/venv-superset/bin/python --version 2>&1 | tail -1