#!/usr/bin/env bash
# The theme export to the apps, offscreen (scripts/test-ui.sh runs it, so does CI):
# services/ThemeExport.qml against a slow stand-in renderer — the realm turning after the
# angel is back (a return "as in the game"), quick toggles while a render runs, a change
# during a render, a wallpaper accent landing in hell (it must change nothing). Whatever happens, the last state
# must be the one on disk. The real renderer never runs here (it reloads kitty).
#
#   tests/theme/run.sh [angelOS dir]     exit 0 = all good, 77 = no quickshell
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
T="$(mktemp -d /tmp/aos-theme.XXXXXX)"
trap 'rm -rf "$T"' EXIT
H="$T/home"
mkdir -p "$H/.config/angelos" "$T/rt" "$T/root" && chmod 700 "$T/rt"

# the real shell minus its screen windows (as scripts/test-ui.sh), with this driver
for f in "$DIR"/*; do [[ "${f##*/}" == shell.qml ]] || ln -s "$f" "$T/root/"; done
python3 - "$DIR/shell.qml" >"$T/root/shell.qml" <<'PY'
import re, sys
lines = [l for l in open(sys.argv[1]).read().splitlines() if not re.match(r"^    [A-Z][A-Za-z0-9]* \{\}\s*$", l)]
text = "\n".join(lines).rstrip()
text = text.replace("import qs.widgets", "import qs.widgets\nimport qs.tests.theme", 1)
print(text[:text.rfind("}")] + "    ThemeDriver {}\n}")
PY

# the stand-in renderer: as slow as a real one on a busy machine, writes the palette the way
# render-templates.py does (--palette) and logs what it rendered
cat >"$T/render.py" <<'PY'
import hashlib, json, os, sys, time
args = sys.argv[1:]
text = args[args.index("--palette") + 1]
time.sleep(0.8)
path = args[0]
os.makedirs(os.path.dirname(path), exist_ok=True)
open(path + ".tmp", "w").write(text)
os.replace(path + ".tmp", path)
p = json.loads(text)
with open(os.path.join(os.environ["HOME"], "renders.log"), "a") as f:
    f.write("%s %s %s\n" % (p.get("realm"), p.get("accent"), hashlib.md5(text.encode()).hexdigest()))
PY

# "From wallpaper": heaven's and hell's accents differ, so a palette from the wrong realm shows;
# the widgets stay out of it (the driver turns the realm itself, as their burn does midway)
cat >"$H/.config/angelos/settings.json" <<'JSON'
{"setup": {"complete": true}, "stream": {"auto": false}, "y2k": {"sounds": false, "helper": false, "boot": false, "hellWidgets": false},
 "bar": {"metaTap": false}, "updates": {"autoCheck": false}, "system": {"nautilusDefaults": true},
 "appearance": {"flavor": "wallpaper", "mode": "dark", "customAccent": "#1f5f99", "customAccentHell": "#99413b", "themeApps": true},
 "game": {"enabled": true}}
JSON

log="${ANGELOS_TEST_LOG:-$T/qs.log}"
runner=()
command -v dbus-run-session >/dev/null && runner=(dbus-run-session --)
env -i PATH="$PATH" LANG=C.UTF-8 HOME="$H" USER="${USER:-angel}" \
  XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.local/state" \
  XDG_CACHE_HOME="$H/.cache" XDG_DATA_HOME="$H/.local/share" XDG_RUNTIME_DIR="$T/rt" \
  QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= LD_LIBRARY_PATH="$LIB" QML_IMPORT_PATH="$QML" \
  ANGELOS_DEV=1 ANGELOS_SCREENS=__none__ ANGELOS_TEST=1 ANGELOS_RENDER_STUB="$T/render.py" QS_NO_RELOAD_POPUP=1 QS_DISABLE_CRASH_HANDLER=1 \
  "${runner[@]}" timeout 120 "$QS" -p "$T/root" >"$log" 2>&1
code=$?

fail=0
while read -r _ name res detail; do
  if [[ "$res" == PASS ]]; then printf '  ✓ %s %s\n' "$name" "$detail"; else printf '  ✕ %s %s\n' "$name" "$detail"; fail=1; fi
done < <(sed -n 's/.*\(TEST [^ ]* \(PASS\|FAIL\).*\)/\1/p' "$log")
grep -q 'TEST DONE' "$log" || { echo "  ✕ the test did not finish (exit $code): $(tail -3 "$log" | tr '\n' ' ' | cut -c1-300)"; fail=1; }
errs=$(grep -E 'ThemeExport|ThemeDriver' "$log" | grep -E 'TypeError|ReferenceError|Unable to assign|is not defined|Cannot read property|Binding loop' | sed 's/\x1b\[[0-9;]*m//g' | sort -u | head -10)
[[ -z "$errs" ]] || { echo "  ✕ QML errors:"; printf '%s\n' "$errs" | sed 's/^/      /'; fail=1; }
((fail == 0)) && echo "  theme export: the last state always reaches the apps"
exit "$fail"
