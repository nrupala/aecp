#!/bin/bash
systemctl is-active aecp-ozone-scm.service
ss -tlnp | grep -E ':(9876|9862)' || echo "no ozone ports"
echo "--- scm log tail ---"
tail -5 /var/lib/aecp/ozone/log/ozone-root-scm-*.log 2>/dev/null || ls /var/lib/aecp/ozone/log/ 2>/dev/null | head
echo "--- om init error head ---"
grep -aE 'OzoneManager|java.net.ConnectException|9876|SCM' /var/lib/aecp/ozone/log/ozone-om-init*.log 2>/dev/null | head -5
sudo -u aecp env OZONE_HOME=/opt/aecp/apps/ozone JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64 /opt/aecp/apps/ozone/bin/ozone om --init 2>&1 | grep -aE 'Exception|Connect|failed|OM Init' | head -6