#!/usr/bin/env bash
# The stream's chat on screen, offline: scripts/stream-chat.py (its self-test), then offscreen
# services/StreamChat over a session log written here (five earlier sessions make a regular) —
# the Halo's capsule, a paid message, the cats' line along the bottom, their switch. Nothing
# talks to YouTube: the log is what a chat reader would write.
#
#   tests/streamchat/run.sh [angelOS dir]      exit 0 = all good, 77 = no quickshell
#   ANGELOS_CHAT_SHOTS=dir …                   pictures of the running cats
set -uo pipefail
DIR="$(cd "${1:-"$(dirname "$0")/../.."}" && pwd)"
[[ -f "$DIR/shell.qml" ]] || { echo "no angelOS in $DIR"; exit 2; }
fail=0
if out=$(python3 "$DIR/scripts/stream-chat.py" --self-test 2>&1); then
  echo "  ✓ chat follower: the newest session, nothing replayed, links cut, regulars, a half-written line waits"
else
  printf '  ✕ chat follower: %s\n' "$(tail -3 <<<"$out" | tr '\n' ' ')"; fail=1
fi

QS="$(command -v quickshell || true)"
LIB="${LD_LIBRARY_PATH:-}" QML="${QML_IMPORT_PATH:-}"
if [[ ! -x /usr/bin/quickshell && -x "$HOME/.local/opt/quickshell/usr/bin/quickshell" ]]; then
  QS="$HOME/.local/opt/quickshell/usr/bin/quickshell"
  LIB="$HOME/.local/opt/quickshell/usr/lib${LIB:+:$LIB}"
  QML="$HOME/.local/opt/quickshell/usr/lib/qt6/qml${QML:+:$QML}"
fi
[[ -x "$QS" ]] || { echo "quickshell not found"; ((fail)) && exit 1; exit 77; }

T="$(mktemp -d /tmp/aos-chat.XXXXXX)"
trap 'pkill -P $$ 2>/dev/null; rm -rf "$T"' EXIT
H="$T/home" C="$T/logs"
mkdir -p "$H/.config/angelos" "$T/rt" "$T/root" "$C" && chmod 700 "$T/rt"
for n in 1 2 3 4 5; do printf '{"event": "chat", "author": "@regular", "text": "hi"}\n' >"$C/2026-10-0$n.jsonl"; done
sleep 0.05
printf '{"event": "chat", "author": "@before", "text": "said before the shell came"}\n' >"$C/2026-10-20_2100.jsonl"
for f in "$DIR"/*; do [[ "${f##*/}" == shell.qml ]] || ln -s "$f" "$T/root/"; done
cat >"$T/root/shell.qml" <<'QML'
//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.tests.streamchat
ShellRoot {
    ChatDriver {}
}
QML
cat >"$H/.config/angelos/settings.json" <<'JSON'
{"setup": {"complete": true}, "appearance": {"language": "ru"}}
JSON
[[ -n "${ANGELOS_CHAT_SHOTS:-}" ]] && mkdir -p "$ANGELOS_CHAT_SHOTS"
log="${ANGELOS_TEST_LOG:-$T/qs.log}"
env -i PATH="$PATH" LANG=C.UTF-8 HOME="$H" USER="${USER:-angel}" \
  XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.local/state" \
  XDG_CACHE_HOME="$H/.cache" XDG_DATA_HOME="$H/.local/share" XDG_RUNTIME_DIR="$T/rt" \
  QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= LD_LIBRARY_PATH="$LIB" QML_IMPORT_PATH="$QML" \
  ANGELOS_TEST=1 QML_XHR_ALLOW_FILE_READ=1 QS_NO_RELOAD_POPUP=1 QS_DISABLE_CRASH_HANDLER=1 NIRI_SOCKET="$T/no-niri" \
  ANGELOS_CHAT_DIR="$C" ANGELOS_CHAT_SHOTS="${ANGELOS_CHAT_SHOTS:-}" \
  timeout 90 "$QS" -p "$T/root" >"$log" 2>&1
code=$?

n=0 qfail=0
while read -r _ name res detail; do
  n=$((n + 1))
  if [[ "$res" == PASS ]]; then [[ -n "${ANGELOS_TEST_VERBOSE:-}" ]] && printf '  ✓ %s %s\n' "$name" "$detail"; else printf '  ✕ %s %s\n' "$name" "$detail"; qfail=1; fi
done < <(sed -n 's/.*\(TEST [^ ]* \(PASS\|FAIL\).*\)/\1/p' "$log")
grep -q 'TEST DONE' "$log" || { echo "  ✕ the chat test did not finish (exit $code): $(tail -3 "$log" | tr '\n' ' ' | cut -c1-400)"; qfail=1; }
errs=$(grep -E 'StreamChat|ChatRunners|ChatDriver|Halo\.qml' "$log" | grep -E 'TypeError|ReferenceError|Unable to assign|is not defined|Cannot read property|Binding loop|is not a type|Cannot assign|not a function' | sed 's/\x1b\[[0-9;]*m//g' | sort -u | head -8)
[[ -z "$errs" ]] || { echo "  ✕ QML errors:"; printf '%s\n' "$errs" | sed 's/^/      /'; qfail=1; }
((qfail)) || echo "  ✓ stream chat: $n checks (a message, the Halo's capsule, paid + regular, a burst of cats as a line, the race, a colour from the chat, a mine and its toll, the switch)"
((qfail)) && fail=1
exit $fail
