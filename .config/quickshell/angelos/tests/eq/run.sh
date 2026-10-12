#!/usr/bin/env bash
# The bar's equalizer inside the shell, offscreen (scripts/test-ui.sh runs it): two faces over
# the one Eq service and the real scripts/eq-bridge.py, against stand-ins of pactl, pw-link
# and of EasyEffects' socket (tests/eq/fake — no sound of the user's is touched). The bridge
# alone is tests/test_eq_bridge.py, run here too.
#
#   tests/eq/run.sh [angelOS dir]          exit 0 = all good, 77 = no quickshell
set -uo pipefail
DIR="$(cd "${1:-"$(dirname "$0")/../.."}" && pwd)"
[[ -f "$DIR/shell.qml" ]] || { echo "no angelOS in $DIR"; exit 2; }

fail=0
out="$(python3 "$DIR/tests/test_eq_bridge.py" 2>&1)" || { echo "  ✕ tests/test_eq_bridge.py:"; printf '%s\n' "$out" | tail -15 | sed 's/^/      /'; fail=1; }

QS="$(command -v quickshell || true)"
LIB="${LD_LIBRARY_PATH:-}" QML="${QML_IMPORT_PATH:-}"
if [[ ! -x /usr/bin/quickshell && -x "$HOME/.local/opt/quickshell/usr/bin/quickshell" ]]; then
  QS="$HOME/.local/opt/quickshell/usr/bin/quickshell"
  LIB="$HOME/.local/opt/quickshell/usr/lib${LIB:+:$LIB}"
  QML="$HOME/.local/opt/quickshell/usr/lib/qt6/qml${QML:+:$QML}"
fi
[[ -x "$QS" ]] || { echo "quickshell not found"; exit 77; }

# a short runtime dir: Quickshell's IPC socket path must fit in 108 bytes
T="$(mktemp -d /tmp/aos-eq.XXXXXX)"
server=""
trap '[[ -n "$server" ]] && kill "$server" 2>/dev/null; rm -rf "$T"' EXIT
H="$T/home"
mkdir -p "$H/.config/angelos" "$T/rt" "$T/root" "$T/fake" "$T/bin" && chmod 700 "$T/rt"

# the real shell minus its screen windows (as tests/search/run.sh), with this driver
for f in "$DIR"/*; do [[ "${f##*/}" == shell.qml ]] || ln -s "$f" "$T/root/"; done
python3 - "$DIR/shell.qml" >"$T/root/shell.qml" <<'PY'
import re, sys
lines = [l for l in open(sys.argv[1]).read().splitlines() if not re.match(r"^    [A-Z][A-Za-z0-9]* \{\}\s*$", l)]
text = "\n".join(lines).rstrip()
text = text.replace("import qs.widgets", "import qs.widgets\nimport qs.tests.eq", 1)
print(text[:text.rfind("}")] + "    EqDriver {}\n}")
PY
cat >"$H/.config/angelos/settings.json" <<'JSON'
{"setup": {"complete": true}, "stream": {"auto": false}, "y2k": {"sounds": false, "helper": false, "boot": false},
 "bar": {"metaTap": false}, "updates": {"autoCheck": false}, "system": {"nautilusDefaults": true}, "appearance": {"language": "ru"}}
JSON
# the stand-ins first on PATH; Helium already plays into "EasyEffects", which plays on System
for t in pactl pw-link; do
  printf '#!/bin/sh\nexec python3 "%s/tests/eq/fake/audio.py" %s "$@"\n' "$DIR" "$t" >"$T/bin/$t"; chmod +x "$T/bin/$t"
done
printf '#!/bin/sh\nexit 127\n' >"$T/bin/cava"; chmod +x "$T/bin/cava"
cat >"$T/fake/audio.json" <<'JSON'
{"sinks": ["rcp_duo_system_in", "rcp_duo_music_in", "easyeffects_sink"], "output": "rcp_duo_system_in",
 "streams": [{"index": 7, "app": "Helium", "sink": "easyeffects_sink"}, {"index": 9, "app": "Spotify", "sink": "rcp_duo_music_in"}]}
JSON
FAKE_EQ_DIR="$T/fake" python3 "$DIR/tests/eq/fake/audio.py" server "$T/rt/EasyEffectsServer" &
server=$!

log="${ANGELOS_TEST_LOG:-$T/qs.log}"
runner=()
command -v dbus-run-session >/dev/null && runner=(dbus-run-session --)
env -i PATH="$T/bin:$PATH" LANG=C.UTF-8 HOME="$H" USER="${USER:-angel}" \
  XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.local/state" \
  XDG_CACHE_HOME="$H/.cache" XDG_DATA_HOME="$H/.local/share" XDG_RUNTIME_DIR="$T/rt" \
  QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= LD_LIBRARY_PATH="$LIB" QML_IMPORT_PATH="$QML" \
  ANGELOS_DEV=1 ANGELOS_SCREENS=__none__ ANGELOS_TEST=1 QS_NO_RELOAD_POPUP=1 QS_DISABLE_CRASH_HANDLER=1 \
  FAKE_EQ_DIR="$T/fake" \
  "${runner[@]}" timeout 120 "$QS" -p "$T/root" >"$log" 2>&1
code=$?
# the bridge outlives a shell that quits by itself; only this run's own (its path is in $T)
pkill -f "$T/root/scripts/eq-bridge.py" 2>/dev/null

n=0
while read -r _ name res detail; do
  n=$((n + 1))
  if [[ "$res" == PASS ]]; then [[ -n "${ANGELOS_EQ_VERBOSE:-}" ]] && printf '  ✓ %s %s\n' "$name" "$detail"; else printf '  ✕ %s %s\n' "$name" "$detail"; fail=1; fi
done < <(sed -n 's/.*\(TEST [^ ]* \(PASS\|FAIL\).*\)/\1/p' "$log")
grep -q 'TEST DONE' "$log" || { echo "  ✕ the test did not finish (exit $code): $(tail -3 "$log" | tr '\n' ' ' | cut -c1-400)"; fail=1; }
# what reached the stand-ins: the band on both channels with half of the boost taken back, the
# app back on the channel chosen for it, no route left behind
python3 - "$T/fake" "$H/.local/state/angelos/eq-route.json" <<'PY' || fail=1
import json, os, sys
fake, route = sys.argv[1:]
ee = json.load(open(fake + "/ee.json")); audio = json.load(open(fake + "/audio.json"))
bad = []
if (ee["left:band0Gain"], ee["right:band0Gain"], float(ee["outputGain"])) != ("3", "3", -1.5):
    bad.append("preset or headroom: %s %s %s" % (ee["left:band0Gain"], ee["right:band0Gain"], ee["outputGain"]))
helium = next(s for s in audio["streams"] if s["app"] == "Helium")
if helium["sink"] != "rcp_duo_music_in":
    bad.append("Helium was left on " + helium["sink"])
if next(s for s in audio["streams"] if s["app"] == "Spotify")["sink"] != "rcp_duo_music_in":
    bad.append("Spotify was moved")
if os.path.exists(route):
    bad.append("a route file is left")
for b in bad:
    print("  ✕ " + b)
sys.exit(1 if bad else 0)
PY
errs=$(grep -E 'Eq\.qml|EqButton|EqDriver|EqMotion' "$log" | grep -E 'TypeError|ReferenceError|Unable to assign|is not defined|Cannot read property|Binding loop|is not a type|Cannot assign|non-existent|not a function|Could not' | sed 's/\x1b\[[0-9;]*m//g' | sort -u | head -12)
[[ -z "$errs" ]] || { echo "  ✕ QML errors:"; printf '%s\n' "$errs" | sed 's/^/      /'; fail=1; }
((fail)) || echo "  ✓ the bar's equalizer: $n checks in the shell + the bridge's own tests (stand-in pactl, pw-link, EasyEffects)"
exit $fail
