# Security Policy — AECP

Copyright © 2026 2351485 ALBERTA INC.

<!--
TEMPLATE STATUS: This file is the standing security policy template for AECP.
Keep it current: when a step below changes (contact, timelines, supported
versions), update this file in the same change that changes the practice.
It states our reporting instructions and our response plan — nothing here
is a guarantee of a specific outcome for a specific report.
-->

## Reporting a vulnerability

**Do not open a public issue for a security vulnerability.**

Report it privately:

- **Email:** info@aimlds.org with subject line `AECP SECURITY: <short summary>`
- **Please include:**
  1. A description of the issue and the impact you believe it has.
  2. The component and version (or commit) affected.
  3. Steps to reproduce, or a proof of concept, if you have one.
  4. Any suggested fix or mitigation, if you have one.
- You may report anonymously. If you want credit in the fix notes, say so
  and tell us the name to use.

If you do not receive an acknowledgement within **2 business days**, please
write again — mail goes missing, and we would rather hear twice than never.

## Our response plan

1. **Acknowledge** — within 2 business days of your report.
2. **Triage** — we assess severity and confirm whether the report reproduces,
   and tell you the result. If we cannot reproduce it, we will say what we
   tried and may ask for more detail.
3. **Fix, by severity** (targets, not promises):
   - Critical (remote compromise, credential or data exposure): fix work
     starts immediately; a release or mitigation as fast as the fix can be
     verified.
   - High: fix targeted within 30 days.
   - Medium / Low: fixed in the normal release flow, scheduled by impact.
4. **Coordinated disclosure** — we agree a disclosure date with the reporter
   (default: when the fix release is public, or 90 days after the report,
   whichever is sooner). We do not publish details before a fix or mitigation
   exists, and we ask reporters to do the same.
5. **Fix notes** — the release notes name the issue class and, with
   permission, credit the reporter.

## Scope

- In scope: the AECP code in this repository (the `aecp/` package, deploy
  tooling, and the gateway) at the latest release and on `main`.
- The Apache Software Foundation components AECP deploys (Pulsar, Flink,
  Solr, Ozone, Iceberg, and others) have their own security teams and
  advisories — report vulnerabilities in those projects to the ASF project
  directly. If an AECP deployment configuration weakens an upstream
  component's security, that part is ours and in scope.
- A deployment's data and credentials are the operator's responsibility
  (see PRIVACY.md). A report that depends on an operator having deployed
  with publicly exposed, unauthenticated services is a configuration
  finding — we still want to hear it if AECP's defaults or docs led there.

## Supported versions

AECP is pre-1.0. Security fixes land on `main` and in the latest release;
older snapshots are not patched separately. Operators should track the
latest release.

## Safe harbour

Good-faith security research that follows this policy — private report,
no data destruction, no privacy violation, no service disruption — is
welcome and will not be treated as hostile.
