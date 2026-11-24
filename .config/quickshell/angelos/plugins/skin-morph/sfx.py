#!/usr/bin/env python3
"""skin-morph sounds, synthesized (numpy): python3 sfx.py [outdir]

  to-mac.wav      Classic → Golden Gate: an airy rising whoosh and four glass bells, one per
                  stage of the wave (bar, widgets, Dock), ringing out in a small reverb.
  to-classic.wav  Golden Gate → Classic: an 8-bit power-down — a square-wave arpeggio falling
                  in steps, bit-crushed and sample-held harder as it goes, with crackle.
  to-serp.wav     → serp: a water drop (a sine flicked up in pitch, a quick bloop), then a soft
                  pastel chord (Cmaj9, sines with a slow swell and a slight chorus) and two
                  smaller drops further out, as the ring runs across the screen.
Kept above ~200 Hz: laptop speakers.
"""
import sys
import wave
from pathlib import Path

import numpy as np

SR = 48000
OUT = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).parent)
rng = np.random.default_rng(7)


def t_(sec):
    return np.arange(int(SR * sec)) / SR


def place(buf, sig, at):
    i = int(at * SR)
    n = min(len(sig), len(buf) - i)
    buf[i:i + n] += sig[:n]


def reverb(x, mix=0.3):
    y = np.copy(x)
    for d, g in ((0.0297, 0.6), (0.0371, 0.55), (0.0411, 0.5), (0.0437, 0.45)):
        k = int(d * SR)
        c = np.copy(x)
        for i in range(k, len(c), k):
            c[i:i + k] += g * c[i - k:i][:len(c[i:i + k])]
        y += mix * 0.25 * c
    return y


def onepole_lp(x, fc):
    a = np.exp(-2 * np.pi * fc / SR)
    y = np.empty_like(x)
    s = 0.0
    for i, v in enumerate(x):
        s = (1 - a) * v + a * s
        y[i] = s
    return y


def save(name, x, peak=0.7):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    fade = int(0.02 * SR)
    x[-fade:] *= np.linspace(1, 0, fade)
    pcm = (x * 32767).astype("<i2")
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(OUT / name)


def to_mac():
    buf = np.zeros(int(SR * 1.5))
    # whoosh: noise through a sweeping low-pass, swelling then gone
    t = t_(0.8)
    n = rng.standard_normal(len(t))
    sweep = np.empty_like(n)
    s = 0.0
    for i, v in enumerate(n):
        fc = 400 + 2600 * (i / len(n)) ** 1.5
        a = np.exp(-2 * np.pi * fc / SR)
        s = (1 - a) * v + a * s
        sweep[i] = s
    sweep -= onepole_lp(sweep, 250)          # no rumble
    env = np.sin(np.pi * np.clip(t / 0.8, 0, 1)) ** 2
    place(buf, 0.14 * sweep * env, 0.0)
    # glass bells, E major, one per stage
    for k, (f, at) in enumerate(((659.3, 0.06), (987.8, 0.21), (1318.5, 0.36), (1661.2, 0.50))):
        t = t_(1.0)
        bell = (np.sin(2 * np.pi * f * t) * np.exp(-t * 4.0)
                + 0.35 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 9.0)
                + 0.12 * np.sin(2 * np.pi * f * 5.40 * t) * np.exp(-t * 16.0))
        bell *= np.minimum(1, t / 0.004) * np.minimum(1, (1.0 - t) / 0.3)  # no click at the cut
        place(buf, (0.55 - 0.06 * k) * bell, at)
    return reverb(buf, 0.45)


def to_classic():
    buf = np.zeros(int(SR * 1.25))
    notes = (1046.5, 784.0, 659.3, 523.3, 392.0, 329.6, 261.6, 220.0)
    step = 0.085
    for k, f in enumerate(notes):
        t = t_(step * 1.6)
        sq = np.sign(np.sin(2 * np.pi * f * t + 0.1)) * (0.5 if k % 2 else 0.6)
        sq *= np.exp(-t * 7.0) * np.minimum(1, t / 0.002)
        place(buf, sq, k * step)
    # the last note drags and drops in pitch: the machine powering down
    t = t_(0.45)
    f = 220.0 * (1 - 0.45 * (t / 0.45) ** 1.3)
    ph = 2 * np.pi * np.cumsum(f) / SR
    place(buf, 0.6 * np.sign(np.sin(ph)) * np.exp(-t * 4.5), len(notes) * step)
    # crackle
    n = rng.standard_normal(len(buf)) * (rng.random(len(buf)) < 0.004)
    buf += 0.5 * onepole_lp(n, 3000) * np.linspace(0.2, 1, len(buf))
    # crush harder as it goes: sample hold 1 → 8, bits 8 → 4
    out = np.empty_like(buf)
    i = 0
    while i < len(buf):
        p = i / len(buf)
        hold = 1 + int(7 * p)
        bits = 8 - 4 * p
        q = 2 ** bits
        v = np.round(buf[i] * q) / q
        out[i:i + hold] = v
        i += hold
    out -= onepole_lp(out, 180)
    return onepole_lp(out, 7000)


def drop(f0, f1, dur=0.12, amp=1.0):
    """a water drop: a sine swept up fast (the bubble's resonance), a short decay"""
    t = t_(dur)
    f = f0 + (f1 - f0) * (1 - np.exp(-t / 0.018))
    ph = 2 * np.pi * np.cumsum(f) / SR
    env = np.minimum(1, t / 0.002) * np.exp(-t * 28)
    return amp * np.sin(ph) * env


def to_serp():
    buf = np.zeros(int(SR * 1.8))
    place(buf, drop(420, 1350, 0.16, 0.9), 0.0)          # the drop hits
    place(buf, drop(700, 1900, 0.10, 0.35), 0.035)       # its little splash
    # the chord: C E G B D, sines with a slow swell, each voice a hair detuned twice (chorus)
    t = t_(1.6)
    env = (1 - np.exp(-t / 0.18)) * np.exp(-t * 1.9)
    chord = np.zeros_like(t)
    for k, f in enumerate((523.3, 659.3, 784.0, 987.8, 1174.7)):
        for det in (-0.6, 0.6):
            chord += np.sin(2 * np.pi * (f + det) * t + k) * (0.22 - 0.025 * k)
    place(buf, chord * env, 0.08)
    # two smaller drops further out, as the ring travels
    place(buf, drop(900, 2300, 0.09, 0.28), 0.42)
    place(buf, drop(1100, 2700, 0.08, 0.18), 0.71)
    buf -= onepole_lp(buf, 200)
    return reverb(buf, 0.5)


if __name__ == "__main__":
    save("to-mac.wav", to_mac(), 0.6)
    save("to-classic.wav", to_classic(), 0.55)
    save("to-serp.wav", to_serp(), 0.55)
