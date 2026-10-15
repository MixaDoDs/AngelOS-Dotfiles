#!/usr/bin/env bash
# the screenshot overlay's auto-selection (scripts/capture_regions.py) on drawn frames:
# tests/capture_regions/test_regions.py. Offscreen, no shell, ~5 s.
#   tests/capture_regions/run.sh [angelOS dir]      exit 0 = all good
DIR="$(cd "${1:-"$(dirname "$0")/../.."}" && pwd)"
python3 -c 'import numpy, PIL' 2>/dev/null || { echo "» capture_regions: skipped (no numpy/Pillow)"; exit 0; }
o="$(python3 "$DIR/tests/capture_regions/test_regions.py" "$DIR" 2>&1)"; rc=$?
printf '%s\n' "$o"
((rc == 0)) && echo "» capture_regions: all good" || echo "» capture_regions: FAILED"
exit $rc
