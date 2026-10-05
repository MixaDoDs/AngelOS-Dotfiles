#!/usr/bin/env python3
"""Tell the Alt+Tab switcher when Alt is let go (with --mod meta: the ⌘Tab one, when the
Windows key — ⌘ of the Golden Gate skin's Mac keys — is let go).

niri runs `angelos alttab next` on every Tab while Alt is held, but it has no
bind for a key release — so this reads the keyboards (evdev, the `input`
group, like meta-tap.py) and prints, then exits:

  down      Alt is held right now (printed first, the switcher may show)
  up        Alt is not held (already let go, or released now) — the last line
  noperm    no keyboard could be opened

Fast on purpose (a quick Alt+Tab tap lasts ~100 ms): no python-evdev, only the
keyboards that have Alt (from /sys) are opened, the key state is one ioctl.
It runs only while the switcher is open (at most --timeout seconds).
Privacy: no key codes are stored, logged or printed; only "is an Alt key down".
Devices are opened read-only and never grabbed.
"""
import argparse
import fcntl
import glob
import os
import select
import struct
import sys
import time

KEY_TAB, KEY_LEFTALT, KEY_RIGHTALT = 15, 56, 100
KEY_LEFTMETA, KEY_RIGHTMETA = 125, 126
MODS = {"alt": (KEY_LEFTALT, KEY_RIGHTALT), "meta": (KEY_LEFTMETA, KEY_RIGHTMETA)}
ALT = MODS["alt"]
EV_KEY = 1
KEY_BYTES = 96                                  # KEY_MAX 0x2ff → 768 bits
EVIOCGKEY = (2 << 30) | (KEY_BYTES << 16) | (ord("E") << 8) | 0x18
EVENT = struct.Struct("llHHi")                  # struct input_event


def has_keys(event_dir, codes):
    try:
        words = open(os.path.join(event_dir, "device/capabilities/key")).read().split()
    except OSError:
        return False
    bits = 0
    for word in words:
        bits = (bits << 64) | int(word, 16)
    return all(bits >> c & 1 for c in codes)


def alt_down(fd):
    buf = bytearray(KEY_BYTES)
    try:
        fcntl.ioctl(fd, EVIOCGKEY, buf)
    except OSError:
        return False
    return any(buf[c // 8] >> (c % 8) & 1 for c in ALT)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeout", type=float, default=30.0)
    parser.add_argument("--mod", choices=sorted(MODS), default="alt")
    args = parser.parse_args()
    global ALT
    ALT = MODS[args.mod]
    fds, denied = [], 0
    for event_dir in glob.glob("/sys/class/input/event*"):
        # a keyboard: Tab and an Alt (⌘) key (skips mice, audio jacks, power buttons…)
        if not (has_keys(event_dir, (KEY_TAB, ALT[0])) or has_keys(event_dir, (KEY_TAB, ALT[1]))):
            continue
        try:
            fds.append(os.open("/dev/input/" + os.path.basename(event_dir), os.O_RDONLY | os.O_NONBLOCK))
        except PermissionError:
            denied += 1
        except OSError:
            pass
    if not fds:
        print("noperm" if denied else "up", flush=True)
        return

    def held():
        return any(alt_down(fd) for fd in fds)

    if not held():
        print("up", flush=True)
        return
    print("down", flush=True)
    end = time.monotonic() + max(1.0, args.timeout)
    while time.monotonic() < end:
        ready, _, _ = select.select(fds, [], [], 0.5)
        released = False
        for fd in ready:
            try:
                data = os.read(fd, EVENT.size * 64)
            except OSError:
                continue
            for off in range(0, len(data) - EVENT.size + 1, EVENT.size):
                _, _, kind, code, value = EVENT.unpack_from(data, off)
                if kind == EV_KEY and code in ALT and value == 0:
                    released = True
        # also catches a keyboard unplugged while Alt was down
        if (released or not ready) and not held():
            break
    print("up", flush=True)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
