"""AECP Gateway: the intelligent onboarding chatbot (L6<->L5 bridge).

Per the AECP spec: user queries (intercepted in Zeppelin) are augmented via
Solr vector retrieval and composed through the neural adapter. This HTTP API
is that loop; Zeppelin notebooks call it from paragraphs.

Endpoints:
- GET  /healthz     -> component health (Solr ping, embedder identity)
- POST /v1/index    -> {"docs":[{"id","title","body"}...]} indexes into Solr
- POST /v1/chat     -> {"question":"..."} -> RAG answer + sources
"""

from __future__ import annotations

import os
import time
from collections.abc import Callable
from typing import Any

try:
    from fastapi import FastAPI
    from pydantic import BaseModel, Field
except ImportError as exc:  # pragma: no cover
    raise SystemExit(f"gateway requires fastapi+pydantic: {exc}") from exc

from aecp.aimesh import solr_io
from aecp.aimesh.embed import Embedder, resolve_embedder

SOLR_URL = os.environ.get("AECP_SOLR_URL", "http://127.0.0.1:8983")
COLLECTION = os.environ.get("AECP_SOLR_COLLECTION", "aecp_docs")
GATEWAY_PORT = int(os.environ.get("AECP_GATEWAY_PORT", "8847"))
EMBEDDER_PREF = os.environ.get("AECP_EMBEDDER", "auto")

_embedder: Embedder | None = None


def get_embedder() -> Embedder:
    global _embedder
    if _embedder is None:
        _embedder = resolve_embedder(EMBEDDER_PREF, solr_io.DIMENSION)
    return _embedder


class Doc(BaseModel):
    id: str = Field(min_length=1)
    title: str = Field(min_length=1)
    body: str = Field(min_length=1)


class IndexRequest(BaseModel):
    docs: list[Doc] = Field(min_length=1)


class ChatRequest(BaseModel):
    question: str = Field(min_length=1)
    top_k: int = Field(default=5, ge=1, le=20)


def compose_answer(question: str, docs: list[dict[str, Any]]) -> dict[str, Any]:
    """Deterministic RAG composition over retrieved sources."""
    if not docs:
        return {
            "answer": (
                f"No indexed knowledge matched the query '{question}'. "
                "Index onboarding documents via POST /v1/index and retry."
            ),
            "sources": [],
            "confidence": 0.0,
        }
    titles = [d.get("title", "") for d in docs]
    top = docs[0]
    body = str(top.get("body", ""))[:280]
    answer = (
        f"Based on {len(docs)} source(s) - primary: '{titles[0]}' - {body}"
    )
    return {
        "answer": answer,
        "sources": [{"id": d.get("id"), "title": d.get("title"),
                     "score": d.get("score")} for d in docs],
        "confidence": round(float(docs[0].get("score") or 0.0), 6),
    }


def make_app(solr_url: str = SOLR_URL,
             retriever: Callable[[list[float], int], list[dict[str, Any]]] | None = None,
             indexer: Callable[[list[dict[str, Any]]], int] | None = None,
             pinger: Callable[[], bool] | None = None) -> FastAPI:  # type: ignore[name-defined]
    """Factory with injectable IO (testable without live Solr)."""
    app = FastAPI(title="AECP Gateway", version="0.1.0")

    @app.get("/healthz")
    def healthz() -> dict[str, Any]:
        emb = get_embedder()
        solr_ok = pinger() if pinger else solr_io.ping(solr_url, COLLECTION)
        return {
            "status": "ok" if solr_ok else "degraded",
            "solr": solr_ok,
            "embedder": emb.name(),
            "dimension": emb.dimension(),
            "ts_ms": int(time.time() * 1000),
        }

    @app.post("/v1/index")
    def index(req: IndexRequest) -> dict[str, Any]:
        emb = get_embedder()
        payload = []
        for d in req.docs:
            payload.append({
                "id": d.id, "title": d.title, "body": d.body,
                solr_io.VECTOR_FIELD: emb.embed(f"{d.title} {d.body}"),
            })
        n = indexer(payload) if indexer else solr_io.index_docs(solr_url, COLLECTION, payload)
        return {"indexed": n, "embedder": emb.name()}

    @app.post("/v1/chat")
    def chat(req: ChatRequest) -> dict[str, Any]:
        emb = get_embedder()
        vec = emb.embed(req.question)
        docs = retriever(vec, req.top_k) if retriever else solr_io.knn_query(
            solr_url, COLLECTION, vec, top_k=req.top_k
        )
        result = compose_answer(req.question, docs)
        result["embedder"] = emb.name()
        return result

    return app


app = make_app()


def serve() -> None:
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=GATEWAY_PORT)


if __name__ == "__main__":
    serve()
