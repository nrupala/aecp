# Test plan — AECP

## Scope

Testing covers the `aecp/` package — the architecture-as-code spec, the Arrow
memory plane, the streaming and storage harnesses, and the gateway — plus the
repository's lint and typecheck gates. Integration tests (marked
`integration`, requiring live Apache components) are deliberately out of the
CI gate and run in deployment validation instead.

## Suites

| Suite | Covers | Run it | Runs in CI |
|---|---|---|---|
| Unit tests (pytest) | spec, memory fabric, gateway, embed, Iceberg-local, Solr schema, units — `tests/test_spec.py`, `test_fabric.py`, `test_gateway.py`, `test_embed.py`, `test_iceberg_local.py`, `test_solr_schema.py`, `test_units.py` | `pytest -m "not integration"` | Yes — aecp-ci |
| Lint (ruff) | `aecp/` and `tests/` (rule set in `pyproject.toml`) | `ruff check aecp tests` | Yes — aecp-ci |
| Typecheck (mypy) | the `aecp/` package | `mypy aecp` | Yes — aecp-ci |
| Memory-plane benchmark | Arrow fabric throughput evidence (1M rows) | `python -m aecp.memory.bench --rows 1000000` | Yes — aecp-ci |
| Static analysis (CodeQL) | the Python codebase | GitHub code scanning | Yes — CodeQL workflow |

## CI gates

- `aecp-ci` (`.github/workflows/ci.yml`, self-hosted Linux ARM64 runner) runs
  install, ruff, mypy, the unit suite and the benchmark on every push and pull
  request to `main`; all steps must pass before merge.
- CodeQL (`.github/workflows/codeql.yml`) runs on push and pull request to
  `main` and weekly; findings are dispositioned on the house SLA (Critical
  48 h, High 7 d, Medium 14 d — fix, or dismiss with the reason recorded).

## Cadence

- Every pull request: the full aecp-ci gate above.
- Weekly: the scheduled CodeQL scan.
- Every release candidate: the release-readiness run (checker + evidence
  reads), per the house Release-Readiness Standard.

## Coverage bar

No numeric floor; new functionality lands with tests per CONTRIBUTING.
