# Privacy Policy — AECP

Copyright © 2026 2351485 ALBERTA INC.

_Last updated: 2026-10-26_

AECP (the 100% Apache Enterprise Computing Platform) is open-source software
published by **2351485 ALBERTA INC.** (operating as AIMLDS). This policy
states, plainly, what the software does with data. It covers the AECP
software in this repository — it does not cover third-party services you
choose to use alongside it.

## The short version

AECP deploys into **your own infrastructure**, under your control. The AECP
software itself **collects no telemetry, runs no usage analytics, and phones
nothing home**. It sends **no personal data — and no data of yours at all —
to 2351485 ALBERTA INC.**

## What happens inside a deployment

- Every network call the AECP code makes is between components of the same
  deployment (for example, the AECP Gateway talking to the deployment's own
  Apache Solr instance), at endpoints the operator configures.
- Data you put into a deployment — documents indexed for search, streams
  processed, tables stored, notebooks, dashboards, and user accounts in the
  deployed components — **stays in that deployment**, in storage the operator
  controls.
- The operator of a deployment (you, or whoever runs AECP for you) is the
  party responsible for that data and for meeting any privacy obligations
  that apply to it.

## The components AECP deploys

AECP deploys and configures Apache Software Foundation products (Pulsar,
Flink, Arrow, Solr, Ozone, Iceberg, Zeppelin, Superset, Guacamole, Tomcat).
Those are independent open-source projects with their own behaviour and
configuration; how they are configured and what they record in a given
deployment is set by the operator. AECP adds no data collection of its own
on top of them.

## When you contact us or engage us

- If you email us, we receive what you send (your address and the contents
  of your message) and use it to reply and to handle your enquiry.
- If you engage 2351485 ALBERTA INC. for certified deployment, managed
  operations, or support, any access to your systems or data happens only
  under that engagement's written terms.

## This repository

Viewing, cloning, or contributing to this repository happens on GitHub and
is governed by GitHub's own privacy policy, not this one.

## Contact

Privacy questions about AECP: **info@aimlds.org**
2351485 ALBERTA INC. (AIMLDS)
