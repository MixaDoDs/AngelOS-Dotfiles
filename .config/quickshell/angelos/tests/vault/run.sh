#!/usr/bin/env bash
# Passwords and spelling inside the shell, offscreen (scripts/check.sh runs it): the Vault
# service and the launcher's "pw …" against stand-ins of bw, rbw, op and of the clipboard
# (tests/vault/fake — no real vault, no real clipboard), the Spell service and a text area with
# two tiny dictionaries made here, the two settings pages.
#
#   tests/vault/run.sh [angelOS dir]          exit 0 = all good, 77 = no quickshell / no libhunspell
#   ANGELOS_VAULT_SHOTS=dir saves pictures of the two settings pages and of a note with mistakes
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
python3 -c 'import ctypes.util, sys; sys.exit(0 if ctypes.util.find_library("hunspell") else 1)' || { echo "no libhunspell"; exit 77; }

# a short runtime dir: Quickshell's IPC socket path must fit in 108 bytes
T="$(mktemp -d /tmp/aos-vault.XXXXXX)"
trap 'rm -rf "$T"' EXIT
H="$T/home"
mkdir -p "$H/.config/angelos" "$H/.local/share/angelos/spell" "$T/rt" "$T/root" "$T/fake" "$T/bin" && chmod 700 "$T/rt"

# the real shell minus its screen windows (as tests/search/run.sh), with this driver
for f in "$DIR"/*; do [[ "${f##*/}" == shell.qml ]] || ln -s "$f" "$T/root/"; done
python3 - "$DIR/shell.qml" >"$T/root/shell.qml" <<'PY'
import re, sys
lines = [l for l in open(sys.argv[1]).read().splitlines() if not re.match(r"^    [A-Z][A-Za-z0-9]* \{\}\s*$", l)]
text = "\n".join(lines).rstrip()
text = text.replace("import qs.widgets", "import qs.widgets\nimport qs.tests.vault", 1)
print(text[:text.rfind("}")] + "    VaultDriver {}\n}")
PY
cat >"$H/.config/angelos/settings.json" <<'JSON'
{"setup": {"complete": true}, "stream": {"auto": false}, "y2k": {"sounds": false, "helper": false, "boot": false},
 "bar": {"metaTap": false}, "updates": {"autoCheck": false}, "system": {"nautilusDefaults": true}, "appearance": {"language": "ru"}, "vault": {"clearAfter": 0, "hideOnStream": false}}
JSON
# hideOnStream is off until the driver tests it: an OBS open on this machine counts as on air
# the stand-ins first on PATH: nothing of the user's own bw / rbw / op / wl-copy is ever run
for t in bw rbw op wl-copy wl-paste secret-tool; do
  printf '#!/bin/sh\nexec python3 "%s/tests/vault/fake/cli.py" %s "$@"\n' "$DIR" "$t" >"$T/bin/$t"; chmod +x "$T/bin/$t"
done
echo '{"bw": "locked", "rbw": "locked", "op": "out"}' >"$T/fake/state.json"
printf 'SET UTF-8\nTRY абвгдеёжзийклмнопрстуфхцчшщъыьэюя\n' >"$H/.local/share/angelos/spell/ru.aff"
printf '4\nпривет\nмир\nой\nэто\n' >"$H/.local/share/angelos/spell/ru.dic"
printf 'SET UTF-8\nTRY esianrtolcdugmphbyfvkwzxjq\n' >"$H/.local/share/angelos/spell/en.aff"
printf '3\nhello\nworld\nnote\n' >"$H/.local/share/angelos/spell/en.dic"

log="${ANGELOS_TEST_LOG:-$T/qs.log}"
runner=()
command -v dbus-run-session >/dev/null && runner=(dbus-run-session --)
env -i PATH="$T/bin:$PATH" LANG=C.UTF-8 HOME="$H" USER="${USER:-angel}" \
  XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.local/state" \
  XDG_CACHE_HOME="$H/.cache" XDG_DATA_HOME="$H/.local/share" XDG_RUNTIME_DIR="$T/rt" \
  QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= LD_LIBRARY_PATH="$LIB" QML_IMPORT_PATH="$QML" \
  ANGELOS_DEV=1 ANGELOS_SCREENS=__none__ ANGELOS_TEST=1 QS_NO_RELOAD_POPUP=1 QS_DISABLE_CRASH_HANDLER=1 \
  FAKE_VAULT_DIR="$T/fake" ANGELOS_SPELL_SYSTEM="$T/none" ANGELOS_VAULT_SHOTS="${ANGELOS_VAULT_SHOTS:-}" \
  "${runner[@]}" timeout 150 "$QS" -p "$T/root" >"$log" 2>&1
code=$?

fail=0 n=0
while read -r _ name res detail; do
  n=$((n + 1))
  if [[ "$res" == PASS ]]; then [[ -n "${ANGELOS_VAULT_VERBOSE:-}" ]] && printf '  ✓ %s %s\n' "$name" "$detail"; else printf '  ✕ %s %s\n' "$name" "$detail"; fail=1; fi
done < <(sed -n 's/.*\(TEST [^ ]* \(PASS\|FAIL\).*\)/\1/p' "$log")
grep -q 'TEST DONE' "$log" || { echo "  ✕ the test did not finish (exit $code): $(tail -3 "$log" | tr '\n' ' ' | cut -c1-400)"; fail=1; }
# what the launcher's Enter left in the (stand-in) clipboard, and how it was put there (the wipe is
# off here — a slow run would find the clipboard empty; tests/vault/test_vault.py times it)
[[ "$(cat "$T/fake/clipboard" 2>/dev/null)" == "wifi pass with spaces" ]] || { echo "  ✕ the password did not reach the clipboard: '$(cat "$T/fake/clipboard" 2>/dev/null)'"; fail=1; }
grep -q -- '--sensitive' "$T/fake/clipboard.args" 2>/dev/null || { echo "  ✕ the password was copied without the sensitive mark"; fail=1; }
# no secret and no master password in the shell's log or among anybody's arguments
if grep -q -e 'correct horse' -e 'gh-secret' -e 'wifi pass' -e 'session-[0-9]' -e '4821' "$log" "$T/fake/calls.log"; then echo "  ✕ a secret got into the log or onto a command line"; fail=1; fi
[[ ! -e "$T/fake/pinentry-opened" ]] || { echo "  ✕ a locked rbw was asked: $(cat "$T/fake/pinentry-opened")"; fail=1; }
[[ "$(cat "$H/.config/angelos/spell-words.txt" 2>/dev/null)" == "" ]] || { echo "  ✕ a forgotten word is still in spell-words.txt"; fail=1; }
errs=$(grep -E 'Vault|Spell|VaultDriver|Launcher\.qml|PxTextArea|PxField' "$log" | grep -E 'TypeError|ReferenceError|Unable to assign|is not defined|Cannot read property|Binding loop|is not a type|Cannot assign|non-existent|not a function|Could not' | sed 's/\x1b\[[0-9;]*m//g' | sort -u | head -12)
[[ -z "$errs" ]] || { echo "  ✕ QML errors:"; printf '%s\n' "$errs" | sed 's/^/      /'; fail=1; }
((fail)) || echo "  ✓ passwords and spelling in the shell: $n checks (stand-in managers and clipboard, two made-up dictionaries)"
exit $fail
