#!/usr/bin/env bash
# E2E L5: AI & search mesh - Solr kNN retrieval with the neural adapter.
# Evidence: index docs with 512-dim vectors, kNN returns the semantically
# nearest document as top-1 (hit target), plus keyword query returns docs.
set -euo pipefail

VENV="${AECP_VENV:-/opt/aecp/venv}"

echo "== [L5.1] index onboarding corpus =="
sudo -u aecp "$VENV/bin/python" <<'PY'
import json
from aecp.aimesh import solr_io
from aecp.aimesh.embed import resolve_embedder

SOLR = "http://127.0.0.1:8983"
emb = resolve_embedder("auto", 512)
print("embedder:", emb.name())

solr_io.delete_collection(SOLR)
import time
time.sleep(2)
print(solr_io.create_collection(SOLR))

DOCS = [
    {"id": "pulsar-1", "title": "Pulsar durable messaging",
     "body": "Apache Pulsar provides durable pub-sub messaging with "
             "acknowledgments, tiered storage and low latency ingestion."},
    {"id": "flink-1", "title": "Flink stateful processing",
     "body": "Apache Flink provides stateful, sub-second continuous "
             "processing for streaming telemetry and windowed aggregation."},
    {"id": "ozone-1", "title": "Ozone object store",
     "body": "Apache Ozone scales object storage past billions of files "
             "without memory saturation, with S3 gateway access."},
    {"id": "iceberg-1", "title": "Iceberg ACID tables",
     "body": "Apache Iceberg tables keep ACID snapshots over object storage "
             "and support time travel queries and snapshot freezing."},
    {"id": "solr-1", "title": "Solr vector search",
     "body": "Apache Solr runs Lucene keyword search and k-NN dense vector "
             "retrieval in a single unified indexing core."},
]

payload = []
for d in DOCS:
    payload.append({**d, solr_io.VECTOR_FIELD: emb.embed(f"{d['title']} {d['body']}")})
n = solr_io.index_docs(SOLR, "aecp_docs", payload)
print("indexed:", n)

print("EVIDENCE_INDEX:", json.dumps({"docs": n, "embedder": emb.name()}))
PY

echo "== [L5.2] kNN retrieval top-1 hit =="
sudo -u aecp "$VENV/bin/python" <<'PY'
import json
from aecp.aimesh import solr_io
from aecp.aimesh.embed import resolve_embedder

SOLR = "http://127.0.0.1:8983"
emb = resolve_embedder("auto", 512)
q = emb.embed("how do I run durable pub-sub message ingestion")
docs = solr_io.knn_query(SOLR, "aecp_docs", q, top_k=3)
print("EVIDENCE_KNN:", json.dumps(docs))
top = docs[0]["id"] if docs else "none"
assert top == "pulsar-1", f"expected pulsar-1 top-1, got {top}"

kw = solr_io.keyword_query(SOLR, "aecp_docs", "Ozone", top_k=2)
print("EVIDENCE_KEYWORD:", json.dumps([d["id"] for d in kw]))
assert any(d["id"] == "ozone-1" for d in kw)
PY

echo "L5 PASS: Solr unified indexing (keyword + 512-dim kNN) top-1 hit"