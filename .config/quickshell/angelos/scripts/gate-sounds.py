#!/usr/bin/env python3
"""The Heaven's Gate wallpaper scene's sounds (GateScene), synthesised on the spot.
  gate-sounds.py <dir>   writes rumble slam tick1 tick2 swish stamp whoosh choir bell shine
                         as .wav, and the version into <dir>/.version
rumble: the low swell before the gates; slam: their blow, a thud with a metal ring;
tick: the title typing; swish: the slabs sweeping in; stamp: a letter of the card's name;
whoosh: the slabs leaving; choir: the chord under the new picture developing; bell: the gates
opening; shine: the light sweeping the desktop back.
Levelled like the Y2K pack (about -6 dBFS peak), so they sit under music.
"""
import sys
import wave
from pathlib import Path

import numpy as np

VERSION = "2"
SR = 48000
rng = np.random.default_rng(7)


def tt(sec):
    return np.arange(int(sec * SR)) / SR


def tone(freq, t):
    # freq: a number or an array over t (a sweep): the phase is its running sum
    f = np.broadcast_to(np.asarray(freq, dtype=float), t.shape)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def lowpass(x, cut):
    a = np.exp(-2 * np.pi * cut / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cut):
    return x - lowpass(x, cut)


def comb(x, delay, g):
    # y[n] = x[n] + g*y[n-delay], a block of `delay` samples at a time
    y = np.concatenate([x, np.zeros(delay * 8)])
    for k in range(delay, len(y), delay):
        end = min(k + delay, len(y))
        y[k:end] += g * y[k - delay:end - delay]
    return y


def reverb(x, wet=0.3, size=1.0):
    tail = None
    for d, g in ((1557, 0.80), (1617, 0.79), (1491, 0.81), (1422, 0.78)):
        c = comb(x, int(d * size), g)
        tail = c if tail is None else tail[:len(c)] + c[:len(tail)]
    out = np.concatenate([x, np.zeros(len(tail) - len(x))])
    return out * (1 - wet) + tail / 4 * wet


def level(x, peak=0.5):
    # a short fade at the end: no click where the tail is cut
    n = min(len(x), int(0.02 * SR))
    x = x.copy()
    x[-n:] *= np.linspace(1, 0, n)
    m = np.max(np.abs(x))
    return x / m * peak if m > 0 else x


def rumble():
    t = tt(0.75)
    swell = (t / t[-1]) ** 1.6
    sub = tone(36 + 14 * t / t[-1], t)
    air = lowpass(lowpass(rng.standard_normal(len(t)), 140), 140) * 30
    riser = tone(220 * 2 ** (t / t[-1]), t) * 0.08 * swell
    return level((sub + air * 0.5) * swell + riser, 0.45)


def slam():
    t = tt(1.6)
    kick = tone(38 + 110 * np.exp(-t * 28), t) * np.exp(-t * 5)
    hit = lowpass(lowpass(rng.standard_normal(len(t)), 900), 900) * np.exp(-t * 45) * 6
    ring = sum(a * tone(f * (1 + 0.002 * np.sin(2 * np.pi * 3 * t)), t) * np.exp(-t * d)
               for f, a, d in ((523, 0.30, 3.0), (1443, 0.20, 4.5), (2830, 0.12, 6.0), (4120, 0.07, 9.0)))
    return level(reverb(kick + hit + ring * 0.5, 0.35, 1.2), 0.5)


def tick(freq):
    t = tt(0.035)
    sq = np.sign(tone(freq, t)) * np.exp(-t * 140)
    return level(sq, 0.18)


def swish():
    # the slabs: a quick rising sweep of air with a metal zing on it
    t = tt(0.45)
    noise = rng.standard_normal(len(t))
    cut = 600 + 7000 * (t / t[-1]) ** 1.5
    y = np.empty_like(noise)
    acc = 0.0
    for i, v in enumerate(noise):
        a = np.exp(-2 * np.pi * cut[i] / SR)
        acc = (1 - a) * v + a * acc
        y[i] = acc
    env = np.sin(np.pi * np.minimum(1, t / 0.32)) ** 1.2 * np.exp(-np.maximum(0, t - 0.3) * 18)
    zing = tone(1800 + 2600 * t / t[-1], t) * np.exp(-((t - 0.22) / 0.08) ** 2) * 0.25
    return level(y * env + zing, 0.42)


def stamp():
    # a letter slapped onto the card: a short thud and paper
    t = tt(0.16)
    thump = tone(70 + 140 * np.exp(-t * 60), t) * np.exp(-t * 28)
    slap = highpass(lowpass(rng.standard_normal(len(t)), 3200), 700) * np.exp(-t * 90) * 1.4
    return level(thump + slap, 0.3)


def choir():
    t = tt(3.2)
    env = np.minimum(1, t / 0.35) * np.where(t > 2.0, np.exp(-(t - 2.0) * 2.2), 1)
    # an "aah": harmonics weighted by its formants
    formants = ((800, 120, 1.0), (1150, 140, 0.6), (2900, 220, 0.25))
    voice = np.zeros(len(t))
    for root in (220.0, 277.18, 329.63, 440.0, 554.37):
        for cents in (-7, 0, 6):
            f0 = root * 2 ** (cents / 1200) * (1 + 0.004 * np.sin(2 * np.pi * (4.6 + cents * 0.03) * t))
            for h in range(1, 14):
                fh = root * h
                w = sum(a * np.exp(-((fh - fc) / bw) ** 2) for fc, bw, a in formants) + 0.05 / h
                voice += w * tone(f0 * h, t)
    shimmer = tone(880, t) * 0.04 + tone(1318.5, t) * 0.03
    return level(reverb((voice / 15 + shimmer) * env, 0.45, 1.4), 0.42)


def whoosh():
    t = tt(0.8)
    noise = rng.standard_normal(len(t))
    cut = 300 + 3500 * np.sin(np.pi * t / t[-1]) ** 2
    y = np.empty_like(noise)
    acc = 0.0
    for i, v in enumerate(noise):
        a = np.exp(-2 * np.pi * cut[i] / SR)
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return level(y * np.sin(np.pi * t / t[-1]) ** 1.5, 0.35)


def bell():
    t = tt(2.6)
    out = 0
    for f, a in ((1046.5, 1.0), (1568.0, 0.5), (2093.0, 0.3)):
        mod = tone(f * 1.4, t) * 2.2 * np.exp(-t * 3)
        out = out + a * np.sin(2 * np.pi * f * t + mod) * np.exp(-t * 2.2)
    return level(reverb(out, 0.4, 1.3), 0.32)


def shine():
    # the light sweeping the desktop back: a quick rising run of small bells, a sparkle on top
    t = tt(1.4)
    out = np.zeros(len(t))
    for i, f in enumerate((1046.5, 1318.5, 1568.0, 2093.0, 2637.0)):
        at = int(i * 0.055 * SR)
        seg = np.arange(len(t) - at) / SR
        mod = tone(f * 2.0, seg) * 1.2 * np.exp(-seg * 6)
        out[at:] += np.sin(2 * np.pi * f * seg + mod) * np.exp(-seg * 4.5) * (0.6 + 0.1 * i)
    sparkle = highpass(rng.standard_normal(len(t)), 6000) * np.exp(-t * 7) * 0.12
    return level(reverb(out + sparkle, 0.4, 1.1), 0.3)


def write_wav(path, x):
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    sounds = {"rumble": rumble, "slam": slam, "tick1": lambda: tick(1800), "tick2": lambda: tick(2150),
              "swish": swish, "stamp": stamp, "whoosh": whoosh, "choir": choir, "bell": bell, "shine": shine}
    for name, make in sounds.items():
        write_wav(out / (name + ".wav"), make())
    (out / ".version").write_text(VERSION)
    print(" ".join(sounds))


if __name__ == "__main__":
    main()
