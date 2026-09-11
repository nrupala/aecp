#!/bin/bash
export TERM=dumb OZONE_HOME=/opt/aecp/apps/ozone JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
OZ=/opt/aecp/apps/ozone/bin/ozone
sudo -u aecp env OZONE_HOME=$OZONE_HOME JAVA_HOME=$JAVA_HOME $OZ admin datanode list 2>&1 | head -10
echo '--- dn jmx volume stats ---'
curl -s -m 5 'http://127.0.0.1:9882/jmx' | python3 -c "
import json,sys
d = json.load(sys.stdin)
for b in d.get('beans', []):
    n = b.get('name','')
    if 'VolumeHealth' in n or 'Volume' in n and 'IOStats' not in n:
        print(n)
        for k in ('Capacity','Remaining','free','capacity','VolumePath','NumFailedVolumes'):
            if k in b: print('  ', k, b[k])
" 2>&1 | head -12
echo '--- dn volume dir now ---'
ls -la /var/lib/aecp/ozone/dn-data/ | head -4