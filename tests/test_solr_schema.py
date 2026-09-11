"""Solr mesh tests: schema payloads, knn query DSL, with stubbed transport."""

import json

import pytest

from aecp.aimesh import solr_io


class StubResponse:
    def __init__(self, ok=True, status_code=200, payload=None):
        self.ok = ok
        self.status_code = status_code
        self._payload = payload or {}

    def json(self):
        return self._payload

    @property
    def text(self) -> str:
        return json.dumps(self._payload)


def test_field_type_payload_hnsw():
    p = solr_io.field_type_payload(512)
    ft = p["add-field-type"]
    assert ft["class"] == "solr.DenseVectorField"
    assert ft["vectorDimension"] == 512
    # Solr 10: knn/distanceFunction/knnAlgorithm are not type args anymore
    assert "distanceFunction" not in ft
    assert "knnAlgorithm" not in ft


def test_create_collection_calls(monkeypatch):
    calls = []

    def fake_get(url, **kw):
        calls.append(("GET", url))
        return StubResponse()

    def post(url, **kw):
        calls.append(("POST", url))
        return StubResponse()

    monkeypatch.setattr(solr_io, "requests_get", fake_get)
    monkeypatch.setattr(solr_io, "requests_post", post)
    result = solr_io.create_collection("http://s", "t")
    assert result["dimension"] == 512
    assert any("admin/collections" in u for _, u in calls)
    assert any("/schema" in u for _, u in calls)


def test_index_docs_posts_payload(monkeypatch):
    captured = {}

    def post(url, **kw):
        captured["url"] = url
        captured["json"] = kw.get("json")
        captured["params"] = kw.get("params")
        return StubResponse()

    monkeypatch.setattr(solr_io, "requests_post", post)
    n = solr_io.index_docs("http://s", "c", [{"id": "1", "title": "t", "body": "b",
                                              "vector_512": [0.1] * 512}])
    assert n == 1
    assert captured["url"].endswith("/update/json/docs")
    assert captured["params"] == {"commit": "true"}


def test_knn_query_format(monkeypatch):
    captured = {}

    def post(url, **kw):
        captured["url"] = url
        captured["json"] = kw.get("json")
        return StubResponse(payload={"response": {"docs": [{"id": "d1", "score": 1.5}]}})

    monkeypatch.setattr(solr_io, "requests_post", post)
    docs = solr_io.knn_query("http://s", "c", [0.25] * 512, top_k=3)
    assert docs == [{"id": "d1", "score": 1.5}]
    body = captured["json"]
    assert body["query"] == "*:*"
    filt = body["filter"][0]
    assert filt.startswith("{!knn f=vector_512 topK=3}")
    assert "[0.25, 0.25" in filt


def test_knn_query_error_raises():
    with pytest.raises(RuntimeError, match="knn query failed"):
        class _Err:
            ok = False
            status_code = 400
            text = "bad vector"

            def json(self):  # pragma: no cover
                return {}

        import aecp.aimesh.solr_io as m
        m.requests_post = lambda *a, **kw: _Err()
        solr_io.knn_query("http://s", "c", [0.0] * 512)
