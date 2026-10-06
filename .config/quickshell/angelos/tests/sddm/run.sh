#!/usr/bin/env bash
# The SDDM theme (extras/sddm/angelos) with a stand-in SDDM: built like `angelos sddm
# install` builds it, loaded in a window, typed into, failed and logged in. No QML errors;
# ANGELOS_TEST_SHOTS=dir keeps the pictures. It runs in this Wayland session as an
# "angelOS [dev]" window (niri keeps those off the stream monitor), or offscreen with
# ANGELOS_SDDM_TEST_OFFSCREEN=1 (no pixelated wallpaper there: no shaders offscreen).
#
#   tests/sddm/run.sh [angelOS dir]     exit 0 = all good, 77 = no quickshell
set -uo pipefail
DIR="$(cd "${1:-"$(dirname "$0")/../.."}" && pwd)"
QS="$(command -v quickshell || true)"
LIB="${LD_LIBRARY_PATH:-}" QML="${QML_IMPORT_PATH:-}"
if [[ ! -x /usr/bin/quickshell && -x "$HOME/.local/opt/quickshell/usr/bin/quickshell" ]]; then
  QS="$HOME/.local/opt/quickshell/usr/bin/quickshell"
  LIB="$HOME/.local/opt/quickshell/usr/lib${LIB:+:$LIB}"
  QML="$HOME/.local/opt/quickshell/usr/lib/qt6/qml${QML:+:$QML}"
fi
[[ -x "$QS" ]] || { echo "quickshell not found"; exit 77; }
T="$(mktemp -d /tmp/aos-sddm.XXXXXX)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/conf" "$T/rt" && chmod 700 "$T/rt"
python3 "$DIR/scripts/sddm-theme.py" build --out "$T/theme" --palette "${ANGELOS_SDDM_PALETTE:-ngo}" >/dev/null || { echo "  ✕ build failed"; exit 1; }
sed "s#@THEME@#$T/theme#" "$DIR/tests/sddm/harness.qml" >"$T/conf/shell.qml"
platform=(QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-$T/rt}")
[[ "${ANGELOS_SDDM_TEST_OFFSCREEN:-}" == 1 || -z "${WAYLAND_DISPLAY:-}" ]] && platform=(QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$T/rt")
log="${ANGELOS_TEST_LOG:-$T/qs.log}"
env -i PATH="$PATH" LANG=C.UTF-8 HOME="$HOME" "${platform[@]}" QT_QPA_PLATFORMTHEME= \
  LD_LIBRARY_PATH="$LIB" QML_IMPORT_PATH="$QML" ANGELOS_TEST_SHOTS="${ANGELOS_TEST_SHOTS:-}" \
  QS_NO_RELOAD_POPUP=1 QS_DISABLE_CRASH_HANDLER=1 timeout 60 "$QS" -p "$T/conf/shell.qml" >"$log" 2>&1
fail=0
while read -r _ name res detail; do
  if [[ "$res" == PASS ]]; then printf '  ✓ %s %s\n' "$name" "$detail"; else printf '  ✕ %s %s\n' "$name" "$detail"; fail=1; fi
done < <(sed -n 's/.*\(TEST [^ ]* \(PASS\|FAIL\).*\)/\1/p' "$log")
grep -q 'TEST DONE' "$log" || { echo "  ✕ did not finish: $(tail -3 "$log" | tr '\n' ' ' | cut -c1-300)"; fail=1; }
errs=$(grep -E 'theme/|harness' "$log" | grep -E 'TypeError|ReferenceError|Unable to assign|is not defined|Cannot read property|Binding loop|is not a type|Cannot assign|failed to load|Required property' | sed 's/\x1b\[[0-9;]*m//g' | sort -u | head -15)
[[ -z "$errs" ]] || { echo "  ✕ QML errors:"; printf '%s\n' "$errs" | sed 's/^/      /'; fail=1; }
((fail == 0)) && echo "  SDDM theme: loads, types, fails, logs in — no errors"
exit "$fail"
