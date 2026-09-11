# ADR-0005: Release process

Date: 2026-09-10. Status: ACCEPTED.

## Decision

1. **Versioning**: SemVer (`MAJOR.MINOR.PATCH`). Version lives in
   `pyproject.toml` and `aecp/__init__.py` (single source: pyproject; the
   `__init__` value must match).
2. **Changelog**: `CHANGELOG.md`, Keep a Changelog format, one section per
   release.
3. **Tags**: `git tag -a v<semver>` on the release commit; tags must have
   passing CI. Releases: `v0.1.0` initial reference model.
4. **Artifacts**: the deployable artifact is the git repository itself
   (cloud-init clones it). Bootstrap reproducibility is guaranteed by pinned
   versions in `deploy/versions.env` + sha512 verification at download.
5. **Evidence**: every release requires the gate tracker (`ASFQC/GATES.md`)
   to show G0-G8 PASS with observed evidence at the release commit.

## Status of v0.1.0

Target: all gates PASS on the Oracle Cloud reference deployment (Aetheris).