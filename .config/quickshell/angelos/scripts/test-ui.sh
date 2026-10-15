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

# Quickshell.Io's types need their import: one file without it and the whole shell does not
# load (2026-10-15: PrivacyCast's FileView); the stands below leave top-level parts of
# shell.qml out, so only this sees it
io_fail=0
while IFS= read -r f; do
  grep -q '^import Quickshell\.Io' "$f" || { bad "${f#"$DIR"/} uses Quickshell.Io types without \`import Quickshell.Io\`"; io_fail=1; }
done < <(grep -rlE '^\s*(FileView|Process|StdioCollector|SplitParser|SocketServer|IpcHandler|Socket|JsonAdapter)\s*\{' --include='*.qml' "$DIR" | grep -v -e '/tests/' -e '\.bak')
((io_fail)) || ok "Quickshell.Io types come with their import"

# the screenshot keys in the key templates: Mod+Shift+S and Print → angelos capture (the old
# region tool when no shell answers), Mod+Shift+T bound nowhere (tests/keys)
if out=$(python3 "$DIR/tests/keys/test_capture_keys.py" "$DIR" 2>&1); then ok "${out#  ✓ }"; else while IFS= read -r l; do bad "${l#  ✕ }"; done <<<"$out"; fi

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

# python helpers at least compile (the bytecode out of the tree: check.sh copies it meanwhile)
pyc="$(mktemp -d)"
if out=$(PYTHONPYCACHEPREFIX="$pyc" python3 -m py_compile "$DIR"/scripts/*.py 2>&1); then ok "scripts/*.py compile"; else bad "python: $out"; fi
rm -rf "$pyc"

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
trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$T"' EXIT
mkdir -p "$T/root"

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
cat >"$T/settings.json" <<'JSON'
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
runner=()
command -v dbus-run-session >/dev/null && runner=(dbus-run-session --)

# The driver in shards that run at once (one after the other the phases took over two
# minutes): each its own HOME and runtime dir, phases FROM…UNTIL (tests/ui/Driver.qml).
SHARDS=("a||previews" "b|previews|game" "c|game|game-exit" "d|game-exit|")
driver() { # NAME FROM UNTIL
  local h="$T/$1"
  mkdir -p "$h/home/.config/angelos" "$h/rt" && chmod 700 "$h/rt"
  cp "$T/settings.json" "$h/home/.config/angelos/settings.json"
  env -i PATH="$T/bin:$PATH" LANG=C.UTF-8 HOME="$h/home" USER="${USER:-angel}" \
    XDG_CONFIG_HOME="$h/home/.config" XDG_STATE_HOME="$h/home/.local/state" \
    XDG_CACHE_HOME="$h/home/.cache" XDG_DATA_HOME="$h/home/.local/share" XDG_RUNTIME_DIR="$h/rt" \
    QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= LD_LIBRARY_PATH="$LIB" QML_IMPORT_PATH="$QML" \
    ANGELOS_DEV=1 ANGELOS_SCREENS=__none__ ANGELOS_TEST=1 ANGELOS_TEST_SHOTS="${ANGELOS_TEST_SHOTS:-}" QS_NO_RELOAD_POPUP=1 QS_DISABLE_CRASH_HANDLER=1 \
    ANGELOS_TEST_FROM="$2" ANGELOS_TEST_UNTIL="$3" \
    "${runner[@]}" timeout 480 "$QS" -p "$T/root" >"$T/$1.log" 2>&1
  echo $? >"$T/$1.code"
}
# the other offscreen suites (tests/<name>/run.sh), alongside
suite() { # NAME [VAR=value…]
  local name="$1" rc=0; shift
  env ANGELOS_TEST_LOG= "$@" bash "$DIR/tests/$name/run.sh" "$DIR" >"$T/suite-$name.out" 2>&1 || rc=$?
  echo "$rc" >"$T/suite-$name.code"
}
# at most ANGELOS_TEST_JOBS at once (default: the CPUs), the longest first
JOBS="${ANGELOS_TEST_JOBS:-$(nproc 2>/dev/null || echo 4)}"
start() { while (( $(jobs -rp | wc -l) >= JOBS )); do wait -n 2>/dev/null || true; done; "$@" & }
start suite scale
for s in b c d a; do
  for sh in "${SHARDS[@]}"; do [[ "${sh%%|*}" == "$s" ]] && { IFS='|' read -r n from until <<<"$sh"; start driver "$n" "$from" "$until"; }; done
done
start suite lock
start suite theme
start suite search
start suite tour
start suite sddm ANGELOS_SDDM_TEST_OFFSCREEN=1
start suite perf
start suite leak
start suite guard
start suite eq
start suite desk
start suite rescue
start suite quickshare
start suite links
start suite circle
start suite capture
start suite capture_regions
start suite island
start suite keys
wait

# A shard or suite that failed in the crowd runs once more on its own, the rest being done:
# a wait that ran out on a busy machine passes then, a real fault fails twice (and counts)
shard_failed() { grep -qE 'TEST [^ ]+ FAIL' "$T/$1.log" || ! grep -q 'TEST DONE' "$T/$1.log"; }
retried=()
for sh in "${SHARDS[@]}"; do
  IFS='|' read -r n from until <<<"$sh"
  shard_failed "$n" || continue
  first=$(sed -n 's/.*TEST \([^ ]*\) FAIL.*/\1/p' "$T/$n.log" | tr '\n' ' ')
  retried+=("shard $n (${first:-did not finish})")
  rm -rf "${T:?}/$n"
  start driver "$n" "$from" "$until"
done
for s in scale lock theme search tour sddm perf leak guard eq desk rescue quickshare links circle capture capture_regions island keys; do
  [[ "$(cat "$T/suite-$s.code" 2>/dev/null)" == 0 ]] && continue
  retried+=("$s")
  if [[ "$s" == sddm ]]; then start suite sddm ANGELOS_SDDM_TEST_OFFSCREEN=1; else start suite "$s"; fi
done
wait
((${#retried[@]} == 0)) || printf '  ⚠ failed beside the others, run once more alone: %s\n' "${retried[*]}"

# results of the driver, shard by shard
for sh in "${SHARDS[@]}"; do
  n="${sh%%|*}" log="$T/${sh%%|*}.log"
  sed -n 's/.*\(TEST \(PASS\|FAIL\|[a-z].*\)\)/\1/p' "$log" | grep -E '^TEST [^ ]+ (PASS|FAIL)' | while read -r _ name res detail; do
    if [[ "$res" == PASS ]]; then printf '  ✓ %s %s\n' "$name" "$detail"; else printf '  ✕ %s %s\n' "$name" "$detail"; fi
  done
  grep -qE 'TEST [^ ]+ FAIL' "$log" && fail=1
  grep -q 'TEST DONE' "$log" || bad "the self-test (shard $n: ${sh#*|}) did not finish (crash or hang, exit $(cat "$T/$n.code" 2>/dev/null)): $(tail -3 "$log" | tr '\n' ' ' | cut -c1-300)"
done
[[ -z "${ANGELOS_TEST_LOG:-}" ]] || for sh in "${SHARDS[@]}"; do cat "$T/${sh%%|*}.log"; done >"$ANGELOS_TEST_LOG"

# errors in the log, with the page that was loading
errs=$(for sh in "${SHARDS[@]}"; do cat "$T/${sh%%|*}.log"; done | awk '/TEST-PAGE /{sub(/.*TEST-PAGE /,""); page=$0; next}
  /is not a type|Binding loop detected|TypeError|ReferenceError|Cannot assign|Unable to assign|is not defined|Cannot read property|Cannot call method|failed to load component|Error loading|Cannot open: file/ {
    line=$0; gsub(/\033\[[0-9;]*m/,"",line); print "[" (page==""?"startup":page) "] " substr(line,1,220) }' | sort -u)
if [[ -n "$errs" ]]; then
  bad "errors in the log:"; printf '%s\n' "$errs" | head -30 | sed 's/^/      /'
else
  ok "no QML errors, binding loops, JS exceptions or missing images"
fi

# suite NAME "what it checks": its result, the lines that are not ✓ when it failed
result() {
  if [[ "$(cat "$T/suite-$1.code" 2>/dev/null)" == 0 ]]; then
    ok "$2"
  else
    bad "$3 (tests/$1/run.sh):"; grep -v '✓' "$T/suite-$1.out" | head -"$4" | sed 's/^/      /'
  fi
}
# the theme export to the apps (tests/theme): heaven ⇄ hell in any order and timing, the last
# state is the one on disk (window borders stayed hell's after a return "as in the game")
result theme "theme export: the last state reaches the apps (late realm, toggles during a render, late hell accent)" "theme export" 20
# the scale matrix (tests/scale): Settings, the Start looks, the bar and a notification at art
# pixel 1–4 and fonts ×1, ×1.5 (the step between) and ×2 — nothing runs over, out of its box or off
result scale "scale matrix: px 2 ×2, px 1, px 4, px 3 ×1.5, px 4 ×2 — no text over text, cut or overflowing" "scale matrix" 30
# the lock screen (tests/lock): both looks type, fail and unlock, the stream's audience
# follows the days, the replay plays, every unlock style draws; and the SDDM theme
# (tests/sddm) under a stand-in SDDM — both offscreen here
result lock "lock screen: NGO and heaven looks, typing, mistakes, unlock styles, the stream's audience by day" "lock screen" 20
result sddm "SDDM theme: builds, loads, types, fails and logs in" "SDDM theme" 20
# the settings search (tests/search/table.json): a hundred everyday queries find what they must
# among the first results (concepts, other endings, debug words, the author's panel only for him)
result search "settings search: the query table finds what it must, fast" "settings search" 30
# the tips after the wizard (tests/tour): three screens, the main one every time, never the streamed one
result tour "tips after the wizard: on the main screen ×10, its own Start circled, never the streamed screen" "tips placement" 20
# the idle budget (tests/perf): left alone, the services rest — no binding that rebuilds itself,
# no poll gone fast, no helper started over and over
result perf "idle budget: CPU, wake-ups and processes started at rest" "idle budget" 10
# memory that stays behind (tests/leak): every settings page opened round after round — a page
# that leaves something when it goes makes each round cost more
result leak "memory: settings pages opened round after round leave nothing behind" "memory left behind" 10
# the hang watchdog (tests/guard, no shell needed): it asks a healthy shell once a minute, not
# every tick, and still aborts one that stopped answering
result guard "hang watchdog: a healthy shell is left in peace, a busy, stuck or silent one is caught" "hang watchdog" 10
# what keeps a user from losing everything or from an empty desk (tests/rescue): a settings.json
# or save.json cut short comes back from its last good copy, a first start takes the system's
# language, five failed starts open the rescue window
result rescue "rescue: settings and save cut short come back, the first start's language, the window after five failed starts" "rescue" 20
# Quick Share (tests/quickshare, no shell needed): two daemons on loopback in a namespace of their own
result quickshare "Quick Share: text, a file byte for byte, a folder, a refusal, receive off" "Quick Share" 15
# links found in text (tests/links, node): Circle's chips, the clipboard's «open», notifications' links
result links "links: addresses with and without https, mail, phones; not file names, versions or sentences" "links" 10
result eq "bar equalizer: one service for every bar, an app found in EasyEffects is taken over and given back" "bar equalizer" 15
# the desk's one clock (tests/desk): the spectrum keeps its blocks and moves on the clock of the
# live wallpaper, LiveBeat hears a spectrum instead of a cava of its own, thumbnails only from the cache
result desk "desk clock: spectrum blocks kept, bars on the scene's tick, LiveBeat from the spectrum, cached thumbnails" "desk clock" 15
# the screenshot (tests/circle, keys, capture, capture_regions, island): the overlay, its keys,
# saving, the areas it finds and the island search it opens
result circle "screenshot overlay: areas, words, picks, keys, bar → Capture/Island/QuickShare; OCR reads both themes, no junk off pictures" "screenshot overlay" 20
result keys "screenshot keys: IPC capture/captureOn/circle, classic, old \"circle\" menu entry" "screenshot keys" 15
result capture "screenshot saving: the part pixel-exact, month folder, clipboard, notification" "screenshot saving" 15
result capture_regions "screenshot areas: windows, pictures side by side, text blocks, cards, shadows, edges to the pixel, < 400 ms" "screenshot areas" 10
result island "island search: search and Lens in the island, ↗ hands the current page to the browser, browser when off" "island search" 15

if ((fail)); then echo "» UI SELF-TEST FAILED"; exit 1; fi
echo "» UI self-test passed ♡"
