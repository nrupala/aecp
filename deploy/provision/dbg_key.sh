#!/bin/bash
export TERM=dumb OZONE_HOME=/opt/aecp/apps/ozone JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
OZ=/opt/aecp/apps/ozone/bin/ozone
echo 'test key content' > /tmp/aecp_test_key.txt
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ sh key put /s3v/aecpiceberg/omtest.txt /tmp/aecp_test_key 2>&1 | tail -3
echo '--- scm log tail after attempt ---'
sudo tail -60 /var/lib/aecp/ozone/log/ozone-aecp-scm-aetheris-free-tier.log 2>/dev/null | grep -aE 'pipeline|Pipeline|ERROR|node|Node|space|allocat' | tail -6
echo '--- scm current conf sanity (grep the LAST startup dump) ---'
sudo awk '/STARTUP_MSG/{n++} n>1' /var/lib/aecp/ozone/log/ozone-aecp-scm-aetheris-free-tier.log 2>/dev/null | grep -aoE 'ozone.scm.(client|datanode|block.client).port=[0-9]+|hdds.scm.safemode.min.datanode=[0-9]+|ozone.recon.address=[0-9.:]+' | head -5