#!/bin/bash
curl -s -m 5 'http://127.0.0.1:9882/jmx?qry=Hadoop:service=HddsDatanode,name=VolumeInfoMetrics-*' | python3 -c "
import json,sys
d = json.load(sys.stdin)
for b in d.get('beans', []):
    print(b.get('name'))
    for k in sorted(b.keys()):
        v = b[k]
        if isinstance(v,(int,float,str)) and k != 'name':
            print('  ', k, '=', v)
" | head -30