#!/usr/bin/env python3
"""Who has a camera open, for the Halo's privacy dot (services/Sensors).

usage: cam-watch.py

Prints one JSON line each time the set changes: [{"pid": 123, "name": "chromium"}, ...]
([] = nobody), and one at the start. Costs nothing while nothing happens: inotify on the
/dev/video* nodes (an open or a close of one) and on /dev (a camera plugged in or out);
then, a moment later (a probe opens and closes at once), a look at /proc/*/fd for the
links to /dev/video* — a few tens of ms, only after an event. No root needed: only our
own processes' fds can be read, which are the ones that matter.
"""
import ctypes
import json
import os
import select
import signal
import struct
import sys
import time

IN_OPEN = 0x020
IN_CLOSE_WRITE = 0x008
IN_CLOSE_NOWRITE = 0x010
IN_CREATE = 0x100
IN_DELETE = 0x200
SETTLE = 0.3          # s: events this close together are one look


def die_with_parent():
    try:
        ctypes.CDLL(None, use_errno=True).prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG
    except (OSError, AttributeError):
        pass


def cams():
    try:
        return sorted("/dev/" + n for n in os.listdir("/dev") if n.startswith("video") and n[5:].isdigit())
    except OSError:
        return []


def holders(devs):
    out = {}
    me = os.getpid()
    for pid in os.listdir("/proc"):
        if not pid.isdigit() or int(pid) == me:
            continue
        fd_dir = "/proc/" + pid + "/fd"
        try:
            fds = os.listdir(fd_dir)
        except OSError:
            continue
        for fd in fds:
            try:
                if os.readlink(fd_dir + "/" + fd) in devs:
                    break
            except OSError:
                continue
        else:
            continue
        try:
            with open("/proc/" + pid + "/comm") as f:
                name = f.read().strip()
        except OSError:
            name = "?"
        out[int(pid)] = name
    return [{"pid": p, "name": n} for p, n in sorted(out.items())]


def main():
    die_with_parent()
    libc = ctypes.CDLL(None, use_errno=True)
    fd = libc.inotify_init1(os.O_CLOEXEC)
    if fd < 0:
        print("error inotify", flush=True)
        return 1
    watched = {}

    def rewatch():
        for wd in list(watched):
            libc.inotify_rm_watch(fd, wd)
        watched.clear()
        for dev in cams():
            wd = libc.inotify_add_watch(fd, dev.encode(), IN_OPEN | IN_CLOSE_WRITE | IN_CLOSE_NOWRITE)
            if wd >= 0:
                watched[wd] = dev

    libc.inotify_add_watch(fd, b"/dev", IN_CREATE | IN_DELETE)
    rewatch()
    last = None
    due = time.monotonic()
    while True:
        timeout = max(0.0, due - time.monotonic()) if due is not None else None
        r, _, _ = select.select([fd], [], [], timeout)
        if r:
            buf = os.read(fd, 65536)
            i, devs_changed, seen = 0, False, False
            while i + 16 <= len(buf):
                wd, mask, _cookie, size = struct.unpack_from("iIII", buf, i)
                name = buf[i + 16:i + 16 + size].rstrip(b"\0").decode(errors="replace")
                i += 16 + size
                if wd in watched:
                    seen = True
                elif mask & (IN_CREATE | IN_DELETE) and name.startswith("video"):
                    devs_changed = seen = True
            if devs_changed:
                rewatch()
            # /dev's other comings and goings (a tty, a disk) are none of ours
            if seen:
                due = time.monotonic() + SETTLE
            continue
        due = None
        now = holders(set(watched.values()))
        if now != last:
            last = now
            print(json.dumps(now), flush=True)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(0)
