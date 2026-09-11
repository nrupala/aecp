# Contributing to AECP

Thanks for your interest in contributing. AECP follows the Apache Software
Foundation methodology.

## Ground rules

1. **No half-baked deliverables.** Work is done when it is tested, documented,
   installable, and free of placeholders. If it cannot be finished, say so
   rather than shipping a stub.
2. **Every change ships with a test.** A failing test means the change is wrong:
   fix the root cause, rerun, and loop until green. Never disable a failing test.
3. **Evidence over claims.** Gate status (`ASFQC/GATES.md`) requires the evidence
   command and the observed output. A pass must be observed, never assumed.
4. **100% ASF components.** Runtime components must be Apache products.
   Deviations require a written ADR in `docs/adr/`.
5. **No Docker.** Processes run on kernel primitives via systemd units.
6. **Secrets never enter the repository.** Configuration accepts environment
   variables; provisioned credentials are generated on the target host.

## Development flow

```bash
pip install -e .[dev]
ruff check aecp tests
mypy aecp
pytest
```

Update `DEVELOPMENT_PROGRESS_TRACKER.md` with a dated entry for every
deliverable, and `ASFQC/GATES.md` when a gate changes state.

## Pull requests

- One logical change per PR; describe the verification performed.
- New behavior requires new tests; regressions must keep their red/green proof.
- Branches: `feat/<topic>`, `fix/<topic>`, `docs/<topic>`.