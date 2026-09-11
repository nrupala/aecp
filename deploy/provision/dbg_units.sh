#!/bin/bash
systemctl list-units --type=service 'aecp-*' --state=failed,activating --no-legend --no-pager
for u in aecp-pulsar aecp-solr aecp-superset aecp-guacamole aecp-guacd aecp-arrow-flight aecp-gateway; do
  echo "-- $u: $(systemctl is-active $u)"
  sudo journalctl -u "$u" -n 8 --no-pager | grep -avE '^--|Scheduled|Started ' | tail -3
done