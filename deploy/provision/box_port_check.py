#!/usr/bin/env python3
import re
import subprocess

out = subprocess.run(["ss", "-tlnp"], capture_output=True, text=True).stdout
ports = {}
for line in out.splitlines():
    m = re.search(r":(\d+)\s", line)
    p = re.search(r"\(\(\"([^\"]+)\"", line)
    if m:
        proc = p.group(1) if p else "?"
        ports.setdefault(int(m.group(1)), set()).add(proc)

print("PORTS IN USE:")
for p in sorted(ports):
    print(f"  {p:6} {','.join(sorted(ports[p]))}")

aecz = {6650, 8091, 3181, 2181, 8082, 6122, 6123, 8983, 9876, 9862, 9863,
        9864, 9878, 9888, 8083, 8087, 8090, 4822, 8847, 8815}
coll = sorted(set(ports) & aecz)
print("COLLISIONS:", coll if coll else "none")