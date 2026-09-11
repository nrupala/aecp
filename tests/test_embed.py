"""Neural adapter tests: determinism, dimensionality, similarity ordering."""

from aecp.aimesh.embed import (
    FeatureHashingEmbedder,
    cosine,
    resolve_embedder,
)


def test_dimension_and_norm():
    emb = FeatureHashingEmbedder(512)
    v = emb.embed("Apache Pulsar provides durable messaging")
    assert len(v) == 512
    assert abs(sum(x * x for x in v) - 1.0) < 0.01


def test_deterministic():
    emb = FeatureHashingEmbedder(512)
    text = "Ozone object store scales past billions of files"
    assert emb.embed(text) == emb.embed(text)


def test_similarity_ordering():
    emb = FeatureHashingEmbedder(512)
    q = emb.embed("how does pulsar handle message durability")
    near = emb.embed("pulsar provides durable message storage with acknowledgment")
    far = emb.embed("superset renders geospatial dashboards for analysts")
    assert cosine(q, near) > cosine(q, far)


def test_unrelated_not_identical():
    emb = FeatureHashingEmbedder(512)
    a = emb.embed("streaming ingestion")
    b = emb.embed("notebook dashboards")
    assert cosine(a, b) < 0.5


def test_resolve_prefers_hashing_without_singa():
    emb = resolve_embedder("auto", 512)
    assert emb.name().startswith("feature-hashing-") or emb.name() == "singa"
    assert emb.dimension() == 512


def test_explicit_singa_raises_with_adr_reference_when_unavailable():
    import pytest

    try:
        import singa  # noqa: F401
        has_singa = True
    except ImportError:
        has_singa = False
    if has_singa:
        emb = resolve_embedder("singa", 512)
        assert emb.name() == "singa"
    else:
        with pytest.raises(RuntimeError, match="ADR-0002"):
            resolve_embedder("singa", 512)
