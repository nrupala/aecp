# ADR-0001: Orchestration layer - daemonless kernel-primitive launcher

Date: 2026-09-10. Status: ACCEPTED.

## Context

The AECP specification (docs/reference/) prescribes **Apache Mesos** as the
bare-metal orchestration layer with the mechanism: *"Bypasses Docker daemon;
utilizes direct Linux kernel primitives (cgroups/namespaces) over host
hardware"*, alongside **Apache YARN** for heavy analytical workloads.

Verified fact (mesos.apache.org, 2026-09-10): Apache Mesos **has retired to the
Apache Attic** ("This project has retired. For details please refer to its
Attic page"). It cannot be the foundation of a commercially deployable product.

## Decision

1. AECP L1 is implemented as the **daemonless `aecpd` launcher**: every component
   runs as a systemd unit inside the dedicated `aecp.slice` cgroup slice. This
   is the *exact mechanism* the AECP spec attributes to Mesos - direct Linux
   kernel primitives (cgroups/namespaces), no Docker daemon, no container
   runtime. The isolation model of the specification is preserved exactly.
2. **Apache YARN** (Hadoop 3.5.x, active ASF project) is retained as the
   optional heavy-analytics lane for multi-node/cloud profiles where MapReduce
   or YARN-scheduled workloads are required. It is not part of the single-node
   reference model (resource budget: ~1.7 GB RAM + 700 MB disk).
3. systemd is used as the kernel-primitive process supervisor. It is OS
   infrastructure (like the Linux kernel itself), not a runtime component of
   the platform; the platform components remain 100% Apache.

## Consequences

- The energy/isolation properties claimed by the AECP spec (no virtualization
  daemons) hold by construction.
- `aecpctl purge` provides a clean rollback path (units + dirs are namespaced).
- If Mesos is ever revived, the two-level-scheduling lane can be re-added
  behind the same unit namespace without touching component contracts.