#!/usr/bin/env python3
"""Pack what a bug report needs into one archive: `angelos report`.

  report.py [--out DIR] [--open] [--json]

Collects versions (angelOS, Quickshell, Qt, niri, kernel, GPU), the shell's
service state and restarts, what it costs (CPU, memory, helpers) and daemons
running twice, the log of the running shell, the last Quickshell crash
reports, the niri config check, plugins and the settings — with personal
bits taken out: the home path and user name become ~ and <user>, launcher
history, workspace names, plugin data and free texts are left out. Nothing is
sent anywhere; the archive lands in ~/ (or --out) and the path is printed with
the link for a new GitHub issue. --open shows it in the file manager and opens
the issue form; --json prints {"archive", "issue"} for the settings page.
"""
import argparse
import datetime
import getpass
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import time
from pathlib import Path

HOME = str(Path.home())
USER = getpass.getuser()
CONF = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
SHELL_DIR = CONF / "quickshell/angelos"
DEFAULT_REPO = "https://github.com/MixaDoDs/AngelOS-Dotfiles"


def run(cmd, timeout=15, env=None):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, env=env)
        return (r.stdout + (("\n" + r.stderr) if r.stderr.strip() else "")).strip()
    except (OSError, subprocess.SubprocessError) as e:
        return f"<{cmd[0]}: {e}>"


def scrub(text):
    text = text.replace(HOME, "~")
    if len(USER) > 2:
        text = re.sub(r"\b%s\b" % re.escape(USER), "<user>", text)
    # tokens that might slip into a log
    text = re.sub(r"(sk-ant-|sk-|ghp_|github_pat_)[A-Za-z0-9_-]{8,}", r"\1<redacted>", text)
    return text


def source_repo():
    info = {}
    try:
        for line in (CONF / "angelos/dotfiles-source").read_text().splitlines():
            if "=" in line:
                k, v = line.split("=", 1)
                info[k.strip()] = v.strip()
    except OSError:
        pass
    repo = info.get("repo") or next((str(p) for p in (Path.home() / "AngelOS-Dotfiles", Path.home() / "PixelStreetArt_Dotfiles_Niri") if p.exists()), str(Path.home() / "AngelOS-Dotfiles"))
    remote = info.get("remote") or DEFAULT_REPO
    return repo, remote


def versions():
    repo, remote = source_repo()
    lines = []
    if Path(repo, ".git").exists():
        lines.append("angelOS: " + run(["git", "-C", repo, "log", "-1", "--format=%h %cs %s"]))
        dirty = run(["git", "-C", repo, "status", "--porcelain"])
        lines.append("repo state: " + ("local changes" if dirty.strip() else "clean"))
    else:
        lines.append("angelOS: repository not found (" + repo + ")")
    qs = shutil.which("qs") or shutil.which("quickshell") or str(Path.home() / ".local/bin/qs")
    qv = run([qs, "--version"])
    lines.append("quickshell: " + (qv.splitlines()[0] if qv else "?"))
    for q in ("/usr/lib/qt6/bin/qtpaths6", "/usr/lib64/qt6/bin/qtpaths6"):
        if os.path.exists(q):
            lines.append("Qt: " + run([q, "--qt-version"]))
            break
    lines.append("niri: " + run(["niri", "--version"]))
    lines.append("kernel: " + run(["uname", "-r"]))
    try:
        osr = dict(l.split("=", 1) for l in Path("/etc/os-release").read_text().splitlines() if "=" in l)
        lines.append("distro: " + osr.get("PRETTY_NAME", "?").strip('"'))
    except OSError:
        pass
    gpus = [l for l in run(["lspci", "-nn"]).splitlines() if re.search(r"VGA|3D|Display", l)]
    lines.extend("gpu: " + g for g in gpus)
    renderer = (CONF / "angelos/renderer")
    lines.append("renderer: " + (renderer.read_text().strip() if renderer.exists() else "auto"))
    lines.append("language: " + os.environ.get("LANG", "?"))
    lines.append("desktop: " + os.environ.get("XDG_CURRENT_DESKTOP", "?") + " / " + os.environ.get("XDG_SESSION_TYPE", "?"))
    return "\n".join(lines), remote


def settings():
    try:
        d = json.loads((CONF / "angelos/settings.json").read_text())
    except (OSError, ValueError) as e:
        return f"<no settings: {e}>"

    def hide(section, key, how="count"):
        s = d.get(section)
        if isinstance(s, dict) and key in s:
            v = s[key]
            s[key] = f"<{len(v)} entries>" if how == "count" and hasattr(v, "__len__") else "<hidden>"

    hide("launcher", "usage")
    hide("workspaces", "names")
    hide("lock", "streamTitle", "text")
    hide("idle", "text", "text")
    hide("dotfiles", "env", "text")
    if isinstance(d.get("plugins"), dict) and isinstance(d["plugins"].get("data"), dict):
        d["plugins"]["data"] = {k: sorted(v) if isinstance(v, dict) else "<hidden>" for k, v in d["plugins"]["data"].items()}
    return scrub(json.dumps(d, indent=2, ensure_ascii=False))


def crash_reports(limit=3):
    root = CACHE / "quickshell/crashes"
    dirs = sorted((p for p in root.glob("*") if p.is_dir()), key=lambda p: p.stat().st_mtime, reverse=True)[:limit]
    out = []
    for d in dirs:
        stamp = datetime.datetime.fromtimestamp(d.stat().st_mtime).isoformat(timespec="seconds")
        entry = {"name": d.name, "time": stamp, "files": {}}
        rep = d / "report.txt"
        if rep.exists():
            entry["files"]["report.txt"] = scrub(rep.read_text(errors="replace"))
        for log in d.glob("*.log"):
            # DEBUG lines carry tray tooltips, file paths and the like: leave them out
            lines = [l for l in log.read_text(errors="replace").splitlines() if " DEBUG " not in l]
            entry["files"][log.name + ".tail"] = scrub("\n".join(lines[-1500:]))
        out.append(entry)
    return out


def load(seconds=2):
    """What the shell costs (CPU measured over a moment, memory, its helpers) and daemons running
    twice: a shell that eats a core at idle, or Voxtype started both by niri and by its service
    (the service then restarting every 5 s for good), show up here."""
    lines = []
    pid = run(["systemctl", "--user", "show", "-p", "MainPID", "--value", "angelos.service"])
    if pid.isdigit() and pid != "0":
        def ticks():   # utime + stime of the shell's process
            f = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()
            return int(f[11]) + int(f[12])
        try:
            t0, a = time.monotonic(), ticks()
            time.sleep(seconds)
            t1, b = time.monotonic(), ticks()
            lines.append(f"shell CPU over {t1 - t0:.1f} s: {100 * (b - a) / os.sysconf('SC_CLK_TCK') / (t1 - t0):.0f}% of one core")
        except (OSError, ValueError, IndexError) as e:
            lines.append(f"shell CPU: <{e}>")
        lines += ["", run(["ps", "-o", "pid,ppid,pcpu,rss,etime,args", "--sort=-pcpu", "-p", pid, "--ppid", pid])]
    else:
        lines.append("angelos.service is not running")
    procs = run(["ps", "-u", USER, "-o", "args="]).splitlines()
    lines.append("")
    for what, rx in (("Voxtype daemon", r"voxtype\s+daemon"), ("Quickshell", r"^\S*\b(qs|quickshell)(\s(?!.*\b(ipc|log|list|kill)\b)|$)"),
                     ("clipboard watcher", r"wl-paste\s+--watch.*clipboard\.py"), ("USB watcher", r"usb-watch\.py")):
        n = sum(1 for p in procs if re.search(rx, p))
        lines.append(f"{what}: {n} running" + ("  ← more than one" if n > 1 else ""))
    vox = run(["systemctl", "--user", "show", "voxtype.service", "-p", "ActiveState", "-p", "NRestarts", "-p", "UnitFileState"])
    lines.append("voxtype.service: " + " ".join(vox.split()))
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(Path.home()))
    ap.add_argument("--open", action="store_true")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    name = f"angelos-report-{stamp}"
    ver, remote = versions()
    files = {
        "versions.txt": scrub(ver),
        "service.txt": scrub(run([str(SHELL_DIR / "bin/angelos"), "status"]) + "\n\n" +
                             run(["systemctl", "--user", "status", "angelos.service", "--no-pager", "-n", "0"]) + "\n\n" +
                             run(["journalctl", "--user", "-u", "angelos.service", "-n", "300", "--no-pager", "-o", "short-iso"])),
        "shell-log.txt": scrub(run([shutil.which("qs") or "qs", "log", "-c", "angelos", "--no-color", "-t", "4000"], timeout=20)),
        "load.txt": scrub(load()),
        "niri-validate.txt": scrub(run(["niri", "validate"])),
        "settings.json": settings(),
        "plugins.txt": scrub("\n".join(sorted(p.name for p in (CONF / "angelos/plugins").glob("*") if p.is_dir())) or "(none)"),
        "README.txt": "angelOS bug report made by `angelos report`.\n"
                      "Home path and user name are replaced; launcher history, workspace names,\n"
                      "plugin data and free texts are left out. Logs can still mention window or\n"
                      "track titles — have a look before you attach it.\n",
    }
    for c in crash_reports():
        for fname, text in c["files"].items():
            files[f"crashes/{c['time']}-{c['name']}/{fname}"] = text

    out = Path(args.out).expanduser()
    out.mkdir(parents=True, exist_ok=True)
    archive = out / (name + ".tar.gz")
    with tarfile.open(archive, "w:gz") as tar:
        for fname, text in files.items():
            data = (text.rstrip("\n") + "\n").encode()
            info = tarfile.TarInfo(f"{name}/{fname}")
            info.size = len(data)
            info.mtime = int(datetime.datetime.now().timestamp())
            info.mode = 0o644
            tar.addfile(info, io.BytesIO(data))
    os.chmod(archive, 0o600)
    base = remote[:-4] if remote.endswith(".git") else remote
    if base.startswith("git@github.com:"):
        base = "https://github.com/" + base.split(":", 1)[1]
    issue = base.rstrip("/") + "/issues/new?template=bug_report.yml"
    if args.json:
        print(json.dumps({"archive": str(archive), "issue": issue, "crashes": len(crash_reports())}))
    else:
        print(f"♡ report: {archive}")
        print(f"  attach it to a new issue: {issue}")
        print("  (home path and user name are replaced; look it over before you send it)")
    if args.open:
        subprocess.Popen(["xdg-open", str(out)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.Popen(["xdg-open", issue], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


if __name__ == "__main__":
    main()
