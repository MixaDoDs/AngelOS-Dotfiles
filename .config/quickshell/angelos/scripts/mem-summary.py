#!/usr/bin/env python3
"""What angelOS holds in memory now (Settings → About → Memory): the shell itself and its helper
processes — everything in the shell's cgroup (angelos.service), counted by PSS (shared pages split
between the processes that share them, so the numbers add up). Started by the shell: the parent
is the shell.

  mem-summary.py   -> {"shellMB": n, "helpersMB": n, "helpers": [{"name", "mb", "count"}…]}
"""
import json
import os
import sys


def pss_kb(pid):
    try:
        with open("/proc/%d/smaps_rollup" % pid) as f:
            for line in f:
                if line.startswith("Pss:"):
                    return int(line.split()[1])
    except OSError:
        pass
    return 0


def name_of(pid):
    try:
        args = open("/proc/%d/cmdline" % pid, "rb").read().split(b"\0")
        comm = open("/proc/%d/comm" % pid).read().strip()
    except OSError:
        return None
    args = [a.decode(errors="replace") for a in args if a]
    # a script: its file's name, not the interpreter's
    if args and os.path.basename(args[0]).startswith(("python", "sh", "bash")):
        for a in args[1:]:
            if not a.startswith("-"):
                return os.path.basename(a)
    return comm


def main():
    me, shell = os.getpid(), os.getppid()
    try:
        cg = open("/proc/self/cgroup").read().strip().split("::", 1)[1]
        pids = [int(p) for p in open("/sys/fs/cgroup" + cg + "/cgroup.procs").read().split()]
    except (OSError, IndexError, ValueError):
        pids = [shell]
    helpers = {}
    shell_kb = 0
    for pid in pids:
        if pid == me:
            continue
        kb = pss_kb(pid)
        if pid == shell:
            shell_kb = kb
            continue
        name = name_of(pid)
        if not name or not kb:
            continue
        h = helpers.setdefault(name, {"name": name, "mb": 0.0, "count": 0})
        h["mb"] += kb / 1024
        h["count"] += 1
    rows = sorted(helpers.values(), key=lambda h: -h["mb"])
    for h in rows:
        h["mb"] = round(h["mb"], 1)
    json.dump({"shellMB": round(shell_kb / 1024), "helpersMB": round(sum(h["mb"] for h in rows)),
               "helpers": rows}, sys.stdout)


if __name__ == "__main__":
    main()
