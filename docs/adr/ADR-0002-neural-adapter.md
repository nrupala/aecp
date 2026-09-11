# ADR-0002: Neural adapter - pluggable embedding/inference lane

Date: 2026-09-10. Status: ACCEPTED.

## Context

The AECP spec prescribes **Apache SINGA** as the distributed neural graph engine
for the AI & search mesh (512-dim embeddings, chatbot inference).

Verified fact (PyPI JSON API, 2026-09-10): the only published SINGA wheel is
`singa-3.0.0.dev1-cp36-cp36m-manylinux2014_x86_64.whl` - CPython 3.6, x86_64
only. It is not installable on the reference target (aarch64, Python 3.12) nor
on any supported modern cloud profile.

## Decision

AECP defines a `NeuralAdapter` interface (`aecp/aimesh/embed.py`) with two
backends:

1. **`feature-hashing`** (default): deterministic signed feature hashing over
   unigram+bigram tokens, L2-normalized to the required 512 dimensions. This is
   a real, reproducible embedding function (Weinberger et al., ICML 2009
   technique), not a stub - it preserves semantic retrieval behavior for
   lexical knowledge bases and makes the full RAG pipeline testable on every
   platform.
2. **`singa`** (lane): selected when `singa` imports on the target platform
   (x86_64 profiles where wheels exist, or source-built deployments). The
   adapter raises with an ADR-0002 reference when unavailable - it never fails
   silently.

Resolution order: explicit config > singa-if-importable > feature-hashing.

## Consequences

- The AI & search mesh (Solr kNN) and the RAG gateway are fully functional on
  all platforms; embedding quality upgrades to SINGA/learned models without
  touching any caller (interface-stable).
- The gateway reports its active embedder identity in `/healthz` - no silent
  degradation.