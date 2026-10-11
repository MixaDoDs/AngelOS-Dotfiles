#!/usr/bin/env bash
# The hang watchdog (`angelos guard`, bin/angelos) against stand-in processes and a stand-in qs —
# no shell, no screen (scripts/test-ui.sh runs it, so does CI). It may ask the shell (a probe is
# a whole quickshell started) only when the main thread looks wrong, and it must still catch a
# shell that stopped answering:
#   healthy    sleeps and wakes like an idle shell: the first look, then once in EVERY
#   busy       burns the tick but still wakes: asked every tick
#   spinning   never sleeps (the 2026-10-01 hang): asked every tick
#   stuck      never wakes: asked every tick
#   stopped    kill -STOP, a debugger: left alone (#46)
#   refused    qs says no three times running: SIGABRT
#   silent     qs never comes back (a hung shell answers nobody): cut off, SIGABRT
#
#   tests/guard/run.sh [angelOS dir]     exit 0 = all good
#   GUARD_SPAN=s                         how long the first five are watched (10)
set -uo pipefail
DIR="$(cd "${1:-"$(dirname "$0")/../.."}" && pwd)"
[[ -f "$DIR/bin/angelos" ]] || { echo "no angelOS in $DIR"; exit 2; }
SPAN="${GUARD_SPAN:-10}"
fail=0
ok()  { printf '  ✓ %s\n' "$*"; }
bad() { printf '  ✕ %s\n' "$*"; fail=1; }

T="$(mktemp -d /tmp/aos-guard.XXXXXX)"
# everything started here, by pid — never by name: a pattern also matches the user's own shell
declare -A target=() guard=()
trap 'kill -KILL "${target[@]}" "${guard[@]}" 2>/dev/null; rm -rf "$T"' EXIT

# the stand-in qs: a line for every probe; GUARD_ANSWER = yes | no | never
mkdir -p "$T/bin"
cat >"$T/bin/qs" <<'QS'
#!/bin/sh
echo "probe $*" >>"$GUARD_LOG"
case "${GUARD_ANSWER:-yes}" in
  yes) exit 0 ;;
  never) exec sleep 600 ;;
  *) exit 1 ;;
esac
QS
chmod +x "$T/bin/qs"

state() { sed 's/^.*) //' "/proc/$1/stat" 2>/dev/null | cut -c1; }
probes() { local n=0; [[ -f "$T/$1.probes" ]] && n="$(wc -l <"$T/$1.probes")"; echo "$n"; }
watch() { # NAME [ANSWER]: the guard over target[NAME], a second a tick, a probe anyway every six
  GUARD_LOG="$T/$1.probes" GUARD_ANSWER="${2:-yes}" PATH="$T/bin:$PATH" \
    ANGELOS_GUARD_FIRST=0 ANGELOS_GUARD_TICK=1 ANGELOS_GUARD_EVERY=6 ANGELOS_GUARD_TIMEOUT=1 \
    sh "$DIR/bin/angelos" guard "${target[$1]}" >/dev/null 2>"$T/$1.err" &
  guard[$1]=$!
}

python3 -c 'import time
while True: time.sleep(0.02)' & target[healthy]=$!
python3 -c 'import time
while True:
    t = time.perf_counter()
    while time.perf_counter() - t < 0.05: pass
    time.sleep(0.001)' & target[busy]=$!
python3 -c 'while True: pass' & target[spinning]=$!
sleep 600 & target[stuck]=$!
python3 -c 'import time
while True: time.sleep(0.02)' & target[stopped]=$!
# (these two take the SIGABRT themselves and leave with 86: no core dump of a test in the journal)
for n in refused silent; do
  python3 -c 'import os, signal, time
signal.signal(signal.SIGABRT, lambda *a: os._exit(86))
time.sleep(600)' & target[$n]=$!
done
sleep 0.7   # the interpreters are up: what follows is their loop, not their start
kill -STOP "${target[stopped]}"
for _ in $(seq 50); do [[ "$(state "${target[stopped]}")" == T ]] && break; sleep 0.1; done

# CPU ticks a process has used (the busy one is judged by what it really got: on a machine with
# every core taken it cannot burn its tick, and the guard is right not to ask)
ticks() { local f; f="$(sed 's/^.*) //' "/proc/$1/stat" 2>/dev/null)"; set -- $f; echo $((${12:-0} + ${13:-0})); }
busy0="$(ticks "${target[busy]}")"
for n in healthy busy spinning stuck; do watch "$n"; done
watch stopped no
watch refused no
watch silent never
sleep "$SPAN"
share=$((($(ticks "${target[busy]}") - busy0) * 100 / ($(getconf CLK_TCK) * SPAN)))

n="$(probes healthy)"
if ((n >= 1 && n <= SPAN / 6 + 2)); then ok "a shell that rests and wakes is asked $n times in $SPAN s (the first look, then once in six)"
else bad "healthy: $n probes in $SPAN s (wanted 1…$((SPAN / 6 + 2)): the look at /proc should spare the rest)"; fi
for n in busy spinning stuck; do
  p="$(probes "$n")"
  case "$n" in
    busy) what="busy all the tick" ;;
    spinning) what="that never sleeps" ;;
    *) what="that never wakes" ;;
  esac
  if [[ "$n" == busy ]] && ((share < 90)); then ok "a main thread $what: this machine gave it only $share % of a core, too busy itself to judge ($p in $SPAN s)"
  elif ((p >= SPAN / 2)); then ok "a main thread $what is asked every tick ($p in $SPAN s)"
  else bad "$n: $p probes in $SPAN s (wanted one a tick, at least $((SPAN / 2)))"; fi
done
p="$(probes stopped)"
if ((p == 0)) && [[ "$(state "${target[stopped]}")" == T ]]; then ok "a stopped shell (kill -STOP, a debugger) is left alone"
else bad "stopped: $p probes, state $(state "${target[stopped]}") (wanted none, still stopped)"; fi

# three misses → SIGABRT; then the guard goes with its shell
for n in refused silent; do
  for _ in $(seq 100); do
    s="$(state "${target[$n]}")"
    [[ -z "$s" || "$s" == Z ]] && break
    sleep 0.1
  done
  wait "${target[$n]}" 2>/dev/null; rc=$?
  for _ in $(seq 50); do kill -0 "${guard[$n]}" 2>/dev/null || break; sleep 0.1; done
  [[ "$n" == refused ]] && what="qs says no" || what="qs never comes back"
  if ((rc != 86)); then bad "$n: the shell ended with $rc after $(probes "$n") probes (wanted 86: SIGABRT after three misses)"
  elif ! grep -q SIGABRT "$T/$n.err"; then bad "$n: the guard did not say why it aborted"
  elif kill -0 "${guard[$n]}" 2>/dev/null; then bad "$n: the guard outlived its shell"
  else ok "$what three times running: SIGABRT (a crash report and a restart), and the guard goes with its shell"; fi
done
exit "$fail"
