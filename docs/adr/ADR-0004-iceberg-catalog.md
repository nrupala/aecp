# ADR-0004: Iceberg catalog - SqlCatalog over Ozone S3, REST path defined

Date: 2026-09-10. Status: ACCEPTED.

## Context

The AECP spec prescribes **Apache Iceberg** tables over **Apache Ozone** object
vaults with snapshot freezing and automated cold-block migration. Ozone does
not ship an Iceberg REST catalog service.

## Decision

1. Reference model: PyIceberg `SqlCatalog` (SQLite metadata DB) with S3 fileio
   pointed at the **Ozone S3 Gateway** (`:9878`). Data files live in Ozone;
   metadata commits are ACID. This is a supported PyIceberg deployment pattern
   for single-node deployments.
2. Time travel reads a prior snapshot by ID; snapshot freezing expires old
   snapshots (metadata compaction), which migrates manifests to Ozone cold
   blocks through Ozone lifecycle policies when configured.
3. Commercial/multi-node upgrade path (documented, not implemented in v0.1):
   point the catalog at an Apache **Polaris**, Apache **Gravitino**, or Apache
   **Nessie** REST catalog. PyIceberg is REST-catalog-first, so this is a
   configuration change, not a code change.

## Consequences

- v0.1.0 tables are created with Iceberg `format-version=2` (verified via
  `table.metadata.format_version`). The v3 spec is supported by Iceberg engines
  (e.g., Spark 4.x); the product records the on-disk format version in its
  evidence output rather than overclaiming.
- SQLite metadata is for the single-node reference model only; production
  profiles MUST use a REST catalog (Polaris/Gravitino/Nessie).