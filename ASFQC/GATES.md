# ASF Gate Tracker — AECP

> A gate is PASS only with recorded evidence (command + observed output/exit code).
> Updates are append-only; corrections are new rows.

Last updated: 2026-09-10

## Gate Status Matrix

| Gate | Description | Status | Evidence Command | Observed | Notes |
|------|-------------|--------|------------------|----------|-------|
| G0 | Build system | PASS | `pip install -e .` | exit 0; aecp installed, entry points created | pyproject.toml + hatchling |
| G1 | Repeatable test suite | PASS | `python -m pytest -m "not integration"` | exit 0; **42 passed** (2026-09-10) | unit suite; integration/e2e runs on box |
| G2 | Lint/typecheck | PASS | `ruff check aecp tests && mypy aecp` | exit 0; "All checks passed!" + "Success: no issues found in 20 source files" | ruff UP/B/SIM clean; mypy strict |
| G3 | License | PASS | LICENSE + NOTICE present | canonical Apache-2.0 text (11,358 bytes from apache.org) + NOTICE | |
| G4 | Contribution docs | PASS | CONTRIBUTING.md + CODE_OF_CONDUCT.md present | both present | |
| G5 | Reproducible install/run | PENDING | `sudo deploy/provision/bootstrap.sh && aecpctl health` on Aetheris | (to record) | idempotent + sha512-verified |
| G6 | Release process | PASS | SemVer + CHANGELOG.md + git tag strategy (docs/adr/ADR-0005) | v0.1.0 planned | |
| G7 | Governance | PASS | docs/adr/ ADR-0001..0005 | written | ADRs for Mesos/SINGA/no-Docker/catalog/releases |
| G8 | CI/CD | PENDING | .github/workflows/ci.yml on GitHub | (to record) | unit tests + lint + typecheck |

## Exemptions

| Date | Scope | User Rationale | Status |
|------|-------|----------------|--------|