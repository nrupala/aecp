#!/bin/bash
sudo journalctl -u aecp-ozone-recon --since '-4 min' --no-pager | grep -avE '^--|Scheduled|systemd\[1\]' | tail -14