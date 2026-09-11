# AECP Build Plan

Process: `[PLAN] -> [IMPLEMENT] -> [TEST] -> [QA/QC] -> [GATE REVIEW] -> [MERGE]`
(Global standing rule 21.) This file is append-only; corrections are new entries.

## Objective

Build the AECP (Apache Enterprise Computing Platform) stated in
`docs/reference/` as a **deployable, cloud-portable system model**: 100% ASF
components, no Docker, daemonless orchestration, one cloud-init bootstrap that
works on AWS/Azure/GCP/Oracle. Reference deployment target: Oracle Cloud ARM64
VM "Aetheris" (4 vCPU, 23 GB RAM, aarch64 Ubuntu).

## Phase 0 — PLAN (done 2026-09-10)

- Verify facts before design: Mesos retired to Attic (mesos.apache.org),
  SINGA wheels cp36/x86_64-only on PyPI (not viable on aarch64/py3.12),
  live version pins fetched from dlcdn.apache.org.
- ADRs written for every substitution/deviation (docs/adr/).
- Resource budget checked against target box: ~9.5 GB RSS across all services
  vs 15 GB available; ~10.5 GB disk vs 20 GB free.

Exit criteria: BUILD_PLAN present, ADRs recorded, versions pinned. **DONE.**

## Phase 1 — IMPLEMENT (core library)

Deliverables:

| Module | Scope |
|--------|-------|
| `aecp/spec.py` | Architecture-as-code: layers, components, ports, health URLs, SLA targets |
| `aecp/launcher/units.py` | systemd unit catalog (aecp.slice, pulsar, flink-jm/tm, solr, ozone×5, zeppelin, superset, gateway, flight) |
| `aecp/launcher/aecpd.py` | daemonless apply/start/stop/status/health via systemctl |
| `aecp/memory/fabric.py` | Arrow IPC zero-copy write/read + O(1) slice proof |
| `aecp/memory/flight.py` | Arrow Flight server/client data plane |
| `aecp/memory/bench.py` | throughput benchmark vs JSON baseline, JSON report |
| `aecp/streaming/pulsar_io.py` | Pulsar producer/consumer harness (optional dep) |
| `aecp/storage/iceberg_io.py` | PyIceberg over Ozone S3G: table create/append/freeze/time-travel |
| `aecp/aimesh/solr_io.py` | configset/collection creation, indexing, kNN query |
| `aecp/aimesh/embed.py` | NeuralAdapter: feature-hashing backend (+ SINGA lane, ADR-0002) |
| `aecp/gateway/app.py` | FastAPI RAG chatbot gateway (health, index, chat) |
| `aecp/cli/main.py` | aecpctl: plan/apply/start/stop/status/health/benchmark/selftest |

Exit criteria: `ruff check`, `mypy`, `pytest` all pass locally. Evidence recorded.

## Phase 2 — TEST (local)

Unit tests: spec integrity, unit rendering, Arrow zero-copy/O(1) proof,
embedding determinism + similarity ordering, Solr schema/query builders,
gateway endpoints with stubbed retrieval, Iceberg snapshot logic with local
SQL catalog + local filesystem fileio.

## Phase 3 — DEPLOY (cloud artifacts + Aetheris)

- `deploy/versions.env` (pinned, sha512-verified downloads)
- `deploy/provision/bootstrap.sh` — idempotent, fails loudly
- `deploy/cloud-init/aecp-bootstrap.yaml` — provider-neutral user-data
- Provider guides: Oracle/AWS/Azure/GCP
- GitHub repo `nrupala/aecp`, CI (G8), tag v0.1.0
- Aetheris: clone, provision, systemd services healthy. **Existing box
  services (oc-bridge, opencode, llama-router, aetheris-core, etc.) must remain
  undisturbed; no port collisions (verified: chosen ports 6650/8080-free/9000+
  ranges documented in spec).**

## Phase 4 — E2E EVIDENCE (on box)

`scripts/e2e/run_all.sh` executes: streaming (Pulsar→Flink windowed sink),
memory (benchmark + Flight round-trip), storage (Iceberg/Ozone snapshot freeze +
time travel), aimesh (Solr kNN), gateway (RAG chat), interfaces (Zeppelin,
Superset, Guacamole). Every result printed as machine-readable evidence.

## Phase 5 — GATE REVIEW + MERGE

All gates G0–G8 PASS with evidence in `ASFQC/GATES.md`; tracker updated;
decision log appended; tag `v0.1.0`.

## Rollback paths

- Provision script is additive under `/opt/aecp`, `/var/lib/aecp`, `/etc/aecp`,
  and unit namespace `aecp-*`; rollback = `aecpd purge` (removes units + dirs).
- No global system config is mutated beyond package installs and one
  `/etc/profile.d/aecp.sh` PATH fragment (documented, removable).