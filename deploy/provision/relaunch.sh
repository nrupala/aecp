#!/bin/bash
cd /home/ubuntu/aecp && git pull --ff-only -q
# kill any orphan ozone JVMs holding ports
sudo pkill -f 'hdds.scm' 2>/dev/null
sudo pkill -f 'ozone' 2>/dev/null
sleep 3
sudo systemctl stop 'aecp-*' 2>/dev/null
sudo bash deploy/provision/bootstrap.sh 2>&1 | tail -14