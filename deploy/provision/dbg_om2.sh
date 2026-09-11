#!/bin/bash
systemctl is-active aecp-ozone-scm.service
ss -tlnp | grep -E ':(9876|9862|9863)' || echo "no ozone ports listening"
echo "--- om init with timeout ---"
timeout 90 sudo -u aecp env OZONE_HOME=/opt/aecp/apps/ozone JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64 \
  /opt/aecp/apps/ozone/bin/ozone om --init 2>&1 | grep -aE 'Exception|Connect|Failed|OM Init|ERROR' | head -8
echo "--- latest om log ---"
ls -t /var/lib/aecp/ozone/log/ | head -5