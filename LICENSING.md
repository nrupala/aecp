# Licensing map — AECP

Copyright 2026 2351485 ALBERTA INC.

This file is the map; the licence text itself is [LICENSE](LICENSE)
(Apache-2.0). Commercial services are described in
[COMMERCIAL-LICENSE.md](COMMERCIAL-LICENSE.md) and
[docs/COMMERCIAL.md](docs/COMMERCIAL.md).

## What is under Apache-2.0

Everything in this repository is licensed under the **Apache License,
Version 2.0**. That includes the parts that are ours — the composition
layer:

- the deployment model (`deploy/` — bootstrap provisioning, cloud-init,
  version pins, systemd-unit approach),
- the integration and glue code (the `aecp/` package: spec, launcher,
  storage/streaming/memory/gateway modules),
- the tooling (`scripts/`, tests, ASFQC gate records),
- the documentation (`docs/`, ADRs, this file).

There is no separate commercial licence for the code, and no use of the
code in this repository requires one.

## What the commercial layer is

2351485 ALBERTA INC. offers paid **services** around AECP — certified cloud
deployments, managed deployment and operations, support tiers, and vertical
templates (see [COMMERCIAL-LICENSE.md](COMMERCIAL-LICENSE.md)). Those are
service engagements under separate written terms (and see
[TERMS.md](TERMS.md) for the product terms that govern the official packaged
version supplied by the Company). Services are the only thing we charge for;
they confer no exclusive rights in the software.

## Provenance note (what is NOT licensed here)

AECP deploys and configures Apache Software Foundation projects: Apache
Pulsar, Apache Flink, Apache Arrow, Apache Solr (Lucene), Apache Ozone,
Apache Iceberg, Apache Zeppelin, Apache Superset, Apache Guacamole, and
Apache Tomcat. **Those projects are not included in this repository and are
not licensed here** — they are downloaded from the Apache Software
Foundation's distribution channels at deployment time (pinned in
`deploy/versions.env`) and remain under their own Apache-2.0 licences. The
upstream attribution in [NOTICE](NOTICE) is preserved as-is. systemd unit
definitions are used as OS-level process management (systemd is
LGPL-2.1+; see NOTICE), not bundled as a component.

In short: the stack belongs to the Apache Software Foundation and its
contributors. What we own — and all we claim — is the way it is composed,
deployed, and operated here, and the services we perform around it.
