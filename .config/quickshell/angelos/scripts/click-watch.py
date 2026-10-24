#!/usr/bin/env python3
"""Report mouse clicks and key presses for the input sounds (Settings → System sounds).

  click-watch.py [--mouse] [--keys]     (no flag = --mouse)
  click-watch.py --shift-right          only: shiftright — the right button went down with the left
                                        Shift held, and both are up again (services/Convert's ring:
                                        its Ctrl+C must not meet a held Shift)

  click left|right|middle      a mouse / touchpad button went down
  release left|right|middle    …and up (the "release" tick)
  key                          a key went down on a keyboard (not its auto-repeat)
  noperm                       no device could be opened (the `input` group)

The shell only sees clicks on its own windows, so this reads evdev like meta-tap.py,
anywhere on the desktop. Runs only while one of these sounds is on.

Privacy: nothing but "a button / some key went down" (or that one combination) is printed — no positions, no
key codes. Devices are opened read-only and never grabbed.
"""
import glob
import os
import select
import struct
import sys
import time

EV_KEY = 1
BTN_LEFT, BTN_RIGHT, BTN_MIDDLE = 272, 273, 274
KEY_A, KEY_SPACE, KEY_LEFTSHIFT = 30, 57, 42
BUTTONS = {BTN_LEFT: "left", BTN_RIGHT: "right", BTN_MIDDLE: "middle"}
EVENT = struct.Struct("llHHi")


def key_bits(event_dir):
    try:
        words = open(os.path.join(event_dir, "device/capabilities/key")).read().split()
    except OSError:
        return 0
    bits = 0
    for word in words:
        bits = (bits << 64) | int(word, 16)
    return bits


def wanted(event_dir, mouse, keys):
    bits = key_bits(event_dir)
    if mouse and bits >> BTN_LEFT & 1:
        return True
    # a keyboard: has letters and a space bar (not a power button or a headset)
    return keys and bool(bits >> KEY_A & 1) and bool(bits >> KEY_SPACE & 1)


def main():
    args = set(sys.argv[1:])
    combo = "--shift-right" in args
    keys = "--keys" in args or combo
    mouse = "--mouse" in args or not keys or combo
    shifted = set()         # the keyboards with the left Shift down now
    armed = False           # the right button went down with Shift
    pending = False         # …and is up: said once Shift is up too
    fds = {}
    said_noperm = False
    last_scan = 0.0
    while True:
        now = time.monotonic()
        if now - last_scan > 5:
            last_scan = now
            denied = 0
            seen = set()
            for event_dir in glob.glob("/sys/class/input/event*"):
                path = "/dev/input/" + os.path.basename(event_dir)
                seen.add(path)
                if path in fds or not wanted(event_dir, mouse, keys):
                    continue
                try:
                    fds[path] = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
                except PermissionError:
                    denied += 1
                except OSError:
                    pass
            for path in [p for p in fds if p not in seen]:
                os.close(fds.pop(path))
            if denied and not fds and not said_noperm:
                said_noperm = True
                print("noperm", flush=True)
        if not fds:
            time.sleep(1)
            continue
        ready, _, _ = select.select(list(fds.values()), [], [], 1.0)
        for fd in ready:
            try:
                data = os.read(fd, EVENT.size * 64)
            except OSError:
                for path, f in list(fds.items()):
                    if f == fd:
                        os.close(fds.pop(path))
                continue
            for off in range(0, len(data) - EVENT.size + 1, EVENT.size):
                _, _, kind, code, value = EVENT.unpack_from(data, off)
                if kind != EV_KEY:
                    continue
                if combo:
                    if code == KEY_LEFTSHIFT:
                        (shifted.add if value else shifted.discard)(fd)
                    elif code == BTN_RIGHT and value == 1:
                        armed = bool(shifted)
                    elif code == BTN_RIGHT and value == 0 and armed:
                        armed = False
                        pending = True
                    if pending and not shifted:
                        pending = False
                        print("shiftright", flush=True)
                    continue
                if code in BUTTONS:
                    if mouse and value in (0, 1):
                        print(("click " if value == 1 else "release ") + BUTTONS[code], flush=True)
                elif keys and code < BTN_LEFT and value == 1:
                    print("key", flush=True)


if __name__ == "__main__":
    try:  # go away together with the shell, even on its SIGKILL (stand restarts left copies behind)
        import ctypes
        import signal
        ctypes.CDLL(None).prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG
    except (OSError, AttributeError):
        pass
    try:
        main()
    except KeyboardInterrupt:
        pass
