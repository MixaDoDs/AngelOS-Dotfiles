#!/usr/bin/env python3
"""Programs nobody sees go to sleep (services/AppSleep, settings.json → appSleep).

A program whose every window has been out of sight (another desk, minimized) for --after
minutes, that plays and records nothing, holds no camera, downloads nothing and has been
idle (CPU) goes to sleep:
  sleep   its systemd scope is frozen (cgroup freezer: 0 CPU, 0 GPU) and its memory is
          pushed into zram (memory.reclaim); thawed the moment one of its windows is seen
          again, or another copy of it starts (a link opened from another program)
  nap     messengers (Discord, Telegram: --nap): not frozen — capped at 5 % of a core and
          squeezed into zram, so messages and notifications still come; a window seen,
          a call, a sound — back at once. A messenger with no window (in the tray) naps too.
Never: the --never list (Spotify, terminals with agents in them, Steam and its games,
OBS…), X11 programs (niri knows only xwayland-satellite's pid for them), the shell, niri.

Everything is woken when this script ends — SIGTERM, the shell gone (PR_SET_PDEATHSIG) —
and on start, whatever a killed copy left asleep ($XDG_RUNTIME_DIR/angelos/app-sleep.json).

  app-sleep.py [--after MIN] [--nap a,b] [--never a,b]
  stdin:  "wake" — everything up now (the tray, a notification…)
  stdout: {"asleep": [{"app": …, "how": "sleep"|"nap", "units": […]}]} on every change
  app-sleep.py --self-test     the decisions, no programs touched
"""
import json
import os
import select
import signal
import subprocess
import sys
import threading
import time

APP_SLICE = "/sys/fs/cgroup/user.slice/user-%d.slice/user@%d.service/app.slice" % (os.getuid(), os.getuid())
STATE = os.environ.get("APP_SLEEP_STATE") or os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "angelos", "app-sleep.json")
NAP = {"discord", "vesktop", "telegram", "freshgram", "ayugram", "64gram", "materialgram"}
NEVER = {"spotify", "kitty", "foot", "alacritty", "wezterm", "konsole", "ghostty", "gnome-terminal", "claude",
         "steam", "steamwebhelper", "gamescope", "wine", "wineserver", "proton", "obs", "resolve", "qemu",
         "quickshell", "niri", "xwayland", "gpu-screen-recorder", "pw-record", "pw-cat"}
IDLE_CPU = 0.05        # of one core, averaged over IDLE_WINDOW
IDLE_WINDOW = 120      # s
TICK = 10              # s
NAP_QUOTA = "5%"
HZ = os.sysconf("SC_CLK_TCK")
ONLY = os.environ.get("APP_SLEEP_ONLY", "")   # stands: only scopes named so are anyone's (real programs untouched)
BUSY_FILES = (".crdownload", ".part", ".download", ".partial")
INTERPRETERS = ("python", "perl", "ruby", "node", "bash", "sh", "java", "lua")


def say(**kw):
    print(json.dumps(kw, ensure_ascii=False), flush=True)


def log(*a):
    print("app-sleep:", *a, file=sys.stderr, flush=True)


def read(path):
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        return None


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=10)


# ── what the system looks like ──────────────────────────────────────

def processes():
    """pid → (ppid, comm, unit or None); unit only for app.slice scopes"""
    out = {}
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        stat = read(f"/proc/{pid}/stat")
        cg = read(f"/proc/{pid}/cgroup")
        if not stat or cg is None:
            continue
        rest = stat[stat.rfind(")") + 2:].split()
        path = cg.strip().split("::", 1)[-1]
        unit = path.rsplit("/", 1)[-1] if "/app.slice/" in path and path.endswith(".scope") else None
        if unit and ONLY and not unit.startswith(ONLY):
            unit = None
        out[int(pid)] = (int(rest[1]), stat[stat.find("(") + 1:stat.rfind(")")], unit)
    return out


def niri_state():
    try:
        wins = json.loads(run(["niri", "msg", "-j", "windows"]).stdout)
        wss = json.loads(run(["niri", "msg", "-j", "workspaces"]).stdout)
    except (ValueError, OSError, subprocess.TimeoutExpired):
        return None
    shown = {w["id"] for w in wss if w.get("is_active")}
    return [{"pid": w.get("pid"), "app": w.get("app_id") or "",
             "seen": w.get("workspace_id") in shown and not w.get("is_minimized")} for w in wins]


def sounding():
    """pids and binaries with a running audio stream (playing or recording)"""
    pids, bins = set(), set()
    try:
        d = json.loads(run(["pw-dump"]).stdout)
    except (ValueError, OSError, subprocess.TimeoutExpired):
        return pids, bins
    clients = {o["id"]: o["info"]["props"] for o in d if o.get("type", "").endswith("Client") and o.get("info")}
    for o in d:
        info = o.get("info") or {}
        p = info.get("props") or {}
        if o.get("type", "").endswith("Node") and p.get("media.class", "").startswith("Stream/") and info.get("state") == "running":
            c = clients.get(p.get("client.id"), {})
            for k in ("application.process.id", "pipewire.sec.pid"):
                if str(c.get(k, "")).isdigit():
                    pids.add(int(c[k]))
            if c.get("application.process.binary"):
                bins.add(c["application.process.binary"].lower()[:15])
    return pids, bins


def holds_busy_files(pids):
    """a camera open, or a download being written"""
    for pid in pids:
        try:
            fds = os.listdir(f"/proc/{pid}/fd")
        except OSError:
            continue
        for fd in fds:
            try:
                t = os.readlink(f"/proc/{pid}/fd/{fd}")
            except OSError:
                continue
            if t.startswith("/dev/video") or t.endswith(BUSY_FILES):
                return True
    return False


def cpu_usec(units):
    total = 0
    for u in units:
        for line in (read(f"{APP_SLICE}/{u}/cpu.stat") or "").splitlines():
            if line.startswith("usage_usec"):
                total += int(line.split()[1])
    return total


# ── the programs ───────────────────────────────────────────────────

def group(procs, wins, sat):
    """programs: name → {"units", "pids", "comms", "seen", "x11"}; a program is the scopes of a
    window's process and of everything it started (Chromium moves its children into a scope of
    their own), or a messenger's scopes when it has no window"""
    kids = {}
    for pid, (ppid, _c, _u) in procs.items():
        kids.setdefault(ppid, []).append(pid)

    def tree(pid):
        out, todo = set(), [pid]
        while todo:
            p = todo.pop()
            if p in out:
                continue
            out.add(p)
            todo += kids.get(p, [])
        return out

    apps = {}
    for w in wins:
        if not w["pid"] or w["pid"] in sat or w["pid"] not in procs:
            continue
        unit = procs[w["pid"]][2]
        if not unit:
            continue
        a = apps.setdefault(unit, {"key": unit, "name": w["app"], "units": set(), "pids": set(), "seen": False,
                                   "main": set()})
        a["seen"] |= w["seen"]
        a["main"].add(w["pid"])
        for p in tree(w["pid"]):
            if procs[p][2]:
                a["units"].add(procs[p][2])
    # programs sharing a scope are one
    merged = []
    for a in apps.values():
        for m in merged:
            if m["units"] & a["units"]:
                m["units"] |= a["units"]
                m["seen"] |= a["seen"]
                m["main"] |= a["main"]
                break
        else:
            merged.append(a)
    taken = set().union(*(m["units"] for m in merged)) if merged else set()
    # a messenger in the tray: its scopes, by name or by what runs in them
    tray = {}
    for pid, (_pp, comm, unit) in procs.items():
        if unit and unit not in taken:
            key = next((n for n in NAP if n in unit.lower() or n in comm.lower()), None)
            if key:
                tray.setdefault(key, {"key": "tray:" + key, "name": key, "units": set(), "pids": set(), "seen": False,
                                      "main": set()})["units"].add(unit)
    out = {}
    for a in merged + list(tray.values()):
        a["pids"] = {p for p, v in procs.items() if v[2] in a["units"]}
        a["comms"] = {procs[p][1].lower() for p in a["pids"]}
        out[a["key"]] = a
    return out


def kind(app, never, nap):
    """"never" | "nap" | "sleep" """
    words = {app["name"].lower()} | app["comms"]
    if any(w.startswith(n) or (len(w) == 15 and n.startswith(w)) for w in words for n in never):  # comm: 15 chars
        return "never"
    if any(n in w for w in words | {u.lower() for u in app["units"]} for n in nap):
        return "nap"
    return "sleep"


def decide(app, hidden_for, cpu, busy, after):
    """wake | sleep | stay"""
    if app["seen"] or busy:
        return "wake"
    if hidden_for >= after and cpu < IDLE_CPU:
        return "sleep"
    return "stay"


# ── doing it ───────────────────────────────────────────────────────

def squeeze(units, part):
    def go():
        for u in units:
            try:
                cur = int(read(f"{APP_SLICE}/{u}/memory.current"))
                with open(f"{APP_SLICE}/{u}/memory.reclaim", "w") as f:
                    f.write(str(int(cur * part)))
            except (OSError, TypeError, ValueError):
                pass               # EAGAIN: it took what it could
    threading.Thread(target=go, daemon=True).start()


def put_to_sleep(units, how):
    if how == "sleep":
        run(["systemctl", "--user", "freeze", *units])
    else:
        for u in units:
            run(["systemctl", "--user", "set-property", "--runtime", u, f"CPUQuota={NAP_QUOTA}"])
    squeeze(units, 1.0 if how == "sleep" else 0.5)


def wake_units(units, how):
    if how == "sleep":
        run(["systemctl", "--user", "thaw", *units])
    else:
        for u in units:
            run(["systemctl", "--user", "set-property", "--runtime", u, "CPUQuota="])


class Sleeper:
    def __init__(self, after, nap, never):
        self.after, self.nap, self.never = after, nap, never
        self.asleep = {}          # key → {"how", "units", "name", "since", "exes"}
        self.hidden = {}          # key → since when out of sight
        self.cpu = {}             # key → [(t, usec)]
        self.clip_pid = None      # the focused window's pid when the clipboard last changed
        self.recover()

    def save(self, tell=True):
        # out of sight since (wall clock): a shell restart does not start the count again
        now, wall = time.monotonic(), time.time()
        os.makedirs(os.path.dirname(STATE), exist_ok=True)
        with open(STATE + ".tmp", "w") as f:
            json.dump({"asleep": {k: {"how": v["how"], "units": sorted(v["units"])} for k, v in self.asleep.items()},
                       "hidden": {k: wall - (now - t) for k, t in self.hidden.items()}}, f)
        os.replace(STATE + ".tmp", STATE)
        if tell:
            say(asleep=[{"app": v["name"], "how": v["how"], "units": sorted(v["units"])} for v in self.asleep.values()])

    def recover(self):
        try:
            st = json.load(open(STATE))
        except (OSError, ValueError):
            st = {}
        left = st.get("asleep", {})
        now, wall = time.monotonic(), time.time()
        self.hidden = {k: now - (wall - t) for k, t in st.get("hidden", {}).items() if 0 <= wall - t < 86400}
        for v in left.values():
            wake_units(v["units"], v["how"])
        if left:
            log("woke what a previous copy left asleep:", ", ".join(left))
        self.save()

    def wake(self, key):
        v = self.asleep.pop(key)
        wake_units(v["units"], v["how"])
        log("wake", v["name"])
        self.hidden.pop(key, None)
        self.save()

    def wake_all(self):
        for k in list(self.asleep):
            self.wake(k)

    def quick(self):
        """a niri event: wake what is seen again — niri's lists only, no /proc walk"""
        wins = niri_state()
        if wins is None:
            return
        seen = {w["pid"] for w in wins if w["seen"]}
        for key in [k for k, v in self.asleep.items() if v["main"] & seen]:
            self.wake(key)

    def look(self):
        """decide who sleeps and who wakes"""
        wins = niri_state()
        if wins is None:
            return
        procs = processes()
        sat = {p for p, v in procs.items() if v[1].startswith("xwayland-sat")}
        apps = group(procs, wins, sat)
        now = time.monotonic()
        snd = sounding()
        for key, app in apps.items():
            k = kind(app, self.never, self.nap)
            if k == "never":
                continue
            if not app["seen"]:
                self.hidden.setdefault(key, now)
            else:
                self.hidden.pop(key, None)
            hist = self.cpu.setdefault(key, [])
            hist.append((now, cpu_usec(app["units"])))
            while len(hist) > 2 and now - hist[1][0] >= IDLE_WINDOW:
                hist.pop(0)
            span = hist[-1][0] - hist[0][0]
            cpu = (hist[-1][1] - hist[0][1]) / 1e6 / span if span >= IDLE_WINDOW / 2 else 1.0
            busy = (bool(app["pids"] & snd[0] or app["comms"] & snd[1]) or self.clip_pid in app["pids"]
                    or holds_busy_files(app["pids"]))
            d = decide(app, now - self.hidden.get(key, now), cpu if key not in self.asleep else 0, busy, self.after)
            if d == "wake" and key in self.asleep:
                self.wake(key)
            elif d == "sleep" and key not in self.asleep:
                put_to_sleep(app["units"], k)
                exes = {os.path.realpath(f"/proc/{p}/exe") for p in app["main"] if os.path.exists(f"/proc/{p}/exe")}
                self.asleep[key] = {"how": k, "units": app["units"], "name": app["name"], "main": set(app["main"]),
                                    # an interpreter starts all the time: not a sign of this program
                                    "exes": {e for e in exes if not os.path.basename(e).startswith(INTERPRETERS)}}
                log(k, app["name"], f"(out of sight {int((now - self.hidden[key]) / 60)} min)")
                self.save()
        for key in list(self.asleep):
            if key not in apps:                  # closed: let its scopes go
                self.wake(key)
        for d in (self.hidden, self.cpu):
            for key in [k for k in d if k not in apps]:
                d.pop(key)
        self.save(tell=False)

    def newcomers(self):
        """another copy of a sleeping program started (a link into a frozen browser): wake it"""
        frozen = {k: v for k, v in self.asleep.items() if v["how"] == "sleep"}
        if not frozen:
            return
        up = float(read("/proc/uptime").split()[0])
        for pid in os.listdir("/proc"):
            if not pid.isdigit():
                continue
            stat = read(f"/proc/{pid}/stat")
            if not stat or up - int(stat[stat.rfind(")") + 2:].split()[19]) / HZ > 5:
                continue
            try:
                exe = os.path.realpath(f"/proc/{pid}/exe")
            except OSError:
                continue
            for k, v in frozen.items():
                if exe in v["exes"] and int(pid) not in self._pids(v["units"]):
                    self.wake(k)
                    return

    @staticmethod
    def _pids(units):
        out = set()
        for u in units:
            out |= {int(x) for x in (read(f"{APP_SLICE}/{u}/cgroup.procs") or "").split()}
        return out


def self_test():
    procs = {100: (1, "helium", "app-niri-sh-100.scope"), 101: (100, "helium", "app-org.chromium.Chromium-100.scope"),
             200: (1, "kitty", "app-niri-kitty-200.scope"), 300: (1, "Discord", "app-flatpak-com.discordapp.Discord-1.scope"),
             400: (1, "xwayland-satell", None), 500: (1, "gedit", "app-niri-gedit-500.scope")}
    wins = [{"pid": 100, "app": "helium", "seen": False}, {"pid": 200, "app": "kitty", "seen": False},
            {"pid": 400, "app": "steam", "seen": False}, {"pid": 500, "app": "gedit", "seen": True}]
    apps = group(procs, wins, {400})
    by = {a["name"]: a for a in apps.values()}
    assert set(apps) == {"app-niri-sh-100.scope", "app-niri-kitty-200.scope", "app-niri-gedit-500.scope", "tray:discord"}, set(apps)
    assert by["helium"]["units"] == {"app-niri-sh-100.scope", "app-org.chromium.Chromium-100.scope"}, by["helium"]
    assert "steam" not in by, "X11 windows are never anyone's"
    assert "discord" in by and by["discord"]["units"] == {"app-flatpak-com.discordapp.Discord-1.scope"}, "a tray messenger"
    assert kind(by["kitty"], NEVER, NAP) == "never"
    assert kind(by["discord"], NEVER, NAP) == "nap"
    assert kind(by["helium"], NEVER, NAP) == "sleep"
    a = by["helium"]
    assert decide(a, 16 * 60, 0.01, False, 15 * 60) == "sleep"
    assert decide(a, 14 * 60, 0.01, False, 15 * 60) == "stay"
    assert decide(a, 16 * 60, 0.30, False, 15 * 60) == "stay", "busy CPU: not idle"
    assert decide(a, 16 * 60, 0.01, True, 15 * 60) == "wake", "a sound / camera / download"
    assert decide(by["gedit"], 99 * 60, 0, False, 15 * 60) == "wake", "a window in sight"
    print("app-sleep ok")


def main():
    if "--self-test" in sys.argv:
        return self_test()
    try:  # go away together with the shell (and wake everything on the way: SIGTERM below)
        import ctypes
        ctypes.CDLL(None).prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG
    except (OSError, AttributeError):
        pass
    args = sys.argv[1:]

    def opt(name, default):
        return args[args.index(name) + 1] if name in args and args.index(name) + 1 < len(args) else default

    after = float(opt("--after", 15)) * 60
    nap = NAP | {x.strip().lower() for x in opt("--nap", "").split(",") if x.strip()}
    never = NEVER | {x.strip().lower() for x in opt("--never", "").split(",") if x.strip()}
    s = Sleeper(after, nap, never)

    def bye(*_):
        s.wake_all()
        sys.exit(0)

    signal.signal(signal.SIGTERM, bye)
    signal.signal(signal.SIGHUP, bye)
    # raw pipes, read with os.read: a buffered readline hides lines from select (a wake 2.6 s late)
    events = subprocess.Popen(["niri", "msg", "-j", "event-stream"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                              bufsize=0)
    clip = subprocess.Popen(["wl-paste", "--watch", "echo", "."], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                            bufsize=0)
    ev, cl, inp = events.stdout.fileno(), clip.stdout.fileno(), sys.stdin.fileno()
    pending = b""
    full = 0.0
    due = None                                   # a quick look after niri's events
    newcomers_at = 0.0
    try:
        while True:
            now = time.monotonic()
            if now >= full:
                s.look()
                full = now + TICK
            wait = 1.0 if due is None else max(0.0, due - now)
            r, _, _ = select.select([ev, inp, cl], [], [], wait)
            if cl in r and os.read(cl, 65536):
                try:
                    s.clip_pid = json.loads(run(["niri", "msg", "-j", "focused-window"]).stdout or "null")["pid"]
                except (ValueError, TypeError, KeyError, OSError, subprocess.TimeoutExpired):
                    s.clip_pid = None
            if inp in r:
                chunk = os.read(inp, 4096)
                if not chunk:
                    break                        # the shell went away
                pending += chunk
                *lines, pending = pending.split(b"\n")
                if b"wake" in (x.strip() for x in lines):
                    s.wake_all()
            if ev in r:
                if not os.read(ev, 65536):
                    break                        # niri gone
                if s.asleep and due is None:
                    due = time.monotonic() + 0.02    # a burst of events: one look
            if due is not None and time.monotonic() >= due:
                due = None
                s.quick()
            if time.monotonic() >= newcomers_at:
                newcomers_at = time.monotonic() + 1
                s.newcomers()
    finally:
        s.wake_all()
        events.kill()
        clip.kill()


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        pass
