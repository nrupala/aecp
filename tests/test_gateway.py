"""Gateway tests: RAG loop with injected retrieval (no live Solr needed)."""

import pytest
from fastapi.testclient import TestClient

from aecp.gateway import app as gw


@pytest.fixture()
def client(monkeypatch):
    monkeypatch.setattr(gw, "_embedder", None)
    app = gw.make_app(
        solr_url="http://stub",
        retriever=lambda vec, k: [
            {"id": "d1", "title": "Pulsar durability", "score": 1.42,
             "body": "Pulsar persists messages with acknowledgment quorum."},
            {"id": "d2", "title": "Ozone scale", "score": 1.10,
             "body": "Ozone scales past billions of files."},
        ][:k],
        indexer=lambda docs: len(docs),
        pinger=lambda: True,
    )
    return TestClient(app)


def test_healthz(client):
    r = client.get("/healthz")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "ok"
    assert body["solr"] is True
    assert "feature-hashing" in body["embedder"] or body["embedder"] == "singa"


def test_index_and_chat_roundtrip(client):
    r = client.post("/v1/index", json={"docs": [
        {"id": "d1", "title": "Pulsar durability",
         "body": "Pulsar persists messages with acknowledgment quorum."},
    ]})
    assert r.status_code == 200
    assert r.json()["indexed"] == 1

    c = client.post("/v1/chat", json={"question": "how does pulsar persist messages?"})
    assert c.status_code == 200
    body = c.json()
    assert "Pulsar durability" in body["answer"]
    assert body["sources"][0]["id"] == "d1"
    assert body["confidence"] == pytest.approx(1.42, rel=1e-3)


def test_chat_no_results(client, monkeypatch):
    app = gw.make_app(solr_url="http://stub", retriever=lambda vec, k: [],
                      indexer=lambda docs: 0, pinger=lambda: True)
    c = TestClient(app)
    r = c.post("/v1/chat", json={"question": "unknown topic"})
    body = r.json()
    assert "No indexed knowledge" in body["answer"]
    assert body["sources"] == []


def test_chat_rejects_empty_question():
    app = gw.make_app(solr_url="http://stub", retriever=lambda v, k: [],
                      indexer=lambda d: 0, pinger=lambda: True)
    c = TestClient(app)
    r = c.post("/v1/chat", json={"question": ""})
    assert r.status_code == 422


def test_degraded_health_when_solr_down():
    app = gw.make_app(solr_url="http://stub", retriever=lambda v, k: [],
                      indexer=lambda d: 0, pinger=lambda: False)
    c = TestClient(app)
    r = c.get("/healthz")
    assert r.json()["status"] == "degraded"
