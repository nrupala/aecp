# ADR-0003: No Docker - processes on kernel primitives only

Date: 2026-09-10. Status: ACCEPTED (standing policy).

## Context

AECP's energy claim ("39.7% total energy savings vs. virtualized/container
daemons") and its mechanism clause ("direct Linux kernel primitives") both
exclude container daemons. The operating policy for this environment also
prohibits Docker as a runtime/sandboxing dependency.

## Decision

1. **No Docker, Podman, containerd, or any container runtime** anywhere in the
   AECP stack - not for deployment, testing, or sandboxing.
2. All processes run as systemd units in the `aecp.slice` cgroup slice with
   `MemoryMax`, `CPUAccounting`, and `Restart` policies per component.
3. Isolation for untrusted code is achieved via OS-level primitives
   (users, cgroups, namespaces, filesystem permissions), never containers.

## Consequences

- Verified by test: `test_no_docker_anywhere` asserts no container-runtime
  reference exists in any rendered unit.
- Provisioning is `apt` + tarballs + systemd - works identically on every
  cloud's Ubuntu images (AWS, Azure, GCP, Oracle).