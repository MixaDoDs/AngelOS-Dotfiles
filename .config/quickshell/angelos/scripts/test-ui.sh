#!/usr/bin/env bash
# angelOS UI self-test, offscreen (no compositor, no windows on screen; runs in CI):
#   every settings page in the simple view and in Expert, every preview scene,
#   settings search speed, the helper's sprite rig, a right click into a window's
#   corner pixel (the Qt crash RightClickGuard works around), plus static checks:
#   every window has a RightClickGuard, no "X is not a type", binding loops, JS
#   errors or missing images in the log.
#
#   scripts/test-ui.sh [angelOS dir]      exit 0 = all good
#   ANGELOS_TEST_LOG=file keeps the full log, ANGELOS_TEST_SHOTS=dir saves pictures (Alt+Tab styles)
set -uo pipefail
DIR="$(cd "${1:-"$(dirname "$0")/.."}" && pwd)"
[[ -f "$DIR/shell.qml" && -f "$DIR/tests/ui/Driver.qml" ]] || { echo "no angelOS in $DIR"; exit 2; }
fail=0
ok()  { printf '  ✓ %s\n' "$*"; }
bad() { printf '  ✕ %s\n' "$*"; fail=1; }

# quickshell: the system one, else the local copy angelOS installs into ~/.local/opt
QS="$(command -v quickshell || true)"
LIB="${LD_LIBRARY_PATH:-}" QML="${QML_IMPORT_PATH:-}"
if [[ ! -x /usr/bin/quickshell && -x "$HOME/.local/opt/quickshell/usr/bin/quickshell" ]]; then
  QS="$HOME/.local/opt/quickshell/usr/bin/quickshell"
  LIB="$HOME/.local/opt/quickshell/usr/lib${LIB:+:$LIB}"
  QML="$HOME/.local/opt/quickshell/usr/lib/qt6/qml${QML:+:$QML}"
fi
[[ -x "$QS" ]] || { echo "quickshell not found"; exit 2; }

echo "» angelOS UI self-test: $DIR"

# every top-level window guards its corner pixel against Qt's right-click crash
while IFS= read -r f; do
  grep -q 'RightClickGuard' "$f" || bad "no RightClickGuard in ${f#"$DIR"/} (a right click into its corner can crash Qt)"
done < <(grep -rlE '^\s*(PanelWindow|FloatingWindow|PopupWindow)\s*\{' --include='*.qml' "$DIR" | grep -v '/tests/')
((fail)) || ok "every window has a RightClickGuard"

# a full-screen overlay takes every click under it unless it has an input mask: effects
# (the shake cursor, B3) must let input through; the ones that are meant to take it
# say why with a "// takes input:" line
while IFS= read -r f; do
  if (( $(grep -cE '^\s*(left|right|top|bottom): true' "$f") >= 4 )) && ! grep -qE '^\s*mask:' "$f" && ! grep -q '// takes input:' "$f"; then
    bad "${f#"$DIR"/}: a full-screen overlay without an input mask takes every click (add mask: Region {…}, or say why with // takes input:)"
  fi
done < <(grep -rlE 'WlrLayer\.Overlay' --include='*.qml' "$DIR" | grep -v '/tests/')
((fail)) || ok "full-screen overlays let input through (or say why they take it)"

# window titles and captions take the ending from Settings → Appearance (I18n.exe, C3): no
# string with a hard-coded ".exe" in QML, JS or a plugin manifest ("// suffix-ok" on the line
# or the one above lets one through: the setting's own three endings)
if out=$(python3 - "$DIR" <<'PY'
import json, pathlib, re, sys
root = pathlib.Path(sys.argv[1])
lit = re.compile(r'"(?:[^"\\\n]|\\.)*"')
bad = []
for p in sorted(list(root.rglob("*.qml")) + list(root.rglob("*.js")) + list(root.rglob("manifest.json"))):
    if "tests" in p.relative_to(root).parts:
        continue
    prev = ""
    for n, line in enumerate(p.read_text(errors="ignore").splitlines(), 1):
        s = line.strip()
        if not s.startswith(("//", "*", "/*")) and "suffix-ok" not in line and "suffix-ok" not in prev:
            for m in lit.finditer(line.split(" //")[0] if p.suffix != ".json" else line):
                if re.search(r"\.exe\b", m.group(0)):
                    bad.append("%s:%d %s" % (p.relative_to(root), n, m.group(0)[:60]))
        prev = line
print("\n".join(bad))
sys.exit(1 if bad else 0)
PY
); then ok "no hard-coded .exe: titles follow the ending setting"; else bad "hard-coded .exe (use I18n.exe):"; printf '%s\n' "$out" | head -20 | sed 's/^/      /'; fi

# python helpers at least compile
if out=$(python3 -m py_compile "$DIR"/scripts/*.py 2>&1); then ok "scripts/*.py compile"; else bad "python: $out"; fi
find "$DIR/scripts" -name __pycache__ -type d -exec rm -rf {} + 2>/dev/null

# the live lens runs as its own quickshell (extras/lens-live) and may not read outside its
# folder: its copy of the lens shader must be the shell's own
if cmp -s "$DIR/shaders/lens.frag.qsb" "$DIR/extras/lens-live/lens.frag.qsb"; then ok "lens-live shader copy is current"; else bad "extras/lens-live/lens.frag.qsb differs from shaders/lens.frag.qsb (copy it after rebuilding)"; fi

# the text-layout checks need real glyphs: with no system font at all (a bare CI
# image) Russian labels have no width, and toggle-wrap fails for no visible reason
if command -v fc-list >/dev/null && [[ -z "$(fc-list 2>/dev/null | head -n1)" ]]; then
  bad "no system fonts (fc-list is empty): install noto-fonts, angelOS's Cyrillic fallback"
fi

# a short runtime dir: Quickshell's IPC socket path must fit in 108 bytes
T="$(mktemp -d /tmp/aos-test.XXXXXX)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/home/.config/angelos" "$T/rt" "$T/root" && chmod 700 "$T/rt"

# The real shell.qml minus its screen windows (layer-shell needs a compositor):
# same imports, type anchors and service start-up, plus the test driver.
for f in "$DIR"/*; do [[ "${f##*/}" == shell.qml ]] || ln -s "$f" "$T/root/"; done
python3 - "$DIR/shell.qml" >"$T/root/shell.qml" <<'PY'
import re, sys
lines = [l for l in open(sys.argv[1]).read().splitlines() if not re.match(r"^    [A-Z][A-Za-z0-9]* \{\}\s*$", l)]
text = "\n".join(lines).rstrip()
text = text.replace("import qs.widgets", "import qs.widgets\nimport qs.tests.ui", 1)
print(text[:text.rfind("}")] + "    Driver {}\n}")
PY
# quiet, offline settings: no OBS, no sounds, no first-run jobs; developer mode on, so its
# pages (Plugin Studio) load with the rest — a page nobody opens in CI breaks unseen
cat >"$T/home/.config/angelos/settings.json" <<'JSON'
{"setup": {"complete": true}, "stream": {"auto": false}, "y2k": {"sounds": false, "helper": false, "boot": false},
 "bar": {"metaTap": false}, "updates": {"autoCheck": false}, "system": {"nautilusDefaults": true},
 "developer": {"enabled": true}}
JSON
# a stand-in cava for the cava widget's check: like the real one it prints 30 frames a
# second whether sound comes through its FIFO or not (the tap behind it finds no PipeWire)
mkdir -p "$T/bin"
cat >"$T/bin/cava" <<'CAVA'
#!/usr/bin/env python3
import os, re, sys, threading, time
conf = open(sys.argv[sys.argv.index("-p") + 1]).read()
fifo = re.search(r"source = (.*)", conf).group(1).strip()
def drain():
    fd = os.open(fifo, os.O_RDONLY)
    while True:
        if not os.read(fd, 4096):
            time.sleep(0.01)
threading.Thread(target=drain, daemon=True).start()
while True:
    print("0;" * 32, flush=True)
    time.sleep(1 / 30)
CAVA
chmod +x "$T/bin/cava"
log="${ANGELOS_TEST_LOG:-$T/qs.log}"
runner=()
command -v dbus-run-session >/dev/null && runner=(dbus-run-session --)
env -i PATH="$T/bin:$PATH" LANG=C.UTF-8 HOME="$T/home" USER="${USER:-angel}" \
  XDG_CONFIG_HOME="$T/home/.config" XDG_STATE_HOME="$T/home/.local/state" \
  XDG_CACHE_HOME="$T/home/.cache" XDG_DATA_HOME="$T/home/.local/share" XDG_RUNTIME_DIR="$T/rt" \
  QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= LD_LIBRARY_PATH="$LIB" QML_IMPORT_PATH="$QML" \
  ANGELOS_DEV=1 ANGELOS_SCREENS=__none__ ANGELOS_TEST=1 ANGELOS_TEST_SHOTS="${ANGELOS_TEST_SHOTS:-}" QS_NO_RELOAD_POPUP=1 QS_DISABLE_CRASH_HANDLER=1 \
  "${runner[@]}" timeout 300 "$QS" -p "$T/root" >"$log" 2>&1
code=$?

# results of the driver
sed -n 's/.*\(TEST \(PASS\|FAIL\|[a-z].*\)\)/\1/p' "$log" | grep -E '^TEST [^ ]+ (PASS|FAIL)' | while read -r _ name res detail; do
  if [[ "$res" == PASS ]]; then printf '  ✓ %s %s\n' "$name" "$detail"; else printf '  ✕ %s %s\n' "$name" "$detail"; fi
done
grep -qE 'TEST [^ ]+ FAIL' "$log" && fail=1
grep -q 'TEST DONE' "$log" || bad "the self-test did not finish (crash or hang, exit $code): $(tail -3 "$log" | tr '\n' ' ' | cut -c1-300)"

# errors in the log, with the page that was loading
errs=$(awk '/TEST-PAGE /{sub(/.*TEST-PAGE /,""); page=$0; next}
  /is not a type|Binding loop detected|TypeError|ReferenceError|Cannot assign|Unable to assign|is not defined|Cannot read property|Cannot call method|failed to load component|Error loading|Cannot open: file/ {
    line=$0; gsub(/\033\[[0-9;]*m/,"",line); print "[" (page==""?"startup":page) "] " substr(line,1,220) }' "$log" | sort -u)
if [[ -n "$errs" ]]; then
  bad "errors in the log:"; printf '%s\n' "$errs" | head -30 | sed 's/^/      /'
else
  ok "no QML errors, binding loops, JS exceptions or missing images"
fi

# the theme export to the apps (tests/theme): heaven ⇄ hell in any order and timing, the last
# state is the one on disk (window borders stayed hell's after a return "as in the game")
if out=$(bash "$DIR/tests/theme/run.sh" "$DIR" 2>&1); then
  ok "theme export: the last state reaches the apps (late realm, toggles during a render, late hell accent)"
else
  bad "theme export (tests/theme/run.sh):"; printf '%s\n' "$out" | grep -v '✓' | head -20 | sed 's/^/      /'
fi

# the scale matrix (tests/scale): Settings, the Start looks, the bar and a notification at art
# pixel 1–4 and fonts ×1, ×1.5 (the step between) and ×2 — nothing runs over, out of its box or off
if out=$(bash "$DIR/tests/scale/run.sh" "$DIR" 2>&1); then
  ok "scale matrix: px 2 ×2, px 1, px 4, px 3 ×1.5, px 4 ×2 — no text over text, cut or overflowing"
else
  bad "scale matrix (tests/scale/run.sh):"; printf '%s\n' "$out" | grep -v '✓' | head -30 | sed 's/^/      /'
fi

# the lock screen (tests/lock): both looks type, fail and unlock, the stream's audience
# follows the days, the replay plays, every unlock style draws; and the SDDM theme
# (tests/sddm) under a stand-in SDDM — both offscreen here
if out=$(ANGELOS_TEST_LOG= bash "$DIR/tests/lock/run.sh" "$DIR" 2>&1); then
  ok "lock screen: NGO and heaven looks, typing, mistakes, unlock styles, the stream's audience by day"
else
  bad "lock screen (tests/lock/run.sh):"; printf '%s\n' "$out" | grep -v '✓' | head -20 | sed 's/^/      /'
fi
if out=$(ANGELOS_TEST_LOG= ANGELOS_SDDM_TEST_OFFSCREEN=1 bash "$DIR/tests/sddm/run.sh" "$DIR" 2>&1); then
  ok "SDDM theme: builds, loads, types, fails and logs in"
else
  bad "SDDM theme (tests/sddm/run.sh):"; printf '%s\n' "$out" | grep -v '✓' | head -20 | sed 's/^/      /'
fi

if ((fail)); then echo "» UI SELF-TEST FAILED"; exit 1; fi
echo "» UI self-test passed ♡"
