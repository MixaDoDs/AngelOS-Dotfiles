#!/usr/bin/env python3
"""USB devices coming and going, for the connect / disconnect sounds (services/Sounds).

usage: usb-watch.py

Prints one line per plug event: `add <name>` / `remove <name>` (name: the product,
else vendor:product). Reads udev's events (udevadm monitor, no root needed), only whole
devices (DEVTYPE=usb_device), not their interfaces. A burst — a hub with things in it,
a dock — comes out as one line (the first device's name and how many: `add 3 Hub`).
After a suspend the devices that re-enumerate are not "plugged in": events in the
first 10 s after waking up are dropped (the boot-time clock runs ahead of the
monotonic one by the time spent asleep).
"""
import ctypes
import os
import select
import signal
import subprocess
import sys
import time

BURST = 0.45          # s: events this close together are one
AFTER_SLEEP = 10.0    # s: quiet after waking up


def asleep_total():
    return time.clock_gettime(time.CLOCK_BOOTTIME) - time.monotonic()


def name_of(props):
    for key in ("ID_MODEL_FROM_DATABASE", "ID_MODEL", "PRODUCT"):
        v = props.get(key, "").replace("_", " ").strip()
        if v:
            vendor = props.get("ID_VENDOR_FROM_DATABASE", "").strip()
            return (vendor + " " + v).strip() if key != "PRODUCT" and vendor and vendor.lower() not in v.lower() else v
    return "?"


def die_with_parent():
    # udevadm goes when we do, even on a SIGKILL (a shell restart used to leave one behind)
    try:
        ctypes.CDLL(None, use_errno=True).prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG
    except (OSError, AttributeError):
        pass


def main():
    try:
        p = subprocess.Popen(["udevadm", "monitor", "--udev", "--subsystem-match=usb/usb_device", "--property"],
                             stdout=subprocess.PIPE, bufsize=0, preexec_fn=die_with_parent)
    except OSError as e:
        print("error", e, flush=True)
        return 1
    fd = p.stdout.fileno()
    slept = asleep_total()
    woke = -AFTER_SLEEP
    props = {}
    pending = None          # [action, first name, count, last at]
    buf = b""

    def flush():
        nonlocal pending
        if pending:
            action, name, count, _ = pending
            print(action, (str(count) + " " if count > 1 else "") + name, flush=True)
            pending = None

    while True:
        # raw reads: select() can't see lines a buffered reader already holds
        timeout = max(0.0, pending[3] + BURST - time.monotonic()) if pending else None
        r, _, _ = select.select([fd], [], [], timeout)
        now = time.monotonic()
        s = asleep_total()
        if s - slept > 2.0:          # the machine was asleep
            woke = now
            pending = None
        slept = s
        if not r:
            flush()
            continue
        chunk = os.read(fd, 65536)
        if not chunk:
            flush()
            return 0
        buf += chunk
        *lines, buf = buf.split(b"\n")
        for raw in lines:
            line = raw.decode("utf-8", "replace").strip()
            if line:
                if "=" in line:
                    k, _, v = line.partition("=")
                    props[k] = v
                continue
            # a blank line ends one event
            action, devtype, name = props.get("ACTION"), props.get("DEVTYPE"), name_of(props)
            props = {}
            if devtype != "usb_device" or action not in ("add", "remove") or now - woke <= AFTER_SLEEP:
                continue
            if pending and pending[0] == action and now - pending[3] < BURST:
                pending[2] += 1
                pending[3] = now
            else:
                flush()
                pending = [action, name, 1, now]


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        pass
