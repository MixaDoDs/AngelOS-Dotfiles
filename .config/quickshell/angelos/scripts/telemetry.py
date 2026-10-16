#!/usr/bin/env python3
"""angelOS telemetry and the sponsor wall (Settings → Sponsor, services/Telemetry.qml).

  telemetry.py preview          the report as it would go, JSON (nothing is sent)
  telemetry.py send [--force]   send it if the user said yes (settings.json setup.telemetry) and
                                it is due: a week since the last one, or angelOS / Quickshell changed
  telemetry.py status           {"consent", "endpoint", "last", "result"}
  telemetry.py forget           ask the relay to delete this computer's reports, drop the local id
  telemetry.py sponsors         the sponsor wall {"names", "updated"} (cached in ~/.cache/angelos)

Where to: data/sponsor.json "endpoint" — the author's relay (owner/telemetry-worker) that keeps
the reports in his private repo; empty = nothing goes anywhere. What goes: a random id made on
the first "yes" (not the machine id), versions (angelOS, Quickshell, Qt, niri, kernel, distro),
the hardware (CPU, threads, RAM, GPUs, screens' modes, laptop or not) and a few choices (language,
look, game on/off). Never: the user or host name, paths, files, IP (the relay doesn't keep it).
No "yes" — nothing is collected or sent. ANGELOS_TEST set — never sent.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

CONF = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
STATE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "angelos"
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "angelos"
SHELL_DIR = Path(__file__).resolve().parents[1]
SETTINGS = CONF / "angelos/settings.json"
ID_FILE = STATE / "telemetry-id"
STATE_FILE = STATE / "telemetry.json"
WALL_CACHE = CACHE / "sponsors.json"
WEEK = 7 * 24 * 3600
UA = "angelOS-telemetry/1"


def out(obj):
    print(json.dumps(obj, ensure_ascii=False))


def read_json(path, default):
    try:
        return json.loads(Path(path).read_text())
    except (OSError, ValueError):
        return default


def write_json(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(obj, ensure_ascii=False, indent=1))
    tmp.replace(path)


def run(cmd, timeout=10):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def settings():
    return read_json(SETTINGS, {})


def consent():
    return (settings().get("setup") or {}).get("telemetry", "")


def endpoint():
    url = os.environ.get("ANGELOS_TELEMETRY_URL") or read_json(SHELL_DIR / "data/sponsor.json", {}).get("endpoint", "")
    return url.rstrip("/")


def machine_id(create):
    try:
        v = ID_FILE.read_text().strip()
        if re.fullmatch(r"[0-9a-f-]{36}", v):
            return v
    except OSError:
        pass
    if not create:
        return ""
    v = str(uuid.uuid4())
    STATE.mkdir(parents=True, exist_ok=True)
    ID_FILE.write_text(v + "\n")
    return v


# ---- what goes ----

def first_line_version(cmd):
    text = run(cmd)
    m = re.search(r"\d+(\.\d+)+", text.splitlines()[0] if text else "")
    return m.group(0) if m else ""


def angelos_version():
    rel = read_json(SHELL_DIR / "data/release.json", {})
    info = {"release": rel.get("number"), "codename": rel.get("codename", "")}
    src = {}
    try:
        for line in (CONF / "angelos/dotfiles-source").read_text().splitlines():
            if "=" in line:
                k, v = line.split("=", 1)
                src[k.strip()] = v.strip()
    except OSError:
        pass
    repo = src.get("repo") or str(Path.home() / "AngelOS-Dotfiles")
    if Path(repo, ".git").exists():
        info["commit"] = run(["git", "-C", repo, "log", "-1", "--format=%h %cs"])
    return info


def cpu():
    model = ""
    try:
        for line in Path("/proc/cpuinfo").read_text().splitlines():
            if line.startswith("model name"):
                model = line.split(":", 1)[1].strip()
                break
    except OSError:
        pass
    return {"model": re.sub(r"\s+", " ", model), "threads": os.cpu_count() or 0}


def ram_gb():
    try:
        for line in Path("/proc/meminfo").read_text().splitlines():
            if line.startswith("MemTotal:"):
                return round(int(line.split()[1]) / 1024 / 1024, 1)
    except (OSError, ValueError):
        pass
    return 0


def gpus():
    names = []
    for line in run(["lspci", "-nn"]).splitlines():
        if re.search(r"VGA|3D|Display", line):
            name = line.split(": ", 1)[-1]
            names.append(re.sub(r"\s*\[[0-9a-f]{4}:[0-9a-f]{4}\]|\s*\(rev [0-9a-f]+\)", "", name).strip())
    return names


def screens():
    res = []
    try:
        for o in json.loads(run(["niri", "msg", "--json", "outputs"]) or "{}").values():
            if o.get("current_mode") is None:
                continue
            m = o["modes"][o["current_mode"]]
            res.append({"mode": "%dx%d@%d" % (m["width"], m["height"], round(m["refresh_rate"] / 1000)),
                        "scale": (o.get("logical") or {}).get("scale")})
    except (ValueError, KeyError, TypeError, IndexError):
        pass
    return res


def distro():
    try:
        osr = dict(l.split("=", 1) for l in Path("/etc/os-release").read_text().splitlines() if "=" in l)
        return osr.get("PRETTY_NAME", "").strip('"')
    except OSError:
        return ""


def qt_version():
    for q in ("/usr/lib/qt6/bin/qtpaths6", "/usr/lib64/qt6/bin/qtpaths6"):
        if os.path.exists(q):
            return run([q, "--qt-version"])
    return ""


def report(rid):
    s = settings()
    qs = shutil.which("qs") or shutil.which("quickshell") or str(Path.home() / ".local/bin/qs")
    pick = lambda sec, key: (s.get(sec) or {}).get(key)
    return {
        "v": 1,
        "id": rid,
        "angelos": angelos_version(),
        "quickshell": first_line_version([qs, "--version"]),
        "qt": qt_version(),
        "niri": first_line_version(["niri", "--version"]),
        "os": {"distro": distro(), "kernel": run(["uname", "-r"])},
        "cpu": cpu(),
        "ram_gb": ram_gb(),
        "gpus": gpus(),
        "screens": screens(),
        "laptop": any(Path("/sys/class/power_supply").glob("BAT*")),
        "choices": {
            "language": pick("appearance", "language"),
            "mode": pick("appearance", "mode"),
            "skin": pick("settingsUi", "skin"),
            "game": pick("game", "enabled"),
            "from": pick("setup", "from"),
            "persona": pick("setup", "persona"),
        },
    }


def version_key(r):
    return "%s|%s|%s" % (r["angelos"].get("release"), r["angelos"].get("commit", ""), r["quickshell"])


# ---- the relay ----

def post(path, obj):
    req = urllib.request.Request(endpoint() + path, data=json.dumps(obj).encode(), method="POST",
                                 headers={"Content-Type": "application/json", "User-Agent": UA})
    with urllib.request.urlopen(req, timeout=20) as r:
        return r.status


def cmd_send(force):
    if os.environ.get("ANGELOS_TEST"):
        return out({"sent": False, "why": "test"})
    if consent() != "yes":
        return out({"sent": False, "why": "no-consent"})
    if not endpoint():
        return out({"sent": False, "why": "no-endpoint"})
    st = read_json(STATE_FILE, {})
    r = report(machine_id(True))
    due = force or time.time() - st.get("last", 0) >= WEEK or st.get("version") != version_key(r)
    if not due:
        return out({"sent": False, "why": "not-due", "last": st.get("last")})
    try:
        post("/v1/report", r)
        st.update(last=int(time.time()), version=version_key(r), result="ok")
        write_json(STATE_FILE, st)
        return out({"sent": True, "last": st["last"]})
    except (urllib.error.URLError, OSError, ValueError) as e:
        st["result"] = "error: %s" % (getattr(e, "reason", None) or e)
        write_json(STATE_FILE, st)
        return out({"sent": False, "why": "error", "error": st["result"]})


def cmd_forget():
    rid = machine_id(False)
    ok = True
    if rid and endpoint() and not os.environ.get("ANGELOS_TEST"):
        try:
            post("/v1/forget", {"id": rid})
        except (urllib.error.URLError, OSError, ValueError):
            ok = False
    for p in (ID_FILE, STATE_FILE):
        try:
            p.unlink()
        except OSError:
            pass
    out({"forgotten": ok})


def cmd_sponsors():
    cached = read_json(WALL_CACHE, None)
    if endpoint() and not os.environ.get("ANGELOS_TEST"):
        try:
            req = urllib.request.Request(endpoint() + "/v1/sponsors", headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=15) as r:
                wall = json.loads(r.read().decode())
            wall = {"names": [str(n)[:40] for n in wall.get("names", [])][:500], "updated": wall.get("updated")}
            write_json(WALL_CACHE, wall)
            return out(wall)
        except (urllib.error.URLError, OSError, ValueError, AttributeError):
            pass
    wall = cached or {"names": [], "updated": None}
    wall["offline"] = True
    out(wall)


def main(argv):
    cmd = argv[1] if len(argv) > 1 else "status"
    if cmd == "preview":
        out(report(machine_id(False) or "<made on the first «yes»>"))
    elif cmd == "send":
        cmd_send("--force" in argv)
    elif cmd == "forget":
        cmd_forget()
    elif cmd == "sponsors":
        cmd_sponsors()
    elif cmd == "status":
        st = read_json(STATE_FILE, {})
        out({"consent": consent(), "endpoint": bool(endpoint()), "last": st.get("last"), "result": st.get("result", "")})
    else:
        print(__doc__, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
