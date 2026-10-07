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
platform=(QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-$T/rt}")
[[ "${ANGELOS_SDDM_TEST_OFFSCREEN:-}" == 1 || -z "${WAYLAND_DISPLAY:-}" ]] && platform=(QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$T/rt")
fail=0
# every look (ANGELOS_SDDM_LOOKS="heaven hell" for some), each built as `angelos sddm install --look` builds it
for look in ${ANGELOS_SDDM_LOOKS:-stream heaven retro hell quiet}; do
  echo " · $look"
  python3 "$DIR/scripts/sddm-theme.py" build --out "$T/theme" --palette "${ANGELOS_SDDM_PALETTE:-ngo}" --look "$look" >/dev/null || { echo "  ✕ build failed"; fail=1; continue; }
  sed "s#@THEME@#$T/theme#" "$DIR/tests/sddm/harness.qml" >"$T/conf/shell.qml"
  log="${ANGELOS_TEST_LOG:-$T/qs.log}"
  env -i PATH="$PATH" LANG=C.UTF-8 HOME="$HOME" "${platform[@]}" QT_QPA_PLATFORMTHEME= \
    LD_LIBRARY_PATH="$LIB" QML_IMPORT_PATH="$QML" ANGELOS_TEST_SHOTS="${ANGELOS_TEST_SHOTS:-}" \
    QS_NO_RELOAD_POPUP=1 QS_DISABLE_CRASH_HANDLER=1 timeout 60 "$QS" -p "$T/conf/shell.qml" >"$log" 2>&1
  while read -r _ name res detail; do
    if [[ "$res" == PASS ]]; then printf '  ✓ %s %s\n' "$name" "$detail"; else printf '  ✕ %s %s\n' "$name" "$detail"; fail=1; fi
  done < <(sed -n 's/.*\(TEST [^ ]* \(PASS\|FAIL\).*\)/\1/p' "$log")
  grep -q 'TEST DONE' "$log" || { echo "  ✕ did not finish: $(tail -3 "$log" | tr '\n' ' ' | cut -c1-300)"; fail=1; }
  errs=$(grep -E 'theme/|harness|shell\.qml' "$log" | grep -E 'TypeError|ReferenceError|Unable to assign|is not defined|Cannot read property|Binding loop|is not a type|Cannot assign|failed to load|Required property' | sed 's/\x1b\[[0-9;]*m//g' | sort -u | head -15)
  [[ -z "$errs" ]] || { echo "  ✕ QML errors:"; printf '%s\n' "$errs" | sed 's/^/      /'; fail=1; }
done
# SDDM starts the Qt 5 greeter unless metadata.desktop says QtVersion=6, and that one
# can't read this QML ("Library import requires a version") and shows its own theme
grep -qx 'QtVersion=6' "$T/theme/metadata.desktop" 2>/dev/null || { echo "  ✕ metadata.desktop without QtVersion=6"; fail=1; }
# the real greeter (it logs to the journal only), when it and the journal are at hand
if command -v sddm-greeter-qt6 >/dev/null && journalctl -n0 -q 2>/dev/null; then
  since=$(date +%s)
  env QT_QPA_PLATFORM=offscreen timeout 5 sddm-greeter-qt6 --test-mode --theme "$T/theme" >/dev/null 2>&1
  sleep 0.5
  glog=$(journalctl -q -o cat -t sddm-greeter-qt6 --since "@$since" 2>/dev/null)
  gerr=$(grep -E 'Main\.qml|theme/.*\.qml:|Fallback to embedded' <<<"$glog" | grep -v '^Loading file' | head -10)
  if ! grep -q 'theme/Main.qml\.\.\.' <<<"$glog"; then echo "  ? sddm-greeter-qt6 left nothing in the journal"
  elif [[ -n "$gerr" ]]; then echo "  ✕ sddm-greeter-qt6:"; printf '%s\n' "$gerr" | sed 's/^/      /'; fail=1
  else echo "  ✓ sddm-greeter-qt6 loads the theme"; fi
fi
((fail == 0)) && echo "  SDDM theme: loads, types, fails, logs in — no errors"
exit "$fail"
