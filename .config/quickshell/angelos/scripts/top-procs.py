#!/usr/bin/env python3
"""The busiest programs for the desktop system monitor (its L layout, SysmonWidget).

usage: top-procs.py [INTERVAL [COUNT]]

Every INTERVAL seconds (2) one JSON line: [{"name": "firefox", "cpu": 22.4}, ...] — the COUNT (3)
busiest by CPU time since the last line, as a percent of the whole CPU (all cores together, like
the widget's CPU meter), the processes of one program added up under its name. Reads /proc only;
quits when the shell that started it is gone or stops reading.
"""
import json
import os
import sys
import time


def sample():
    """pid -> (name, utime + stime in clock ticks)"""
    out = {}
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open(f"/proc/{pid}/stat", "rb") as f:
                data = f.read().decode(errors="replace")
        except OSError:
            continue
        left, right = data.find("("), data.rfind(")")
        rest = data[right + 2:].split()
        if left < 0 or len(rest) < 13:
            continue
        # after the name: state is field 3, utime 14, stime 15
        out[pid] = (data[left + 1:right], int(rest[11]) + int(rest[12]))
    return out


def main():
    interval = float(sys.argv[1]) if len(sys.argv) > 1 else 2.0
    count = int(sys.argv[2]) if len(sys.argv) > 2 else 3
    ticks = os.sysconf("SC_CLK_TCK") * (os.cpu_count() or 1)
    parent = os.getppid()
    last, at = sample(), time.monotonic()
    while True:
        time.sleep(interval)
        if os.getppid() != parent:
            return
        now, t = sample(), time.monotonic()
        spent = {}
        for pid, (name, cpu) in now.items():
            before = last.get(pid)
            if before and before[0] == name and cpu >= before[1]:
                spent[name] = spent.get(name, 0) + cpu - before[1]
        span = max(1e-3, t - at) * ticks
        top = sorted(spent.items(), key=lambda kv: -kv[1])[:count]
        try:
            print(json.dumps([{"name": n, "cpu": round(100 * v / span, 1)} for n, v in top]), flush=True)
        except BrokenPipeError:
            return
        last, at = now, t


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
