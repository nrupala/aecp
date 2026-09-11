"""AECP neural adapter (L5).

ADR-0002: Apache SINGA is the specified neural engine, but its published
PyPI wheels (3.0.0.dev1) are CPython 3.6 x86_64 only - unusable on modern
targets (aarch64, py3.10+). The adapter is therefore pluggable:

- ``singa`` backend: selected automatically when singa imports successfully
  (supported cloud profiles, documented in docs/COMMERCIAL.md).
- ``feature-hashing`` backend: deterministic signed feature hashing with
  unigram+bigram tokens, L2-normalized. A real, reproducible embedding
  function (not a stub) that keeps the full RAG pipeline functional on any
  platform.
"""

from __future__ import annotations

import hashlib
import math
import re
from dataclasses import dataclass
from typing import Protocol

_TOKEN_RE = re.compile(r"[a-z0-9]+")


class Embedder(Protocol):
    def embed(self, text: str) -> list[float]: ...
    def dimension(self) -> int: ...
    def name(self) -> str: ...


@dataclass(frozen=True)
class FeatureHashingEmbedder:
    """Deterministic signed feature-hashing embedding (unigrams + bigrams)."""

    dim: int = 512
    seed: bytes = b"aecp-fh-v1"

    def _tokens(self, text: str) -> list[str]:
        toks = _TOKEN_RE.findall(text.lower())
        return toks + [f"{a}_{b}" for a, b in zip(toks, toks[1:], strict=False)]

    def _slot(self, token: str) -> tuple[int, float]:
        digest = hashlib.blake2b(token.encode("utf-8"), digest_size=8,
                                 person=self.seed).digest()
        idx = int.from_bytes(digest, "little") % self.dim
        sign = 1.0 if (digest[7] & 1) == 0 else -1.0
        return idx, sign

    def embed(self, text: str) -> list[float]:
        vec = [0.0] * self.dim
        for token in self._tokens(text):
            idx, sign = self._slot(token)
            vec[idx] += sign
        norm = math.sqrt(sum(v * v for v in vec)) or 1.0
        return [round(v / norm, 6) for v in vec]

    def dimension(self) -> int:
        return self.dim

    def name(self) -> str:
        return f"feature-hashing-{self.dim}"


class SingaEmbedder:
    """SINGA-backed embedder for platforms where singa wheels exist (ADR-0002)."""

    def __init__(self, dim: int = 512):
        try:
            import singa  # type: ignore[import-not-found]
        except ImportError as exc:
            raise RuntimeError(
                "singa is not installable on this platform (see ADR-0002); "
                f"use feature-hashing backend. Original error: {exc}"
            ) from exc
        self._singa = singa
        self._dim = dim

    def embed(self, text: str) -> list[float]:
        raise NotImplementedError(
            "SINGA embedding pipeline must be configured per cloud profile; "
            "see docs/adr/ADR-0002-neural-adapter.md"
        )

    def dimension(self) -> int:
        return self._dim

    def name(self) -> str:
        return "singa"


def resolve_embedder(preferred: str = "auto", dim: int = 512) -> Embedder:
    """Pick the neural adapter: singa when available, else feature-hashing."""
    if preferred == "singa":
        return SingaEmbedder(dim)
    if preferred == "feature-hashing":
        return FeatureHashingEmbedder(dim)
    try:
        return SingaEmbedder(dim)
    except RuntimeError:
        return FeatureHashingEmbedder(dim)


def cosine(a: list[float], b: list[float]) -> float:
    num = sum(x * y for x, y in zip(a, b, strict=False))
    da = math.sqrt(sum(x * x for x in a))
    db = math.sqrt(sum(y * y for y in b))
    return num / (da * db) if da and db else 0.0
