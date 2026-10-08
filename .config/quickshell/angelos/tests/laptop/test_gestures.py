#!/usr/bin/env python3
"""scripts/gesture-watch.py's Recognizer against synthetic touches (no touchpad needed): the
pinches, the four-finger swipes, the edge swipes, the taps and the hold come out once each;
niri's own (three-finger swipes, four up) and plain two-finger scrolling give nothing.
Run: python3 tests/laptop/test_gestures.py   (scripts/check.sh runs it)"""
import importlib.util
import math
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("gw", ROOT / "scripts/gesture-watch.py")
gw = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gw)

W, H, RES = 3000, 2000, 30          # a 100 × 66 mm pad, 30 units per mm
TOOLKEY = {1: gw.BTN_TOOL_FINGER, 2: gw.BTN_TOOL_DOUBLETAP, 3: gw.BTN_TOOL_TRIPLETAP,
           4: gw.BTN_TOOL_QUADTAP, 5: gw.BTN_TOOL_QUINTTAP}


class Pad:
    """drives a Recognizer like a touchpad would: frames of finger positions (None = up)"""

    def __init__(self, level="normal", slots=5):
        self.r = gw.Recognizer(W, H, RES, RES, level)
        self.t = 100.0
        self.down = {}
        self.tool = 0
        self.max_slots = slots
        self.out = []

    def ev(self, *e):
        self.out += self.r.feed(*e, self.t)

    def frame(self, fingers, dt=0.012):
        """fingers: list of (x, y); a shorter list lifts the last ones"""
        self.t += dt
        n = len(fingers)
        for i in range(max(n, len(self.down))):
            if i >= self.max_slots:
                break
            self.ev(gw.EV_ABS, gw.ABS_MT_SLOT, i)
            if i < n:
                if i not in self.down:
                    self.ev(gw.EV_ABS, gw.ABS_MT_TRACKING_ID, 100 + i)
                x, y = fingers[i]
                self.ev(gw.EV_ABS, gw.ABS_MT_POSITION_X, int(x))
                self.ev(gw.EV_ABS, gw.ABS_MT_POSITION_Y, int(y))
                self.down[i] = True
            elif i in self.down:
                self.ev(gw.EV_ABS, gw.ABS_MT_TRACKING_ID, -1)
                del self.down[i]
        if n != self.tool:
            if self.tool:
                self.ev(gw.EV_KEY, TOOLKEY[self.tool], 0)
            if n:
                self.ev(gw.EV_KEY, TOOLKEY[min(n, 5)], 1)
            self.tool = n
        self.ev(gw.EV_SYN, gw.SYN_REPORT, 0)

    def stroke(self, start, end, steps=25, dt=0.012):
        """fingers moving from `start` to `end` (lists of points), then lifted"""
        for k in range(steps + 1):
            f = k / steps
            self.frame([(a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f) for a, b in zip(start, end)], dt)
        self.frame([], dt)
        return self.out


def hand(cx, cy, r, n=4):
    return [(cx + r * math.cos(a), cy + r * math.sin(a)) for a in (2 * math.pi * i / n + 0.3 for i in range(n))]


def shifted(pts, dx, dy):
    return [(x + dx, y + dy) for x, y in pts]


class Gestures(unittest.TestCase):
    def test_pinch(self):
        self.assertEqual(Pad().stroke(hand(1500, 1000, 700), hand(1500, 1000, 250)), ["pinchIn"])
        self.assertEqual(Pad().stroke(hand(1500, 1000, 250), hand(1500, 1000, 750)), ["pinchOut"])

    def test_four_finger_swipes(self):
        h = hand(1500, 1000, 300)
        self.assertEqual(Pad().stroke(h, shifted(h, -1200, 30)), ["swipe4Left"])
        self.assertEqual(Pad().stroke(h, shifted(h, 1200, -40)), ["swipe4Right"])
        self.assertEqual(Pad().stroke(h, shifted(h, 20, 900)), ["swipe4Down"])
        self.assertEqual(Pad().stroke(h, shifted(h, 0, -900)), [])          # niri's overview

    def test_niri_keeps_three_and_two(self):
        h3 = hand(1500, 1000, 300, 3)
        self.assertEqual(Pad().stroke(h3, shifted(h3, 1200, 0)), [])        # columns
        self.assertEqual(Pad().stroke(h3, shifted(h3, 0, 900)), [])         # workspaces
        h2 = hand(1500, 1000, 200, 2)
        self.assertEqual(Pad().stroke(h2, shifted(h2, 0, 900)), [])         # scrolling
        self.assertEqual(Pad().stroke(h2, [(1500, 1000), (1520, 1000)]), [])  # the apps' pinch

    def test_edges(self):
        self.assertEqual(Pad().stroke([(40, 1000)], [(900, 1050)]), ["edgeLeft"])
        self.assertEqual(Pad().stroke([(2970, 900)], [(2200, 950)]), ["edgeRight"])
        self.assertEqual(Pad().stroke([(800, 1000)], [(1800, 1000)]), [])  # a plain pointer move
        slow = Pad()
        self.assertEqual(slow.stroke([(40, 1000)], [(900, 1000)], steps=200, dt=0.012), [])  # too slow

    def test_taps_and_hold(self):
        p = Pad()
        for _ in range(8):
            p.frame(hand(1500, 1000, 300, 4))
        p.frame([])
        self.assertEqual(p.out, ["tap4"])
        p = Pad()
        for _ in range(8):
            p.frame(hand(1500, 1000, 300, 3))
        p.frame([])
        self.assertEqual(p.out, ["tap3"])
        p = Pad()
        for _ in range(70):
            p.frame(hand(1500, 1000, 300, 3))
        p.frame([])
        self.assertEqual(p.out, ["hold3"])

    def test_fingers_landing_one_by_one(self):
        # four fingers put down one after another, then a pinch: still one pinchIn
        p = Pad()
        h = hand(1500, 1000, 700)
        for k in range(1, 5):
            for _ in range(3):
                p.frame(h[:k])
        self.assertEqual(p.stroke(h, hand(1500, 1000, 250)), ["pinchIn"])

    def test_two_slot_pad(self):
        # an old pad that tracks two slots and reports four fingers by BTN_TOOL_QUADTAP
        h = hand(1500, 1000, 300)
        self.assertEqual(Pad(slots=2).stroke(h, shifted(h, -1200, 0)), ["swipe4Left"])

    def test_sensitivity(self):
        h = hand(1500, 1000, 300)
        short = shifted(h, -540, 0)                              # 18 mm
        self.assertEqual(Pad("low").stroke(h, short), [])
        self.assertEqual(Pad("high").stroke(h, short), ["swipe4Left"])


if __name__ == "__main__":
    unittest.main(verbosity=1)
