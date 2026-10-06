#!/usr/bin/env bash
# The lock screen, offscreen: both looks (NGO stream, heaven's gate) through typing, a
# wrong password and the unlock, the replay, and every unlock style over a stand-in
# desktop. No QML errors; ANGELOS_TEST_SHOTS=dir keeps the pictures to look at.
# Qt's offscreen platform draws no shaders (the pixelated wallpaper, heaven's sky, the
# replay's blur, the unlock styles): ANGELOS_LOCK_TEST_GPU=1 runs it in a real window in
# this Wayland session instead ("angelOS [dev]", which niri keeps off the stream monitor).
#
#   tests/lock/run.sh [angelOS dir]     exit 0 = all good, 77 = no quickshell
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

T="$(mktemp -d /tmp/aos-lock.XXXXXX)"
trap 'rm -rf "$T"' EXIT
H="$T/home"
mkdir -p "$H/.config/angelos" "$H/Videos" "$T/rt" "$T/root" && chmod 700 "$T/rt"

for f in "$DIR"/*; do [[ "${f##*/}" == shell.qml ]] || ln -s "$f" "$T/root/"; done
python3 - "$DIR/shell.qml" >"$T/root/shell.qml" <<'PY'
import re, sys
lines = [l for l in open(sys.argv[1]).read().splitlines() if not re.match(r"^    [A-Z][A-Za-z0-9]* \{\}\s*$", l)]
text = "\n".join(lines).rstrip()
text = text.replace("import qs.widgets", "import qs.widgets\nimport qs.tests.lock", 1)
print(text[:text.rfind("}")] + "    LockDriver {}\n}")
PY

# a picture for the wallpaper and a short video for the replay (both made here)
wall="$H/wall.png"
python3 - "$wall" <<'PY'
import struct, sys, zlib
w, h = 320, 180
rows = b"".join(b"\0" + bytes(sum(([(x * 255 // w), (y * 255 // h), 200] for x in range(w)), [])) for y in range(h))
png = b"\x89PNG\r\n\x1a\n"
def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b"")
open(sys.argv[1], "wb").write(png)
PY
if command -v ffmpeg >/dev/null; then
  ffmpeg -loglevel error -f lavfi -i "testsrc2=size=640x360:rate=25:duration=30" -c:v libx264 -pix_fmt yuv420p "$H/Videos/clip.mp4" 2>/dev/null || true
fi

# the user's fonts, so the pictures look like the real thing (CI has none: system fonts)
[[ -d "$HOME/.local/share/fonts" ]] && mkdir -p "$H/.local/share" && ln -s "$HOME/.local/share/fonts" "$H/.local/share/fonts"

cat >"$H/.config/angelos/settings.json" <<JSON
{"setup": {"complete": true}, "stream": {"auto": false}, "y2k": {"sounds": false, "helper": false, "boot": false},
 "bar": {"metaTap": false}, "updates": {"autoCheck": false}, "system": {"nautilusDefaults": true},
 "appearance": {"px": 2, "fontScale": 1}, "wallpaper": {"fallback": "$wall"},
 "lock": {"stream": true, "replayDelay": 5}}
JSON

log="${ANGELOS_TEST_LOG:-$T/qs.log}"
runner=()
command -v dbus-run-session >/dev/null && runner=(dbus-run-session --)
platform=(QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$T/rt")
if [[ "${ANGELOS_LOCK_TEST_GPU:-}" == 1 && -n "${WAYLAND_DISPLAY:-}" ]]; then
  platform=(QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="$WAYLAND_DISPLAY" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR")
fi
env -i PATH="$PATH" LANG=C.UTF-8 HOME="$H" USER="${USER:-angel}" \
  XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.local/state" \
  XDG_CACHE_HOME="$H/.cache" XDG_DATA_HOME="$H/.local/share" "${platform[@]}" \
  QT_QPA_PLATFORMTHEME= LD_LIBRARY_PATH="$LIB" QML_IMPORT_PATH="$QML" \
  ANGELOS_DEV=1 ANGELOS_SCREENS=__none__ ANGELOS_TEST=1 ANGELOS_TEST_SHOTS="${ANGELOS_TEST_SHOTS:-}" \
  QS_NO_RELOAD_POPUP=1 QS_DISABLE_CRASH_HANDLER=1 \
  "${runner[@]}" timeout 140 "$QS" -p "$T/root" >"$log" 2>&1
code=$?

fail=0
while read -r _ name res detail; do
  if [[ "$res" == PASS ]]; then printf '  ✓ %s %s\n' "$name" "$detail"; else printf '  ✕ %s %s\n' "$name" "$detail"; fail=1; fi
done < <(sed -n 's/.*\(TEST [^ ]* \(PASS\|FAIL\).*\)/\1/p' "$log")
grep -q 'TEST DONE' "$log" || { echo "  ✕ the test did not finish (exit $code): $(tail -3 "$log" | tr '\n' ' ' | cut -c1-300)"; fail=1; }
errs=$(grep -E 'modules/lock|LockDriver|LockStream|HeartBurst' "$log" | grep -E 'TypeError|ReferenceError|Unable to assign|is not defined|Cannot read property|Binding loop|is not a type|Cannot assign|failed to load' | sed 's/\x1b\[[0-9;]*m//g' | sort -u | head -15)
[[ -z "$errs" ]] || { echo "  ✕ QML errors:"; printf '%s\n' "$errs" | sed 's/^/      /'; fail=1; }
((fail == 0)) && echo "  lock screen: both looks, typing, mistakes, the unlocks — no errors"
exit "$fail"
