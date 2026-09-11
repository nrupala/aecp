#!/bin/bash
grep -nE 'SOLR_HOME|not supported|solr.home' /opt/aecp/apps/solr/bin/solr | head -10
grep -nE 'SOLR_HOME|SOLR_SOLR_HOME' /opt/aecp/apps/solr/bin/solr.in.sh | head -6