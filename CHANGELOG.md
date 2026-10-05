# Changelog

All notable changes. Format based on Keep a Changelog; versioning: SemVer.

## [Unreleased]

### Added

- Portfolio certification rollout: PR-flow discipline in CONTRIBUTING.md
  (draft PR -> CI green -> owner merges; CHANGELOG entry + semver bump per PR;
  releases tagged vX.Y.Z). Signed-deploy survey: provisioning-only repo, no
  signed-wrapper target. License verified: Apache-2.0, NOTICE present.

## [0.1.0] - 2026-09-10

### Added

- Architecture-as-code spec (`aecp/spec.py`) covering all 7 AECP layers.
- Daemonless launcher `aecpd` + systemd unit catalog (no Docker anywhere).
- Arrow zero-copy memory plane: IPC fabric, O(1) slice proof, Flight server,
  throughput benchmark vs JSON baseline.
- Streaming harness for Pulsar 4.0 LTS ingestion and Flink 2.2 stateful jobs.
- Storage tier: PyIceberg tables over Apache Ozone S3 gateway with snapshot
  freezing and time travel.
- AI & search mesh: Solr 10 kNN collection tooling + pluggable neural adapter
  (feature-hashing default, SINGA lane documented).
- AECP Gateway: RAG chatbot API (health/index/chat) wired to Solr kNN.
- `aecpctl` CLI: plan/apply/start/stop/status/health/benchmark/selftest.
- Cloud-neutral bootstrap: `deploy/cloud-init/aecp-bootstrap.yaml` +
  idempotent provision script with sha512 verification.
- Provider guides: Oracle Cloud, AWS, Azure, Google Cloud.
- Full test suite (unit + integration harness) and CI workflow.