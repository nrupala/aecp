#!/bin/bash
echo '--- all SCM JVMs ---'
pgrep -fa StorageContainerManagerStarter | awk '{print $1}' | while read p; do
  echo "PID $p started $(ps -o lstart= -p $p)"
  tr '\0' '\n' < /proc/$p/cmdline | grep -c 'preferIPv4Stack=true' | xargs echo "  flag count:"
done
echo '--- sockets on 9876 ---'
sudo ss -tlnp | grep 9876
echo '--- tcp/9876 v4 listener probe ---'
timeout 3 bash -c 'echo > /dev/tcp/127.0.0.1/9876' 2>&1 && echo "v4 connect OK" || echo "v4 connect REFUSED"
timeout 3 bash -c 'echo > /dev/tcp/::1/9876' 2>&1 && echo "v6 connect OK" || echo "v6 connect REFUSED"