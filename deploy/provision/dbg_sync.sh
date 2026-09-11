#!/bin/bash
cd /home/ubuntu/aecp
git log --oneline -2
git status --short | head -4
git pull --ff-only 2>&1 | tail -1
git log --oneline -1
rsync -a --delete --exclude .git /home/ubuntu/aecp/ /opt/aecp/aecp-repo/
grep -c FsspecFileIO /opt/aecp/aecp-repo/aecp/storage/iceberg_io.py