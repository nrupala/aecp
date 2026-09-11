#!/bin/bash
export TERM=dumb OZONE_HOME=/opt/aecp/apps/ozone JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
/opt/aecp/apps/ozone/bin/ozone help 2>&1 | grep -aE '^\s+[a-z]+' | awk '{print $1}' | sort -u | tr '\n' ' '
echo
/opt/aecp/apps/ozone/bin/ozone 2>&1 | grep -aE '^\s+(sh|namespace|admin|s3|fs|debug|check|version|freon|cli)' | head -12