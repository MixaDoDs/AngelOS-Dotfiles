#!/usr/bin/env python3
"""Shake the mouse to find the pointer (Settings → Cursor), like macOS.

Reads pointer motion from evdev like meta-tap.py (needs the `input` group):
relative motion of mice, absolute motion of touchpads while touched. A shake is
several quick direction reversals, each a real stroke of the hand, along X or Y.
Not while a button is held: dragging a slider or a window back and forth is no lost
pointer (the overlay would take the pointer mid-drag and the drag would never end —
Settings → Keyboard's repeat sliders did not save).

  shake-watch.py [--sensitivity low|normal|high] [--dpi 1000] [--drag]

Prints "ready" when devices are open, "noperm" / "noevdev" when none can be,
and "shake" (at most every 90 ms) while the pointer is being shaken.
--drag turns it round, for the cobwebs (services/Cobweb): only a shake with a button held
counts — a window dragged back and forth — and it prints "dragshake" (at most every 0.5 s).
Privacy: nothing but "shake" / "dragshake" is printed — no positions, no keys.
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

EV_KEY, EV_REL, EV_ABS = 1, 2, 3
REL_X, REL_Y = 0, 1
ABS_X, ABS_Y = 0, 1
BTN_TOUCH = 330
BUTTONS = range(0x110, 0x118)       # BTN_LEFT … BTN_TASK
EVENT = struct.Struct("llHHi")
ABSINFO = struct.Struct("6i")
# stroke length (mm of hand motion), reversals needed, max gap between reversals (s)
LEVELS = {"low": (24, 5, 0.32), "normal": (14, 4, 0.34), "high": (8, 3, 0.38)}
WINDOW = 1.1


def bits(event_dir, kind):
    try:
        words = open(os.path.join(event_dir, "device/capabilities", kind)).read().split()
    except OSError:
        return 0
    value = 0
    for word in words:
        value = (value << 64) | int(word, 16)
    return value


def eviocgabs(axis):
    return (2 << 30) | (ABSINFO.size << 16) | (ord("E") << 8) | (0x40 + axis)


class Axis:
    """Direction reversals of one axis, counted only after a real stroke."""

    def __init__(self, stroke, need, gap):
        self.stroke, self.need, self.gap = stroke, need, gap
        self.dir, self.run, self.flips = 0, 0.0, []

    def move(self, mm, now):
        if not mm:
            return False
        d = 1 if mm > 0 else -1
        if d == self.dir:
            self.run += abs(mm)
            return False
        counted = self.dir != 0 and self.run >= self.stroke
        self.dir, self.run = d, abs(mm)
        if not counted:
            return False
        # a slow wobble is not a shake: reversals follow each other quickly
        if self.flips and now - self.flips[-1] > self.gap:
            self.flips = []
        self.flips.append(now)
        self.flips = [t for t in self.flips if now - t <= WINDOW]
        return len(self.flips) >= self.need


class Device:
    def __init__(self, path, fd, touchpad, dpi, level):
        self.path, self.fd, self.touchpad = path, fd, touchpad
        self.x, self.y = Axis(*level), Axis(*level)
        self.scale_x = self.scale_y = 25.4 / dpi          # counts → mm for a mouse
        self.last = {ABS_X: None, ABS_Y: None}
        self.touching = False
        self.held = set()               # the mouse buttons down now
        if touchpad:
            for axis in (ABS_X, ABS_Y):
                try:
                    info = ABSINFO.unpack(fcntl.ioctl(fd, eviocgabs(axis), b"\0" * ABSINFO.size))
                    res = info[5] or max(1, (info[2] - info[1]) // 100)   # units per mm
                except OSError:
                    res = 30
                if axis == ABS_X:
                    self.scale_x = 1.0 / res
                else:
                    self.scale_y = 1.0 / res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sensitivity", default="normal", choices=list(LEVELS))
    ap.add_argument("--dpi", type=int, default=1000)
    ap.add_argument("--drag", action="store_true")
    a = ap.parse_args()
    word, gap = ("dragshake", 0.5) if a.drag else ("shake", 0.09)
    level = LEVELS[a.sensitivity]
    devices = {}
    said = ""
    last_scan = 0.0
    last_shake = 0.0
    while True:
        now = time.monotonic()
        if now - last_scan > 5:
            last_scan = now
            denied = found = 0
            seen = set()
            for event_dir in glob.glob("/sys/class/input/event*"):
                path = "/dev/input/" + os.path.basename(event_dir)
                rel, absb, key = bits(event_dir, "rel"), bits(event_dir, "abs"), bits(event_dir, "key")
                mouse = bool(rel >> REL_X & 1 and rel >> REL_Y & 1)
                touchpad = bool(absb >> ABS_X & 1 and absb >> ABS_Y & 1 and key >> BTN_TOUCH & 1) and not mouse
                if not (mouse or touchpad):
                    continue
                found += 1
                seen.add(path)
                if path in devices:
                    continue
                try:
                    fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
                    devices[path] = Device(path, fd, touchpad, a.dpi, level)
                except PermissionError:
                    denied += 1
                except OSError:
                    pass
            for path in [p for p in devices if p not in seen]:
                os.close(devices.pop(path).fd)
            state = "ready" if devices else "noperm" if denied else "noevdev" if not found else ""
            if state and state != said:
                said = state
                print(state, flush=True)
        if not devices:
            time.sleep(1)
            continue
        by_fd = {d.fd: d for d in devices.values()}
        ready, _, _ = select.select(list(by_fd), [], [], 1.0)
        for fd in ready:
            dev = by_fd[fd]
            try:
                data = os.read(fd, EVENT.size * 64)
            except OSError:
                os.close(devices.pop(dev.path).fd)
                continue
            t = time.monotonic()
            hit = False
            for off in range(0, len(data) - EVENT.size + 1, EVENT.size):
                _, _, kind, code, value = EVENT.unpack_from(data, off)
                if kind == EV_KEY and code in BUTTONS:
                    (dev.held.add if value else dev.held.discard)(code)
                    # a drag starts or ends: strokes before it don't count after it
                    dev.x.dir = dev.y.dir = 0
                    dev.x.flips, dev.y.flips = [], []
                    continue
                # a drag: the motion is not a shake (touches still tracked); with --drag only a
                # drag is
                if kind in (EV_REL, EV_ABS) and any(d.held for d in devices.values()) != a.drag:
                    if dev.touchpad:
                        dev.last = {ABS_X: None, ABS_Y: None}
                    continue
                if kind == EV_REL and not dev.touchpad:
                    if code == REL_X:
                        hit |= dev.x.move(value * dev.scale_x, t)
                    elif code == REL_Y:
                        hit |= dev.y.move(value * dev.scale_y, t)
                elif dev.touchpad and kind == EV_KEY and code == BTN_TOUCH:
                    dev.touching = bool(value)
                    dev.last = {ABS_X: None, ABS_Y: None}
                elif dev.touchpad and kind == EV_ABS and code in (ABS_X, ABS_Y) and dev.touching:
                    prev = dev.last[code]
                    dev.last[code] = value
                    if prev is not None:
                        axis, scale = (dev.x, dev.scale_x) if code == ABS_X else (dev.y, dev.scale_y)
                        hit |= axis.move((value - prev) * scale, t)
            if hit and t - last_shake >= gap:
                last_shake = t
                print(word, flush=True)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
