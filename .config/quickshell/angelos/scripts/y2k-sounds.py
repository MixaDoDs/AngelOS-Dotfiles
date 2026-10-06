#!/usr/bin/env python3
"""The angelOS Y2K sound pack, synthesised on the spot (no samples, no licences).

  y2k-sounds.py <dir> [name…]  writes startup notify error click shutdown angel
                               wallpaper open toggle screenshot volume windowClose
                               demon crack choir rocks shatter voice, the input and
                               system ones clickRight key (+ key2 key3, typing
                               variety) windowOpen workspace lock unlock usbIn
                               usbOut bark harp as .ogg
                               (.wav without ffmpeg) and the pips voiceAngel
                               voiceDemon, voiceFallen1…5 and the harp's strings
                               harp1…16 as .wav, prints JSON

Chimes are FM bells and detuned triangle pads with a small echo, levelled to
about -6 dBFS peak and at most -20 dBFS RMS so they sit under music and voice.
The helper's sounds are quieter still (LOUDNESS): her pips play once per letter,
a whole sentence of square waves at chime level was deafening.
The pack's version goes into <dir>/.version; the shell regenerates older packs.
"""
import json
import math
import shutil
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 44100


def t_axis(sec):
    return np.arange(int(sec * RATE)) / RATE


def env(n, attack=0.005, release=0.2, sec=None):
    t = np.arange(n) / RATE
    total = n / RATE
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    r = np.clip((total - t) / max(release, 1e-4), 0, 1)
    return a * r


def bell(freq, sec, index=2.0, ratio=3.5, decay=4.0):
    t = t_axis(sec)
    mod = np.sin(2 * np.pi * freq * ratio * t) * index * np.exp(-t * decay * 1.5)
    return np.sin(2 * np.pi * freq * t + mod) * np.exp(-t * decay)


def tri(freq, sec, detune=0.0):
    t = t_axis(sec)
    out = np.zeros_like(t)
    for d in (-detune, 0.0, detune):
        ph = (freq * (1 + d) * t) % 1.0
        out += 2 * np.abs(2 * ph - 1) - 1
    return out / 3


def square(freq, sec):
    t = t_axis(sec)
    return np.sign(np.sin(2 * np.pi * freq * t))


def place(buf, sound, at):
    i = int(at * RATE)
    end = min(len(buf), i + len(sound))
    buf[i:end] += sound[:end - i]


def echo(x, delay=0.18, fb=0.35, taps=4):
    out = x.copy()
    d = int(delay * RATE)
    for k in range(1, taps + 1):
        shifted = np.zeros_like(x)
        shifted[d * k:] = x[:len(x) - d * k] if d * k < len(x) else 0
        out += shifted * fb ** k
    return out


def note(n):
    """MIDI note -> Hz"""
    return 440.0 * 2 ** ((n - 69) / 12)


def level(x, peak_db=-6.0, rms_db=-20.0):
    """peak at peak_db, then turned down until the RMS is at most rms_db
    (a square wave at -6 dBFS peak is ~12 dB louder than a bell at -6)"""
    m = np.max(np.abs(x)) or 1.0
    x = x / m * 10 ** (peak_db / 20)
    rms = float(np.sqrt(np.mean(x * x))) or 1.0
    cap = 10 ** (rms_db / 20)
    return x * (cap / rms) if rms > cap else x


# RMS ceilings, dBFS: the helper speaks under everything else
LOUDNESS = {"bark": -24.0, "voiceAngel": -25.0, "voiceDemon": -26.0, "voice": -25.0, "angel": -24.0, "demon": -25.0,
            "voiceFallen1": -27.0, "voiceFallen2": -27.0, "voiceFallen3": -27.0, "voiceFallen4": -27.0, "voiceFallen5": -27.0,
            "choir": -23.0, "crack": -25.0, "rocks": -23.0, "shatter": -23.0,
            "key": -27.0, "key2": -27.0, "key3": -27.0, "clickRight": -22.0, "workspace": -24.0,
            "circle": -21.0, "circleSoft": -27.0, "achievement": -23.0}
# peaks, dBFS: the harp's strings ring together (a glissando stacks them)
PEAKS = {"harp%d" % (i + 1): -10.0 for i in range(16)}
PACK_VERSION = "9"


def startup():
    # soft pad (Cmaj9 → Fmaj7/C) under a rising bell arpeggio and a sparkle
    sec = 2.6
    buf = np.zeros(int(sec * RATE))
    for n in (48, 55, 64, 67, 71, 74):
        pad = tri(note(n), sec, detune=0.004) * env(int(sec * RATE), attack=0.35, release=1.2)
        buf += pad * 0.16
    for i, n in enumerate((72, 76, 79, 83, 86, 88)):
        place(buf, bell(note(n), 1.4, index=1.6, decay=3.2) * 0.5, 0.12 + i * 0.11)
    for i, n in enumerate((96, 100, 103)):
        place(buf, bell(note(n), 0.5, index=0.8, decay=8) * 0.25, 1.05 + i * 0.07)
    return echo(buf, 0.21, 0.3)


def notify():
    sec = 0.9
    buf = np.zeros(int(sec * RATE))
    place(buf, bell(note(88), 0.7, index=1.2, decay=6), 0.0)
    place(buf, bell(note(83), 0.8, index=1.2, decay=5), 0.13)
    return echo(buf, 0.12, 0.25, 2)


def error():
    sec = 0.45
    t = t_axis(sec)
    f = 220 * np.exp(-t * 3.0)
    ph = np.cumsum(f) / RATE
    x = np.sign(np.sin(2 * np.pi * ph)) * 0.6 + np.sin(2 * np.pi * ph * 0.5) * 0.4
    return x * env(len(t), 0.003, 0.25)


def click():
    sec = 0.035
    t = t_axis(sec)
    return np.sin(2 * np.pi * 2400 * t) * np.exp(-t * 180)


def shutdown():
    sec = 1.8
    buf = np.zeros(int(sec * RATE))
    for i, n in enumerate((88, 84, 79, 76, 72, 67)):
        place(buf, bell(note(n), 1.0, index=1.4, decay=3.8) * 0.55, i * 0.13)
    pad = tri(note(48), sec, detune=0.003) * env(int(sec * RATE), 0.2, 1.3) * 0.2
    return echo(buf + pad, 0.22, 0.28)


def angel():
    sec = 0.8
    buf = np.zeros(int(sec * RATE))
    for i, n in enumerate((91, 95, 98)):
        place(buf, bell(note(n), 0.5, index=0.7, decay=7) * 0.6, i * 0.06)
    return echo(buf, 0.09, 0.3, 3)


def noise(sec, seed=1):
    return np.random.default_rng(seed).uniform(-1, 1, int(sec * RATE))


def lowpass(x, cutoff):
    # one-pole, enough to take the fizz off noise
    a = np.exp(-2 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def wallpaper():
    # a shimmer: rising bell arpeggio with glitter on top
    sec = 1.2
    buf = np.zeros(int(sec * RATE))
    for i, n in enumerate((79, 84, 88, 91, 96)):
        place(buf, bell(note(n), 0.8, index=1.0, decay=5.5) * 0.5, i * 0.07)
    rng = np.random.default_rng(7)
    for k in range(9):
        place(buf, bell(note(98 + rng.integers(0, 10)), 0.25, index=0.5, decay=14) * 0.18, 0.3 + k * 0.05)
    return echo(buf, 0.11, 0.3, 3)


def open_():
    sec = 0.32
    buf = np.zeros(int(sec * RATE))
    place(buf, bell(note(79), 0.25, index=0.6, decay=12) * 0.6, 0.0)
    place(buf, bell(note(86), 0.28, index=0.6, decay=11) * 0.6, 0.05)
    return buf


def toggle():
    sec = 0.07
    t = t_axis(sec)
    f = 1900 * np.exp(-t * 9)
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * 60)


def screenshot():
    # a little shutter: two filtered clicks
    sec = 0.3
    buf = np.zeros(int(sec * RATE))
    for at, seed in ((0.0, 3), (0.085, 4)):
        n = noise(0.05, seed) * np.exp(-t_axis(0.05) * 90)
        place(buf, lowpass(n, 3500) * 0.9, at)
    place(buf, bell(note(96), 0.2, index=0.4, decay=16) * 0.25, 0.12)
    return buf


def volume():
    sec = 0.05
    t = t_axis(sec)
    return np.sin(2 * np.pi * 1320 * t) * np.exp(-t * 90)


def window_close():
    sec = 0.4
    buf = np.zeros(int(sec * RATE))
    place(buf, bell(note(84), 0.3, index=0.7, decay=10) * 0.55, 0.0)
    place(buf, bell(note(77), 0.35, index=0.7, decay=9) * 0.55, 0.08)
    return buf


def click_right():
    # lower than the left click, and doubled: "tik-tik"
    sec = 0.07
    buf = np.zeros(int(sec * RATE))
    t = t_axis(0.03)
    tick = np.sin(2 * np.pi * 1700 * t) * np.exp(-t * 200)
    place(buf, tick, 0.0)
    place(buf, tick * 0.6, 0.032)
    return buf


def key(variant=0):
    # a soft typewriter tick: a short band of noise and a little body; three
    # variants so fast typing does not sound like a machine gun
    cut, body, seed = ((4200, 520, 11), (3600, 470, 12), (4800, 580, 13))[variant]
    sec = 0.045
    t = t_axis(sec)
    n = lowpass(noise(sec, seed), cut) * np.exp(-t * 160)
    thump = np.sin(2 * np.pi * body * t) * np.exp(-t * 120) * 0.5
    return n + thump


def window_open():
    # window_close turned around: two bells going up
    sec = 0.4
    buf = np.zeros(int(sec * RATE))
    place(buf, bell(note(77), 0.3, index=0.7, decay=10) * 0.55, 0.0)
    place(buf, bell(note(84), 0.35, index=0.7, decay=9) * 0.55, 0.07)
    return buf


def workspace():
    # a soft swish: noise through a sweeping low-pass
    sec = 0.22
    t = t_axis(sec)
    n = noise(sec, 21)
    out = np.zeros_like(n)
    for i, cut in enumerate(np.linspace(900, 5200, 8)):
        a, b = int(i * len(n) / 8), int((i + 1) * len(n) / 8)
        out[a:b] = lowpass(n, cut)[a:b]
    return out * np.sin(np.pi * t / sec) ** 2


def lock():
    # a little padlock: a click and a falling fifth
    sec = 0.5
    buf = np.zeros(int(sec * RATE))
    place(buf, lowpass(noise(0.02, 31), 3000) * np.exp(-t_axis(0.02) * 200) * 0.8, 0.0)
    place(buf, bell(note(79), 0.35, index=0.9, decay=8) * 0.5, 0.03)
    place(buf, bell(note(72), 0.45, index=0.9, decay=7) * 0.5, 0.14)
    return buf


def unlock():
    # the padlock opens: a rising arpeggio with a sparkle on top
    sec = 0.6
    buf = np.zeros(int(sec * RATE))
    for i, n in enumerate((72, 76, 79, 84)):
        place(buf, bell(note(n), 0.4, index=0.8, decay=8) * 0.45, i * 0.06)
    place(buf, bell(note(96), 0.25, index=0.5, decay=14) * 0.2, 0.26)
    return echo(buf, 0.1, 0.2, 2)


def bark():
    # Cerberus (the Wheel of Hell): three quick puppy barks, one a head — noisy little
    # 8-bit yaps dropping in pitch, the last one the deepest
    sec = 0.75
    buf = np.zeros(int(sec * RATE))
    for i, (f, at) in enumerate(((520, 0.0), (430, 0.2), (330, 0.42))):
        d = 0.13
        t = t_axis(d)
        x = pulse(f * 1.25, f * 0.7, d, 0.35) * 0.7 + lowpass(noise(d, 51 + i), 2600) * 0.45
        x = crunch8(x * np.exp(-t * 14) * env(len(t), 0.004, 0.05))
        place(buf, lowpass(x, 3400), at)
    return buf


def usb_in():
    # a device plugged in: "da-ding" going up — a soft knock, then a fifth and an octave
    # on bells over a short triangle pad, the way old systems greeted a new device
    sec = 0.75
    buf = np.zeros(int(sec * RATE))
    place(buf, lowpass(noise(0.025, 41), 1800) * np.exp(-t_axis(0.025) * 160) * 0.5, 0.0)
    place(buf, bell(note(67), 0.45, index=1.1, decay=7) * 0.55, 0.01)
    place(buf, bell(note(74), 0.5, index=1.0, decay=6) * 0.5, 0.11)
    place(buf, bell(note(79), 0.55, index=0.9, decay=5.5) * 0.45, 0.2)
    pad = tri(note(55), 0.45, detune=0.003) * env(int(0.45 * RATE), attack=0.04, release=0.3)
    place(buf, pad * 0.18, 0.08)
    return echo(buf, 0.13, 0.22, 2)


def usb_out():
    # unplugged: the same three bells falling, duller, with a little click of the plug
    sec = 0.7
    buf = np.zeros(int(sec * RATE))
    place(buf, bell(note(79), 0.4, index=0.8, decay=8) * 0.45, 0.0)
    place(buf, bell(note(74), 0.45, index=0.8, decay=7) * 0.5, 0.1)
    place(buf, bell(note(67), 0.5, index=0.9, decay=6) * 0.55, 0.2)
    place(buf, lowpass(noise(0.02, 43), 2400) * np.exp(-t_axis(0.02) * 200) * 0.35, 0.21)
    return lowpass(echo(buf, 0.13, 0.2, 2), 5200)


def achievement():
    """an achievement earned: a quick bright arpeggio up, a sparkle on top, a soft chord under"""
    sec = 1.5
    buf = np.zeros(int(sec * RATE))
    for i, n in enumerate((84, 88, 91, 96)):
        place(buf, bell(note(n), 0.7, index=0.9, decay=6) * (0.55 + i * 0.1), i * 0.07)
    for n in (72, 76, 79):
        place(buf, tri(note(n), 0.9) * env(int(0.9 * RATE), 0.02, 0.6) * 0.18, 0.28)
    place(buf, bell(note(103), 0.4, index=0.5, decay=9) * 0.35, 0.34)
    return echo(buf, 0.12, 0.3, 3)


def demon():
    # the demon's "heh": two wobbly low squares, a minor second apart
    sec = 0.55
    buf = np.zeros(int(sec * RATE))
    for i, n in enumerate((50, 49)):
        t = t_axis(0.2)
        f = note(n) * (1 + 0.03 * np.sin(2 * np.pi * 18 * t))
        x = np.sign(np.sin(2 * np.pi * np.cumsum(f) / RATE)) * 0.5 + np.sin(2 * np.pi * np.cumsum(f * 2) / RATE) * 0.3
        place(buf, x * env(len(t), 0.005, 0.12), i * 0.2)
    return echo(buf, 0.13, 0.25, 2)


def crack():
    # a punch into the screen, then glass giving way: a thump, a crunch of
    # noise and a scatter of tiny high "tinks"
    sec = 1.1
    buf = np.zeros(int(sec * RATE))
    t = t_axis(0.35)
    thump = np.sin(2 * np.pi * np.cumsum(90 * np.exp(-t * 7) + 38) / RATE) * np.exp(-t * 11)
    place(buf, thump * 1.0, 0.0)
    crunch = noise(0.45, 11) * np.exp(-t_axis(0.45) * 9)
    place(buf, (crunch - lowpass(crunch, 1800)) * 0.9, 0.012)
    rng = np.random.default_rng(5)
    for k in range(26):
        f = rng.uniform(2600, 7800)
        at = 0.02 + rng.exponential(0.12)
        if at < sec - 0.15:
            place(buf, bell(f, 0.12, index=0.3, ratio=2.7, decay=40) * rng.uniform(0.12, 0.35), at)
    return echo(buf, 0.07, 0.18, 2)


def choir():
    # a short heavenly "aaah" (think of the item room in Isaac): a D major chord
    # of formant-shaped voices with vibrato, slow in, soft out, in a big room
    sec = 1.7
    n = int(sec * RATE)
    t = np.arange(n) / RATE
    formants = ((800, 110, 1.0), (1150, 130, 0.6), (2900, 220, 0.25))  # the vowel "a"
    out = np.zeros(n)
    rng = np.random.default_rng(3)
    for midi in (62, 66, 69, 74, 78):
        for voice in range(3):
            f0 = note(midi) * (1 + rng.uniform(-0.004, 0.004))
            vib = 1 + 0.006 * np.sin(2 * np.pi * rng.uniform(4.8, 6.0) * t + rng.uniform(0, 6.28))
            phase = 2 * np.pi * np.cumsum(f0 * vib) / RATE
            for k in range(1, 40):
                fk = f0 * k
                if fk > 7000:
                    break
                amp = sum(g / (1 + ((fk - fc) / bw) ** 2) for fc, bw, g in formants) / k ** 0.3
                out += np.sin(k * phase) * amp
    out *= env(n, attack=0.28, release=0.8)
    return echo(out, 0.19, 0.42, 5)


def lfsr(sec, period, short=False, seed=1):
    """the NES noise channel: a 15-bit LFSR clocked every `period` samples
    (bigger = lower); short mode loops after 93 steps and rings metallic"""
    n = int(sec * RATE)
    steps = n // max(1, period) + 1
    reg, tap = seed or 1, 6 if short else 1
    bits = np.empty(steps)
    for i in range(steps):
        fb = (reg ^ (reg >> tap)) & 1
        reg = (reg >> 1) | (fb << 14)
        bits[i] = 1.0 if reg & 1 else -1.0
    return np.repeat(bits, max(1, period))[:n]


def pulse(freq_start, freq_end, sec, duty=0.25):
    t = t_axis(sec)
    f = freq_start * (freq_end / freq_start) ** (t / sec)
    ph = np.cumsum(f) / RATE % 1.0
    return np.where(ph < duty, 1.0, -1.0)


def crunch8(x, levels=16, hold=4):
    """8-bit grit: 4-bit amplitude steps and ~11 kHz sample-and-hold"""
    x = np.repeat(x[::hold], hold)[:len(x)]
    return np.round(x * levels / 2) / (levels / 2)


def rocks():
    # the ground shakes and stones tumble down: a low noise-channel rumble that
    # rolls off, low pulse thuds and a clatter of rocks hitting each other
    sec = 1.25
    buf = np.zeros(int(sec * RATE))
    rumble = lfsr(1.1, 90, seed=3) * np.exp(-t_axis(1.1) * 2.6) * env(int(1.1 * RATE), 0.01, 0.25)
    place(buf, rumble * 0.55, 0.0)
    place(buf, pulse(70, 38, 0.5, 0.5) * np.exp(-t_axis(0.5) * 5) * 0.5, 0.0)
    rng = np.random.default_rng(12)
    at = 0.04
    for k in range(14):
        size = rng.uniform(0.3, 1.0)                     # big stones: lower, longer
        hit = 0.05 + 0.07 * size
        clack = lfsr(hit, int(6 + 20 * size), short=rng.random() < 0.35, seed=int(rng.integers(1, 30000)))
        clack *= np.exp(-t_axis(hit) * (70 - 35 * size))
        thud = pulse(260 - 120 * size, 90 - 30 * size, hit, 0.5) * np.exp(-t_axis(hit) * 45)
        place(buf, (clack * 0.7 + thud * 0.45) * (1 - k / 22), at)
        at += rng.uniform(0.035, 0.09)
        if at > sec - 0.15:
            break
    return crunch8(buf)


def shatter():
    # the screen breaks, 8-bit: a white-noise crash, a pulse "kssh" falling down
    # two octaves and glass bits ringing in short-mode noise
    sec = 1.05
    buf = np.zeros(int(sec * RATE))
    crash = lfsr(0.5, 1, seed=9) * np.exp(-t_axis(0.5) * 9)
    place(buf, crash * 0.8, 0.0)
    place(buf, lfsr(0.3, 3, short=True, seed=77) * np.exp(-t_axis(0.3) * 16) * 0.5, 0.01)
    for i, n in enumerate((96, 91, 88, 84, 79, 76, 72, 67)):
        place(buf, pulse(note(n), note(n) * 0.97, 0.06, 0.125) * np.exp(-t_axis(0.06) * 30) * 0.32, 0.06 + i * 0.045)
    rng = np.random.default_rng(21)
    for k in range(12):
        f = rng.uniform(2200, 5200)
        place(buf, pulse(f, f, 0.04, 0.5) * np.exp(-t_axis(0.04) * 90) * rng.uniform(0.12, 0.28), 0.12 + rng.exponential(0.16))
    return crunch8(buf)


def circle(soft=False):
    # hell's next circle, in the dark (modules/y2k/CircleTransition): one low, heavy hit —
    # a sub thump falling from 70 to 30 Hz, a dull body of filtered noise, a deep iron
    # resonance under it and a long dark tail, as if a door the size of a wall shut far
    # below. `soft` (Settings → Game → calm): a slow swell instead of the blow, quieter
    sec = 3.4
    buf = np.zeros(int(sec * RATE))
    t = t_axis(1.8)
    f = 30 + 40 * np.exp(-t * 5)
    sub = np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * 2.2)
    if soft:
        sub = sub * np.clip(t / 0.35, 0, 1)
    place(buf, sub * 1.0, 0.0)
    if not soft:
        body = lowpass(noise(0.3, 61), 320) * np.exp(-t_axis(0.3) * 14)
        place(buf, body * 0.9, 0.0)
    ring = bell(55.0, 2.6, index=0.6, ratio=2.76, decay=1.6) * (0.25 if soft else 0.35)
    place(buf, ring, 0.02)
    place(buf, bell(41.2, 2.8, index=0.4, ratio=1.5, decay=1.2) * 0.3, 0.05)
    buf = lowpass(echo(buf, 0.31, 0.42, 5), 900 if soft else 1600)
    return buf


def pip(freq, duty, sec, drop, grit=0.0, seed=1):
    t = t_axis(sec)
    x = pulse(freq, freq * drop, sec, duty)
    if grit:
        x = x * (1 - grit) + lfsr(sec, 4, seed=seed) * grit
    # 8-bit steps, then the fizz taken off: a raw square pip hurts at any volume
    return lowpass(crunch8(x * np.exp(-t * 18) * env(len(t), 0.002, 0.012)), 3800)


def voice_angel():
    # Undertale-style pip for the angel: a bright, short 1/4-duty square
    return pip(880, 0.25, 0.045, 0.97)


def voice_demon():
    # the demon's: lower, half-duty, dropping, with a little noise in it
    return pip(300, 0.5, 0.055, 0.85, grit=0.18, seed=5)


# her broken voice past cold (story/game.json → angel.fallen; AngelHelper plays one on each
# vowel she types): a short syllable — a consonant's onset, then a sung vowel with a whining
# pitch that trembles and sags, as in the choir (formant-shaped harmonics) — driven through a
# hard waveshaper and an 8-bit crush, ring-modulated a little (the wrong, metallic edge), then
# the fizz cut off: two low-passes at ~2.4 kHz. Unpleasant in kind, not in level: LOUDNESS
# keeps it under her pips' level on a whole sentence.
FALLEN = (
    # onset, vowel formants (F1, F2, F3), start Hz → end Hz, length s
    ("m", ((800, 1200, 2800)), 330, 255, 0.15),   # "ma"
    ("n", ((560, 2050, 2850)), 360, 290, 0.13),   # "ne"
    ("h", ((520, 880, 2600)), 300, 230, 0.17),    # "ho"
    ("m", ((390, 900, 2500)), 345, 300, 0.14),    # "mu"
    ("n", ((360, 2500, 3100)), 390, 310, 0.12),   # "ni"
)


def voice_fallen(i):
    onset, formants, f_start, f_end, sec = FALLEN[i]
    n = int(sec * RATE)
    t = np.arange(n) / RATE
    rng = np.random.default_rng(70 + i)
    # the whine: a glide down with a sob in it (a quick tremble that widens as it sags)
    f0 = f_start * (f_end / f_start) ** (t / sec)
    f0 = f0 * (1 + (0.012 + 0.03 * t / sec) * np.sin(2 * np.pi * 9.5 * t + rng.uniform(0, 6.28)))
    phase = 2 * np.pi * np.cumsum(f0) / RATE
    vowel = np.zeros(n)
    for k in range(1, 30):
        fk = f_start * k
        if fk > 5000:
            break
        amp = sum(g / (1 + ((fk - fc) / bw) ** 2) for fc, bw, g in zip(formants, (90, 120, 200), (1.0, 0.55, 0.25)))
        vowel += np.sin(k * phase) * amp / k ** 0.2
    on = int(0.035 * RATE)
    if onset == "h":
        # a breath before the vowel
        head = lowpass(noise(0.05, 80 + i), 1800) * 0.5
        vowel[:len(head)] = vowel[:len(head)] * np.linspace(0, 1, len(head)) + head * np.linspace(1, 0.2, len(head))
    else:
        # a hum through the nose: the fundamental and a low formant, closed mouth
        hum = np.sin(phase[:on]) * 0.8 + np.sin(2 * phase[:on]) * 0.3
        vowel[:on] = vowel[:on] * np.linspace(0.05, 1, on) + hum * np.linspace(1, 0, on)
    x = vowel * env(n, 0.006, 0.05)
    x = x / (np.max(np.abs(x)) or 1)
    # broken: overdriven, crushed, a little ring modulation
    x = np.tanh(x * 5.0) + 0.25 * np.sign(x) * (np.abs(x) > 0.6)
    x = crunch8(x, levels=24, hold=3)
    x = x * (1 - 0.3 + 0.3 * np.sin(2 * np.pi * 63 * t))
    # the harsh top after the distortion cut off
    return lowpass(lowpass(x, 2400), 2600) * env(n, 0.004, 0.04)


# the harp menu's strings (modules/background/HarpLook): C Lydian up from middle C, heaven's
# mode (the raised fourth), the first string — by the pillar, the longest — the lowest
HARP = (60, 62, 64, 66, 67, 69, 71, 72, 74, 76, 78, 79, 81, 83, 84, 86)


def pluck(freq, seed=1):
    """a plucked string (Karplus–Strong): a burst of soft noise in a delay line one period
    long, averaged with itself on every pass — the highs die first and the string rings out.
    Plucked by a finger, not a pick (the burst low-passed), a third of the way along (a
    comb thins those harmonics), the soundboard's warmth under it (its fundamental); the
    low strings ring longer (to -60 dB in ~2.6 s, the top one in ~1 s)"""
    t60 = 2.6 - 1.6 * min(1.0, max(0.0, (freq - 260) / 900))
    sec = min(2.2, t60 * 0.7 + 0.35)
    n = int(sec * RATE)
    p = max(2, int(round(RATE / freq - 0.5)))      # the averaging adds half a sample
    g = 10 ** (-3 * (p + 0.5) / RATE / t60)
    y = np.zeros(n + p + 1)
    burst = lowpass(noise((p + 1) / RATE, seed), 2600)[:p + 1]
    y[:len(burst)] = burst - burst.mean()
    k = p + 1
    while k < len(y):
        # a period at a time: every sample of it reads the period before
        i = np.arange(k, min(len(y), k + p))
        y[i] = g * 0.5 * (y[i - p] + y[i - p - 1])
        k += p
    y = y[:n]
    b = max(1, int(round(p * 0.3)))
    y[b:] = y[b:] - 0.6 * y[:-b]
    t = t_axis(sec)
    body = np.sin(2 * np.pi * freq * t) * np.exp(-t * 6.9 / t60) * 0.35 * np.max(np.abs(y))
    return echo((y + body) * env(n, 0.002, 0.3), 0.11, 0.18, 2)


def harp_string(i):
    return pluck(note(HARP[i]), seed=40 + i)


def harp():
    # the preview in Settings: a glissando up all sixteen, as the menu plays it when it
    # opens (one string every 34 ms), from the strings as levelled; turned down only if
    # they pile up past -3 dBFS
    notes = [level(harp_string(i), PEAKS["harp%d" % (i + 1)], LOUDNESS.get("harp%d" % (i + 1), -20.0)) for i in range(16)]
    buf = np.zeros(int((0.034 * 15 + max(len(x) for x in notes) / RATE) * RATE))
    for i, x in enumerate(notes):
        place(buf, x, i * 0.034)
    m = np.max(np.abs(buf)) or 1.0
    return buf * min(1.0, 10 ** (-3 / 20) / m)


def voice():
    # the preview in Settings: "pip pip pip" of each
    buf = np.zeros(int(1.0 * RATE))
    for i in range(4):
        place(buf, voice_angel(), 0.04 + i * 0.07)
    for i in range(4):
        place(buf, voice_demon(), 0.52 + i * 0.08)
    return buf


SOUNDS = {"startup": startup, "notify": notify, "error": error, "click": click, "shutdown": shutdown, "angel": angel,
          "wallpaper": wallpaper, "open": open_, "toggle": toggle, "screenshot": screenshot, "volume": volume,
          "windowClose": window_close, "demon": demon, "crack": crack, "choir": choir, "rocks": rocks,
          "shatter": shatter, "voice": voice, "voiceAngel": voice_angel, "voiceDemon": voice_demon,
          "voiceFallen1": lambda: voice_fallen(0), "voiceFallen2": lambda: voice_fallen(1),
          "voiceFallen3": lambda: voice_fallen(2), "voiceFallen4": lambda: voice_fallen(3),
          "voiceFallen5": lambda: voice_fallen(4),
          "clickRight": click_right, "key": key, "key2": lambda: key(1), "key3": lambda: key(2),
          "windowOpen": window_open, "workspace": workspace, "lock": lock, "unlock": unlock,
          "usbIn": usb_in, "usbOut": usb_out, "bark": bark, "circle": circle,
          "circleSoft": lambda: circle(True), "harp": harp,
          "achievement": achievement}
SOUNDS.update({"harp%d" % (i + 1): (lambda i=i: harp_string(i)) for i in range(16)})
# played by QtMultimedia's SoundEffect, which only takes .wav
WAV_ONLY = {"voiceAngel", "voiceDemon", "voiceFallen1", "voiceFallen2", "voiceFallen3", "voiceFallen4", "voiceFallen5"} | {"harp%d" % (i + 1) for i in range(16)}
# levelled already (the harp's glissando: its strings as they are)
AS_IS = {"harp"}


def write_wav(path, x):
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    stereo = np.repeat(pcm[:, None], 2, axis=1)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(stereo.tobytes())


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else Path.home() / ".local/share/angelos/sounds/y2k")
    out.mkdir(parents=True, exist_ok=True)
    ffmpeg = shutil.which("ffmpeg")
    made = {}
    only = set(sys.argv[2:])
    for name, fn in SOUNDS.items():
        if only and name not in only:
            continue
        x = fn() if name in AS_IS else level(fn(), PEAKS.get(name, -6.0), LOUDNESS.get(name, -20.0))
        wav = out / (name + ".wav")
        write_wav(wav, x)
        if ffmpeg and name not in WAV_ONLY:
            ogg = out / (name + ".ogg")
            r = subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "5", str(ogg)])
            if r.returncode == 0:
                wav.unlink()
                made[name] = str(ogg)
                continue
        made[name] = str(wav)
    if not only:
        (out / ".version").write_text(PACK_VERSION + "\n")
    print(json.dumps({"ok": True, "sounds": made}))


if __name__ == "__main__":
    main()
