#!/usr/bin/env bash
# The Halo's shelf (services/Shelf), offscreen: files, folders, links, text and a downloaded
# picture land on it, duplicates move up, stars keep what is dragged out, a starred folder takes
# copies (a name already there gets « (2)»), a deleted file shows as missing, the state file.
# Stand-in wl-copy, curl, notify-send, xdg-open and gdbus; nothing real is copied or fetched.
#
#   tests/shelf/run.sh [angelOS dir]      exit 0 = all good, 77 = no quickshell
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

T="$(mktemp -d /tmp/aos-shelf.XXXXXX)"
trap 'rm -rf "$T"' EXIT
H="$T/home"
mkdir -p "$H/.config/angelos" "$H/.local/state/angelos" "$T/rt" "$T/root" "$T/fake" "$T/bin" && chmod 700 "$T/rt"
for f in "$DIR"/*; do [[ "${f##*/}" == shell.qml ]] || ln -s "$f" "$T/root/"; done
cat >"$T/root/shell.qml" <<'QML'
//@ pragma UseQApplication
import Quickshell
import qs.tests.shelf
ShellRoot {
    ShelfDriver {}
}
QML
cat >"$H/.config/angelos/settings.json" <<'JSON'
{"setup": {"complete": true}, "stream": {"auto": false}, "y2k": {"sounds": false, "helper": false, "boot": false},
 "updates": {"autoCheck": false}, "appearance": {"language": "ru"}}
JSON
# what gets dropped: a file, a folder, a starred folder that already holds a file of that name
F="$T/files"
mkdir -p "$F/dir" "$F/fav" && echo hello >"$F/a.txt" && echo old >"$F/fav/a.txt"
cat >"$T/bin/notify-send" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >>"$FAKE_DIR/notify"
SH
for t in wl-copy xdg-open gdbus; do printf '#!/bin/sh\nprintf "%%s\\n" "$*" >>"$FAKE_DIR/%s"\n' "$t" >"$T/bin/$t"; done
# pictures from a browser: a local site that, like many real ones, refuses a bare client —
# /p/cat.png wants a browser's User-Agent, /php?id=3 (a JPEG with no extension) a Referer
PORT=$((40000 + RANDOM % 20000))
python3 -I - "$PORT" <<'PY' &
import http.server, sys
PNG = bytes.fromhex("89504e470d0a1a0a0000000d4948445200000001000000010806000000")
JPG = b"\xff\xd8\xff\xe0" + b"\0" * 64
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        ua, ref = self.headers.get("User-Agent", ""), self.headers.get("Referer", "")
        body, ok = (PNG, "Mozilla" in ua) if self.path.startswith("/p/cat.png") else (JPG, bool(ref)) if self.path.startswith("/php") else (b"<html>no</html>", True)
        self.send_response(200 if ok else 403)
        self.end_headers()
        self.wfile.write(body if ok else b"refused")
    def log_message(self, *a): pass
http.server.ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
PY
srv=$!
trap 'kill "$srv" 2>/dev/null; rm -rf "$T"' EXIT
for t in pw-play qs; do printf '#!/bin/sh\nexit 0\n' >"$T/bin/$t"; done
chmod +x "$T/bin/"*

log="$T/log"
env -i PATH="$T/bin:$PATH" LANG=C.UTF-8 HOME="$H" USER="${USER:-angel}" \
  XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.local/state" \
  XDG_CACHE_HOME="$H/.cache" XDG_DATA_HOME="$H/.local/share" XDG_RUNTIME_DIR="$T/rt" \
  QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= LD_LIBRARY_PATH="$LIB" QML_IMPORT_PATH="$QML" \
  ANGELOS_DEV=1 ANGELOS_TEST=1 QS_NO_RELOAD_POPUP=1 QS_DISABLE_CRASH_HANDLER=1 \
  NIRI_SOCKET="$T/no-niri" FAKE_DIR="$T/fake" FIX_DIR="$F" SHELF_PORT="$PORT" \
  timeout 60 "$QS" -p "$T/root" >"$log" 2>&1
code=$?

fail=0 n=0
while read -r _ name res detail; do
  n=$((n + 1))
  if [[ "$res" == PASS ]]; then [[ -n "${ANGELOS_TEST_VERBOSE:-}" ]] && printf '  ✓ %s %s\n' "$name" "$detail"; else printf '  ✕ %s %s\n' "$name" "$detail"; fail=1; fi
done < <(sed -n 's/.*\(TEST [^ ]* \(PASS\|FAIL\).*\)/\1/p' "$log")
grep -q 'TEST DONE' "$log" || { echo "  ✕ the test did not finish (exit $code): $(tail -5 "$log" | tr '\n' ' ' | cut -c1-600)"; fail=1; }
errs=$(grep -E 'Shelf|shelf' "$log" | grep -E 'TypeError|ReferenceError|Unable to assign|is not defined|Cannot read property|Binding loop|is not a type|Cannot assign|non-existent|not a function|Could not' | sed 's/\x1b\[[0-9;]*m//g' | sort -u | head -12)
[[ -z "$errs" ]] || { echo "  ✕ QML errors:"; printf '%s\n' "$errs" | sed 's/^/      /'; fail=1; }
((fail)) || echo "  ✓ shelf: $n checks (drops, duplicates, stars, folder copies, missing, state file; pictures from a browser: inside a link, refused bare, data:, blob:, not a picture)"
exit $fail
