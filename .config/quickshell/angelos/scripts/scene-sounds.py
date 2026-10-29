#!/usr/bin/env python3
"""A wallpaper scene's sounds, synthesized (an author's tool): no recordings, nothing to license.

  scene-sounds.py OUT_DIR NAME...     -> OUT_DIR/NAME.ogg (48 kHz stereo Vorbis)
  scene-sounds.py --list

Loops (crickets, birds, leaves, hum, rumble, crackle) are 60 s and join end to start without a
seam (the tail is crossfaded into the head); one-shots (whistle, impact, siren, static) start
and end in silence. Everything is far away — the meteor falls behind the houses — so the highs
are rolled off by distance and a little room is added. Seeded: a run gives the same files.
Swap any file for a recording of your own under the same name: widgets read only the names
(scene.json → "sounds").
"""
import subprocess
import sys
from pathlib import Path

import numpy as np

RATE = 48000
LOOP = 60.0


def t_of(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def band(x, lo=0.0, hi=None, soft=0.15):
    """x filtered to lo..hi Hz in the frequency domain (soft edges, a fraction of an octave)"""
    n = len(x)
    f = np.fft.rfftfreq(n, 1 / RATE)
    g = np.ones_like(f)
    if lo > 0:
        g *= 1 / (1 + (lo / np.maximum(f, 1e-3)) ** (2 / soft * 0.1))
    if hi:
        g *= 1 / (1 + (f / hi) ** (2 / soft * 0.1))
    return np.fft.irfft(np.fft.rfft(x, axis=0) * (g[:, None] if x.ndim == 2 else g), n, axis=0)


def noise(seconds, rng, colour=0.0, ch=1):
    """white (0), pink (1), brown (2)"""
    n = int(seconds * RATE)
    w = rng.standard_normal((n, ch)) if ch > 1 else rng.standard_normal(n)
    if colour:
        f = np.fft.rfftfreq(n, 1 / RATE)
        g = 1 / np.maximum(f, 5.0) ** (colour / 2)
        w = np.fft.irfft(np.fft.rfft(w, axis=0) * (g[:, None] if ch > 1 else g), n, axis=0)
    return w / (np.abs(w).max() + 1e-9)


def room(x, rng, seconds=1.8, wet=0.25, hi=4000):
    """a little distance: convolved with a decaying, darkened noise tail, per channel"""
    n = int(seconds * RATE)
    ir = rng.standard_normal((n, 2)) * np.exp(-np.arange(n) / RATE * 6.9 / seconds)[:, None]
    ir = band(ir, 0, hi)
    ir /= np.sqrt((ir ** 2).sum(0))
    m = len(x) + n
    y = np.fft.irfft(np.fft.rfft(x, m, axis=0) * np.fft.rfft(ir, m, axis=0), m, axis=0)
    out = np.zeros((m, 2))
    out[:len(x)] = x * (1 - wet)
    return out + y * wet


def pan(mono, p):
    """-1 left .. 1 right, equal power"""
    a = (p + 1) * np.pi / 4
    return np.stack([mono * np.cos(a), mono * np.sin(a)], -1)


def place(buf, sound, at):
    i = int(at * RATE) % len(buf)
    n = len(sound)
    end = min(len(buf), i + n)
    buf[i:end] += sound[:end - i]
    if i + n > len(buf):         # a loop: what runs past the end comes in at the start
        buf[:i + n - len(buf)] += sound[end - i:]


def seamless(x, cross=2.0):
    """x made one sample longer than LOOP in the making: its tail faded into its head"""
    n, c = int(LOOP * RATE), int(cross * RATE)
    y = x[:n].copy()
    k = np.linspace(0, 1, c)[:, None] if x.ndim == 2 else np.linspace(0, 1, c)
    y[:c] = x[:c] * np.sqrt(k) + x[n:n + c] * np.sqrt(1 - k)
    return y


def norm(x, peak):
    return x / (np.abs(x).max() + 1e-9) * peak


# ---- the night: crickets, a far hum ----

def crickets(rng):
    buf = np.zeros((int((LOOP + 3) * RATE), 2))
    for k in range(6):
        f = rng.uniform(4100, 4900)
        near = rng.uniform(0.25, 1.0)
        period = rng.uniform(0.55, 1.1)
        syll, gap, count = rng.uniform(0.012, 0.018), rng.uniform(0.012, 0.02), int(rng.integers(3, 6))
        tt = t_of(syll)
        s = np.sin(2 * np.pi * f * tt) * np.sin(np.pi * tt / syll) ** 2
        s += 0.3 * np.sin(2 * np.pi * 2 * f * tt) * np.sin(np.pi * tt / syll) ** 2
        chirp = np.zeros(int((syll + gap) * count * RATE))
        for j in range(count):
            i = int(j * (syll + gap) * RATE)
            chirp[i:i + len(s)] += s
        chirp = band(chirp, 0, 3000 + 4000 * near)
        side = pan(chirp * near, rng.uniform(-0.9, 0.9))
        at, rest = rng.uniform(0, period), 0.0
        while at < LOOP + 3:
            # a cricket now and then falls quiet for a while
            if rest <= 0 and rng.random() < 0.02:
                rest = rng.uniform(3, 9)
            if rest > 0:
                rest -= period
            else:
                place(buf, side * rng.uniform(0.8, 1.0), at)
            at += period * rng.uniform(0.95, 1.05)
    field = band(noise(LOOP + 3, rng, 0, 2), 4000, 5200) * (0.5 + 0.5 * np.sin(2 * np.pi * 31 * t_of(LOOP + 3)))[:, None]
    buf += field * 0.04
    return norm(seamless(room(buf, rng, 1.2, 0.2)[:len(buf)]), 0.5)


def hum(rng):
    x = band(noise(LOOP + 3, rng, 2, 2), 25, 260) * 0.8
    tt = t_of(LOOP + 3)
    # a car far off now and then: a swell of tyre noise
    for _ in range(3):
        at, d = rng.uniform(0, LOOP), rng.uniform(6, 10)
        env = np.exp(-((tt - at - d / 2) / (d / 4)) ** 2)
        x += band(noise(LOOP + 3, rng, 1, 2), 150, 1200) * env[:, None] * 0.5
    return norm(seamless(x), 0.35)


# ---- the day: birds, leaves ----

def chirp_sound(rng, kind):
    if kind == "sparrow":
        d = rng.uniform(0.05, 0.11)
        tt = t_of(d)
        f0, f1 = rng.uniform(3800, 5200), rng.uniform(2600, 3600)
        f = f0 + (f1 - f0) * (tt / d) ** 0.6 + 300 * np.sin(2 * np.pi * rng.uniform(40, 70) * tt)
    else:                               # a songbird's whistle, gliding, with vibrato
        d = rng.uniform(0.18, 0.45)
        tt = t_of(d)
        f0, f1 = rng.uniform(2200, 3400), rng.uniform(2400, 4200)
        f = f0 + (f1 - f0) * np.sin(np.pi * tt / d / 2) + 60 * np.sin(2 * np.pi * 9 * tt)
    ph = 2 * np.pi * np.cumsum(f) / RATE
    env = np.sin(np.pi * tt / d) ** 1.5
    return (np.sin(ph) + 0.25 * np.sin(2 * ph)) * env


def birds(rng, songbirds=0.3, density=1.0):
    buf = np.zeros((int((LOOP + 3) * RATE), 2))
    for b in range(5):
        kind = "song" if rng.random() < songbirds else "sparrow"
        near = rng.uniform(0.2, 0.9)
        p = rng.uniform(-0.9, 0.9)
        at = rng.uniform(0, 4)
        while at < LOOP + 3:
            # a burst: chirp-chirp-chirp, then a pause
            n = int(rng.integers(2, 7 if kind == "sparrow" else 4))
            for j in range(n):
                s = band(chirp_sound(rng, kind), 0, 2500 + 6000 * near) * near
                place(buf, pan(s, p), at)
                at += len(s) / RATE + rng.uniform(0.04, 0.14)
            at += rng.uniform(1.5, 7) / density
    buf += band(noise(LOOP + 3, rng, 2, 2), 40, 400) * 0.05      # the yard, far off
    return norm(seamless(room(buf, rng, 0.9, 0.18)[:len(buf)]), 0.45)


def leaves(rng):
    tt = t_of(LOOP + 3)
    x = band(noise(LOOP + 3, rng, 1, 2), 700, 7000)
    gust = 0.35 + 0.65 * np.clip(band(rng.standard_normal(len(tt)), 0, 0.15) * 40 + 0.5, 0, 1)
    flutter = 1 + 0.25 * band(rng.standard_normal(len(tt)), 2, 9) * 30
    return norm(seamless(x * (gust * flutter)[:, None]), 0.4)


# ---- the meteor ----

def rumble(rng):
    tt = t_of(LOOP + 3)
    x = band(noise(LOOP + 3, rng, 2, 2), 22, 110)
    swell = 0.6 + 0.4 * np.clip(band(rng.standard_normal(len(tt)), 0, 0.2) * 50 + 0.5, 0, 1)
    air = band(noise(LOOP + 3, rng, 1, 2), 1800, 3800) * 0.06
    return norm(seamless(x * swell[:, None] + air), 0.7)


def whistle(rng):
    d = 48.0
    tt = t_of(d)
    u = tt / d
    x = np.zeros((len(tt), 2))
    # the band sweeps down as it comes, louder and louder, cut off when it goes behind the house
    for i in range(0, len(tt), RATE // 4):
        c = 3200 - 2500 * u[i] ** 1.4
        seg = band(noise(0.5, rng, 1, 2), c * 0.7, c * 1.4)[:min(RATE // 2, len(tt) - i)]
        x[i:i + len(seg)] += seg * np.hanning(len(seg))[:, None]
    x += band(noise(d, rng, 2, 2), 25, 90) * (u ** 2)[:, None] * 1.4
    env = u ** 2.2 * np.clip((1 - u) / 0.01, 0, 1)
    return norm(room(x * env[:, None], rng, 2.5, 0.3)[:len(tt) + RATE], 0.6)


def impact(rng):
    d = 36.0
    tt = t_of(d)
    # the thump: a low drop and a dark burst
    thump = np.sin(2 * np.pi * np.cumsum(25 + 30 * np.exp(-tt / 0.35)) / RATE) * np.exp(-tt / 1.6)
    burst = band(rng.standard_normal(len(tt)), 20, 380) * np.exp(-tt / 0.9) * 0.9
    x = pan(thump * 0.9 + burst, 0.0)
    # rolling thunder: swells that die down over half a minute, left and right
    roll = band(noise(d, rng, 2, 2), 18, 260)
    swells = np.clip(band(rng.standard_normal(len(tt)), 0, 0.6) * 60 + 0.4, 0, 1.2)
    x += roll * (swells * np.exp(-tt / 12) * np.clip(tt / 0.6, 0, 1))[:, None] * 3.5
    return norm(room(x, rng, 4.0, 0.45, 900)[:len(tt)] * np.clip((d - tt) / 4, 0, 1)[:, None], 0.95)


def crackle(rng):
    # the fire, far off behind the house: mostly its roar; the crackling comes in clusters, a few
    # soft pops and now and then a snap, each a short burst muffled by the distance, never a
    # single click (evenly spread clicks of one size is a Geiger counter, not a fire)
    n = int((LOOP + 3) * RATE)
    tt = t_of(LOOP + 3)
    breath = 0.65 + 0.35 * np.clip(band(rng.standard_normal(n), 0, 0.8) * 40 + 0.5, 0, 1)
    x = band(noise(LOOP + 3, rng, 2, 2), 28, 380) * breath[:, None]
    x += band(noise(LOOP + 3, rng, 1, 2), 300, 1400) * (0.12 * breath ** 2)[:, None]
    heat = np.clip(band(rng.standard_normal(n), 0, 0.3) * 50 + 0.35, 0, 1)
    at = 0.0
    while at < LOOP + 3:
        at += rng.exponential(1 / (0.4 + 2.6 * heat[min(int(at * RATE), n - 1)]))
        for _ in range(int(rng.integers(1, 6))):
            at += rng.exponential(0.06)
            d = rng.uniform(0.004, 0.025)
            pop = band(rng.standard_normal(int(d * RATE * 3)), 0, rng.uniform(900, 2400)) * np.exp(-t_of(d * 3) / d)
            loud = min(rng.pareto(2.2) * 0.25 + 0.05, 1.0)
            place(x, pan(pop * loud, rng.uniform(-0.6, 0.1)) * 3, at)
    return norm(seamless(room(band(x, 0, 2200), rng, 1.6, 0.35, 1800)[:n]), 0.5)


def siren(rng):
    d = 26.0
    tt = t_of(d)
    f = 820 + 330 * np.sin(2 * np.pi * tt / 4.2 - np.pi / 2)
    ph = 2 * np.pi * np.cumsum(f) / RATE
    s = np.sin(ph) + 0.4 * np.sin(2 * ph) + 0.15 * np.sin(3 * ph)
    near = np.exp(-((tt - d * 0.55) / (d * 0.3)) ** 2)            # far off, passing a street away
    s = band(s * (0.25 + 0.75 * near), 0, 1600)
    x = pan(s, rng.uniform(-0.6, 0.6))
    edge = np.clip(tt / 3, 0, 1) * np.clip((d - tt) / 3, 0, 1)
    return norm(room(x * edge[:, None], rng, 3.0, 0.6, 1400)[:len(tt)], 0.35)


def static(rng):
    d = 3.0
    tt = t_of(d)
    gate = (rng.random(int(d * 12)) < 0.5).repeat(RATE // 12)[:len(tt)]
    gate = np.pad(gate, (0, len(tt) - len(gate)))
    x = band(rng.standard_normal(len(tt)), 300, 9000) * gate * 0.6
    x += 0.08 * np.sin(2 * np.pi * 15734 * tt)
    x[:200] += np.hanning(200) * 1.5                                # the pop
    env = np.clip((d - tt) / 0.8, 0, 1)
    return norm(pan(x * env, 0.15), 0.4)


SOUNDS = {
    "crickets": crickets, "hum": hum, "birds": birds, "leaves": leaves,
    "birds-morning": lambda r: birds(r, songbirds=0.6, density=1.4),
    "rumble": rumble, "whistle": whistle, "impact": impact, "crackle": crackle,
    "siren": siren, "static": static,
}


def write(path, x):
    pcm = np.clip(x, -1, 1).astype(np.float32)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", "2", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "3", str(path)], input=pcm.tobytes(), check=True)


if __name__ == "__main__":
    if sys.argv[1:] == ["--list"]:
        print(" ".join(SOUNDS))
        sys.exit(0)
    out = Path(sys.argv[1]).expanduser()
    out.mkdir(parents=True, exist_ok=True)
    for name in sys.argv[2:] or SOUNDS:
        rng = np.random.default_rng(sum(map(ord, name)) * 7919)
        write(out / f"{name}.ogg", SOUNDS[name](rng))
        print(out / f"{name}.ogg")
