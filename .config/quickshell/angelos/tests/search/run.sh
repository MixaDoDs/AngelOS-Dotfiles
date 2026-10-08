#!/usr/bin/env bash
# The settings search against tests/search/table.json, offscreen (scripts/test-ui.sh runs it,
# so does scripts/check.sh): every query finds what it must among its first results, the author's
# debug panel only for the author, and no query is slow.
#
#   tests/search/run.sh [angelOS dir]          exit 0 = all good, 77 = no quickshell
#   ANGELOS_SEARCH_DUMP=file tests/search/run.sh   print the first results of each line of file
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
T="$(mktemp -d /tmp/aos-search.XXXXXX)"
trap 'rm -rf "$T"' EXIT
H="$T/home"
mkdir -p "$H/.config/angelos" "$T/rt" "$T/root" && chmod 700 "$T/rt"

# the real shell minus its screen windows (as scripts/test-ui.sh), with this driver
for f in "$DIR"/*; do [[ "${f##*/}" == shell.qml ]] || ln -s "$f" "$T/root/"; done
python3 - "$DIR/shell.qml" >"$T/root/shell.qml" <<'PY'
import re, sys
lines = [l for l in open(sys.argv[1]).read().splitlines() if not re.match(r"^    [A-Z][A-Za-z0-9]* \{\}\s*$", l)]
text = "\n".join(lines).rstrip()
text = text.replace("import qs.widgets", "import qs.widgets\nimport qs.tests.search", 1)
print(text[:text.rfind("}")] + "    SearchDriver {}\n}")
PY
cat >"$H/.config/angelos/settings.json" <<'JSON'
{"setup": {"complete": true}, "stream": {"auto": false}, "y2k": {"sounds": false, "helper": false, "boot": false},
 "bar": {"metaTap": false}, "updates": {"autoCheck": false}, "system": {"nautilusDefaults": true}, "appearance": {"language": "ru"}}
JSON

dump="${ANGELOS_SEARCH_DUMP:-}"
[[ -z "$dump" ]] || dump="$(cd "$(dirname "$dump")" && pwd)/$(basename "$dump")"
log="${ANGELOS_TEST_LOG:-$T/qs.log}"
runner=()
command -v dbus-run-session >/dev/null && runner=(dbus-run-session --)
env -i PATH="$PATH" LANG=C.UTF-8 HOME="$H" USER="${USER:-angel}" \
  XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.local/state" \
  XDG_CACHE_HOME="$H/.cache" XDG_DATA_HOME="$H/.local/share" XDG_RUNTIME_DIR="$T/rt" \
  QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= LD_LIBRARY_PATH="$LIB" QML_IMPORT_PATH="$QML" \
  ANGELOS_DEV=1 ANGELOS_SCREENS=__none__ ANGELOS_TEST=1 QS_NO_RELOAD_POPUP=1 QS_DISABLE_CRASH_HANDLER=1 \
  ANGELOS_SEARCH_TABLE="$DIR/tests/search/table.json" ANGELOS_SEARCH_DUMP="$dump" \
  "${runner[@]}" timeout 120 "$QS" -p "$T/root" >"$log" 2>&1
code=$?

if [[ -n "$dump" ]]; then sed -n 's/.*DUMP //p' "$log"; exit 0; fi
fail=0 n=0
while read -r _ name res detail; do
  n=$((n + 1))
  if [[ "$res" == PASS ]]; then [[ -n "${ANGELOS_SEARCH_VERBOSE:-}" ]] && printf '  ✓ %s\n' "${name#q:}"; else printf '  ✕ %s %s\n' "${name#q:}" "$detail"; fail=1; fi
done < <(sed -n 's/.*\(TEST [^ ]* \(PASS\|FAIL\).*\)/\1/p' "$log")
grep -q 'TEST DONE' "$log" || { echo "  ✕ the test did not finish (exit $code): $(tail -3 "$log" | tr '\n' ' ' | cut -c1-300)"; fail=1; }
errs=$(grep -E 'SettingsSearch|SearchDriver' "$log" | grep -E 'TypeError|ReferenceError|Unable to assign|is not defined|Cannot read property|Binding loop' | sed 's/\x1b\[[0-9;]*m//g' | sort -u | head -10)
[[ -z "$errs" ]] || { echo "  ✕ QML errors:"; printf '%s\n' "$errs" | sed 's/^/      /'; fail=1; }
((fail)) || echo "  ✓ settings search: $((n - 1)) queries find what they must ($(sed -n 's/.*TEST search-time PASS [0-9]* queries, //p' "$log"))"
exit $fail
