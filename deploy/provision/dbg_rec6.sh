#!/bin/bash
systemctl is-active aecp-ozone-recon
PID=$(systemctl show -p MainPID --value aecp-ozone-recon)
echo "mainpid=$PID"
ps -o pid,pcpu,stat,cmd -p "$PID" | tail -2
sudo journalctl -u aecp-ozone-recon.service -n 14 --no-pager | grep -avE '^--' | tail -10