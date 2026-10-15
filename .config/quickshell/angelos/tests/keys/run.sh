#!/usr/bin/env bash
# The screenshot's ways in: the key templates (test_capture_keys.py), then offscreen the IPC
# (angelos capture / captureOn / the old circle names → the overlay's grab; with Settings →
# Screenshots → «Classic region selection» the old selector) and the desktop menus (an old
# "circle" entry is the screenshot). grim, niri and the old selector are stand-ins.
#
#   tests/keys/run.sh [angelOS dir]      exit 0 = all good, 77 = no quickshell
set -uo pipefail
DIR="$(cd "${1:-"$(dirname "$0")/../.."}" && pwd)"
[[ -f "$DIR/shell.qml" ]] || { echo "no angelOS in $DIR"; exit 2; }
fail=0
python3 "$DIR/tests/keys/test_capture_keys.py" "$DIR" || fail=1

QS="$(command -v quickshell || true)"
LIB="${LD_LIBRARY_PATH:-}" QML="${QML_IMPORT_PATH:-}"
if [[ ! -x /usr/bin/quickshell && -x "$HOME/.local/opt/quickshell/usr/bin/quickshell" ]]; then
  QS="$HOME/.local/opt/quickshell/usr/bin/quickshell"
  LIB="$HOME/.local/opt/quickshell/usr/lib${LIB:+:$LIB}"
  QML="$HOME/.local/opt/quickshell/usr/lib/qt6/qml${QML:+:$QML}"
fi
[[ -x "$QS" ]] || { echo "quickshell not found"; exit 77; }

T="$(mktemp -d /tmp/aos-keys.XXXXXX)"
trap 'rm -rf "$T"' EXIT
H="$T/home"
mkdir -p "$H/.config/angelos" "$H/.local/bin" "$T/rt" "$T/root" "$T/fake" "$T/bin" && chmod 700 "$T/rt"
for f in "$DIR"/*; do [[ "${f##*/}" == shell.qml ]] || ln -s "$f" "$T/root/"; done
cat >"$T/root/shell.qml" <<'QML'
//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.modules
import qs.tests.keys
ShellRoot {
    Ipc {
        id: ipc
    }
    KeysDriver {
        ipc: ipc
    }
}
QML
cat >"$H/.config/angelos/settings.json" <<'JSON'
{"setup": {"complete": true}, "appearance": {"language": "ru"}, "capture": {"classic": false}}
JSON
# stand-ins: each says it was called, and fails (no frame, no compositor)
for t in grim niri; do printf '#!/bin/sh\necho "%s $*" >>"$FAKE_DIR/calls"\nexit 1\n' "$t" >"$T/bin/$t"; done
printf '#!/bin/sh\necho "old-selector $*" >>"$FAKE_DIR/calls"\n' >"$H/.local/bin/niri-screenshot-region"
printf '#!/bin/sh\nexit 0\n' >"$T/bin/notify-send"
chmod +x "$T/bin/"* "$H/.local/bin/"*

log="${ANGELOS_TEST_LOG:-$T/qs.log}"
env -i PATH="$T/bin:$PATH" LANG=C.UTF-8 HOME="$H" USER="${USER:-angel}" \
  XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.local/state" \
  XDG_CACHE_HOME="$H/.cache" XDG_DATA_HOME="$H/.local/share" XDG_RUNTIME_DIR="$T/rt" \
  QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= LD_LIBRARY_PATH="$LIB" QML_IMPORT_PATH="$QML" \
  ANGELOS_TEST=1 QML_XHR_ALLOW_FILE_READ=1 QS_NO_RELOAD_POPUP=1 QS_DISABLE_CRASH_HANDLER=1 \
  NIRI_SOCKET="$T/no-niri" FAKE_DIR="$T/fake" \
  timeout 60 "$QS" -p "$T/root" >"$log" 2>&1
code=$?

n=0 qfail=0
while read -r _ name res detail; do
  n=$((n + 1))
  if [[ "$res" == PASS ]]; then [[ -n "${ANGELOS_TEST_VERBOSE:-}" ]] && printf '  ✓ %s %s\n' "$name" "$detail"; else printf '  ✕ %s %s\n' "$name" "$detail"; qfail=1; fi
done < <(sed -n 's/.*\(TEST [^ ]* \(PASS\|FAIL\).*\)/\1/p' "$log")
grep -q 'TEST DONE' "$log" || { echo "  ✕ the test did not finish (exit $code): $(tail -3 "$log" | tr '\n' ' ' | cut -c1-400)"; qfail=1; }
errs=$(grep -E 'Ipc\.qml|DeskMenu|Capture\.qml|KeysDriver' "$log" | grep -E 'TypeError|ReferenceError|Unable to assign|is not defined|Cannot read property|Binding loop|is not a type|Cannot assign|not a function' | sed 's/\x1b\[[0-9;]*m//g' | sort -u | head -8)
[[ -z "$errs" ]] || { echo "  ✕ QML errors:"; printf '%s\n' "$errs" | sed 's/^/      /'; qfail=1; }
((qfail)) || echo "  ✓ screenshot IPC and menus: $n checks (capture/captureOn/circle → the overlay, classic → the old selector, old \"circle\" menu entry)"
((qfail)) && fail=1
exit $fail
