#!/bin/bash
grep -a 'OZONE_OPTS' /etc/systemd/system/aecp-ozone-recon.service
PID=$(systemctl show -p MainPID --value aecp-ozone-recon)
tr '\0' '\n' < /proc/$PID/cmdline | grep -c 'preferIPv4Stack=true'
sudo journalctl -u aecp-ozone-recon.service -n 6 --no-pager | grep -avE '^--' | tail -4
sudo ss -tlnp | grep -E ':9891|:9890'