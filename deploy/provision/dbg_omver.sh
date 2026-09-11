#!/bin/bash
ls -la /var/lib/aecp/ozone/log/ | tail -8
echo '--- om init stderr capture (60s bounded) ---'
sudo -u aecp env OZONE_HOME=/opt/aecp/apps/ozone JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64 \
  timeout 55 /opt/aecp/apps/ozone/bin/ozone om --init 2>&1 | tail -20