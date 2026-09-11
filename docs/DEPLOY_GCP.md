# Deploy AECP on Google Cloud (Compute Engine)

1. Instance: e2-standard-2 (4 vCPU / 8 GB) or c4/t2a (Arm T2A for aarch64),
   Ubuntu 24.04 LTS, 40 GB pd-balanced.
2. Startup script (Metadata > startup-script key) or:
   `gcloud compute instances create aecp --metadata-from-file startup-script=deploy/cloud-init/aecp-bootstrap.yaml ...`
3. Firewall rules for 8083/8087/8090/8847.
4. Verify: `gcloud compute ssh aecp --command="/opt/aecp/venv/bin/aecpctl health"`.