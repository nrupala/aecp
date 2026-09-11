#!/bin/bash
curl -s 'http://127.0.0.1:9882/jmx?qry=Hadoop:service=DataNodeVolume*,name=Volume*' 2>/dev/null | python3 -c "
import json,sys
try:
    d = json.load(sys.stdin)
    for b in d.get('beans', []):
        print({k: b.get(k) for k in ('capacity','free','resourceUsedSpace','volumePath') if k in b})
except Exception as e:
    print('jmx parse fail', e)" | head -5
echo '--- scm jmx nodes ---'
curl -s 'http://127.0.0.1:9877/jmx?qry=Hadoop:service=SCMNode,name=SCMNodeInfo*' 2>/dev/null | python3 -c "
import json,sys
d = json.load(sys.stdin)
for b in d.get('beans', []):
    for k in ('Capacity','FreeSpaceToLeaveVolume','NodeCount','NodesInSpaceRequirement'):
        if k in b: print(k, b[k])
" | head -8