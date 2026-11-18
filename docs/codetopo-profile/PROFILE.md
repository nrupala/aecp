# Codetopo Profile — AECP (nrupala/aecp)

**What this is.** The agent-facing map of this repository, generated with
Codetopo 0.9.1 (local engine, `~/.cargo/bin/codetopo`) so an arriving agent
can see the machine — topology, trust boundaries, money surface — before it
submits or changes anything. Read this first; the graph snapshot beside it
(`snapshot.json`, `stats.json`) is the measured evidence.

- **Repo:** nrupala/aecp
- **Commit profiled:** `613deb6a965821e214e666b63f43381879708066` (main)
- **Engine:** codetopo 0.9.1 · index run 2026-11-18
- **Graph:** 54 files walked · 0 failed · 674 nodes · 2002 edges · audit chain valid (3 entries, head `85d3194f…5eb17`)
- **Nodes by kind:** class 35 · doc 23 · external 299 · file 54 · function 144 · interface 1 · method 23 · module 54 · package 1 · variable 40
- **Edges by kind:** calls 669 · contains 374 · defines 68 · imports 112 · reads 736 · writes 43

## Coverage honesty

Codetopo extracts Rust, TypeScript/JavaScript and Python, plus Markdown
as Doc nodes. This repo's code is Python: the graph walks 54 files
(the `aecp/` package, `tests/`, `scripts/e2e/`, deploy helper) at full
symbol level. The 23 Markdown files are indexed as Doc nodes only.
**Not covered:** the 29 Shell scripts (`deploy/`, `scripts/` — the
provisioning and e2e evidence harness) are not parsed into the graph;
read them directly. `deploy/versions.env`, YAML/TOML/JSON config and
the ASFQC gate records are data/docs, not code — also not parsed.

## Topology

A deployable system model of an all-Apache enterprise stack
(README layer map L0–L6), with a small Python control package:

- `aecp/cli/main.py` — the `aecpctl` CLI entry point.
- `aecp/launcher/aecpd.py` + `units.py` — L1 orchestration: daemonless
  launcher generating systemd transient units on cgroup slices.
- `aecp/storage/iceberg_io.py` — L2 decoupled storage (Apache Iceberg /
  PyIceberg over Ozone).
- `aecp/streaming/pulsar_io.py` — L3 streaming fabric (Apache Pulsar);
  Flink SQL is driven from `scripts/e2e/flink_sql_rest.py`.
- `aecp/memory/fabric.py` + `flight.py` + `bench.py` — L4 zero-copy
  Arrow IPC/Flight fabric and its benchmarks.
- `aecp/aimesh/embed.py` + `solr_io.py` — L5 AI/search mesh (Solr kNN
  retrieval + pluggable neural adapter, ADR-0002).
- `aecp/gateway/app.py` — L6 intelligent UI: FastAPI app (`make_app`,
  L84) exposing `GET /healthz`, `POST /v1/index`, `POST /v1/chat`;
  `compose_answer` (L59) builds RAG answers from Solr hits.
- `aecp/spec.py` — the pinned component/version specification the
  gates check against. `tests/` (7 test modules) + `ASFQC/GATES.md`
  carry the G0–G8 evidence discipline.

## Trust boundaries

- **No credentials in the graph's code paths.** Configuration is by
  environment variable NAME only: `AECP_APPS`, `AECP_DATA`,
  `AECP_JAVA_HOME`, `AECP_REPO`, `AECP_USER`, `AECP_VENV` (path/layout
  settings, read via `os.getenv` in the launcher/spec code).
- **Trust boundary is the host, not the app:** provisioning runs as
  root via `deploy/provision/bootstrap.sh` and systemd; the gateway
  (`aecp/gateway/app.py`) exposes index/chat endpoints with no auth
  layer of its own in the profiled code — it assumes a trusted local /
  proxied deployment (Guacamole/Superset/Zeppelin provide the user
  access layer per the README). Do not expose the gateway publicly
  without adding that boundary.
- **Blast radius:** `aecp/spec.py` and the launcher unit generation
  (`units.py`) — a change there changes every deployed service.

## Money surface

No payment, billing, checkout or card surface exists in this repo:
greps for `stripe|paddle|checkout|billing` over all Python/JS/TS
sources return zero hits, and the graph's 112 import edges are
stdlib + Apache-stack libraries only. `docs/COMMERCIAL.md` states the
model explicitly: Apache-2.0 software, revenue from certified
deployments and support services around it, and "No SaaS billing
infrastructure is part of this repository." Cloud spend is the
operator's own (the stack boots on the operator's cloud account via
cloud-init); no code path in this repo charges anything.

## How an agent should approach

1. Read `README.md`, `BUILD_PLAN.md` and `ASFQC/GATES.md`, then this
   profile, then the snapshot.
2. Use codetopo queries against the snapshot before editing —
   especially around `spec.py`, the launcher and the gateway.
3. Run the repo's tests (`tests/`) and the relevant gate evidence
   scripts after any change; regenerate this profile (below) at every
   material change.
4. Never commit credentials or cloud account identifiers — env-var
   names and paths only.

## Regeneration

`docs/codetopo-profile/refresh.sh` (in this pack) re-downloads the repo
at a named ref, re-runs the index, and rewrites `snapshot.json`,
`stats.json` and the header block inputs of this profile. Regenerate at
every release / material change.
