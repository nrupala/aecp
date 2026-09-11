#!/bin/bash
echo '--- dn jmx volume beans (raw) ---'
curl -s -m 5 'http://127.0.0.1:9882/jmx' | python3 -c "
import json,sys
d = json.load(sys.stdin)
for b in d.get('beans', []):
    n = b.get('name','')
    if 'Volume' in n or 'FSDataset' in n:
        keys = [k for k in b.keys() if 'apacit' in k or 'ree' in k.lower() or 'Used' in k]
        print(n, {k: b[k] for k in keys})
" 2>&1 | head -6
echo '--- dn data dir free ---'
df -BG /var/lib/aecp/ozone/dn-data | tail -1
ls -la /var/lib/aecp/ozone/dn-data/ 2>/dev/null | head -4