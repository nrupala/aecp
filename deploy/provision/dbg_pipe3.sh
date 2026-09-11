#!/bin/bash
export TERM=dumb OZONE_HOME=/opt/aecp/apps/ozone JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
OZ=/opt/aecp/apps/ozone/bin/ozone
sudo grep -aE 'Creating pipeline|createPipeline|PipelineCreation|Unable to find|pipeline creation' /var/lib/aecp/ozone/log/ozone-aecp-scm-aetheris-free-tier.log 2>/dev/null | tail -4
echo '--- all scm log since 21:30, ERROR/Exception ---'
sudo awk '/2026-09-11 2[12]:/{p=1} p' /var/lib/aecp/ozone/log/ozone-aecp-scm-aetheris-free-tier.log 2>/dev/null | grep -aE 'ERROR|Exception|pipeline|Pipeline' | head -6
echo '--- try manual pipeline create via admin ---'
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ admin pipeline create --replicationConfig RATIS/ONE 2>&1 | tail -3