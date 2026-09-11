"""AECP AI & search mesh (L5): Apache Solr unified indexing (keyword + kNN).

Vector search uses Solr's DenseVectorField with HNSW (knnAlgorithm) and the
{!knn} query parser - keyword and vector retrieval in a single Solr core,
matching the AECP specification.
"""

from __future__ import annotations

import json
from typing import Any

import requests

VECTOR_FIELD = "vector_512"
DIMENSION = 512


def field_type_payload(dimension: int = DIMENSION) -> dict[str, Any]:
    return {
        "add-field-type": {
            "name": "KnnVector",
            "class": "solr.DenseVectorField",
            "vectorDimension": dimension,
            "distanceFunction": "cosine",
            "knn": "true",
            "knnAlgorithm": "hnsw",
        }
    }


def field_payload(dimension: int = DIMENSION) -> dict[str, Any]:
    return {
        "add-field": {
            "name": VECTOR_FIELD,
            "type": "KnnVector",
            "stored": True,
            "indexed": True,
            "multiValued": False,
        }
    }


def delete_collection(solr_url: str, collection: str = "aecp_docs",
                      timeout: float = 60.0) -> bool:
    """Remove a collection (used to reset schema before recreate)."""
    r = requests_get(
        f"{solr_url}/solr/admin/collections",
        params={"action": "DELETE", "name": collection},
        timeout=timeout,
    )
    return bool(r.ok)


def create_collection(solr_url: str, collection: str = "aecp_docs",
                      timeout: float = 60.0) -> dict[str, Any]:
    """Create collection from _default configset, then apply vector schema."""
    r = requests_get(
        f"{solr_url}/solr/admin/collections",
        params={"action": "CREATE", "name": collection, "numShards": 1,
                "replicationFactor": 1},
        timeout=timeout,
    )
    if not r.ok:
        raise RuntimeError(f"collection create failed: {r.status_code} {r.text[:400]}")
    # Solr 10 schema API: single object of {"command": {...}, ...}
    patch = {**field_type_payload(), **field_payload()}
    s = requests_post(f"{solr_url}/solr/{collection}/schema",
                      json=patch, timeout=timeout)
    if not s.ok:
        raise RuntimeError(f"schema update failed: {s.status_code} {s.text[:400]}")
    return {"collection": collection, "status": "created", "dimension": DIMENSION}


def index_docs(solr_url: str, collection: str,
               docs: list[dict[str, Any]], timeout: float = 30.0) -> int:
    """POST docs (each with id/title/body and vector_512 array)."""
    r = requests_post(f"{solr_url}/solr/{collection}/update/json/docs",
                      json=docs, params={"commit": "true"}, timeout=timeout)
    if not r.ok:
        raise RuntimeError(f"index failed: {r.status_code} {r.text[:400]}")
    return len(docs)


def knn_query(solr_url: str, collection: str, vector: list[float],
              top_k: int = 5, fl: str = "id,title,score",
              timeout: float = 30.0) -> list[dict[str, Any]]:
    body = {
        "query": "*:*",
        "filter": [f"{{!knn f={VECTOR_FIELD} topK={top_k}}}{json.dumps(vector)}"],
        "fields": fl.split(","),
        "limit": top_k,
    }
    r = requests_post(f"{solr_url}/solr/{collection}/query", json=body, timeout=timeout)
    if not r.ok:
        raise RuntimeError(f"knn query failed: {r.status_code} {r.text[:400]}")
    docs = r.json().get("response", {}).get("docs", [])
    return list(docs)


def keyword_query(solr_url: str, collection: str, text: str,
                  top_k: int = 5, timeout: float = 30.0) -> list[dict[str, Any]]:
    r = requests_get(
        f"{solr_url}/solr/{collection}/select",
        params={"q": f"body:{text}", "rows": top_k, "wt": "json"},
        timeout=timeout,
    )
    if not r.ok:
        raise RuntimeError(f"keyword query failed: {r.status_code} {r.text[:200]}")
    docs = r.json().get("response", {}).get("docs", [])
    return list(docs)


def ping(solr_url: str, collection: str = "aecp_docs", timeout: float = 5.0) -> bool:
    try:
        r = requests_get(f"{solr_url}/solr/{collection}/admin/ping",
                         params={"wt": "json"}, timeout=timeout)
        return bool(r.ok)
    except Exception:
        return False


# thin wrappers so tests can stub transport in one place
def requests_get(url: str, **kw: Any) -> Any:

    return requests.get(url, **kw)


def requests_post(url: str, **kw: Any) -> Any:

    return requests.post(url, **kw)
