#!/usr/bin/env bash
# The screenshot overlay (Circle to Search / Live Text), offscreen: a frame with known words (drawn
# by the driver) grabbed through a stand-in grim, its areas (capture_regions.py), its words
# (tesseract), the picks (loop, line, words, rectangle, area, corner drag), the keys, the bar's
# actions through the real Capture / Island / QuickShare: saving into the fake home, the island and
# the browser as stand-in qml6 / xdg-open, translate through a stand-in `trans`, copy through a
# stand-in `wl-copy` — no real clipboard, network or screen.
#
#   tests/circle/run.sh [angelOS dir]      exit 0 = all good, 77 = no quickshell
#   CIRCLE_SNAP_DIR=<dir>                  also keep pictures of the overlay's face there
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

T="$(mktemp -d /tmp/aos-circle.XXXXXX)"
trap 'rm -rf "$T"' EXIT
H="$T/home"
mkdir -p "$H/.config/angelos" "$T/rt" "$T/root" "$T/fake" "$T/bin" && chmod 700 "$T/rt"
# the user's own OCR languages (tessdata in ~/.local/share), if any
[[ -d "$HOME/.local/share/tessdata" ]] && mkdir -p "$H/.local/share" && ln -s "$HOME/.local/share/tessdata" "$H/.local/share/tessdata"

for f in "$DIR"/*; do [[ "${f##*/}" == shell.qml ]] || ln -s "$f" "$T/root/"; done
python3 - "$DIR/shell.qml" >"$T/root/shell.qml" <<'PY'
import re, sys
lines = [l for l in open(sys.argv[1]).read().splitlines() if not re.match(r"^    [A-Z][A-Za-z0-9]* \{\}\s*$", l)]
text = "\n".join(lines).rstrip()
text = text.replace("import qs.widgets", "import qs.widgets\nimport qs.tests.circle", 1)
print(text[:text.rfind("}")] + "    CircleDriver {}\n}")
PY
cat >"$H/.config/angelos/settings.json" <<'JSON'
{"setup": {"complete": true}, "stream": {"auto": false}, "y2k": {"sounds": false, "helper": false, "boot": false},
 "bar": {"metaTap": false}, "updates": {"autoCheck": false}, "appearance": {"language": "ru"}}
JSON
cat >"$T/bin/wl-copy" <<'EOF'
#!/bin/sh
[ "$1" = "--" ] && shift
printf '%s' "$*" >"$FAKE_DIR/clip.part" && mv "$FAKE_DIR/clip.part" "$FAKE_DIR/clip"
EOF
for t in gdbus pw-play; do printf '#!/bin/sh\nexit 0\n' >"$T/bin/$t"; done
# notify-send: what it was asked kept; asked to wait for a button, it answers what the test put in
cat >"$T/bin/notify-send" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$FAKE_DIR/notify"
case " $* " in *" --wait "*) [ -s "$FAKE_DIR/answer" ] && cat "$FAKE_DIR/answer";; esac
exit 0
EOF
cat >"$T/bin/trans" <<'EOF'
#!/bin/sh
# trans -b -no-ansi -no-autocorrect :<to> <text>: what it was given is kept
for a; do case "$a" in :*) to="${a#:}";; esac; last="$a"; done
printf '%s\n' "$last" >>"$FAKE_DIR/trans"
echo "ПЕРЕВОД:$to"
EOF
# grim [-c] -o <screen> -t ppm <out>: its arguments kept, the driver's frame is "the screen"
cat >"$T/bin/grim" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$FAKE_DIR/grim"
for a; do out="$a"; done
cp "$FAKE_DIR/frame.ppm" "$out"
EOF
# what the island (qml6 Island.qml -- URL …) and the browser were asked to open
cat >"$T/bin/qml6" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$FAKE_DIR/island"
EOF
cat >"$T/bin/xdg-open" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$FAKE_DIR/xdg"
EOF
chmod +x "$T/bin/"*
tess=0; command -v tesseract >/dev/null && tess=1

log="${ANGELOS_TEST_LOG:-$T/qs.log}"
runner=()
command -v dbus-run-session >/dev/null && runner=(dbus-run-session --)
env -i PATH="$T/bin:$PATH" LANG=C.UTF-8 HOME="$H" USER="${USER:-angel}" \
  XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.local/state" \
  XDG_CACHE_HOME="$H/.cache" XDG_DATA_HOME="$H/.local/share" XDG_RUNTIME_DIR="$T/rt" \
  QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= LD_LIBRARY_PATH="$LIB" QML_IMPORT_PATH="$QML" \
  ANGELOS_DEV=1 ANGELOS_TEST=1 QS_NO_RELOAD_POPUP=1 QS_DISABLE_CRASH_HANDLER=1 \
  NIRI_SOCKET="$T/no-niri" FAKE_DIR="$T/fake" HAS_TESSERACT="$tess" CIRCLE_SNAP_DIR="${CIRCLE_SNAP_DIR:-}" \
  "${runner[@]}" timeout 240 "$QS" -p "$T/root" >"$log" 2>&1
code=$?

fail=0 n=0
while read -r _ name res detail; do
  n=$((n + 1))
  if [[ "$res" == PASS ]]; then [[ -n "${ANGELOS_TEST_VERBOSE:-}" ]] && printf '  ✓ %s %s\n' "$name" "$detail"; else printf '  ✕ %s %s\n' "$name" "$detail"; fail=1; fi
done < <(sed -n 's/.*\(TEST [^ ]* \(PASS\|FAIL\).*\)/\1/p' "$log")
grep -q 'TEST DONE' "$log" || { echo "  ✕ the test did not finish (exit $code): $(tail -3 "$log" | tr '\n' ' ' | cut -c1-400)"; fail=1; }
errs=$(grep -E 'Circle|circle' "$log" | grep -E 'TypeError|ReferenceError|Unable to assign|is not defined|Cannot read property|Binding loop|is not a type|Cannot assign|non-existent|not a function|Could not' | sed 's/\x1b\[[0-9;]*m//g' | sort -u | head -12)
[[ -z "$errs" ]] || { echo "  ✕ QML errors:"; printf '%s\n' "$errs" | sed 's/^/      /'; fail=1; }
# the OCR page itself (scripts/circle.py on drawn pieces: mixed polarity, buttons, a doubtful link)
if ((tess)); then
  o="$(python3 "$DIR/tests/circle/test_ocr.py" "$DIR" 2>&1)"; rc=$?
  n=$((n + $(grep -c '[✓✕]' <<<"$o")))
  ((rc == 0 || rc == 77)) || { grep '✕' <<<"$o"; fail=1; }
fi
# what it learns (services/CircleLearn.js), in node
if command -v node >/dev/null; then
  o="$(node "$DIR/tests/circle/test_learn.mjs" 2>&1)" || { echo "  ✕ learning: $o" | head -5; fail=1; }
  n=$((n + $(grep -o '[0-9]* checks' <<<"$o" | grep -o '[0-9]*' || echo 0)))
fi
# a YouTube id read wrong (I/l/1, O/0): its look-alikes against a stand-in YouTube
o="$(python3 "$DIR/tests/circle/test_fixlink.py" "$DIR" 2>&1)" || { grep '✕' <<<"$o"; fail=1; }
n=$((n + $(grep -c '[✓✕]' <<<"$o")))
((fail)) || echo "  ✓ screenshot overlay: $n checks (stand-in grim, trans, wl-copy, island)"
exit $fail
