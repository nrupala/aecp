#!/bin/bash
# Clean-slate Ozone data reset: stop ozone units, wipe metadata+data, re-init
set -uo pipefail
sudo systemctl stop aecp-ozone-om aecp-ozone-datanode aecp-ozone-s3g aecp-ozone-recon aecp-ozone-scm 2>/dev/null
sleep 3
sudo rm -rf /var/lib/aecp/ozone/meta /var/lib/aecp/ozone/dn-data /tmp/hadoop-aecp
sudo mkdir -p /var/lib/aecp/ozone/meta /var/lib/aecp/ozone/dn-data /var/lib/aecp/ozone/log /var/lib/aecp/iceberg
sudo chown -R aecp:aecp /var/lib/aecp/ozone /var/lib/aecp/iceberg
sudo rm -f /var/lib/aecp/ozone/.scm-initialized /var/lib/aecp/ozone/.om-initialized
export OZONE_HOME=/opt/aecp/apps/ozone JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
OZ=/opt/aecp/apps/ozone/bin/ozone
grep -c 'hdds.datanode.dir' /opt/aecp/apps/ozone/etc/hadoop/ozone-site.xml
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ scm --init 2>&1 | tail -1 || true
sudo systemctl restart aecp-ozone-scm
for i in $(seq 1 40); do
  sudo ss -tln | grep -qE ':9860 ' && { echo "SCM up after ${i}x2s"; break; }
  sleep 2
done
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ om --init 2>&1 | tail -1 || true
sudo systemctl restart aecp-ozone-om aecp-ozone-datanode aecp-ozone-s3g aecp-ozone-recon
sleep 45
echo '--- datanode state ---'
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ admin datanode list 2>&1 | head -6
echo '--- write test ---'
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ sh key put /s3v/aecpiceberg/pipeprobe2.txt /etc/hostname 2>&1 | tail -2
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ sh key list /s3v/aecpiceberg 2>&1 | grep -ac pipeprobe2