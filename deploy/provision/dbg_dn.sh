#!/bin/bash
export TERM=dumb OZONE_HOME=/opt/aecp/apps/ozone JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
OZ=/opt/aecp/apps/ozone/bin/ozone
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ admin datanode list 2>&1 | tail -3
echo '--- dn log registration ---'
sudo grep -aE 'Registered|register|Node is (not )?healthy|HEARTBEAT' /var/lib/aecp/ozone/log/ozone-aecp-datanode-aetheris-free-tier.log 2>/dev/null | tail -4
echo '--- dn dir ---'
ls -la /tmp/hadoop-aecp/dfs/data 2>/dev/null | head -3
sudo du -sh /tmp/hadoop-aecp 2>/dev/null
df -h /tmp | tail -1