#!/usr/bin/env bash
# Win+V pastes (issue #61), offscreen (scripts/check.sh runs it): the Clipboard service against
# stand-ins of wl-copy and wtype (no real clipboard, no keys pressed anywhere) — Ctrl+V in the
# window the history was opened over, Ctrl+Shift+V in a terminal, nothing for Shift+Enter, the
# setting off or an empty desktop, waiting for the keyboard to come back, a stored picture.
#
#   tests/clipboard/run.sh [angelOS dir]      exit 0 = all good, 77 = no quickshell
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
T="$(mktemp -d /tmp/aos-clip.XXXXXX)"
trap 'rm -rf "$T"' EXIT
H="$T/home"
mkdir -p "$H/.config/angelos" "$T/rt" "$T/root" "$T/fake" "$T/bin" "$T/store" && chmod 700 "$T/rt" "$T/store"

# the real shell minus its screen windows (as tests/vault/run.sh), with this driver
for f in "$DIR"/*; do [[ "${f##*/}" == shell.qml ]] || ln -s "$f" "$T/root/"; done
python3 - "$DIR/shell.qml" >"$T/root/shell.qml" <<'PY'
import re, sys
lines = [l for l in open(sys.argv[1]).read().splitlines() if not re.match(r"^    [A-Z][A-Za-z0-9]* \{\}\s*$", l)]
text = "\n".join(lines).rstrip()
text = text.replace("import qs.widgets", "import qs.widgets\nimport qs.tests.clipboard", 1)
print(text[:text.rfind("}")] + "    ClipboardDriver {}\n}")
PY
cat >"$H/.config/angelos/settings.json" <<'JSON'
{"setup": {"complete": true}, "stream": {"auto": false}, "y2k": {"sounds": false, "helper": false, "boot": false},
 "bar": {"metaTap": false}, "updates": {"autoCheck": false}, "system": {"nautilusDefaults": true}, "appearance": {"language": "ru"}}
JSON
# the stand-ins first on PATH: the user's own clipboard and keyboard are never touched
cat >"$T/bin/wl-copy" <<'EOF'
#!/bin/sh
printf '%s' "$*" >"$FAKE_CLIP_DIR/clip.args"
cat >"$FAKE_CLIP_DIR/clip.part" && mv "$FAKE_CLIP_DIR/clip.part" "$FAKE_CLIP_DIR/clip"
EOF
cat >"$T/bin/wtype" <<'EOF'
#!/bin/sh
echo "$*" >>"$FAKE_CLIP_DIR/wtype.log"
EOF
for t in wl-paste setpriv pkill; do printf '#!/bin/sh\nexit 0\n' >"$T/bin/$t"; done
chmod +x "$T/bin/"*
printf '\x89PNG\r\n\x1a\n\0\0\0\rIHDR\0\0\0\1\0\0\0\1\10\6\0\0\0' >"$T/store/0123456789abcdef0123456789abcdef.png"

log="${ANGELOS_TEST_LOG:-$T/qs.log}"
runner=()
command -v dbus-run-session >/dev/null && runner=(dbus-run-session --)
env -i PATH="$T/bin:$PATH" LANG=C.UTF-8 HOME="$H" USER="${USER:-angel}" \
  XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.local/state" \
  XDG_CACHE_HOME="$H/.cache" XDG_DATA_HOME="$H/.local/share" XDG_RUNTIME_DIR="$T/rt" \
  QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= LD_LIBRARY_PATH="$LIB" QML_IMPORT_PATH="$QML" \
  ANGELOS_DEV=1 ANGELOS_SCREENS=__none__ ANGELOS_TEST=1 QS_NO_RELOAD_POPUP=1 QS_DISABLE_CRASH_HANDLER=1 \
  NIRI_SOCKET="$T/no-niri" FAKE_CLIP_DIR="$T/fake" ANGELOS_CLIPBOARD_DIR="$T/store" \
  "${runner[@]}" timeout 90 "$QS" -p "$T/root" >"$log" 2>&1
code=$?

fail=0 n=0
while read -r _ name res detail; do
  n=$((n + 1))
  if [[ "$res" == PASS ]]; then [[ -n "${ANGELOS_CLIP_VERBOSE:-}" ]] && printf '  ✓ %s %s\n' "$name" "$detail"; else printf '  ✕ %s %s\n' "$name" "$detail"; fail=1; fi
done < <(sed -n 's/.*\(TEST [^ ]* \(PASS\|FAIL\).*\)/\1/p' "$log")
grep -q 'TEST DONE' "$log" || { echo "  ✕ the test did not finish (exit $code): $(tail -3 "$log" | tr '\n' ' ' | cut -c1-400)"; fail=1; }
errs=$(grep -E 'Clipboard|ClipboardDriver' "$log" | grep -E 'TypeError|ReferenceError|Unable to assign|is not defined|Cannot read property|Binding loop|is not a type|Cannot assign|non-existent|not a function|Could not' | sed 's/\x1b\[[0-9;]*m//g' | sort -u | head -12)
[[ -z "$errs" ]] || { echo "  ✕ QML errors:"; printf '%s\n' "$errs" | sed 's/^/      /'; fail=1; }
((fail)) || echo "  ✓ Win+V pastes: $n checks (stand-in wl-copy and wtype)"
exit $fail
