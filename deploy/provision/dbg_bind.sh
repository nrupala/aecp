#!/bin/bash
sudo systemctl stop aecp-ozone-scm.service
sleep 2
sudo pkill -9 -f 'ozone.scm\|StorageContainerManager' 2>/dev/null
sleep 2
sudo ss -tlnp | grep 9876 || echo "9876 free now"
sudo journalctl -u aecp-ozone-scm.service --since '30 min ago' --no-pager | grep -aE 'BindException|Address already' | head -3
echo "--- who held it? full listener snapshot at crash moment is gone; try starting and watching ---"
sudo systemctl start aecp-ozone-scm.service
for i in $(seq 1 45); do
  st=$(systemctl is-active aecp-ozone-scm.service)
  l=$(sudo ss -tln | grep -c ':9876 ')
  echo "t=$i state=$st listen9876=$l"
  [ "$l" -ge 1 ] && [ "$st" = "active" ] && break
  sleep 2
done
sudo ss -tlnp | grep 9876 || echo "STILL NOT LISTENING"
sudo journalctl -u aecp-ozone-scm.service -n 5 --no-pager | tail -5