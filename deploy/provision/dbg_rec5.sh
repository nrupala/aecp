#!/bin/bash
sudo journalctl -u aecp-ozone-recon.service --since '-9 min' --no-pager | grep -avE '^--|systemd\[1\]' | head -14
echo '--- recon socket ---'
sudo ss -tlnp | grep -E ':(9890|9891)'