#!/bin/bash
export TERM=dumb
/opt/aecp/apps/ozone/bin/ozone 2>&1 | sed -n '/SUBCOMMAND is one of:/,$p' | head -40