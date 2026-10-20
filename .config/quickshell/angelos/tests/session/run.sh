#!/usr/bin/env bash
# Logging out, restarting and shutting down ask first, offscreen (tests/session/SessionDriver.qml):
# every way in (a click, a letter, the arrows and Enter, Start's buttons) opens the one question,
# only its yes does it, Esc / Cancel / a click beside it / anything else opening drop it, repeats
# and an early yes do nothing, Lock and Sleep never ask. Nothing real ends: the shell only writes
# the action down (ANGELOS_TEST), and systemctl, loginctl and niri here are stand-ins that log.
#
#   tests/session/run.sh [angelOS dir]     exit 0 = all good, 77 = no quickshell
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
T="$(mktemp -d /tmp/aos-sess.XXXXXX)"
trap 'rm -rf "$T"' EXIT
H="$T/home"
mkdir -p "$H/.config/angelos" "$T/rt" "$T/root" "$T/bin" && chmod 700 "$T/rt"

# the real shell minus its screen windows (as tests/eq/run.sh), with this driver
for f in "$DIR"/*; do [[ "${f##*/}" == shell.qml ]] || ln -s "$f" "$T/root/"; done
python3 - "$DIR/shell.qml" >"$T/root/shell.qml" <<'PY'
import re, sys
lines = [l for l in open(sys.argv[1]).read().splitlines() if not re.match(r"^    [A-Z][A-Za-z0-9]* \{\}\s*$", l)]
text = "\n".join(lines).rstrip()
text = text.replace("import qs.widgets", "import qs.widgets\nimport qs.tests.session", 1)
print(text[:text.rfind("}")] + "    SessionDriver {}\n}")
PY
# offscreen has no layer shell: the session's two windows come as plain windows here — the same
# files with PanelWindow → FloatingWindow and its layer-shell lines left out, the rest as it is
rm "$T/root/modules" && cp -rs "$DIR/modules" "$T/root/modules"
for f in SessionMenu SessionConfirm; do
  rm "$T/root/modules/session/$f.qml"
  python3 - "$DIR/modules/session/$f.qml" >"$T/root/modules/session/$f.qml" <<'PY2'
import re, sys
t = open(sys.argv[1]).read()
t = re.sub(r"\n    anchors \{[^}]*\}", "", t, count=1)
t = re.sub(r"\n    (screen|exclusionMode|WlrLayershell\.[A-Za-z]+):[^\n]*", "", t)
t = t.replace("PanelWindow {", "FloatingWindow {\n    implicitWidth: 1280\n    implicitHeight: 800", 1)
print(t)
PY2
done
cat >"$H/.config/angelos/settings.json" <<'JSON'
{"setup": {"complete": true}, "stream": {"auto": false}, "y2k": {"sounds": false, "helper": false, "boot": false},
 "bar": {"metaTap": false}, "updates": {"autoCheck": false}, "system": {"nautilusDefaults": true}}
JSON
# stand-ins for whatever could end the session or sleep the machine: they only log
for c in systemctl loginctl niri shutdown reboot poweroff; do
  printf '#!/bin/sh\necho "%s $*" >>"%s"\n' "$c" "$T/calls" >"$T/bin/$c"; chmod +x "$T/bin/$c"
done

log="${ANGELOS_TEST_LOG:-$T/qs.log}"
runner=()
command -v dbus-run-session >/dev/null && runner=(dbus-run-session --)
env -i PATH="$T/bin:$PATH" LANG=C.UTF-8 HOME="$H" USER="${USER:-angel}" \
  XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.local/state" \
  XDG_CACHE_HOME="$H/.cache" XDG_DATA_HOME="$H/.local/share" XDG_RUNTIME_DIR="$T/rt" \
  QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= LD_LIBRARY_PATH="$LIB" QML_IMPORT_PATH="$QML" \
  ANGELOS_DEV=1 ANGELOS_SCREENS=__none__ ANGELOS_TEST=1 QS_NO_RELOAD_POPUP=1 QS_DISABLE_CRASH_HANDLER=1 \
  "${runner[@]}" timeout 90 "$QS" -p "$T/root" >"$log" 2>&1
code=$?

fail=0 n=0
while read -r _ name res detail; do
  n=$((n + 1))
  if [[ "$res" == PASS ]]; then [[ -n "${ANGELOS_SESSION_VERBOSE:-}" ]] && printf '  ✓ %s %s\n' "$name" "$detail"; else printf '  ✕ %s %s\n' "$name" "$detail"; fail=1; fi
done < <(sed -n 's/.*\(TEST [^ ]* \(PASS\|FAIL\).*\)/\1/p' "$log")
grep -q 'TEST DONE' "$log" || { echo "  ✕ the test did not finish (exit $code): $(tail -3 "$log" | tr '\n' ' ' | cut -c1-400)"; fail=1; }
errs=$(grep -E 'SessionMenu|SessionConfirm|SessionDriver|Shell.qml' "$log" | grep -E 'TypeError|ReferenceError|Unable to assign|is not defined|Cannot read property|Binding loop|is not a type|Cannot assign|non-existent|not a function|Could not' | sed 's/\x1b\[[0-9;]*m//g' | sort -u | head -12)
[[ -z "$errs" ]] || { echo "  ✕ QML errors:"; printf '%s\n' "$errs" | sed 's/^/      /'; fail=1; }
bad=$(grep -E 'reboot|poweroff|suspend|terminate|quit|kill-session' "$T/calls" 2>/dev/null)
[[ -z "$bad" ]] || { echo "  ✕ a session command ran: $bad"; fail=1; }
((fail)) || echo "  ✓ the session asks first: $n checks (every way in, one question, only its yes; Lock and Sleep never ask)"
exit $fail
