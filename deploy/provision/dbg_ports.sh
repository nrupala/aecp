#!/bin/bash
sudo ss -tlnp | grep -E ':(8091|9865|9891|8087|9862|9888)' || echo "none of those ports listening"
echo '--- om http ---'
sudo ss -tlnp | grep java | head -12