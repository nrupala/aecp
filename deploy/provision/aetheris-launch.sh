#!/bin/bash
# Deploy AECP on Aetheris from GitHub (launched detached per global rule 1)
set -uo pipefail
cd /home/ubuntu
if [ ! -d aecp ]; then
  git clone https://github.com/nrupala/aecp.git
else
  git -C aecp pull --ff-only
fi
sudo bash -c 'nohup bash /home/ubuntu/aecp/deploy/provision/bootstrap.sh > /var/log/aecp-bootstrap.log 2>&1 & echo "bootstrap PID: $!"'