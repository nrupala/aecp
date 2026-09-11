# Deploy AECP on Oracle Cloud (Ampere A1 / x86)

Tested reference deployment: `ubuntu@147.224.174.50` (Aetheris), Ubuntu
aarch64, 4 OCPU / 23 GB RAM.

## Option A - instance with cloud-init (fresh VM)

1. Create instance (Ubuntu 22.04/24.04 aarch64 or x86_64).
2. At "Show advanced options > Management > User data": paste
   `deploy/cloud-init/aecp-bootstrap.yaml`.
3. Wait ~20-30 min (downloads ~3.5 GB of Apache distributions).
4. Verify:
   ```bash
   ssh ubuntu@<ip> "tail -5 /var/log/aecp-bootstrap.log"
   ssh ubuntu@<ip> "/opt/aecp/venv/bin/aecpctl health"
   ```

## Option B - existing VM (Aetheris)

```bash
git clone https://github.com/nrupala/aecp.git
sudo bash aecp/deploy/provision/bootstrap.sh
scripts/e2e/run_all.sh
```

## Security-group (OCI) ingress needed for external UI access

| Port | Service |
|------|---------|
| 8083 | Zeppelin |
| 8087 | Superset |
| 8090 | Guacamole |
| 8847 | AECP Gateway |

All internal service ports bind to localhost or are intentionally internal;
open only the four above for demo use (or keep everything loopback and
access via Guacamole/SSH).