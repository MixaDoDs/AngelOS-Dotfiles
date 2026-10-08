#!/usr/bin/env python3
"""angelOS's own touchpad gestures (services/Gestures; Settings → Devices → Touchpad).

niri keeps its own: three fingers swipe the columns and the workspaces, four up/down open and
close the overview, two pinch for the apps. This adds what niri leaves alone, read from the
touchpad's multitouch events (needs the `input` group, like meta-tap.py and shake-watch.py):

  pinchIn pinchOut        four fingers (three and the thumb) drawn together / spread apart
  swipe4Left swipe4Right  four fingers across (niri only moves the overview up and down)
  swipe4Down              four fingers down (niri: only closes an open overview)
  edgeLeft edgeRight      one finger from the touchpad's very edge inwards, as on Windows
  tap3 tap4               three / four fingers tapped (three is also libinput's middle click)
  hold3                   three fingers held still for a moment

  gesture-watch.py [--sensitivity low|normal|high]

Prints "ready" when a touchpad is open, "noperm" / "notouchpad" when none can be, then one
"gesture <name>" per gesture. Privacy: nothing but the gesture's name is printed — no
positions, no keys. Devices are opened read-only and never grabbed.
"""
import argparse
import fcntl
import glob
import math
import os
import select
import struct
import sys
import time

EV_SYN, EV_KEY, EV_ABS = 0, 1, 3
SYN_REPORT = 0
ABS_MT_SLOT, ABS_MT_POSITION_X, ABS_MT_POSITION_Y, ABS_MT_TRACKING_ID = 0x2f, 0x35, 0x36, 0x39
BTN_TOOL_FINGER, BTN_TOOL_QUINTTAP, BTN_TOUCH = 0x145, 0x148, 0x14a
BTN_TOOL_DOUBLETAP, BTN_TOOL_TRIPLETAP, BTN_TOOL_QUADTAP = 0x14d, 0x14e, 0x14f
TOOLS = {BTN_TOOL_FINGER: 1, BTN_TOOL_DOUBLETAP: 2, BTN_TOOL_TRIPLETAP: 3, BTN_TOOL_QUADTAP: 4, BTN_TOOL_QUINTTAP: 5}
PROP_DIRECT = 1
EVENT = struct.Struct("llHHi")
ABSINFO = struct.Struct("6i")

# swipe distance (mm), pinch ratio, edge travel (fraction of the width), tap movement (mm)
LEVELS = {"low": (32, 0.45, 0.22, 2.5), "normal": (22, 0.6, 0.15, 3.5), "high": (14, 0.72, 0.10, 4.5)}
TAP_MS, HOLD_MS, EDGE_ZONE, EDGE_MS = 260, 650, 0.04, 700


class Recognizer:
    """One touchpad's frames → gesture names. `feed` takes the evdev events one by one and
    returns the gestures a SYN_REPORT completed (a list, mostly empty). Positions in device
    units; `xres`/`yres` units per mm, `width`/`height` the axis ranges."""

    def __init__(self, width, height, xres, yres, level="normal"):
        self.width, self.height = max(1, width), max(1, height)
        self.xres, self.yres = max(1e-3, xres), max(1e-3, yres)
        self.swipe_mm, self.pinch, self.edge_frac, self.tap_mm = LEVELS.get(level, LEVELS["normal"])
        self.slots = {}               # slot -> [x, y] while touched
        self.slot = 0
        self.tool = 0                 # fingers by BTN_TOOL_* (pads track fewer slots than fingers)
        self.session = None

    # ---- the raw stream ----
    def feed(self, etype, code, value, t):
        if etype == EV_ABS:
            if code == ABS_MT_SLOT:
                self.slot = value
            elif code == ABS_MT_TRACKING_ID:
                if value < 0:
                    self.slots.pop(self.slot, None)
                else:
                    self.slots[self.slot] = [None, None]
            elif code in (ABS_MT_POSITION_X, ABS_MT_POSITION_Y):
                s = self.slots.setdefault(self.slot, [None, None])
                s[0 if code == ABS_MT_POSITION_X else 1] = value
        elif etype == EV_KEY and code in TOOLS:
            if value:
                self.tool = TOOLS[code]
            elif self.tool == TOOLS[code]:
                self.tool = 0
        elif etype == EV_SYN and code == SYN_REPORT:
            return self.frame(t)
        return []

    # ---- one frame ----
    def points(self):
        return [(x, y) for x, y in self.slots.values() if x is not None and y is not None]

    def count(self):
        return max(len(self.slots), self.tool)

    def mm(self, dx, dy):
        return dx / self.xres, dy / self.yres

    @staticmethod
    def centroid(pts):
        return (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))

    def spread(self, pts):
        cx, cy = self.centroid(pts)
        return sum(math.hypot(*self.mm(p[0] - cx, p[1] - cy)) for p in pts) / len(pts)

    def frame(self, t):
        n, pts = self.count(), self.points()
        s = self.session
        if n == 0:
            out = self.end(t) if s else []
            self.session = None
            return out
        if s is None:
            s = self.session = {"t0": t, "max": n, "done": False, "start": None, "spread0": None,
                                "moved": 0.0, "edge": None, "n": n, "last": None}
            if n == 1 and pts:
                x = pts[0][0]
                if x <= self.width * EDGE_ZONE:
                    s["edge"] = ("edgeLeft", x)
                elif x >= self.width * (1 - EDGE_ZONE):
                    s["edge"] = ("edgeRight", x)
        if n > s["max"]:
            s["max"] = n
        # the fingers land one after another: each new count measures from where it began
        if n != s["n"]:
            s["n"] = n
            s["start"] = s["spread0"] = None
        if not pts:
            return []
        c = self.centroid(pts)
        if s["start"] is None:
            s["start"], s["spread0"], s["last"] = c, self.spread(pts) if len(pts) >= 2 else None, c
            return []
        dx, dy = self.mm(c[0] - s["start"][0], c[1] - s["start"][1])
        s["moved"] = max(s["moved"], math.hypot(dx, dy))
        s["last"] = c
        if s["done"]:
            return []
        out = []
        if n >= 4:
            if s["spread0"] and len(pts) >= 2:
                ratio = self.spread(pts) / max(0.1, s["spread0"])
                if ratio <= self.pinch:
                    out = ["pinchIn"]
                elif ratio >= 1 / self.pinch:
                    out = ["pinchOut"]
            if not out and math.hypot(dx, dy) >= self.swipe_mm:
                if abs(dx) >= 1.6 * abs(dy):
                    out = ["swipe4Right" if dx > 0 else "swipe4Left"]
                elif abs(dy) >= 1.6 * abs(dx) and dy > 0:
                    out = ["swipe4Down"]
                else:
                    s["done"] = True        # diagonal, or up (niri's overview): nothing of ours
        elif n == 1 and s["edge"] and s["max"] == 1:
            name, x0 = s["edge"]
            travel = (c[0] - x0) / self.width * (1 if name == "edgeLeft" else -1)
            if (t - s["t0"]) * 1000 > EDGE_MS:
                s["edge"] = None
            elif travel >= self.edge_frac and abs(dy) < abs(travel * self.width / self.xres):
                out = [name]
        if out:
            s["done"] = True
        return out

    def end(self, t):
        s = self.session
        if s["done"]:
            return []
        ms = (t - s["t0"]) * 1000
        if s["max"] in (3, 4) and ms <= TAP_MS and s["moved"] <= self.tap_mm:
            return ["tap%d" % s["max"]]
        if s["max"] == 3 and ms >= HOLD_MS and s["moved"] <= self.tap_mm:
            return ["hold3"]
        return []


def caps(event_dir, kind):
    try:
        words = open(os.path.join(event_dir, "device", kind)).read().split()
    except OSError:
        return 0
    value = 0
    for word in words:
        value = (value << 64) | int(word, 16)
    return value


def eviocgabs(axis):
    return (2 << 30) | (ABSINFO.size << 16) | (ord("E") << 8) | (0x40 + axis)


def touchpads():
    """event nodes of touchpads: multitouch, a finger tool, not a touchscreen"""
    out = []
    for d in sorted(glob.glob("/sys/class/input/event*")):
        if not caps(d, "capabilities/abs") >> ABS_MT_POSITION_X & 1:
            continue
        if caps(d, "properties") >> PROP_DIRECT & 1:
            continue
        if not caps(d, "capabilities/key") >> BTN_TOOL_FINGER & 1:
            continue
        out.append("/dev/input/" + os.path.basename(d))
    return out


def open_pad(node, level):
    fd = os.open(node, os.O_RDONLY | os.O_NONBLOCK)
    info = {}
    for axis in (ABS_MT_POSITION_X, ABS_MT_POSITION_Y):
        buf = bytearray(ABSINFO.size)
        fcntl.ioctl(fd, eviocgabs(axis), buf)
        _, lo, hi, _, _, res = ABSINFO.unpack(buf)
        info[axis] = (hi - lo, res)
    (w, xres), (h, yres) = info[ABS_MT_POSITION_X], info[ABS_MT_POSITION_Y]
    # no resolution in the firmware: a pad of about 100 × 60 mm
    xres = xres or w / 100.0
    yres = yres or h / 60.0
    return fd, Recognizer(w, h, xres, yres, level)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sensitivity", default="normal", choices=sorted(LEVELS))
    args = ap.parse_args()
    nodes = touchpads()
    if not nodes:
        print("notouchpad", flush=True)
        return 0
    pads, denied = {}, False
    for node in nodes:
        try:
            fd, rec = open_pad(node, args.sensitivity)
            pads[fd] = rec
        except PermissionError:
            denied = True
        except OSError:
            pass
    if not pads:
        print("noperm" if denied else "notouchpad", flush=True)
        return 0
    print("ready", flush=True)
    poll = select.poll()
    for fd in pads:
        poll.register(fd, select.POLLIN)
    while pads:
        for fd, ev in poll.poll():
            if ev & (select.POLLHUP | select.POLLERR):
                poll.unregister(fd)
                os.close(fd)
                pads.pop(fd, None)
                continue
            try:
                data = os.read(fd, EVENT.size * 64)
            except BlockingIOError:
                continue
            except OSError:
                poll.unregister(fd)
                pads.pop(fd, None)
                continue
            for i in range(0, len(data) - EVENT.size + 1, EVENT.size):
                sec, usec, etype, code, value = EVENT.unpack_from(data, i)
                for g in pads[fd].feed(etype, code, value, sec + usec / 1e6):
                    print("gesture " + g, flush=True)
    # the touchpad went away (a detachable's keyboard): the service starts us again later
    return 0


if __name__ == "__main__":
    sys.exit(main())
