# Deploy AECP on Azure (VM)

1. Create VM: Ubuntu 24.04 LTS, size D2s_v5 (x86_64) or D2ps_v5 (ARM), OS disk 40 GB Premium SSD.
2. User data: Azure CLI accepts cloud-init as customData:
   `az vm create ... --custom-data deploy/cloud-init/aecp-bootstrap.yaml`
3. NSG inbound: 22, 8083, 8087, 8090, 8847.
4. Verify: `ssh azureuser@<ip> "/opt/aecp/venv/bin/aecpctl health"`.