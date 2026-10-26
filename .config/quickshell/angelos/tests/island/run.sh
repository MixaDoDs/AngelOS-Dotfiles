#!/usr/bin/env bash
# The mini island's search and Lens (services/Island), offscreen: the engines' result links,
# Cyrillic and signs encoded, off → the browser, on → the island (a stand-in qml6 records how
# it was started; the command file says what it was told), the Lens page with the picture.
# No network, no browser, no window: xdg-open and qml6 are stand-ins.
# Then the island's own program (scripts/island, real qml6 + QtWebEngine, offscreen) against a
# little web on 127.0.0.1 (web.py): our Lens page, loaded from a file, posts the picture;
# ↗ ("browser") hands the default browser the page it is on now. Skipped without QtWebEngine.
#
#   tests/island/run.sh [angelOS dir]      exit 0 = all good, 77 = no quickshell
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

QML6="$(command -v qml6 || true)"
T="$(mktemp -d /tmp/aos-island.XXXXXX)"
# our own processes only, by PID
trap 'for p in $(cat "$T/fake/qml6.pid" "$T/pids" 2>/dev/null); do kill "$p" 2>/dev/null; done; rm -rf "$T"' EXIT
H="$T/home"
mkdir -p "$H/.config/angelos" "$T/rt" "$T/root" "$T/fake" "$T/bin" && chmod 700 "$T/rt"
for f in "$DIR"/*; do [[ "${f##*/}" == shell.qml ]] || ln -s "$f" "$T/root/"; done
cat >"$T/root/shell.qml" <<'QML'
//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.tests.island
ShellRoot {
    IslandDriver {}
}
QML
cat >"$H/.config/angelos/settings.json" <<'JSON'
{"setup": {"complete": true}, "appearance": {"language": "ru"}, "circle": {"engine": "google", "lensWindow": false}}
JSON
cat >"$T/bin/xdg-open" <<'EOF2'
#!/bin/sh
printf '%s\n' "$1" >>"$FAKE_DIR/xdg-open"
EOF2
# the island's program: say how it was started, then stay (running) until the test ends;
# ↗ pressed (the driver leaves "arrow"): the events the island sends, one that must go nowhere
cat >"$T/bin/qml6" <<'EOF2'
#!/bin/sh
printf '%s\n' "$@" >"$FAKE_DIR/qml6"
echo $$ >"$FAKE_DIR/qml6.pid"
for i in $(seq 600); do
  if [ -f "$FAKE_DIR/arrow" ]; then
    rm -f "$FAKE_DIR/arrow"
    echo 'ISLAND {"ev":"browser","url":"javascript:alert(1)"}' >&2
    echo 'ISLAND {"ev":"browser","url":"https://example.org/now?a=1#b"}' >&2
  fi
  sleep 0.1
done
EOF2
printf '#!/bin/sh\nexit 0\n' >"$T/bin/notify-send"
chmod +x "$T/bin/"*
printf '\x89PNG\r\n\x1a\nangelOS-lens-test\x00\xff' >"$T/fake/pic.png"

log="${ANGELOS_TEST_LOG:-$T/qs.log}"
env -i PATH="$T/bin:$PATH" LANG=C.UTF-8 HOME="$H" USER="${USER:-angel}" \
  XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.local/state" \
  XDG_CACHE_HOME="$H/.cache" XDG_DATA_HOME="$H/.local/share" XDG_RUNTIME_DIR="$T/rt" \
  QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= LD_LIBRARY_PATH="$LIB" QML_IMPORT_PATH="$QML" \
  ANGELOS_TEST=1 QML_XHR_ALLOW_FILE_READ=1 QS_NO_RELOAD_POPUP=1 QS_DISABLE_CRASH_HANDLER=1 \
  NIRI_SOCKET="$T/no-niri" FAKE_DIR="$T/fake" \
  timeout 60 "$QS" -p "$T/root" >"$log" 2>&1
code=$?

fail=0 n=0
while read -r _ name res detail; do
  n=$((n + 1))
  if [[ "$res" == PASS ]]; then [[ -n "${ANGELOS_TEST_VERBOSE:-}" ]] && printf '  ✓ %s %s\n' "$name" "$detail"; else printf '  ✕ %s %s\n' "$name" "$detail"; fail=1; fi
done < <(sed -n 's/.*\(TEST [^ ]* \(PASS\|FAIL\).*\)/\1/p' "$log")
grep -q 'TEST DONE' "$log" || { echo "  ✕ the test did not finish (exit $code): $(tail -3 "$log" | tr '\n' ' ' | cut -c1-400)"; fail=1; }
errs=$(grep -E 'Island|island' "$log" | grep -E 'TypeError|ReferenceError|Unable to assign|is not defined|Cannot read property|Binding loop|is not a type|Cannot assign|not a function' | sed 's/\x1b\[[0-9;]*m//g' | sort -u | head -8)
[[ -z "$errs" ]] || { echo "  ✕ QML errors:"; printf '%s\n' "$errs" | sed 's/^/      /'; fail=1; }
((fail)) || echo "  ✓ Island search and Lens: $n checks (stand-in qml6 and xdg-open)"

# ── the island's program ──
P="$T/prog"
mkdir -p "$P/bin" "$P/lens" "$H/.cache"
web_ok=0
# qml6 is the system's Qt (not quickshell's own libraries)
if [[ -z "$QML6" ]] || ! printf 'import QtWebEngine\nimport QtQuick\nItem { Component.onCompleted: Qt.quit() }\n' >"$P/probe.qml" ||
  ! env -i PATH="$PATH" HOME="$H" QT_QPA_PLATFORM=offscreen timeout 20 "$QML6" "$P/probe.qml" >/dev/null 2>&1; then
  echo "  - the island's program skipped (no qml6 with QtWebEngine)"
  exit $fail
fi
cat >"$P/bin/xdg-open" <<'EOF2'
#!/bin/sh
printf '%s\n' "$1" >>"$FAKE_DIR/browser"
EOF2
chmod +x "$P/bin/xdg-open"
python3 -I "$DIR/tests/island/web.py" "$P/port" "$P/web.log" "$T/fake/pic.png" &
echo $! >>"$T/pids"
for _ in $(seq 50); do [[ -s "$P/port" ]] && break; sleep 0.1; done
port="$(cat "$P/port" 2>/dev/null)"
# the page Island.lens wrote (above), its form sent here instead of to Google
lensf="$P/lens/angelos-island-lens.html"
sed "s|https://lens.google.com/v3/upload?|http://127.0.0.1:$port/upload?|" "$T/rt/angelos-island-lens.html" >"$lensf"
grep -q "127.0.0.1:$port/upload" "$lensf" || { echo "  ✕ no Lens page from Island.lens to load"; exit 1; }
printf '{"cmd":"open","url":"file://%s","seq":1}' "$lensf" >"$P/cmd.json"
env -i PATH="$P/bin:$PATH" LANG=C.UTF-8 HOME="$H" XDG_DATA_HOME="$H/.local/share" XDG_CACHE_HOME="$H/.cache" \
  XDG_CONFIG_HOME="$H/.config" XDG_RUNTIME_DIR="$T/rt" QT_QPA_PLATFORM=offscreen \
  QML_XHR_ALLOW_FILE_READ=1 QT_FORCE_STDERR_LOGGING=1 QTWEBENGINE_CHROMIUM_FLAGS="--no-proxy-server" FAKE_DIR="$P" \
  timeout 60 "$QML6" "$DIR/scripts/island/Island.qml" -- "file://$lensf" "$P/cmd.json" 460 720 dev shell-opens >"$P/prog.log" 2>&1 &
prog=$!
echo $prog >>"$T/pids"
until_log() { for _ in $(seq 150); do grep -q "$1" "$P/web.log" 2>/dev/null && return 0; sleep 0.1; done; return 1; }
check() { if [[ "$2" == 1 ]]; then [[ -n "${ANGELOS_TEST_VERBOSE:-}" ]] && printf '  ✓ %s\n' "$1"; else printf '  ✕ %s %s\n' "$1" "$3"; fail=1; fi; }
until_log '^POST '
check "program-lens-posts" "$(grep -qE '^POST /upload\?ep=ccm(&hl=[a-zA-Z]*)?&st=[0-9]+ picture' "$P/web.log" && echo 1)" "$(head -3 "$P/web.log" 2>/dev/null | tr '\n' ' ') $(grep -v GBM "$P/prog.log" | tail -2 | tr '\n' ' ')"
printf '{"cmd":"open","url":"http://127.0.0.1:%s/p1","seq":2}' "$port" >"$P/cmd.json"
until_log '^GET /p2'
check "program-opens" "$(grep -q '^GET /p1' "$P/web.log" && grep -q '^GET /p2' "$P/web.log" && echo 1)" "$(tr '\n' ' ' <"$P/web.log")"
sleep 0.5
printf '{"cmd":"browser","seq":3}' >"$P/cmd.json"
for _ in $(seq 50); do kill -0 $prog 2>/dev/null || break; sleep 0.1; done
# ↗ is the shell's to open (services/Island: the browser event), the page it is on now
said=$(sed -n 's/.*ISLAND \({"ev":"browser".*\)/\1/p' "$P/prog.log")
check "program-browser-now" "$( [[ "$said" == "{\"ev\":\"browser\",\"url\":\"http://127.0.0.1:$port/p2?x=1\"}" ]] && echo 1)" "said: $said"
check "program-browser-not-itself" "$( [[ ! -e "$P/browser" ]] && echo 1)" "the island opened it too: $(cat "$P/browser" 2>/dev/null)"
check "program-browser-closes" "$(kill -0 $prog 2>/dev/null || echo 1)" "still running"
errs=$(grep -E 'Island.qml' "$P/prog.log" | grep -E 'TypeError|ReferenceError|Unable to assign|is not defined|Cannot read property|is not a type|Cannot assign|not a function' | sort -u | head -5)
[[ -z "$errs" ]] || { echo "  ✕ the program's QML errors:"; printf '%s\n' "$errs" | sed 's/^/      /'; fail=1; }
((fail)) || echo "  ✓ the island's program: Lens page posts from a file, ↗ takes the page it is on now (offscreen, 127.0.0.1)"
exit $fail
