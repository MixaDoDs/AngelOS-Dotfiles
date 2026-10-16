#!/usr/bin/env bash
# The Halo's quick buttons (services/HaloButtons), offscreen: the catalog and its icons, the
# chosen order, the toggles, the fields (a timer, a note for the shelf), the pomodoro.
# Stand-in notify-send, gdbus, pw-play, qs, niri, wl-copy, curl; nothing real changes.
#
#   tests/halo_buttons/run.sh [angelOS dir]      exit 0 = all good, 77 = no quickshell
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

T="$(mktemp -d /tmp/aos-halobuttons.XXXXXX)"
trap 'rm -rf "$T"' EXIT
H="$T/home"
mkdir -p "$H/.config/angelos" "$H/.local/state/angelos" "$T/rt" "$T/root" "$T/fake" "$T/bin" && chmod 700 "$T/rt"
for f in "$DIR"/*; do [[ "${f##*/}" == shell.qml ]] || ln -s "$f" "$T/root/"; done
cat >"$T/root/shell.qml" <<'QML'
//@ pragma UseQApplication
import Quickshell
import qs.tests.halo_buttons
ShellRoot {
    ButtonsDriver {}
}
QML
cat >"$H/.config/angelos/settings.json" <<'JSON'
{"setup": {"complete": true}, "stream": {"auto": false}, "y2k": {"sounds": false, "helper": false, "boot": false},
 "updates": {"autoCheck": false}, "appearance": {"language": "ru"}}
JSON
cat >"$T/bin/notify-send" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >>"$FAKE_DIR/notify"
SH
for t in gdbus pw-play qs wl-copy curl; do printf '#!/bin/sh\nexit 0\n' >"$T/bin/$t"; done
# niri without its socket: Capture.launch runs the tool itself
printf '#!/bin/sh\nexit 1\n' >"$T/bin/niri"
chmod +x "$T/bin/"*

log="$T/log"
env -i PATH="$T/bin:$PATH" LANG=C.UTF-8 HOME="$H" USER="${USER:-angel}" \
  XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.local/state" \
  XDG_CACHE_HOME="$H/.cache" XDG_DATA_HOME="$H/.local/share" XDG_RUNTIME_DIR="$T/rt" \
  QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= LD_LIBRARY_PATH="$LIB" QML_IMPORT_PATH="$QML" \
  ANGELOS_DEV=1 ANGELOS_TEST=1 QS_NO_RELOAD_POPUP=1 QS_DISABLE_CRASH_HANDLER=1 \
  NIRI_SOCKET="$T/no-niri" FAKE_DIR="$T/fake" \
  timeout 60 "$QS" -p "$T/root" >"$log" 2>&1
code=$?

fail=0 n=0
while read -r _ name res detail; do
  n=$((n + 1))
  if [[ "$res" == PASS ]]; then [[ -n "${ANGELOS_TEST_VERBOSE:-}" ]] && printf '  ✓ %s %s\n' "$name" "$detail"; else printf '  ✕ %s %s\n' "$name" "$detail"; fail=1; fi
done < <(sed -n 's/.*\(TEST [^ ]* \(PASS\|FAIL\).*\)/\1/p' "$log")
grep -q 'TEST DONE' "$log" || { echo "  ✕ the test did not finish (exit $code): $(tail -5 "$log" | tr '\n' ' ' | cut -c1-600)"; fail=1; }
errs=$(grep -E 'HaloButtons|halo_buttons|ButtonsDriver' "$log" | grep -E 'TypeError|ReferenceError|Unable to assign|is not defined|Cannot read property|Binding loop|is not a type|Cannot assign|non-existent|not a function|Could not' | sed 's/\x1b\[[0-9;]*m//g' | sort -u | head -12)
[[ -z "$errs" ]] || { echo "  ✕ QML errors:"; printf '%s\n' "$errs" | sed 's/^/      /'; fail=1; }
((fail)) || echo "  ✓ halo buttons: $n checks (catalog, order, toggles, fields)"
exit $fail
