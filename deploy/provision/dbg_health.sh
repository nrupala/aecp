#!/bin/bash
echo "-- pulsar health URL:"
curl -s -m 5 -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8091/admin/v2/brokers/health
echo "-- om jmx:"
curl -s -m 5 -o /dev/null -w '%{http_code}\n' 'http://127.0.0.1:9865/jmx?qry=Hadoop:service=OzoneManager,name=*'
echo "-- recon summary:"
curl -s -m 5 -o /dev/null -w '%{http_code}\n' http://127.0.0.1:9891/api/summary
echo "-- superset health:"
curl -s -m 5 -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8087/health
echo "-- superserset unauth /:"
curl -s -m 5 -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8087/