#!/bin/bash
ls /var/lib/aecp/ozone/log/ | grep -i om | head -4
sudo timeout 60 sudo -u aecp env OZONE_HOME=/opt/aecp/apps/ozone JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64 \
  /opt/aecp/apps/ozone/bin/ozone om --init 2>&1 | grep -aE 'ERROR|Exception|Caused by|version|Init' | head -10
echo '--- meta dir ---'
ls -la /var/lib/aecp/ozone/meta/ 2>/dev/null | head -8