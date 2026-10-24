#!/usr/bin/env python3
"""Long waits the shell knows by name (services/Waiting, the bar's «Забег»): a build, an
install, a system update running somewhere — any terminal, an IDE, a script.

Every 3 s it reads /proc (no ps, nothing spawned) and prints one JSON line when the list of
waits changes: [{"name": "cargo build", "pid": 123, "start": <unix s>}, …], oldest first.
Only commands with the words that make them long count: `npm run dev` runs for hours and
is not a wait, `npm run build` is. A wait shows once it has run for MIN_AGE seconds; a
make under a make (or cargo's rustc) is the same wait, only the topmost one is listed.
"""
import json
import os
import sys
import time

MIN_AGE = 8
TICK = 3

# the command (argv[0]'s name) and the words after it that make it a wait; None: any words
WAITS = {
    "cargo": {"build", "b", "test", "t", "install", "check", "c", "clippy", "bench"},
    "make": None,
    "ninja": None,
    "cmake": {"--build"},
    "makepkg": None,
    "pacman": {"-S", "-Syu", "-Syyu", "-Su", "-Sy", "-U"},
    "paru": None,
    "yay": None,
    "npm": {"ci", "install", "i", "build"},
    "pnpm": {"ci", "install", "i", "build"},
    "docker": {"build"},
    "flatpak": {"install", "update"},
}
# the AUR helpers' quick answers (a search, a look) are no wait
QUICK = ("-Q", "-Ss", "-Si", "-G", "-P")
RUNNERS = {"node", "python", "python3", "sh", "bash", "sudo", "doas", "env", "nice", "ionice", "time"}

try:
    HZ = os.sysconf("SC_CLK_TCK")
except (ValueError, OSError):
    HZ = 100


def boot_time():
    with open("/proc/stat") as f:
        for line in f:
            if line.startswith("btime "):
                return int(line.split()[1])
    return 0


BOOT = boot_time()


def name_of(argv):
    """`cargo build`, `pacman -Syu`, `make` — or None when it is no wait"""
    while argv and os.path.basename(argv[0]) in RUNNERS:
        argv = argv[1:]
        # sudo -E pacman …: the runners' own flags
        while argv and argv[0].startswith("-"):
            argv = argv[1:]
    if not argv:
        return None
    cmd = os.path.basename(argv[0])
    # npm as node's script: /usr/lib/node_modules/npm/bin/npm-cli.js
    cmd = cmd.rsplit(".", 1)[0] if cmd.endswith((".js", ".cjs", ".mjs")) else cmd
    cmd = cmd[:-4] if cmd.endswith("-cli") else cmd
    if cmd not in WAITS:
        return None
    words = WAITS[cmd]
    rest = argv[1:]
    if words is None:
        if cmd in ("paru", "yay") and rest and rest[0].startswith(QUICK):
            return None
        return cmd
    run = ""
    if cmd in ("npm", "pnpm") and rest[:1] == ["run"]:
        rest, run = rest[1:], " run"
    if cmd == "docker" and rest[:1] == ["buildx"]:
        rest = rest[1:]
    if rest and rest[0] in words:
        return cmd + run + " " + rest[0]
    return None


def scan():
    procs = {}
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open(f"/proc/{pid}/cmdline", "rb") as f:
                raw = f.read()
            if not raw:
                continue
            argv = raw.rstrip(b"\0").decode(errors="replace").split("\0")
            name = name_of(argv)
            if not name:
                continue
            with open(f"/proc/{pid}/stat") as f:
                st = f.read()
            # the fields after the command's name in parentheses: state is 3rd, ppid 4th, starttime 22nd
            f2 = st[st.rfind(")") + 2:].split()
            procs[int(pid)] = {"name": name, "pid": int(pid), "ppid": int(f2[1]), "start": BOOT + int(f2[19]) / HZ}
        except (OSError, IndexError, ValueError):
            continue
    now = time.time()
    out = []
    for p in procs.values():
        # a make under a make, rustc under cargo: the topmost one is the wait
        up, top = p["ppid"], True
        for _ in range(32):
            if up in procs:
                top = False
                break
            try:
                with open(f"/proc/{up}/stat") as f:
                    st = f.read()
                up = int(st[st.rfind(")") + 2:].split()[1])
            except (OSError, IndexError, ValueError):
                break
            if up <= 1:
                break
        if top and now - p["start"] >= MIN_AGE:
            out.append({"name": p["name"], "pid": p["pid"], "start": round(p["start"])})
    out.sort(key=lambda p: p["start"])
    return out


def main():
    last = None
    while True:
        cur = scan()
        if cur != last:
            print(json.dumps(cur), flush=True)
            last = cur
        time.sleep(TICK)


if __name__ == "__main__":
    try:  # go away together with the shell, even on its SIGKILL (stand restarts left copies behind)
        import ctypes
        import signal
        ctypes.CDLL(None).prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG
    except (OSError, AttributeError):
        pass
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        sys.exit(0)
