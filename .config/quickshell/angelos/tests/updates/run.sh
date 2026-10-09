#!/usr/bin/env bash
# Settings → Updates UI test, offscreen (scripts/test-update.sh runs it, so does CI):
# services/Updates.qml and the Updates page against a stand-in dotfiles-update.sh
# that answers from a plan — a stop before the snapshot, a failed install, an
# "UPDATED" followed by a failure, a failed and a good restore, a good update.
#
#   tests/updates/run.sh [angelOS dir]     exit 0 = all good, 77 = no quickshell
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
T="$(mktemp -d /tmp/aos-upd.XXXXXX)"
trap 'rm -rf "$T"' EXIT
H="$T/home"
mkdir -p "$H/.config/angelos" "$H/repo" "$H/stub" "$T/rt" "$T/root/scripts" && chmod 700 "$T/rt"

# the real shell minus its screen windows (as scripts/test-ui.sh), with this driver,
# and the update script swapped for the stand-in
for f in "$DIR"/*; do
  case "${f##*/}" in shell.qml|scripts) ;; *) ln -s "$f" "$T/root/" ;; esac
done
for f in "$DIR"/scripts/*; do
  [[ "${f##*/}" == dotfiles-update.sh ]] || ln -s "$f" "$T/root/scripts/"
done
python3 - "$DIR/shell.qml" >"$T/root/shell.qml" <<'PY'
import re, sys
lines = [l for l in open(sys.argv[1]).read().splitlines() if not re.match(r"^    [A-Z][A-Za-z0-9]* \{\}\s*$", l)]
text = "\n".join(lines).rstrip()
text = text.replace("import qs.widgets", "import qs.widgets\nimport qs.tests.updates", 1)
print(text[:text.rfind("}")] + "    UpdatesDriver {}\n}")
PY

cat >"$T/root/scripts/dotfiles-update.sh" <<'SH'
#!/usr/bin/env bash
# stand-in for dotfiles-update.sh: its protocol, answers taken from $HOME/stub/plan
S="$HOME/stub"
case "${1:-}" in
  --find) echo "$HOME/repo"; exit 0 ;;
  --check) printf 'BRANCH main\nUPSTREAM origin/main\nBEHIND 0\nAHEAD 0\nDIRTY 0\nREMOTE https://example.invalid/dotfiles\nTRUSTED 1\n'; exit 0 ;;
  --last) cat "$S/last" 2>/dev/null; exit 0 ;;
esac
step="$(head -n 1 "$S/plan")"
sed -i 1d "$S/plan"
echo "$step $*" >>"$S/calls"
B="$HOME/.local/state/angelos/backups/20260101-120000-update"
F="$HOME/.local/state/angelos/backups/20991231-235959-update"     # taken "after" the shell started
case "$step" in
  dirty)
    echo "» в репозитории есть свои изменения — обнови вручную"
    exit 3 ;;
  install-fails)
    echo "» запускаю установщик"
    echo "BACKUP $B"
    echo "FAILED install установщик завершился с ошибкой (код 1)"
    printf 'LAST failed install %s aaa bbb\nMESSAGE установщик завершился с ошибкой (код 1)\n' "$B" >"$S/last"
    exit 10 ;;
  claims-then-fails)
    echo "UPDATED aaa bbb 3"
    echo "BACKUP $F"
    echo "FAILED niri-validate конфиг niri не проходит niri validate"
    printf 'LAST failed niri-validate %s aaa bbb\nMESSAGE конфиг niri не проходит niri validate\n' "$F" >"$S/last"
    exit 12 ;;
  restore-fails)
    [[ "${1:-}" == --restore && "${2:-}" == "$F" ]] || { echo "RESTORE-FAILED test wrong arguments: $*"; exit 9; }
    echo "RESTORE-FAILED niri конфиг niri после отката не проходит проверку"
    printf 'LAST restore-failed niri-validate %s aaa bbb\nMESSAGE конфиг niri после отката не проходит проверку\n' "$F" >"$S/last"
    exit 6 ;;
  restore-ok)
    echo "CONFLICT $HOME/.config/niri/cfg/layout.kdl"
    echo "REPO aaa"
    echo "RESTORED 4 1 1"
    printf 'LAST restored niri-validate %s aaa bbb\nCONFLICT %s/.config/niri/cfg/layout.kdl\n' "$F" "$HOME" >"$S/last"
    exit 0 ;;
  update-ok)
    echo "BACKUP $HOME/.local/state/angelos/backups/20260101-130000-update"
    echo "» готово ♡"
    echo "UPDATED aaa ccc 2"
    printf 'LAST ok done %s aaa ccc\n' "$HOME/.local/state/angelos/backups/20260101-130000-update" >"$S/last"
    exit 0 ;;
  local-commits)
    echo "» git fetch (main)"
    echo "» в репозитории 2 своих коммит(а/ов), которых нет в origin/main, а нового там нет — обновлять нечего"
    echo "FAILED local-commits в репозитории 2 своих коммит(а/ов), которых нет в origin/main, а нового там нет — обновлять нечего. Ничего не менялось."
    exit 7 ;;
  install-dies)
    G="$HOME/.local/state/angelos/backups/20991231-235958-update"
    echo "BACKUP $G"
    printf '\033[1;31m[dotfiles] ERROR:\033[0m disk on fire\n'
    echo "FAILED install установщик остановился (код 1): disk on fire"
    printf 'LAST failed install %s ccc ccc\nMESSAGE установщик остановился (код 1): disk on fire\n' "$G" >"$S/last"
    exit 10 ;;
  update-same)
    echo "BACKUP $HOME/.local/state/angelos/backups/20991231-235959-update"
    echo "UPDATED ccc ccc 0"
    printf 'LAST ok done %s ccc ccc\n' "$HOME/.local/state/angelos/backups/20991231-235959-update" >"$S/last"
    exit 0 ;;
  system-fails)
    echo "» сначала обновляю систему (pacman -Syu) — попросит пароль администратора"
    echo "error: failed to commit transaction (conflicting files)"
    echo "FAILED system обновление системы (pacman -Syu) остановилось: failed to commit transaction (conflicting files). angelOS не обновлялся"
    exit 8 ;;
  update-qt)
    echo "SYSTEM 5 1"
    echo "BACKUP $HOME/.local/state/angelos/backups/20260101-140000-update"
    echo "UPDATED ccc ccc 0"
    printf 'LAST ok done %s ccc ccc\n' "$HOME/.local/state/angelos/backups/20260101-140000-update" >"$S/last"
    exit 0 ;;
esac
echo "unexpected run: $*"
exit 99
SH
chmod +x "$T/root/scripts/dotfiles-update.sh"
printf '%s\n' dirty install-fails claims-then-fails restore-fails restore-ok update-ok local-commits install-dies update-same system-fails update-qt >"$H/stub/plan"
# quiet, offline settings (as test-ui.sh)
cat >"$H/.config/angelos/settings.json" <<'JSON'
{"setup": {"complete": true}, "stream": {"auto": false}, "y2k": {"sounds": false, "helper": false, "boot": false},
 "bar": {"metaTap": false}, "updates": {"autoCheck": false}, "system": {"nautilusDefaults": true}}
JSON

log="${ANGELOS_TEST_LOG:-$T/qs.log}"
runner=()
command -v dbus-run-session >/dev/null && runner=(dbus-run-session --)
env -i PATH="$PATH" LANG=C.UTF-8 HOME="$H" USER="${USER:-angel}" \
  XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.local/state" \
  XDG_CACHE_HOME="$H/.cache" XDG_DATA_HOME="$H/.local/share" XDG_RUNTIME_DIR="$T/rt" \
  QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= LD_LIBRARY_PATH="$LIB" QML_IMPORT_PATH="$QML" \
  ANGELOS_DEV=1 ANGELOS_SCREENS=__none__ ANGELOS_TEST=1 QS_NO_RELOAD_POPUP=1 QS_DISABLE_CRASH_HANDLER=1 \
  "${runner[@]}" timeout 120 "$QS" -p "$T/root" >"$log" 2>&1
code=$?

fail=0
while read -r _ name res detail; do
  if [[ "$res" == PASS ]]; then printf '  ✓ %s\n' "$name"; else printf '  ✕ %s %s\n' "$name" "$detail"; fail=1; fi
done < <(sed -n 's/.*\(TEST [^ ]* \(PASS\|FAIL\).*\)/\1/p' "$log")
grep -q 'TEST DONE' "$log" || { echo "  ✕ the test did not finish (exit $code): $(tail -3 "$log" | tr '\n' ' ' | cut -c1-300)"; fail=1; }
errs=$(grep -E 'UpdatesPage|Updates\.qml|UpdatesDriver|UpdatePrompt' "$log" | grep -E 'TypeError|ReferenceError|Unable to assign|is not defined|Cannot read property|Binding loop' | sed 's/\x1b\[[0-9;]*m//g' | sort -u | head -10)
[[ -z "$errs" ]] || { echo "  ✕ QML errors:"; printf '%s\n' "$errs" | sed 's/^/      /'; fail=1; }
left="$(cat "$H/stub/plan")"
[[ -z "$left" ]] || { echo "  ✕ planned runs never happened: $left"; fail=1; }
((fail == 0)) && echo "  updates UI: all good"
exit "$fail"
