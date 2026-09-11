# AECP Commercial Model

AECP is Apache-2.0 licensed software. Commercial value is delivered through
deployment and operations, not license restrictions.

## What sells

1. **Certified cloud deployments.** The reference model (this repo) boots the
   full stack on any cloud from one cloud-init artifact. Certified profiles
   (per cloud, per instance family) carry measured evidence:
   throughput numbers, health checks, and gate-compliance artifacts.
2. **Support tiers.** Standard (best effort) and Enterprise (24h response,
   certified profile updates, security patching) support for operators running
   AECP.
3. **Vertical templates.** Pre-built Zeppelin notebooks, Superset dashboards,
   Solr retrieval corpora, and Flink SQL jobs per industry - packaged as
   importable AECP bundles.

## Honest boundaries

- The free reference model runs on a single node (this repo, as deployed on
  Oracle Cloud A1). Multi-node orchestration (YARN lane, Ozone replication,
  Solr Cloud mode) is configuration work, not product code, and is where
  certified profiles add value.
- Embedding quality on the default feature-hashing adapter is lexical-grade;
  commercial profiles can certify SINGA or other learned-model lanes on
  platforms where they run (ADR-0002).
- No SaaS billing infrastructure is part of this repository. Licensing is
  Apache-2.0; revenue comes from services around the software.