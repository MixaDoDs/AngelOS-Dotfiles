#!/usr/bin/env bash
# The scale matrix, offscreen (scripts/test-ui.sh runs it, so does CI): Settings pages, the
# Start looks, the bar's widgets and a notification card at art pixel 1–4 and font scale ×1,
# ×1.5, ×2 on a 1280×720 screen, against px 2 / ×1. No new overlaps, cut or overflowing text.
#
#   tests/scale/run.sh [angelOS dir]     exit 0 = all good, 77 = no quickshell
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
T="$(mktemp -d /tmp/aos-scale.XXXXXX)"
trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$T"' EXIT
mkdir -p "$T/root"

# the real shell minus its screen windows (as scripts/test-ui.sh), with this driver
for f in "$DIR"/*; do [[ "${f##*/}" == shell.qml ]] || ln -s "$f" "$T/root/"; done
python3 - "$DIR/shell.qml" >"$T/root/shell.qml" <<'PY'
import re, sys
lines = [l for l in open(sys.argv[1]).read().splitlines() if not re.match(r"^    [A-Z][A-Za-z0-9]* \{\}\s*$", l)]
text = "\n".join(lines).rstrip()
text = text.replace("import qs.widgets", "import qs.widgets\nimport qs.tests.scale", 1)
print(text[:text.rfind("}")] + "    ScaleDriver {}\n}")
PY

runner=()
command -v dbus-run-session >/dev/null && runner=(dbus-run-session --)
# the matrix in parts that run at once, each against its own reference run (ScaleDriver's
# ANGELOS_SCALE_ONLY: indexes into its combos), each with its own HOME and runtime dir
PARTS=("1 2" "3 4" "5")
part() { # N "COMBOS"
  local H="$T/$1/home"
  mkdir -p "$H/.config/angelos" "$T/$1/rt" && chmod 700 "$T/$1/rt"
  # quiet, offline settings (as test-ui.sh); the reference look: px 2, fonts ×1
  cat >"$H/.config/angelos/settings.json" <<'JSON'
{"setup": {"complete": true}, "stream": {"auto": false}, "y2k": {"sounds": false, "helper": false, "boot": false},
 "bar": {"metaTap": false}, "updates": {"autoCheck": false}, "system": {"nautilusDefaults": true},
 "appearance": {"px": 2, "fontScale": 1}}
JSON
  env -i PATH="$PATH" LANG=C.UTF-8 HOME="$H" USER="${USER:-angel}" \
    XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.local/state" \
    XDG_CACHE_HOME="$H/.cache" XDG_DATA_HOME="$H/.local/share" XDG_RUNTIME_DIR="$T/$1/rt" \
    QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= LD_LIBRARY_PATH="$LIB" QML_IMPORT_PATH="$QML" \
    ANGELOS_DEV=1 ANGELOS_SCREENS=__none__ ANGELOS_TEST=1 QS_NO_RELOAD_POPUP=1 QS_DISABLE_CRASH_HANDLER=1 \
    ANGELOS_SCALE_ONLY="$2" \
    "${runner[@]}" timeout 120 "$QS" -p "$T/root" >"$T/$1.log" 2>&1
  echo $? >"$T/$1.code"
}
for i in "${!PARTS[@]}"; do part "$i" "${PARTS[i]}" & done
wait

fail=0
for i in "${!PARTS[@]}"; do
  log="$T/$i.log" code="$(cat "$T/$i.code" 2>/dev/null)"
  while read -r _ name res detail; do
    if [[ "$res" == PASS ]]; then printf '  ✓ %s %s\n' "$name" "$detail"; else printf '  ✕ %s %s\n' "$name" "$detail"; fail=1; fi
  done < <(sed -n 's/.*\(TEST [^ ]* \(PASS\|FAIL\).*\)/\1/p' "$log")
  grep -q 'TEST DONE' "$log" || { echo "  ✕ the test did not finish (part $i, exit $code): $(tail -3 "$log" | tr '\n' ' ' | cut -c1-300)"; fail=1; }
  errs=$(grep -E 'ThemeExport|ScaleDriver' "$log" | grep -E 'TypeError|ReferenceError|Unable to assign|is not defined|Cannot read property|Binding loop' | sed 's/\x1b\[[0-9;]*m//g' | sort -u | head -10)
  [[ -z "$errs" ]] || { echo "  ✕ QML errors:"; printf '%s\n' "$errs" | sed 's/^/      /'; fail=1; }
  grep '^.*SCALE ' "$log" | sed 's/.*SCALE /      /' | head -40
done
((fail == 0)) && echo "  scale matrix: nothing runs over, out of its box or past the window"
exit "$fail"
