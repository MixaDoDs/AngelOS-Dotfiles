#!/usr/bin/env python3
"""`angelos perf` — what angelOS spends while it runs, and where.

  angelos perf [seconds]             a sample of the running shell (10 s): CPU and wake-ups by
                                     thread, its helper processes, memory, the frames each window
                                     drew, what keeps ticking in the windows (timers, endless
                                     animations), processes started
  angelos perf --stand [seconds]     the same of a fresh copy of the shell, started for it (own
                                     HOME seeded from your settings, on one screen: --screen,
                                     default a screen stream mode does not stream), left to settle
                                     for --settle seconds (45) first; ANGELOS_PERF_ENV="A=1 B=2"
                                     passes variables to it (to compare)
  angelos perf --profile [seconds]   a stand with the QML profiler: the signal handlers, bindings
                                     and functions that take the time, with file:line
                                     (scripts/perf-trace.py; the trace stays in --out)
  --json                             the numbers as JSON
  --budget [file]                    compare with the budget (data/perf-budget.json): exit 1 when
                                     something is over it
  --pid PID                          another instance (a dev copy; its XDG_RUNTIME_DIR in the env)

The profile needs a QML debug port, and Quickshell opens it on every network interface: the stand
it profiles runs in a network namespace of its own (unshare), where nobody else can reach it — and
where the shell has no network. The running shell is never given one.
"""
import json
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time

SHELL_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RU = os.environ.get("LC_ALL", os.environ.get("LC_MESSAGES", os.environ.get("LANG", ""))).startswith("ru")
HZ = os.sysconf("SC_CLK_TCK")


def t(ru, en):
    return ru if RU else en


def qs():
    return shutil.which("qs") or os.path.expanduser("~/.local/bin/qs")


def quickshell():
    """The quickshell binary and the variables it needs: the system one, else angelOS's own copy
    (~/.local/opt — the `qs` wrapper finds it through $HOME, which a stand changes)."""
    if os.path.exists("/usr/bin/quickshell"):
        return "/usr/bin/quickshell", {}
    p = os.path.expanduser("~/.local/opt/quickshell/usr")
    lib, qml = os.environ.get("LD_LIBRARY_PATH", ""), os.environ.get("QML_IMPORT_PATH", "")
    return p + "/bin/quickshell", {"LD_LIBRARY_PATH": p + "/lib" + (":" + lib if lib else ""),
                                   "QML_IMPORT_PATH": p + "/lib/qt6/qml" + (":" + qml if qml else "")}


def die(msg, code=2):
    print(msg, file=sys.stderr)
    sys.exit(code)


# ---- the process ----

def shell_pid():
    try:
        out = subprocess.run(["systemctl", "--user", "show", "-p", "MainPID", "--value", "angelos.service"],
                             capture_output=True, text=True, timeout=5).stdout.strip()
        if out and out != "0" and os.path.exists("/proc/" + out):
            return int(out)
    except Exception:
        pass
    try:
        out = subprocess.run([qs(), "-c", "angelos", "list"], capture_output=True, text=True, timeout=5).stdout
        for line in out.splitlines():
            if "Process ID:" in line:
                return int(line.split(":")[1])
    except Exception:
        pass
    return None


def ipc(pid, fn, *args, env=None, timeout=20):
    r = subprocess.run([qs(), "ipc", "--pid", str(pid), "call", "angelos", fn, *map(str, args)],
                       capture_output=True, text=True, timeout=timeout, env=env)
    if r.returncode != 0:
        raise RuntimeError((r.stderr or r.stdout).strip()[:300])
    return r.stdout.strip()


def threads(pid):
    out = {}
    for tid in os.listdir("/proc/%d/task" % pid):
        try:
            s = open("/proc/%d/task/%s/stat" % (pid, tid)).read()
            name = s[s.index("(") + 1:s.rindex(")")]
            f = s[s.rindex(")") + 2:].split()
            st = open("/proc/%d/task/%s/status" % (pid, tid)).read()
            sw = sum(int(l.split()[1]) for l in st.splitlines() if "ctxt_switches" in l)
            out[tid] = (name, int(f[11]) + int(f[12]), sw)
        except (OSError, ValueError, IndexError):
            pass
    return out


def descendants(pid):
    out = []
    try:
        for tid in os.listdir("/proc/%d/task" % pid):
            for c in open("/proc/%d/task/%s/children" % (pid, tid)).read().split():
                out += [int(c)] + descendants(int(c))
    except OSError:
        pass
    return out


def proc_info(pid):
    try:
        s = open("/proc/%d/stat" % pid).read()
        f = s[s.rindex(")") + 2:].split()
        cmd = open("/proc/%d/cmdline" % pid).read().split("\0")
        rss = int(open("/proc/%d/statm" % pid).read().split()[1]) * os.sysconf("SC_PAGE_SIZE")
        pss = 0
        try:
            for line in open("/proc/%d/smaps_rollup" % pid):
                if line.startswith("Pss:"):
                    pss = int(line.split()[1]) * 1024
        except OSError:
            pass
        return {"cpu": int(f[11]) + int(f[12]), "childCpu": int(f[13]) + int(f[14]), "rss": rss, "pss": pss,
                "cmd": [c for c in cmd if c]}
    except (OSError, ValueError, IndexError):
        return None


def helper_name(cmd):
    if not cmd:
        return "?"
    exe = os.path.basename(cmd[0])
    args = [a for a in cmd[1:] if not a.startswith("-")]
    if exe.startswith("python") and args:
        return os.path.basename(args[0])
    if exe in ("sh", "bash") and len(cmd) > 2 and cmd[1] == "-c":
        return "sh -c " + cmd[2][:40]
    return exe + (" " + os.path.basename(args[0]) if exe in ("sh", "bash") and args else "")


def sample(pid, seconds, env=None):
    """Everything over `seconds`: the shell's threads, its helpers, its own report."""
    hooks = None
    try:
        hooks = int(ipc(pid, "perfStart", int(seconds), env=env) or 0)
    except Exception as e:
        hooks = None
        own_err = str(e)
    t0 = time.time()
    th0, p0 = threads(pid), proc_info(pid)
    kids0 = {k: proc_info(k) for k in descendants(pid)}
    seen = set(kids0)
    deadline = t0 + seconds
    while time.time() < deadline:
        # short-lived helpers: seen while they run (their CPU lands in the shell's children time)
        for k in descendants(pid):
            seen.add(k)
        time.sleep(min(0.5, max(0.0, deadline - time.time())))
    span = time.time() - t0
    th1, p1 = threads(pid), proc_info(pid)
    kids1 = {k: proc_info(k) for k in descendants(pid)}
    report = {}
    if hooks is not None:
        try:
            report = json.loads(ipc(pid, "perfReport", env=env))
        except Exception as e:
            report = {"error": str(e)}
    else:
        report = {"error": own_err}
    rows = []
    for tid, (name, c, sw) in th1.items():
        if tid in th0:
            rows.append({"thread": name, "tid": int(tid), "cpu": (c - th0[tid][1]) / HZ / span * 100,
                         "wakeups": (sw - th0[tid][2]) / span})
    rows.sort(key=lambda r: -r["cpu"])
    helpers = []
    for k, info in kids1.items():
        if not info:
            continue
        before = kids0.get(k)
        cpu = (info["cpu"] - before["cpu"]) / HZ / span * 100 if before else None
        helpers.append({"pid": k, "name": helper_name(info["cmd"]), "cpu": cpu, "rssMB": info["rss"] / 1048576,
                        "pssMB": info["pss"] / 1048576})
    helpers.sort(key=lambda h: -(h["pssMB"] or 0))
    return {
        "pid": pid, "seconds": round(span, 1),
        "cpu": sum(r["cpu"] for r in rows), "wakeups": sum(r["wakeups"] for r in rows),
        "childCpu": (p1["childCpu"] - p0["childCpu"]) / HZ / span * 100 if p0 and p1 else 0,
        "rssMB": p1["rss"] / 1048576 if p1 else 0, "pssMB": p1["pss"] / 1048576 if p1 else 0,
        "threads": rows, "helpers": helpers,
        "helpersPssMB": sum(h["pssMB"] for h in helpers),
        "started": len(seen - set(kids0)),
        "shell": report,
    }


# ---- the stand: a fresh copy of the shell ----

def stand_screen(settings, want):
    if want:
        return want
    streamed = set(((settings.get("stream") or {}).get("screens")) or [])
    try:
        outs = json.loads(subprocess.run(["niri", "msg", "--json", "outputs"], capture_output=True,
                                         text=True, timeout=5).stdout or "{}")
        names = [n for n, o in outs.items() if o.get("current_mode") is not None]
    except Exception:
        names = []
    free = [n for n in sorted(names) if n not in streamed]
    if not free:
        die(t("нет экрана для стенда: все экраны стримятся (--screen ИМЯ)",
              "no screen for the stand: every screen is streamed (--screen NAME)"))
    return free[0]


class Stand:
    def __init__(self, screen, port=0, extra_env=""):
        self.dir = tempfile.mkdtemp(prefix="aos-perf.", dir="/tmp")    # short: socket paths
        self.port = port
        self.screen = screen
        self.extra_env = extra_env
        self.proc = None
        self.pid = None

    def env(self):
        h = os.path.join(self.dir, "home")
        rt = os.path.join(self.dir, "rt")
        e = {
            "PATH": os.environ.get("PATH", ""), "LANG": os.environ.get("LANG", "C.UTF-8"), "HOME": h,
            "USER": os.environ.get("USER", ""), "XDG_CONFIG_HOME": h + "/.config",
            "XDG_STATE_HOME": h + "/.local/state", "XDG_CACHE_HOME": h + "/.cache", "XDG_DATA_HOME": h + "/.local/share",
            "XDG_DATA_DIRS": os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share"), "XDG_RUNTIME_DIR": rt,
            "PIPEWIRE_RUNTIME_DIR": os.environ.get("XDG_RUNTIME_DIR", ""),
            "PULSE_RUNTIME_PATH": os.path.join(os.environ.get("XDG_RUNTIME_DIR", ""), "pulse"),
            "QT_QPA_PLATFORM": "wayland", "QT_QPA_PLATFORMTHEME": "gtk3", "QT_WAYLAND_DISABLE_WINDOWDECORATION": "1",
            "ANGELOS_DEV": "1", "ANGELOS_SCREENS": self.screen, "QS_NO_RELOAD_POPUP": "1", "ANGELOS_PERF_STAND": "1",
        }
        wd = os.environ.get("WAYLAND_DISPLAY", "wayland-1")
        e["WAYLAND_DISPLAY"] = wd if wd.startswith("/") else os.path.join(os.environ.get("XDG_RUNTIME_DIR", ""), wd)
        e.update(quickshell()[1])
        for k in ("NIRI_SOCKET", "__GLX_VENDOR_LIBRARY_NAME", "QT_PLUGIN_PATH", "QSG_RHI_BACKEND"):
            if os.environ.get(k):
                e[k] = os.environ[k]
        for pair in self.extra_env.split():
            if "=" in pair:
                k, v = pair.split("=", 1)
                e[k] = v
        return e

    def start(self):
        h = os.path.join(self.dir, "home")
        for d in (".config/angelos", ".local/share", ".cache", ".local/state"):
            os.makedirs(os.path.join(h, d), exist_ok=True)
        os.makedirs(os.path.join(self.dir, "rt"), mode=0o700, exist_ok=True)
        for d in ("fonts", "angelos"):
            src = os.path.expanduser("~/.local/share/" + d)
            if os.path.exists(src):
                os.symlink(src, os.path.join(h, ".local/share", d))
        try:
            settings = json.load(open(os.path.expanduser("~/.config/angelos/settings.json")))
        except (OSError, ValueError):
            settings = {}
        # quiet and on its own: no OBS, no sounds, no boot screen, no update check
        settings.setdefault("stream", {})["auto"] = False
        y = settings.setdefault("y2k", {})
        y["boot"] = False
        y["sounds"] = False
        settings.setdefault("setup", {})["complete"] = True
        settings.setdefault("system", {})["primaryScreen"] = self.screen
        # your desktop widgets, whatever screen they live on, come to the stand's (else a stand on
        # a second screen measures an empty desktop)
        for w in ((settings.get("desktop") or {}).get("widgets") or []):
            if isinstance(w, dict) and w.get("screen"):
                w["screen"] = self.screen
        # …and so do the Halo and the lyrics line, when they are kept to some screens (empty =
        # every screen, the stand's among them)
        for sect, key in (("halo", "screens"), ("lyrics", "screens"), ("lyrics", "haloScreens")):
            if (settings.get(sect) or {}).get(key):
                settings[sect][key] = [self.screen]
        settings.setdefault("updates", {})["autoCheck"] = False
        json.dump(settings, open(os.path.join(h, ".config/angelos/settings.json"), "w"))
        cmd = [quickshell()[0], "-p", SHELL_DIR]
        if self.port:
            cmd += ["--debug", str(self.port)]
        if shutil.which("dbus-run-session"):
            cmd = ["dbus-run-session", "--"] + cmd
        if self.port:
            # the debug port listens on every interface: a network of its own, loopback only
            if not shutil.which("unshare"):
                die(t("для профиля нужен unshare (util-linux)", "the profile needs unshare (util-linux)"))
            cmd = ["unshare", "--map-root-user", "--net", "sh", "-c", 'ip link set lo up && exec "$@"', "sh"] + cmd
        self.proc = subprocess.Popen(cmd, env=self.env(), stdout=open(os.path.join(self.dir, "log"), "w"),
                                     stderr=subprocess.STDOUT, start_new_session=True)
        for _ in range(100):
            for k in descendants(self.proc.pid) + [self.proc.pid]:
                info = proc_info(k)
                if info and info["cmd"] and os.path.basename(info["cmd"][0]) == "quickshell" and "-p" in info["cmd"]:
                    self.pid = k
                    return self.pid
            time.sleep(0.2)
        log = open(os.path.join(self.dir, "log"), errors="replace").read()[-1500:]
        self.stop()
        die(t("стенд не запустился:\n", "the stand did not start:\n") + log)

    def ns(self):
        """Run inside the stand's network (and user) namespace."""
        return ["nsenter", "--preserve-credentials", "-U", "-n", "-t", str(self.pid)] if self.port else []

    def stop(self):
        if self.proc and self.proc.poll() is None:
            try:
                os.killpg(self.proc.pid, signal.SIGTERM)
                self.proc.wait(5)
            except (OSError, subprocess.TimeoutExpired):
                try:
                    os.killpg(self.proc.pid, signal.SIGKILL)
                except OSError:
                    pass
        shutil.rmtree(self.dir, ignore_errors=True)


def profile(stand, seconds, out):
    """qmlprofiler against the stand, inside its namespace."""
    if not shutil.which("qmlprofiler"):
        die(t("нет qmlprofiler (пакет qt6-declarative)", "no qmlprofiler (package qt6-declarative)"))
    script = "sleep %d; echo r; sleep 6; echo 'o %s'; sleep 6; echo q; sleep 1; echo y" % (seconds, out)
    feeder = subprocess.Popen(["sh", "-c", script], stdout=subprocess.PIPE)
    subprocess.run(stand.ns() + ["qmlprofiler", "--interactive", "-a", "localhost", "-p", str(stand.port)],
                   stdin=feeder.stdout, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=seconds + 60)
    feeder.wait()
    return os.path.exists(out)


# ---- the budget ----

def check_budget(r, path):
    try:
        b = json.load(open(path))
    except (OSError, ValueError) as e:
        die(t("бюджет не прочитан: ", "cannot read the budget: ") + str(e))
    over = []
    sh = r.get("shell") or {}

    def cmp(name, value, limit, unit):
        if limit is not None and value > limit:
            over.append("%s: %.1f%s > %.1f%s" % (name, value, unit, limit, unit))
    cmp(t("CPU оболочки", "shell CPU"), r["cpu"], b.get("cpu"), "%")
    cmp(t("пробуждений", "wake-ups"), r["wakeups"], b.get("wakeups"), "/s")
    cmp(t("память оболочки (PSS)", "shell memory (PSS)"), r["pssMB"], b.get("pssMB"), " MB")
    cmp(t("память помощников (PSS)", "helpers' memory (PSS)"), r["helpersPssMB"], b.get("helpersPssMB"), " MB")
    fps = sum(f["fps"] for f in sh.get("frames", []))
    cmp(t("кадров в простое", "frames while idle"), fps, b.get("fps"), "/s")
    cmp(t("скрытых таймеров", "timers in hidden windows"), len([x for x in sh.get("timers", []) if not x.get("visible")]),
        b.get("hiddenTimers"), "")
    cmp(t("бесконечных анимаций в скрытых окнах", "endless animations in hidden windows"),
        len([x for x in sh.get("anims", []) + sh.get("frameAnims", []) if not x.get("visible")]), b.get("hiddenAnims"), "")
    cmp(t("запусков процессов", "processes started"), r["started"] / max(r["seconds"], 1) * 60, b.get("startsPerMin"), "/min")
    return over


# ---- printing ----

def show(r):
    sh = r.get("shell") or {}
    print(t("angelOS за %.0f с (PID %d)" % (r["seconds"], r["pid"]), "angelOS over %.0f s (PID %d)" % (r["seconds"], r["pid"])))
    print(t("  CPU %.1f %%, пробуждений %.0f/с; помощники ещё %.1f %% (завершённые)" % (r["cpu"], r["wakeups"], r["childCpu"]),
            "  CPU %.1f %%, %.0f wake-ups/s; finished helpers another %.1f %%" % (r["cpu"], r["wakeups"], r["childCpu"])))
    print(t("  память: %.0f МБ (PSS), помощники %.0f МБ, процессов запущено: %d" % (r["pssMB"], r["helpersPssMB"], r["started"]),
            "  memory: %.0f MB (PSS), helpers %.0f MB, processes started: %d" % (r["pssMB"], r["helpersPssMB"], r["started"])))
    busy = [x for x in r["threads"] if x["cpu"] >= 0.1 or x["wakeups"] >= 20][:6]
    if busy:
        print(t("\nПотоки:", "\nThreads:"))
        for x in busy:
            print("  %5.1f %%  %5.0f/s  %s" % (x["cpu"], x["wakeups"], x["thread"]))
    if r["helpers"]:
        print(t("\nПомощники:", "\nHelpers:"))
        for h in r["helpers"]:
            cpu = "  —  " if h["cpu"] is None else "%4.1f%%" % h["cpu"]
            print("  %s %5.0f MB  %s" % (cpu, h["pssMB"], h["name"]))
    if sh.get("error"):
        if "Function not found" in sh["error"] or "invalid literal" in sh["error"]:
            print(t("\nОкна и кадры: эта оболочка запущена до `angelos perf` — `angelos restart`, и они будут",
                    "\nWindows and frames: this shell was started before `angelos perf` — `angelos restart` brings them"))
        else:
            print(t("\nОболочка не ответила: ", "\nThe shell did not answer: ") + sh["error"])
        return
    frames = sh.get("frames", [])
    print(t("\nКадры в секунду по окнам (всего %.1f):" % sum(f["fps"] for f in frames),
            "\nFrames a second, by window (%.1f in all):" % sum(f["fps"] for f in frames)))
    for f in frames[:12]:
        print("  %6.1f  %s" % (f["fps"], f["window"]))
    if not frames:
        print(t("  ничего не рисовалось", "  nothing was drawn"))
    wins = sh.get("windows", [])
    print(t("\nОкон: %d, показано %d; объектов в них %d" % (len(wins), sum(1 for w in wins if w["visible"]), sh.get("objects", 0)),
            "\nWindows: %d, %d shown; %d objects in them" % (len(wins), sum(1 for w in wins if w["visible"]), sh.get("objects", 0))))
    heavy = sorted([w for w in wins if not w["visible"] and w.get("objects", 0) >= 300], key=lambda w: -w["objects"])[:8]
    if heavy:
        print(t("  скрытые, но собранные (объектов):", "  hidden but built (objects):"))
        for w in heavy:
            print("  %7d  %s" % (w["objects"], w["name"]))

    def listed(title, items, fmt):
        if not items:
            return
        print("\n" + title)
        seen = {}
        for x in items:
            k = fmt(x)
            seen[k] = seen.get(k, 0) + 1
        for k, n in sorted(seen.items(), key=lambda kv: -kv[1])[:15]:
            print("  %s%s" % ("%d× " % n if n > 1 else "", k))
    hidden = t(" [скрыто]", " [hidden]")
    listed(t("Таймеры, что повторяются:", "Repeating timers:"), sorted(sh.get("timers", []), key=lambda x: x["interval"]),
           lambda x: "%5d ms  %s%s" % (x["interval"], x["at"], "" if x["visible"] else hidden))
    listed(t("Бесконечные анимации:", "Endless animations:"), sh.get("anims", []),
           lambda x: "%s  %s%s" % (x["type"], x["at"], "" if x["visible"] else hidden))
    listed("FrameAnimation:", sh.get("frameAnims", []), lambda x: "%s%s" % (x["at"], "" if x["visible"] else hidden))
    listed(t("Запуски процессов (в минуту):", "Processes started (a minute):"), sh.get("spawns", []),
           lambda x: "%5.1f  %s" % (x["perMin"], x["at"]))


def main(argv):
    args = list(argv)
    flag = lambda f: f in args and (args.remove(f) or True)

    def opt(name, default=None):
        if name in args:
            i = args.index(name)
            v = args[i + 1] if i + 1 < len(args) else default
            del args[i:i + 2]
            return v
        return default
    if flag("-h") or flag("--help") or flag("help"):
        print(__doc__.strip())
        return 0
    as_json = flag("--json")
    budget = None
    if "--budget" in args:
        i = args.index("--budget")
        nxt = args[i + 1] if i + 1 < len(args) else ""
        if nxt.endswith(".json"):
            budget = nxt
            del args[i:i + 2]
        else:
            budget = os.path.join(SHELL_DIR, "data", "perf-budget.json")
            del args[i]
    pid = opt("--pid")
    screen = opt("--screen")
    settle = float(opt("--settle", "45"))
    out = opt("--out")
    want_stand = flag("--stand")
    want_profile = flag("--profile")
    seconds = float(args[0]) if args and args[0].replace(".", "", 1).isdigit() else (30 if want_profile else 10)

    stand = None
    env = None
    try:
        if want_stand or want_profile:
            try:
                settings = json.load(open(os.path.expanduser("~/.config/angelos/settings.json")))
            except (OSError, ValueError):
                settings = {}
            stand = Stand(stand_screen(settings, screen), port=37000 + os.getpid() % 2000 if want_profile else 0,
                          extra_env=os.environ.get("ANGELOS_PERF_ENV", ""))
            pid = stand.start()
            env = dict(os.environ, XDG_RUNTIME_DIR=os.path.join(stand.dir, "rt"))
            if not as_json:
                print(t("стенд на %s (PID %d), жду %d с, пока успокоится…" % (stand.screen, pid, settle),
                        "stand on %s (PID %d), %d s to settle…" % (stand.screen, pid, settle)), file=sys.stderr)
            time.sleep(settle)
        else:
            pid = int(pid) if pid else shell_pid()
            if not pid:
                die(t("angelOS не запущен", "angelOS is not running"))
            env = os.environ.copy()
        if want_profile:
            out = out or os.path.join(tempfile.gettempdir(), "angelos-perf-%d.qtd" % int(time.time()))
            if not profile(stand, int(seconds), out):
                die(t("профиль не записался", "the profile was not written"))
            subprocess.run([sys.executable, os.path.join(SHELL_DIR, "scripts", "perf-trace.py"), out]
                           + (["--json"] if as_json else []))
            if not as_json:
                print(t("\nтрасса: %s (Qt Creator → Анализ → QML Profiler → Загрузить)" % out,
                        "\ntrace: %s (Qt Creator → Analyze → QML Profiler → Load)" % out))
            return 0
        r = sample(int(pid), seconds, env=env)
        over = check_budget(r, budget) if budget else []
        if as_json:
            r["overBudget"] = over
            print(json.dumps(r, ensure_ascii=False))
        else:
            show(r)
            if budget:
                print(t("\nБюджет (%s): " % os.path.basename(budget), "\nBudget (%s): " % os.path.basename(budget))
                      + (t("в норме", "within") if not over else t("превышен", "over")))
                for o in over:
                    print("  ✕ " + o)
        return 1 if over else 0
    finally:
        if stand:
            stand.stop()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
