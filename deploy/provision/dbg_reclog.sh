#!/bin/bash
sudo ls -t /var/lib/aecp/ozone/log/ | head -6
F=$(sudo ls -t /var/lib/aecp/ozone/log/ | grep -a recon | head -1)
echo "--- $F tail ---"
sudo tail -12 "/var/lib/aecp/ozone/log/$F" | grep -avE '^$' | tail -8