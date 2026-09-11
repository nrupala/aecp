#!/bin/bash
sudo -u aecp python3 - <<'PY'
import urllib.request, json
# schema patch with visible error
ft = {"add-field-type": {"name": "KnnVector", "class": "solr.DenseVectorField",
      "vectorDimension": 512, "distanceFunction": "cosine", "knn": "true", "knnAlgorithm": "hnsw"}}
fl = {"add-field": {"name": "vector_512", "type": "KnnVector", "stored": True, "indexed": True, "multiValued": False}}
for name, payload in (("field-type", ft), ("field", fl)):
    req = urllib.request.Request("http://127.0.0.1:8983/solr/aecp_docs/schema",
                                 json.dumps([payload]).encode(), {"Content-Type": "application/json"})
    try:
        r = urllib.request.urlopen(req, timeout=15)
        print(name, "OK")
    except Exception as e:
        print(name, "FAIL", e.__class__.__name__, getattr(e, 'read', lambda: b'')().decode()[:250])
PY