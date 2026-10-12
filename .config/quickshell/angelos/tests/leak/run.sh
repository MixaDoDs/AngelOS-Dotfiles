#!/usr/bin/env bash
# Memory that stays behind, offscreen (scripts/test-ui.sh runs it, so does CI): the settings
# window, every page opened in turn, round after round (tests/leak/LeakDriver.qml). The first
# round builds the caches (fonts, icons, the search index); after it a page that cleans up when
# it goes costs nothing, so the rounds after it must not grow the shell by more than the budget.
#
#   tests/leak/run.sh [angelOS dir]     exit 0 = within, 77 = no quickshell
#   LEAK_ROUNDS=n LEAK_DWELL_MS=ms      rounds (10, at least 4), time on each page (120)
#   LEAK_MAX_KB=kb                      growth allowed a round over the last three (3072)
#
# What it measures (2026-10-11, 16 rounds, heap profile): about 1 MB a round stays even now, 20 KB
# a page opened — strings written by bindings and the layers of effects, too little to chase. A
# page that leaves its own tree behind costs 2–3 MB a round on top of that: over the budget.
set -uo pipefail
DIR="$(cd "${1:-"$(dirname "$0")/../.."}" && pwd)"
[[ -f "$DIR/shell.qml" ]] || { echo "no angelOS in $DIR"; exit 2; }
MAX_KB="${LEAK_MAX_KB:-3072}"
# ten rounds: with 53 pages the caches are still filling in rounds 2–5 (6 rounds read 3–5 MB a
# round for a tree that settles at 1.7; one page alone over 40 rounds: 50–80 KB a round)
ROUNDS="${LEAK_ROUNDS:-10}"
((ROUNDS >= 4)) || ROUNDS=4

QS="$(command -v quickshell || true)"
LIB="${LD_LIBRARY_PATH:-}" QML="${QML_IMPORT_PATH:-}"
if [[ ! -x /usr/bin/quickshell && -x "$HOME/.local/opt/quickshell/usr/bin/quickshell" ]]; then
  QS="$HOME/.local/opt/quickshell/usr/bin/quickshell"
  LIB="$HOME/.local/opt/quickshell/usr/lib${LIB:+:$LIB}"
  QML="$HOME/.local/opt/quickshell/usr/lib/qt6/qml${QML:+:$QML}"
fi
[[ -x "$QS" ]] || { echo "quickshell not found"; exit 77; }

T="$(mktemp -d /tmp/aos-leak.XXXXXX)"
# the shell in a process group of its own, all of it gone at the end (as tests/perf/run.sh)
trap '[[ -n "${pg:-}" ]] && kill -TERM -- "-$pg" 2>/dev/null; sleep 0.5; [[ -n "${pg:-}" ]] && kill -KILL -- "-$pg" 2>/dev/null; rm -rf "$T"' EXIT
mkdir -p "$T/root" "$T/home/.config/angelos" "$T/rt" && chmod 700 "$T/rt"

# the real shell minus its screen windows, plus the driver
for f in "$DIR"/*; do [[ "${f##*/}" == shell.qml ]] || ln -s "$f" "$T/root/"; done
python3 - "$DIR/shell.qml" >"$T/root/shell.qml" <<'PY'
import re, sys
lines = [l for l in open(sys.argv[1]).read().splitlines() if not re.match(r"^    [A-Z][A-Za-z0-9]* \{\}\s*$", l)]
text = "\n".join(lines).rstrip()
text = text.replace("import qs.widgets", "import qs.widgets\nimport qs.tests.leak", 1)
print(text[:text.rfind("}")] + "    LeakDriver {}\n}")
PY
# quiet, offline settings (as scripts/test-ui.sh), developer mode on: its pages count too
cat >"$T/home/.config/angelos/settings.json" <<'JSON'
{"setup": {"complete": true}, "stream": {"auto": false}, "y2k": {"sounds": false, "helper": false, "boot": false},
 "bar": {"metaTap": false}, "updates": {"autoCheck": false}, "system": {"nautilusDefaults": true},
 "developer": {"enabled": true}}
JSON

# the allocator gives freed memory back at once (jemalloc, Quickshell's; glibc's kept small where
# there is no jemalloc): the shell's size then follows what it holds, not what it held a moment
# ago — otherwise the rounds differ by several MB either way on a busy machine
runner=()
command -v dbus-run-session >/dev/null && runner=(dbus-run-session --)
env -i PATH="$PATH" LANG=C.UTF-8 HOME="$T/home" USER="${USER:-angel}" \
  XDG_CONFIG_HOME="$T/home/.config" XDG_STATE_HOME="$T/home/.local/state" \
  XDG_CACHE_HOME="$T/home/.cache" XDG_DATA_HOME="$T/home/.local/share" XDG_RUNTIME_DIR="$T/rt" \
  QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= LD_LIBRARY_PATH="$LIB" QML_IMPORT_PATH="$QML" \
  ANGELOS_DEV=1 ANGELOS_SCREENS=__none__ ANGELOS_TEST=1 ANGELOS_SETTINGS_WARM=0 QS_NO_RELOAD_POPUP=1 \
  QS_DISABLE_CRASH_HANDLER=1 GIO_USE_VFS=local LEAK_ROUNDS="$ROUNDS" LEAK_DWELL_MS="${LEAK_DWELL_MS:-120}" \
  MALLOC_CONF=dirty_decay_ms:0,muzzy_decay_ms:0 MALLOC_ARENA_MAX=1 MALLOC_TRIM_THRESHOLD_=65536 \
  setsid "${runner[@]}" timeout --foreground 600 "$QS" -p "$T/root" >"$T/log" 2>&1 &
pg=$!

# the quickshell process (under dbus-run-session and timeout); its RSS after each round is the
# least of the reads while the driver rests (3 s): on a busy machine what was just freed takes a
# moment to go back
pid=""
for _ in $(seq 100); do
  pid="$(pgrep -f -n "^$QS -p $T/root")" && break
  sleep 0.2
done
[[ -n "$pid" ]] || { echo "  ✕ the shell did not start: $(tail -3 "$T/log" | tr '\n' ' ' | cut -c1-300)"; exit 1; }
rss=()
for _ in $(seq 3000); do
  n="$(grep -c 'ROUND [0-9]' "$T/log" 2>/dev/null)"
  if ((n > ${#rss[@]})); then
    least=0
    for _ in 1 2 3 4 5 6 7 8; do
      sleep 0.3
      r="$(awk '/^VmRSS:/ {print $2}' "/proc/$pid/status" 2>/dev/null)"
      [[ -n "$r" ]] && ((least == 0 || r < least)) && least="$r"
    done
    rss+=("$least")
  fi
  grep -q 'DONE\|LEAK no settings pages' "$T/log" 2>/dev/null && break
  kill -0 "$pid" 2>/dev/null || break
  sleep 0.2
done
pages="$(sed -n 's/.*LEAK pages \([0-9]*\).*/\1/p' "$T/log" | head -1)"
if ! grep -q DONE "$T/log" || ((${#rss[@]} < 4)); then
  echo "  ✕ the rounds did not finish (${#rss[@]} of $ROUNDS): $(grep -E 'ERROR|LEAK' "$T/log" | tail -3 | tr '\n' ' ' | cut -c1-300)"
  exit 1
fi
# the last three rounds, KB a round: the caches are built by then, also on a machine so busy that
# what loads in the background (fonts, icons) was still coming in during the second
first="${rss[-4]}" last="${rss[-1]}"
per=$(((last - first) / 3))
line="$pages pages × ${#rss[@]} rounds, RSS by round (MB): $(for r in "${rss[@]}"; do printf '%d ' $((r / 1024)); done)"
if ((per > MAX_KB)); then
  echo "  ✕ settings pages leave $((per / 1024)).$((per % 1024 * 10 / 1024)) MB behind a round (> $((MAX_KB / 1024)) MB): $line"
  exit 1
fi
echo "  ✓ settings pages leave ${per} KB a round (≤ ${MAX_KB} KB): $line"
