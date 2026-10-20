#!/usr/bin/env python3
"""tests/rhythm: scripts/osu-beats.py's Tracker on made-up drums, no sound device.

  beats.py <angelOS dir>   prints {"case": [estimates…]} as JSON

Each case is a kick (a falling 60 Hz thump) with a hat between, fed in the hops pw-record
would send, the way main() does; every quarter of a second the estimate is taken.
"""
import importlib.util
import json
import os
import sys

import numpy as np

spec = importlib.util.spec_from_file_location("osu_beats", os.path.join(sys.argv[1], "scripts", "osu-beats.py"))
ob = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ob)
RATE, HOP = ob.RATE, ob.HOP


def song(beats, seconds, seed):
    rng = np.random.default_rng(seed)
    x = rng.normal(0, 0.004, int(seconds * RATE)).astype(np.float32)
    k = np.arange(int(0.12 * RATE)) / RATE
    kick = (np.sin(2 * np.pi * 60 * k) * np.exp(-k * 30)).astype(np.float32) * 0.8
    h = np.arange(int(0.03 * RATE)) / RATE
    hat = (rng.normal(0, 1, len(h)) * np.exp(-h * 150)).astype(np.float32) * 0.15
    for i, t in enumerate(beats):
        a = int(t * RATE)
        x[a:a + len(kick)] += kick[:len(x) - a]
        if i + 1 < len(beats):
            b = int((t + beats[i + 1]) / 2 * RATE)
            x[b:b + len(hat)] += hat[:len(x) - b]
    return x


def grid(bpm, start, end, jitter=0.0, seed=0):
    rng = np.random.default_rng(seed)
    p = 60 / bpm
    return [t + rng.uniform(-jitter, jitter) for t in np.arange(start, end, p)]


def run(beats, seconds, seed=1):
    x = song(beats, seconds, seed)
    tr = ob.Tracker()
    out, last = [], 0.0
    for i in range(0, len(x) - HOP, HOP):
        t_end = (i + HOP) / RATE
        tr.feed(x[i:i + HOP], t_end)
        if t_end - last >= 0.25:
            last = t_end
            e = tr.estimate()
            if e:
                e["at"] = round(t_end * 1000)
                out.append(e)
    return out


rng = np.random.default_rng(7)
rubato, t = [], 0.3
while t < 16:
    rubato.append(t)
    t += rng.uniform(0.28, 0.95)
cases = {
    "even": run(grid(120, 0.5, 16), 16),
    "jitter": run(grid(128, 0.5, 16, jitter=0.012, seed=3), 16),
    "change": run(grid(100, 0.5, 8) + grid(130, 8.0, 20), 20),
    "rubato": run(rubato, 16),
}
print(json.dumps(cases))
