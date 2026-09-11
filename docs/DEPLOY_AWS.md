# Deploy AECP on AWS (EC2)

1. Instance: Ubuntu 24.04 LTS (x86_64 or Graviton/arm64), t3.large / t4g.large
   minimum (8 GB RAM), 40 GB gp3 root volume.
2. User data (Advanced details > User data field): paste
   `deploy/cloud-init/aecp-bootstrap.yaml`.
3. Security group ingress: 22 (your IP), 8083/8088/8090/8847.
4. Verify after ~25 min:
   `ssh ubuntu@<ip> "/opt/aecp/venv/bin/aecpctl health && /opt/aecp/venv/bin/aecpctl benchmark"`

Notes: the same artifact works on both x86_64 and Graviton; the provision
script resolves JDK paths per architecture.