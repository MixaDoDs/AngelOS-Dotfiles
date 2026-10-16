#!/usr/bin/env bash
# Browser downloads (services/Downloads) and the Halo's order, offscreen: a real Helium
# (helium-browser --headless, its own profile) downloads from a slow local server into a stand-in
# ~/Downloads — the capsule while it runs, then on the shelf; a small one done at once; a
# cancelled one says nothing; Firefox's way (an empty file beside its .part); files there before
# say nothing. Without helium-browser the browser steps are made by hand, the same files.
#
#   tests/downloads/run.sh [angelOS dir]      exit 0 = all good, 77 = no quickshell
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

T="$(mktemp -d /tmp/aos-downloads.XXXXXX)"
srv=""
bye() {
  [[ -n "$srv" ]] && kill "$srv" 2>/dev/null
  # the browsers write their profiles while they go: wait for them
  pkill -f -- "--user-data-dir=$T/helium" 2>/dev/null
  for _ in $(seq 30); do pgrep -f -- "--user-data-dir=$T/helium" >/dev/null || break; sleep 0.1; done
  rm -rf "$T"
}
trap bye EXIT
H="$T/home"
mkdir -p "$H/.config/angelos" "$H/.local/state/angelos" "$H/Downloads" "$T/rt" "$T/root" "$T/bin" "$T/helium/Default" && chmod 700 "$T/rt"
echo before >"$H/Downloads/old.txt"
for f in "$DIR"/*; do [[ "${f##*/}" == shell.qml ]] || ln -s "$f" "$T/root/"; done
cat >"$T/root/shell.qml" <<'QML'
//@ pragma UseQApplication
import Quickshell
import qs.tests.downloads
ShellRoot {
    DownloadsDriver {}
}
QML
cat >"$H/.config/angelos/settings.json" <<'JSON'
{"setup": {"complete": true}, "stream": {"auto": false}, "y2k": {"sounds": false, "helper": false, "boot": false},
 "updates": {"autoCheck": false}, "appearance": {"language": "ru"}}
JSON
for t in gdbus pw-play qs notify-send; do printf '#!/bin/sh\nexit 0\n' >"$T/bin/$t"; done
chmod +x "$T/bin/"*

# the browser: Helium with a profile of its own that saves into the stand-in folder unasked
HELIUM="$(command -v helium-browser || true)"
PORT=""
if [[ -n "$HELIUM" ]]; then
  cat >"$T/helium/Default/Preferences" <<JSON
{"download": {"default_directory": "$H/Downloads", "prompt_for_download": false, "directory_upgrade": true}}
JSON
  # the percent: angelOS's extension and its native host, as browser-downloads.py puts them
  mkdir -p "$T/helium/NativeMessagingHosts"
  cat >"$T/helium/NativeMessagingHosts/org.angelos.downloads.json" <<JSON
{"name": "org.angelos.downloads", "description": "angelOS downloads", "path": "$DIR/scripts/browser-downloads-host.py", "type": "stdio",
 "allowed_origins": ["chrome-extension://mblodkbgkjnmhkbecpmfgjannflbgncc/"]}
JSON
  PORT=$((40000 + RANDOM % 20000))
  python3 -I "$DIR/tests/downloads/serve.py" "$PORT" &
  srv=$!
  # what the driver runs: a URL in the headless browser (it lives on until the test ends)
  cat >"$T/bin/get" <<SH2
#!/bin/sh
# a profile each: a second headless Helium on a profile in use aborts (ProcessSingleton)
mkdir -p "$T/helium-\$1" && cp -r "$T/helium/Default" "$T/helium/NativeMessagingHosts" "$T/helium-\$1/"
exec "$HELIUM" --headless=new --user-data-dir="$T/helium-\$1" --no-first-run --disable-gpu --no-sandbox --load-extension="$DIR/data/browser-downloads" "http://127.0.0.1:$PORT/\$1" >>"$T/helium.log" 2>&1
SH2
  chmod +x "$T/bin/get"
fi

log="$T/log"
env -i PATH="$T/bin:$PATH" LANG=C.UTF-8 HOME="$H" USER="${USER:-angel}" \
  XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.local/state" \
  XDG_CACHE_HOME="$H/.cache" XDG_DATA_HOME="$H/.local/share" XDG_RUNTIME_DIR="$T/rt" \
  QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= LD_LIBRARY_PATH="$LIB" QML_IMPORT_PATH="$QML" \
  ANGELOS_DEV=1 ANGELOS_TEST=1 QS_NO_RELOAD_POPUP=1 QS_DISABLE_CRASH_HANDLER=1 \
  NIRI_SOCKET="$T/no-niri" BROWSER_GET="${HELIUM:+get}" \
  timeout 90 "$QS" -p "$T/root" >"$log" 2>&1
code=$?

# the installer (scripts/browser-downloads.py) in a home of its own: into the one flags line beside
# another extension, the host's manifest; out again leaves the line as it was
I="$T/inst"; mkdir -p "$I/.config" "$I/bin"
printf '#!/bin/sh\n' >"$I/bin/helium-browser"; chmod +x "$I/bin/helium-browser"
printf -- '--foo\n--load-extension=/x/theme\n' >"$I/.config/helium-browser-flags.conf"
ienv=(env -i PATH="$I/bin:/usr/bin" HOME="$I" XDG_CONFIG_HOME="$I/.config" XDG_DATA_HOME="$I/share")
"${ienv[@]}" python3 "$DIR/scripts/browser-downloads.py" ensure >/dev/null
line=$(grep -- '--load-extension=' "$I/.config/helium-browser-flags.conf")
if [[ "$line" == "--load-extension=/x/theme,$I/share/angelos/browser-downloads" && -f "$I/.config/net.imput.helium/NativeMessagingHosts/org.angelos.downloads.json" && -f "$I/share/angelos/browser-downloads/bg.js" ]]
then echo "TEST install PASS" >>"$log"; else echo "TEST install FAIL $line" >>"$log"; fi
"${ienv[@]}" python3 "$DIR/scripts/browser-downloads.py" remove
if [[ "$(cat "$I/.config/helium-browser-flags.conf")" == $'--foo\n--load-extension=/x/theme' && ! -e "$I/.config/net.imput.helium/NativeMessagingHosts/org.angelos.downloads.json" ]]
then echo "TEST uninstall PASS" >>"$log"; else echo "TEST uninstall FAIL $(tr '\n' ' ' <"$I/.config/helium-browser-flags.conf")" >>"$log"; fi

fail=0 n=0
while read -r _ name res detail; do
  n=$((n + 1))
  if [[ "$res" == PASS ]]; then [[ -n "${ANGELOS_TEST_VERBOSE:-}" ]] && printf '  ✓ %s %s\n' "$name" "$detail"; else printf '  ✕ %s %s\n' "$name" "$detail"; fail=1; fi
done < <(sed -n 's/.*\(TEST [^ ]* \(PASS\|FAIL\).*\)/\1/p' "$log")
grep -q 'TEST DONE' "$log" || { echo "  ✕ the test did not finish (exit $code): $(tail -5 "$log" | tr '\n' ' ' | cut -c1-600)"; fail=1; }
errs=$(grep -E 'Downloads|Halo|Shelf' "$log" | grep -E 'TypeError|ReferenceError|Unable to assign|is not defined|Cannot read property|Binding loop|is not a type|Cannot assign|non-existent|not a function|Could not' | sed 's/\x1b\[[0-9;]*m//g' | sort -u | head -12)
[[ -z "$errs" ]] || { echo "  ✕ QML errors:"; printf '%s\n' "$errs" | sed 's/^/      /'; fail=1; }
((fail)) || echo "  ✓ downloads: $n checks (${HELIUM:+real Helium with the extension: the percent, }slow, small, growing, cancelled, Firefox's way; the Halo's order; the installer)"
exit $fail
