#!/bin/bash
sudo journalctl -u aecp-solr.service --since '-8 min' --no-pager | grep -aE 'ERROR|WARN|Java|force|root|ERROR:' | head -8