#!/usr/bin/env bash
# the screenshot overlay's saving (scripts/capture_save.py) against stand-in tools
DIR="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
python3 -c 'import numpy, PIL' 2>/dev/null || { echo "» capture: skipped (no numpy/Pillow)"; exit 0; }
o="$(python3 "$DIR/tests/capture/test_capture_save.py" "$DIR" 2>&1)"; rc=$?
printf '%s\n' "$o"
((rc == 0)) && echo "» capture: all good" || echo "» capture: FAILED"
exit $rc
