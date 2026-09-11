# AECP: The 100% Apache Enterprise Computing Platform

AECP is a **deployable system model** of a complete enterprise computing stack built
exclusively on Apache Software Foundation products — portable to any major cloud
(AWS, Azure, Google Cloud, Oracle Cloud, and others) with a single provider-neutral
bootstrap artifact and no container runtime.

```
L6  USER ACCESS          Zeppelin (notebooks) | Superset (dashboards) | Guacamole (HTML5 access)
    + INTELLIGENT UI     AECP Gateway (RAG chatbot: Solr kNN retrieval + neural adapter)
L5  AI & SEARCH MESH     Solr 10 (Lucene keyword + 512-dim kNN vector search)
L4  ZERO-COPY MEMORY     Arrow IPC/Flight fabric: O(1) transit, no serialization tax
L3  STREAMING FABRIC     Pulsar 4.0 LTS ingestion | Flink 2.2 stateful processing
L2  DECOUPLED STORAGE    Ozone 2.2 object vaults | Iceberg ACID tables (snapshot freeze + time travel)
L1  ORCHESTRATION        aecpd daemonless launcher: systemd transient units on cgroup slices
L0  HARDWARE             bare-metal CPU (GPU/NPU/TPU lanes reserved in spec)
```

## Why AECP

- **100% ASF**: every runtime component is an Apache product. No Docker, no container
  daemons — processes run directly on Linux kernel primitives (cgroups/namespaces)
  via systemd, exactly the isolation mechanism the AECP specification calls for.
- **Cloud-provider-neutral**: one `cloud-init` artifact boots AECP on AWS, Azure,
  GCP, and Oracle Cloud. Provider docs: `docs/`.
- **Measured, not marketed**: every capability ships with a repeatable test that
  prints its own evidence (throughput, latency, correctness). See `scripts/e2e/`.
- **Apache methodology**: gates G0–G8 tracked in `ASFQC/GATES.md` with recorded evidence.

## Quickstart (Oracle Cloud / Aetheris reference deployment)

```bash
git clone https://github.com/nrupala/aecp.git && cd aecp
sudo bash deploy/provision/bootstrap.sh        # installs JDK 17 + pinned ASF dists, configures, applies systemd units
aecpctl health                                  # verifies every layer
scripts/e2e/run_all.sh                          # full-stack evidence run
```

Cloud launch: paste `deploy/cloud-init/aecp-bootstrap.yaml` as user-data
(AWS), customData (Azure), startup-script (GCP), or user-data (Oracle Cloud).

## Component versions (pinned in `deploy/versions.env`)

| Layer | Component | Version |
|-------|-----------|---------|
| L1 | systemd launcher (aecpd) | system |
| L2 | Apache Ozone | 2.2.1 |
| L2 | Apache Iceberg (PyIceberg) | >=0.8 |
| L3 | Apache Pulsar (standalone) | 4.0.13 |
| L3 | Apache Flink (+ connector-pulsar) | 2.2.1 / 4.2.0 |
| L4 | Apache Arrow (pyarrow) | >=15 |
| L5 | Apache Solr | 10.0.0 |
| L5 | Neural adapter | pluggable (ADR-0002) |
| L6 | Apache Zeppelin | 0.12.1 |
| L6 | Apache Superset | latest stable (pip) |
| L6 | Apache Guacamole + Tomcat | 1.6.0 / 10.x (apt) |

## Verification

Each layer has a named test with recorded evidence in `ASFQC/GATES.md`:

- `pytest` — unit + memory-plane zero-copy proofs (runs anywhere)
- `scripts/e2e/run_all.sh` — streaming ingest→stateful→sink, Iceberg-over-Ozone
  snapshot freeze + time travel, Solr kNN retrieval, gateway RAG round-trip,
  Zeppelin/Superset/Guacamole health.

## Commercial deployment

`docs/COMMERCIAL.md` defines the packaging: free reference model (this repo),
certified cloud profiles, and support tiers. AECP is Apache-2.0 licensed;
commercial value is delivered through certified deployments and operations,
not license restrictions.

## Governance

- `docs/adr/` — architecture decision records (Mesos retirement, neural adapter,
  no-Docker kernel primitives, Iceberg catalog)
- `DEVELOPMENT_PROGRESS_TRACKER.md` — work log
- `ASFQC/GATES.md` — gate tracker with evidence