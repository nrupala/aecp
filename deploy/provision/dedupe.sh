#!/bin/bash
pids=$(pgrep -f 'bash /home/ubuntu/aecp/deploy/provision/bootstrap.sh')
echo "pids: $pids"
n=$(echo $pids | wc -w)
if [ "$n" -gt 1 ]; then
  newest=$(echo $pids | tr ' ' '\n' | sort -n | tail -1)
  for p in $pids; do
    if [ "$p" != "$newest" ]; then sudo kill "$p" && echo "killed $p"; fi
  done
fi
sleep 2
pgrep -fa 'bootstrap.sh' | head -3
echo "single-or-none: $(pgrep -f 'bootstrap.sh' | wc -l)"