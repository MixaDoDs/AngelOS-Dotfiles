#!/usr/bin/env bash
# The desk's one clock inside the shell, offscreen (scripts/test-ui.sh runs it): the music
# spectrum keeps its blocks and moves on DeskClock's tick, the clock's rate with and without a
# live scene, LiveBeat listening to a spectrum instead of a cava of its own, the launcher's
# thumbnails only from the cache's files (tests/desk/DeskDriver.qml).
#
#   tests/desk/run.sh [angelOS dir]        exit 0 = all good, 77 = no quickshell
set -uo pipefail
DIR="$(cd "${1:-"$(dirname "$0")/../.."}" && pwd)"
[[ -f "$DIR/shell.qml" ]] || { echo "no angelOS in $DIR"; exit 2; }

QS="$(command -v quickshell || true)"
LIB="${LD_LIBRARY_PATH:-}" QML="${QML_IMPORT_PATH:-}"
if [[ ! -x /usr/bin/quickshell && -x "$HOME/.local/opt/quickshell/usr/bin/quickshell" ]]; then
  QS="$HOME/.local/opt/quickshell/usr/bin/quickshell"
  LIB="$HOME/.local/opt/quickshell/usr/lib${LIB:+:$LIB}"
  QML="$HOME/.local/opt/quickshell/usr/lib/qt6/qml${QML:+:$QML}"
fi
[[ -x "$QS" ]] || { echo "quickshell not found"; exit 77; }

# a short runtime dir: Quickshell's IPC socket path must fit in 108 bytes
T="$(mktemp -d /tmp/aos-desk.XXXXXX)"
trap 'rm -rf "$T"' EXIT
H="$T/home"
mkdir -p "$H/.config/angelos" "$T/rt" "$T/root" "$T/bin" && chmod 700 "$T/rt"

# the real shell minus its screen windows (as tests/eq/run.sh), with this driver
for f in "$DIR"/*; do [[ "${f##*/}" == shell.qml ]] || ln -s "$f" "$T/root/"; done
python3 - "$DIR/shell.qml" >"$T/root/shell.qml" <<'PY'
import re, sys
lines = [l for l in open(sys.argv[1]).read().splitlines() if not re.match(r"^    [A-Z][A-Za-z0-9]* \{\}\s*$", l)]
text = "\n".join(lines).rstrip()
text = text.replace("import qs.widgets", "import qs.widgets\nimport qs.tests.desk", 1)
print(text[:text.rfind("}")] + "    DeskDriver {}\n}")
PY
cat >"$H/.config/angelos/settings.json" <<'JSON'
{"setup": {"complete": true}, "stream": {"auto": false}, "y2k": {"sounds": false, "helper": false, "boot": false},
 "bar": {"metaTap": false}, "updates": {"autoCheck": false}, "system": {"nautilusDefaults": true}}
JSON
# one thumbnail in the cache, where Nautilus 45+ puts them (the key: md5 of the file's URI)
mkdir -p "$H/.cache/thumbnails/x-large"
: >"$H/.cache/thumbnails/x-large/$(printf 'file://%s' "$H/docs/has.txt" | md5sum | cut -d' ' -f1).png"
# no sound here: the spectrum's tap and LiveBeat's own cava never get a frame
printf '#!/bin/sh\nsleep 600\n' >"$T/bin/cava"; chmod +x "$T/bin/cava"

log="${ANGELOS_TEST_LOG:-$T/qs.log}"
runner=()
command -v dbus-run-session >/dev/null && runner=(dbus-run-session --)
env -i PATH="$T/bin:$PATH" LANG=C.UTF-8 HOME="$H" USER="${USER:-angel}" \
  XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.local/state" \
  XDG_CACHE_HOME="$H/.cache" XDG_DATA_HOME="$H/.local/share" XDG_RUNTIME_DIR="$T/rt" \
  QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= LD_LIBRARY_PATH="$LIB" QML_IMPORT_PATH="$QML" \
  ANGELOS_DEV=1 ANGELOS_SCREENS=__none__ ANGELOS_TEST=1 QS_NO_RELOAD_POPUP=1 QS_DISABLE_CRASH_HANDLER=1 \
  "${runner[@]}" timeout 90 "$QS" -p "$T/root" >"$log" 2>&1
code=$?
# a tap of this run's own left behind (its path is in $T)
pkill -f "$T/root/scripts/audio-tap.py" 2>/dev/null

fail=0 n=0
while read -r _ name res detail; do
  n=$((n + 1))
  if [[ "$res" == PASS ]]; then [[ -n "${ANGELOS_DESK_VERBOSE:-}" ]] && printf '  ✓ %s %s\n' "$name" "$detail"; else printf '  ✕ %s %s\n' "$name" "$detail"; fail=1; fi
done < <(sed -n 's/.*\(TEST [^ ]* \(PASS\|FAIL\).*\)/\1/p' "$log")
grep -q 'TEST DONE' "$log" || { echo "  ✕ the test did not finish (exit $code): $(tail -3 "$log" | tr '\n' ' ' | cut -c1-400)"; fail=1; }
errs=$(grep -E 'MusicSpectrum|DeskClock|LiveBeat|DeskDriver' "$log" | grep -E 'TypeError|ReferenceError|Unable to assign|is not defined|Cannot read property|Binding loop|is not a type|Cannot assign|non-existent|not a function|Could not' | sed 's/\x1b\[[0-9;]*m//g' | sort -u | head -12)
[[ -z "$errs" ]] || { echo "  ✕ QML errors:"; printf '%s\n' "$errs" | sed 's/^/      /'; fail=1; }
((fail)) || echo "  ✓ the desk's one clock: $n checks in the shell (spectrum blocks kept, bars on the tick, LiveBeat from the spectrum, thumbnails from the cache)"
exit $fail
