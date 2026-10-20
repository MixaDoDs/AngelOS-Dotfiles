#!/usr/bin/env bash
# The idle budget, offscreen (scripts/test-ui.sh runs it, so does CI): the shell's services with
# nobody touching anything — after it settles, CPU, wake-ups and processes started stay under
# the budget below. A binding that rebuilds itself forever (the 90 % CPU of the settings search
# index, 2026-10-01), a poll that got fast or a helper started over and over fail here.
# The windows' own cost (frames, the live wallpaper) needs a screen: `angelos perf --stand --budget`.
#
#   tests/perf/run.sh [angelOS dir]     exit 0 = within, 77 = no quickshell
#   PERF_SETTLE=s PERF_SPAN=s           how long it settles (30), how long it is measured (20)
set -uo pipefail
DIR="$(cd "${1:-"$(dirname "$0")/../.."}" && pwd)"
[[ -f "$DIR/shell.qml" ]] || { echo "no angelOS in $DIR"; exit 2; }

# the budget: an idle angelOS without windows, every service made, sits at 0.0 % CPU and under
# one wake-up a second (2026-10-11) — nothing here waits for a screen, niri or sound. A 20 ms
# timer left running (50/s) or a binding that never settles is over it
MAX_CPU="${PERF_MAX_CPU:-1.0}"         # % of one core
MAX_WAKE="${PERF_MAX_WAKE:-25}"        # voluntary context switches a second, all threads
MAX_STARTS="${PERF_MAX_STARTS:-6}"     # processes started a minute

QS="$(command -v quickshell || true)"
LIB="${LD_LIBRARY_PATH:-}" QML="${QML_IMPORT_PATH:-}"
if [[ ! -x /usr/bin/quickshell && -x "$HOME/.local/opt/quickshell/usr/bin/quickshell" ]]; then
  QS="$HOME/.local/opt/quickshell/usr/bin/quickshell"
  LIB="$HOME/.local/opt/quickshell/usr/lib${LIB:+:$LIB}"
  QML="$HOME/.local/opt/quickshell/usr/lib/qt6/qml${QML:+:$QML}"
fi
[[ -x "$QS" ]] || { echo "quickshell not found"; exit 77; }

T="$(mktemp -d /tmp/aos-perf.XXXXXX)"
# the shell runs in a process group of its own: all of it goes at the end (dbus-run-session's
# children outlive a plain kill), then its folder
trap '[[ -n "${pg:-}" ]] && kill -TERM -- "-$pg" 2>/dev/null; sleep 0.5; [[ -n "${pg:-}" ]] && kill -KILL -- "-$pg" 2>/dev/null; rm -rf "$T"' EXIT
mkdir -p "$T/root" "$T/home/.config/angelos" "$T/rt" && chmod 700 "$T/rt"

# the real shell minus its screen windows (as scripts/test-ui.sh): what is left are the services
# — every one of them: a singleton is made only when something names it, and with the windows
# gone most would never be, so the copy names them all (services/ and config/)
for f in "$DIR"/*; do [[ "${f##*/}" == shell.qml ]] || ln -s "$f" "$T/root/"; done
python3 - "$DIR" >"$T/root/shell.qml" <<'PY'
import os, re, sys
d = sys.argv[1]
lines = [l for l in open(os.path.join(d, "shell.qml")).read().splitlines() if not re.match(r"^    [A-Z][A-Za-z0-9]* \{\}\s*$", l)]
text = "\n".join(lines).rstrip()
names = []
for sub in ("services", "config"):
    for f in sorted(os.listdir(os.path.join(d, sub))):
        if f.endswith(".qml") and "pragma Singleton" in open(os.path.join(d, sub, f)).read(300):
            names.append(f[:-4])
text = text.replace("import qs.services", "import qs.services\nimport qs.config", 1)
print(text[:text.rfind("}")] + "    QtObject {\n        readonly property var all: [%s]\n    }\n}" % ", ".join(names))
PY
cat >"$T/home/.config/angelos/settings.json" <<'JSON'
{"setup": {"complete": true}, "stream": {"auto": false}, "y2k": {"sounds": false, "boot": false},
 "bar": {"metaTap": false}, "updates": {"autoCheck": false}, "system": {"nautilusDefaults": true}}
JSON

runner=()
command -v dbus-run-session >/dev/null && runner=(dbus-run-session --)
SETTLE="${PERF_SETTLE:-30}" SPAN="${PERF_SPAN:-20}"
env -i PATH="$PATH" LANG=C.UTF-8 HOME="$T/home" USER="${USER:-angel}" \
  XDG_CONFIG_HOME="$T/home/.config" XDG_STATE_HOME="$T/home/.local/state" \
  XDG_CACHE_HOME="$T/home/.cache" XDG_DATA_HOME="$T/home/.local/share" XDG_RUNTIME_DIR="$T/rt" \
  QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= LD_LIBRARY_PATH="$LIB" QML_IMPORT_PATH="$QML" \
  ANGELOS_DEV=1 ANGELOS_SCREENS=__none__ ANGELOS_TEST=1 QS_NO_RELOAD_POPUP=1 QS_DISABLE_CRASH_HANDLER=1 GIO_USE_VFS=local \
  setsid "${runner[@]}" timeout --foreground $((SETTLE + SPAN + 30)) "$QS" -p "$T/root" >"$T/log" 2>&1 &
pg=$!

# the quickshell process itself (under dbus-run-session and timeout)
pid=""
for _ in $(seq 100); do
  pid="$(pgrep -f -n "^$QS -p $T/root")" && break
  sleep 0.2
done
[[ -n "$pid" ]] || { echo "  ✕ the shell did not start: $(tail -3 "$T/log" | tr '\n' ' ' | cut -c1-300)"; exit 1; }
sleep "$SETTLE"
kill -0 "$pid" 2>/dev/null || { echo "  ✕ the shell died while settling: $(tail -3 "$T/log" | tr '\n' ' ' | cut -c1-300)"; exit 1; }

out="$(python3 - "$pid" "$SPAN" <<'PY'
import os, sys, time
pid, span = int(sys.argv[1]), float(sys.argv[2])
hz = os.sysconf("SC_CLK_TCK")
def kids(p):
    out = set()
    try:
        for t in os.listdir("/proc/%d/task" % p):
            for c in open("/proc/%d/task/%s/children" % (p, t)).read().split():
                out |= {int(c)} | kids(int(c))
    except OSError:
        pass
    return out
def snap():
    th = {}
    for t in os.listdir("/proc/%d/task" % pid):
        try:
            s = open("/proc/%d/task/%s/stat" % (pid, t)).read()
            f = s[s.rindex(")") + 2:].split()
            # voluntary only: the thread waking up itself; being preempted by the tests beside it is not its fault
            sw = sum(int(l.split()[1]) for l in open("/proc/%d/task/%s/status" % (pid, t)) if l.startswith("voluntary_ctxt_switches"))
            th[t] = (int(f[11]) + int(f[12]), sw)
        except (OSError, ValueError):
            pass
    s = open("/proc/%d/stat" % pid).read()
    f = s[s.rindex(")") + 2:].split()
    return th, int(f[13]) + int(f[14])
before = kids(pid)
seen = set(before)
th0, k0 = snap()
t0 = time.time()
while time.time() - t0 < span:
    seen |= kids(pid)
    time.sleep(0.25)
th1, k1 = snap()
# the threads there both times (one that ended took its counts along)
both = [t for t in th1 if t in th0]
c1 = sum(th1[t][0] - th0[t][0] for t in both)
w1 = sum(th1[t][1] - th0[t][1] for t in both)
c0 = w0 = 0
dt = time.time() - t0
new = seen - before
names = {}
for p in new:
    try:
        cmd = open("/proc/%d/cmdline" % p).read().split("\0")
    except OSError:
        cmd = ["(gone)"]
    n = " ".join(os.path.basename(c) for c in cmd[:3] if c)
    names[n] = names.get(n, 0) + 1
print("%.2f %.0f %.2f %.1f %s" % ((c1 - c0) / hz / dt * 100, (w1 - w0) / dt, (k1 - k0) / hz / dt * 100,
                                  len(new) / dt * 60, ";".join("%s ×%d" % kv for kv in sorted(names.items(), key=lambda kv: -kv[1])[:5])))
PY
)"
read -r cpu wake kcpu starts who <<<"$out"
fail=0
over() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a > b) }'; }
if over "$cpu" "$MAX_CPU"; then echo "  ✕ idle CPU ${cpu} % > ${MAX_CPU} % (a binding or timer that never rests: angelos perf --profile finds it)"; fail=1
else echo "  ✓ idle CPU ${cpu} % (≤ ${MAX_CPU} %), finished helpers ${kcpu} %"; fi
if over "$wake" "$MAX_WAKE"; then echo "  ✕ idle wake-ups ${wake}/s > ${MAX_WAKE}/s"; fail=1
else echo "  ✓ idle wake-ups ${wake}/s (≤ ${MAX_WAKE}/s)"; fi
if over "$starts" "$MAX_STARTS"; then echo "  ✕ ${starts} processes started a minute > ${MAX_STARTS} (${who//;/, })"; fail=1
else echo "  ✓ ${starts} processes started a minute (≤ ${MAX_STARTS})${who:+: ${who//;/, }}"; fi
exit "$fail"
