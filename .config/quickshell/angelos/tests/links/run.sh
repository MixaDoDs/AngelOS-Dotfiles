#!/usr/bin/env bash
# links, mail and phones found in text (services/Links.js), in node: tests/links/test_links.mjs.
# Without node (the CI image has none) it is skipped and says so.
#   tests/links/run.sh [angelOS dir]      exit 0 = all good
set -uo pipefail
DIR="$(cd "${1:-"$(dirname "$0")/../.."}" && pwd)"
command -v node >/dev/null || { echo "  ✓ links: skipped (no node)"; exit 0; }
exec node "$DIR/tests/links/test_links.mjs"
