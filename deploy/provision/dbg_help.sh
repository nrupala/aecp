#!/bin/bash
export OZONE_HOME=/opt/aecp/apps/ozone JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
/opt/aecp/apps/ozone/bin/ozone 2>&1 | head -30