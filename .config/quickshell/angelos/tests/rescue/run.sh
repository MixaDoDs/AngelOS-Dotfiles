#!/usr/bin/env bash
# What keeps a user from an empty desk or from losing everything — offscreen, on a throw-away
# HOME, no screen (scripts/test-ui.sh runs it, so does CI):
#   settings   settings.json / save.json cut short (they are written in place): the last good
#              copy comes back, the broken file is put aside, nothing is overwritten with the
#              defaults; with no copy at all the shell still starts, and says so
#   language   a first start nobody answered the language for takes the system's
#   failed     five failed starts of the service in a minute open `angelos rescue` in a
#              terminal (once, and never after a clean stop); the rescue names the reason
#
#   tests/rescue/run.sh [angelOS dir]     exit 0 = all good
set -uo pipefail
DIR="$(cd "${1:-"$(dirname "$0")/../.."}" && pwd)"
[[ -f "$DIR/shell.qml" && -f "$DIR/bin/angelos" ]] || { echo "no angelOS in $DIR"; exit 2; }
fail=0
ok()  { printf '  ✓ %s\n' "$*"; }
bad() { printf '  ✕ %s\n' "$*"; fail=1; }

QS="$(command -v quickshell || true)"
LIB="${LD_LIBRARY_PATH:-}" QML="${QML_IMPORT_PATH:-}"
if [[ ! -x /usr/bin/quickshell && -x "$HOME/.local/opt/quickshell/usr/bin/quickshell" ]]; then
  QS="$HOME/.local/opt/quickshell/usr/bin/quickshell"
  LIB="$HOME/.local/opt/quickshell/usr/lib${LIB:+:$LIB}"
  QML="$HOME/.local/opt/quickshell/usr/lib/qt6/qml${QML:+:$QML}"
fi
[[ -x "$QS" ]] || { echo "quickshell not found"; exit 2; }

T="$(mktemp -d /tmp/aos-rescue.XXXXXX)"
trap 'rm -rf "$T"' EXIT
# the real shell.qml minus its screen windows, as scripts/test-ui.sh builds it
mkdir -p "$T/root"
for f in "$DIR"/*; do [[ "${f##*/}" == shell.qml ]] || ln -s "$f" "$T/root/"; done
python3 - "$DIR/shell.qml" >"$T/root/shell.qml" <<'PY'
import re, sys
print("\n".join(l for l in open(sys.argv[1]).read().splitlines() if not re.match(r"^    [A-Z][A-Za-z0-9]* \{\}\s*$", l)))
PY
runner=()
command -v dbus-run-session >/dev/null && runner=(dbus-run-session --)
A=""   # ~/.config/angelos of the home in use
home() { A="$T/$1/home/.config/angelos"; mkdir -p "$A" "$T/$1/rt"; chmod 700 "$T/$1/rt"; }
# shell NAME LANG — until WAIT_FOR (a shell test on $A) holds, 40 s at most
shell() {
  local h="$T/$1" i
  env -i PATH="$PATH" LANG="$2" HOME="$h/home" USER="${USER:-angel}" \
    XDG_CONFIG_HOME="$h/home/.config" XDG_STATE_HOME="$h/home/.local/state" \
    XDG_CACHE_HOME="$h/home/.cache" XDG_DATA_HOME="$h/home/.local/share" XDG_RUNTIME_DIR="$h/rt" \
    QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= LD_LIBRARY_PATH="$LIB" QML_IMPORT_PATH="$QML" \
    ANGELOS_DEV=1 ANGELOS_SCREENS=__none__ ANGELOS_TEST=1 QS_NO_RELOAD_POPUP=1 QS_DISABLE_CRASH_HANDLER=1 \
    "${runner[@]}" timeout 40 "$QS" -p "$T/root" >"$h/log" 2>&1 &
  local pid=$!
  for ((i = 0; i < 200; i++)); do
    eval "$WAIT_FOR" 2>/dev/null && break
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.2
  done
  sleep 0.6     # a write that would follow (the defaults over the file) has its time
  # the runner's own child, by pid — never by name
  pkill -TERM -P "$pid" 2>/dev/null; kill -TERM "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
}
accent() { sed -n 's/.*"customAccent": *"\([^"]*\)".*/\1/p' "$1" 2>/dev/null | head -n 1; }
language() { sed -n 's/.*"language": *"\([^"]*\)".*/\1/p' "$1" 2>/dev/null | head -n 1; }
GOOD='{"setup": {"complete": true}, "appearance": {"language": "ru", "customAccent": "#123456"}, "stream": {"auto": false}, "updates": {"autoCheck": false}, "y2k": {"sounds": false, "boot": false, "helper": false}, "bar": {"metaTap": false}, "system": {"nautilusDefaults": true}}'

# ---- settings.json ----
home s
printf '%s' "$GOOD" >"$A/settings.json"
WAIT_FOR='[[ -s "$A/settings.json.last-good" && -s "$A/save.json.last-good" ]]' shell s C.UTF-8
[[ "$(accent "$A/settings.json.last-good")" == "#123456" ]] && ok "a good start keeps a copy of settings.json" || bad "no last good copy of settings.json after a start: $(ls "$A" | tr '\n' ' ')"
[[ -s "$A/save.json.last-good" ]] && ok "… and of save.json" || bad "no last good copy of save.json"

head -c 300 "$A/settings.json" >"$A/cut" && mv "$A/cut" "$A/settings.json"
WAIT_FOR='ls "$A"/settings.json.broken-* >/dev/null && [[ "$(accent "$A/settings.json")" == "#123456" ]]' shell s C.UTF-8
if [[ "$(accent "$A/settings.json")" == "#123456" ]] && grep -q '"complete": true' "$A/settings.json" && ls "$A"/settings.json.broken-* >/dev/null 2>&1; then
  ok "settings.json cut short: the last good copy is back, the broken file is aside"
else
  bad "settings.json cut short was not put right: accent '$(accent "$A/settings.json")', files $(ls "$A" | tr '\n' ' ')"
fi

: >"$A/settings.json"
rm -f "$A"/settings.json.broken-*
WAIT_FOR='ls "$A"/settings.json.broken-* >/dev/null && [[ "$(accent "$A/settings.json")" == "#123456" ]]' shell s C.UTF-8
[[ "$(accent "$A/settings.json")" == "#123456" ]] && ok "an empty settings.json: the last good copy is back" || bad "an empty settings.json was not put right"

python3 - "$A/save.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); d["hell"]["falls"] = 7; json.dump(d, open(sys.argv[1], "w"))
PY
rm -f "$A/save.json.last-good"
WAIT_FOR='grep -q "\"falls\": 7" "$A/save.json.last-good"' shell s C.UTF-8
head -c 200 "$A/save.json" >"$A/cut" && mv "$A/cut" "$A/save.json"
WAIT_FOR='ls "$A"/save.json.broken-* >/dev/null && grep -q "\"falls\": 7" "$A/save.json"' shell s C.UTF-8
grep -q '"falls": 7' "$A/save.json" && ok "save.json cut short: the game's save is back" || bad "save.json cut short was not put right: $(head -c 120 "$A/save.json")"

# no copy to bring back: the shell starts from the defaults and keeps the broken file
home n
printf '{"setup": {"complete": true}, "appearance": {"customAcc' >"$A/settings.json"
WAIT_FOR='ls "$A"/settings.json.broken-* >/dev/null && grep -q "\"alttab\"" "$A/settings.json"' shell n C.UTF-8
if ls "$A"/settings.json.broken-* >/dev/null 2>&1 && python3 -c 'import json, sys; json.load(open(sys.argv[1]))' "$A/settings.json" 2>/dev/null; then
  ok "no copy to bring back: the broken file is kept, the shell starts from the defaults"
else
  bad "a broken settings.json without a copy: $(ls "$A" | tr '\n' ' ')"
fi

# ---- the first start's language ----
for pair in "en_US.UTF-8 en" "ru_RU.UTF-8 ru" "C.UTF-8 en"; do
  read -r loc want <<<"$pair"
  home "l-$want-${loc%%.*}"
  WAIT_FOR='[[ -n "$(language "$A/settings.json")" ]]' shell "l-$want-${loc%%.*}" "$loc"
  got="$(language "$A/settings.json")"
  [[ "$got" == "$want" ]] && ok "first start, locale $loc: the interface is «$got»" || bad "first start, locale $loc: language «$got», expected «$want»"
done
# the wizard is done and the key is not there (an old settings.json): nothing changes
home l-old
printf '{"setup": {"complete": true}, "stream": {"auto": false}, "updates": {"autoCheck": false}}' >"$A/settings.json"
WAIT_FOR='[[ -s "$A/settings.json.last-good" && -n "$(language "$A/settings.json")" ]]' shell l-old en_US.UTF-8
[[ "$(language "$A/settings.json")" == "ru" ]] && ok "a finished wizard without the key keeps the language it had" || bad "a finished wizard's language changed to «$(language "$A/settings.json")»"

# ---- five failed starts: the rescue window ----
R="$T/r"; mkdir -p "$R/home/.config/angelos" "$R/home/.config/quickshell" "$R/rt" "$R/bin"
ln -s "$DIR" "$R/home/.config/quickshell/angelos"
printf '{"appearance": {"language": "en"}, "system": {"terminal": "faketerm"}}' >"$R/home/.config/angelos/settings.json"
printf '#!/bin/sh\necho "$*" >>"%s/spawned"\n' "$R" >"$R/bin/faketerm"
# a stand-in niri: `msg action spawn -- CMD…` runs CMD
printf '#!/bin/sh\n[ "$1 $2 $3" = "msg action spawn" ] && { shift 4; exec "$@"; }\nexit 1\n' >"$R/bin/niri"
chmod +x "$R/bin/faketerm" "$R/bin/niri"
reap() { env -i PATH="$R/bin:/usr/bin:/bin" HOME="$R/home" XDG_CONFIG_HOME="$R/home/.config" XDG_RUNTIME_DIR="$R/rt" \
  ANGELOS_UNIT=angelos-rescue-test.service "$@" sh "$DIR/bin/angelos" reap >/dev/null 2>&1; }
windows() { if [[ -f "$R/spawned" ]]; then wc -l <"$R/spawned"; else echo 0; fi; }
for _ in 1 2 3 4; do reap SERVICE_RESULT=exit-code; done
reap SERVICE_RESULT=success
[[ "$(windows)" == 0 ]] && ok "four failed starts and a clean stop: no rescue window" || bad "the rescue window opened early ($(windows))"
reap SERVICE_RESULT=exit-code
[[ "$(windows)" == 1 ]] && grep -q 'angelos rescue$' "$R/spawned" && ok "the fifth failed start in a minute opens «angelos rescue» in the user's terminal" || bad "no rescue window after five failed starts: $(cat "$R/spawned" 2>/dev/null)"
# while a rescue is open, another loop of failures does not open a second
sleep 300 & holder=$!
echo "$holder" >"$R/rt/angelos/rescue.pid"
for _ in 1 2 3 4 5; do reap SERVICE_RESULT=exit-code; done
[[ "$(windows)" == 1 ]] && ok "one rescue window at a time" || bad "a second rescue window opened ($(windows))"
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
rm -f "$R/rt/angelos/rescue.pid"
echo off >"$R/home/.config/angelos/rescue"
for _ in 1 2 3 4 5; do reap SERVICE_RESULT=signal; done
[[ "$(windows)" == 1 ]] && ok "switched off (~/.config/angelos/rescue): no window" || bad "the rescue window opened though switched off"

# the rescue names the reason of the last start only
cat >"$R/log" <<'LOG'
  INFO: Launching config: "shell.qml"
 ERROR:   caused by @widgets/Old.qml[1:1]: an older start's error
  INFO: Launching config: "shell.qml"
 ERROR: Failed to load configuration
 ERROR:   caused by @widgets/PxProgress.qml[27:5]: Invalid property assignment: "shown" is a read-only property
LOG
why="$(env -i PATH="/usr/bin:/bin" HOME="$R/home" XDG_CONFIG_HOME="$R/home/.config" XDG_RUNTIME_DIR="$R/rt" ANGELOS_RESCUE_LOG="$R/log" bash "$DIR/scripts/rescue.sh" --why)"
[[ "$why" == *"PxProgress.qml[27:5]"* && "$why" != *"Old.qml"* ]] && ok "the rescue names the last start's error" || bad "the rescue's reason: $why"
screen="$(echo q | env -i PATH="/usr/bin:/bin" TERM=dumb HOME="$R/home" XDG_CONFIG_HOME="$R/home/.config" XDG_RUNTIME_DIR="$R/rt" \
  ANGELOS_UNIT=angelos-rescue-test.service ANGELOS_RESCUE_LOG="$R/log" bash "$DIR/scripts/rescue.sh" 2>&1)"
[[ "$screen" == *"angelOS did not start"* && "$screen" == *"1) Try to start it again"* && "$screen" == *"PxProgress.qml"* ]] && ok "the rescue screen: what happened, the reason, what can be done (in the shell's language)" || bad "the rescue screen: $(printf '%s' "$screen" | head -5)"

if ((fail)); then echo "» RESCUE TEST FAILED"; exit 1; fi
echo "» rescue test passed ♡"
