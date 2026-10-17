#!/usr/bin/env python3
"""The flip phone's sounds (modules/sidebar/Phone, services/PhoneLine), synthesised: a phone of
2002 with a one-voice beeper, no samples.

  phone-sounds.py pack DIR            every short sound into DIR (once; `v2` marks it done):
                                      key0…key9, keyStar, keyHash (DTMF pairs), clack (the lid
                                      shut), click (the lid open), buzz (the vibration motor),
                                      sms (the message beep), busy (the wrong number's three
                                      tones), eat and die (Snake), shutter (the camera), hiss (the
                                      voicemail's line), boot (the phone coming on), low (the
                                      battery running out), plug (the charger in), and note48…note95 (one beeper
                                      note each, C3…B6, for the composer's keys)
  phone-sounds.py melody SPEC OUT     a whole melody into one file: SPEC in the composer's words,
                                      "8c2 8e2 4g2 2-" — duration (1 2 4 8 16 32), # for sharp,
                                      the note (c d e f g a b, - a rest), the octave (1 2 3)
"""
import math
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 22050
VERSION = "v4"


def save(path, x):
    x = np.clip(x, -1, 1)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((x * 32767 * 0.85).astype("<i2").tobytes())


def t(sec):
    return np.arange(int(RATE * sec)) / RATE


def env(n, attack=0.004, release=0.03):
    e = np.ones(n)
    a, r = int(RATE * attack), int(RATE * release)
    if a:
        e[:a] = np.linspace(0, 1, a)
    if r and r < n:
        e[-r:] = np.linspace(1, 0, r)
    return e


def square(f, sec, duty=0.5):
    ph = (t(sec) * f) % 1.0
    return np.where(ph < duty, 1.0, -1.0)


def beeper(f, sec):
    """a phone's piezo: a square, a little softened, that dies away a touch"""
    x = square(f, sec, 0.5) * 0.5 + square(f * 2, sec, 0.5) * 0.08
    decay = np.exp(-t(sec) * 2.2)
    return x * env(len(x), 0.003, 0.02) * (0.6 + 0.4 * decay)


DTMF = {"1": (697, 1209), "2": (697, 1336), "3": (697, 1477), "4": (770, 1209), "5": (770, 1336),
        "6": (770, 1477), "7": (852, 1209), "8": (852, 1336), "9": (852, 1477), "Star": (941, 1209),
        "0": (941, 1336), "Hash": (941, 1477)}


def pack(out):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    for name, (lo, hi) in DTMF.items():
        s = t(0.12)
        x = (np.sin(2 * math.pi * lo * s) + np.sin(2 * math.pi * hi * s)) * 0.35
        save(out / f"key{name}.wav", x * env(len(x), 0.002, 0.02))
    # the lid shut: a plastic knock and a small spring
    s = t(0.09)
    knock = np.random.default_rng(3).uniform(-1, 1, len(s)) * np.exp(-s * 90) * 0.7
    knock += np.sin(2 * math.pi * 180 * s) * np.exp(-s * 60) * 0.6
    knock += np.sin(2 * math.pi * 2400 * s) * np.exp(-s * 140) * 0.2
    save(out / "clack.wav", knock)
    # the lid open: a lighter tick
    s = t(0.05)
    tick = np.random.default_rng(5).uniform(-1, 1, len(s)) * np.exp(-s * 160) * 0.45
    tick += np.sin(2 * math.pi * 3200 * s) * np.exp(-s * 120) * 0.25
    save(out / "click.wav", tick)
    # the motor: a low wobbling hum
    s = t(0.42)
    hum = np.sin(2 * math.pi * 150 * s + 3 * np.sin(2 * math.pi * 23 * s))
    hum = np.sign(hum) * np.abs(hum) ** 0.6 * 0.35
    save(out / "buzz.wav", hum * env(len(hum), 0.02, 0.06))
    # a message: two quick beeps
    save(out / "sms.wav", np.concatenate([beeper(1760, 0.08), np.zeros(int(RATE * 0.05)), beeper(2093, 0.12)]))
    # the number is wrong: three rising tones
    save(out / "busy.wav", np.concatenate([beeper(f, 0.28) for f in (950, 1400, 1800)]) * 0.8)
    # Snake: a bite and the end
    save(out / "eat.wav", beeper(1568, 0.05))
    save(out / "die.wav", np.concatenate([beeper(f, 0.09) for f in (523, 392, 262)]))
    # the camera: a fake shutter, a click and a short whirr, as the phones of 2002 played it
    s = t(0.16)
    shut = np.random.default_rng(9).uniform(-1, 1, len(s)) * (np.exp(-s * 70) + 0.5 * np.exp(-np.maximum(0, s - 0.07) * 90) * (s > 0.07)) * 0.6
    save(out / "shutter.wav", shut)
    # the voicemail's bad line: a band of noise that swells and drops
    s = t(0.22)
    hiss = np.random.default_rng(11).uniform(-1, 1, len(s))
    hiss = np.convolve(hiss, np.ones(3) / 3, "same") * (0.5 + 0.5 * np.sin(2 * math.pi * 7 * s)) * 0.32
    save(out / "hiss.wav", hiss * env(len(hiss), 0.02, 0.05))
    # coming on: a little rising fanfare; the battery low: two falling beeps
    save(out / "boot.wav", np.concatenate([beeper(f, 0.1) for f in (1047, 1319, 1568)] + [beeper(2093, 0.22)]))
    save(out / "low.wav", np.concatenate([beeper(1175, 0.12), np.zeros(int(RATE * 0.06)), beeper(880, 0.2)]))
    # the charger in: a click and a short chirp
    s = t(0.12)
    plug = np.random.default_rng(13).uniform(-1, 1, len(s)) * np.exp(-s * 120) * 0.5
    plug += beeper(2637, 0.12) * (s > 0.05) * 0.5
    save(out / "plug.wav", plug)
    for m in range(48, 96):
        save(out / f"note{m}.wav", beeper(440 * 2 ** ((m - 69) / 12), 0.22))
    (out / VERSION).write_text("ok\n")


NOTES = {"c": 0, "d": 2, "e": 4, "f": 5, "g": 7, "a": 9, "b": 11, "h": 11}


def parse(spec):
    """the composer's words → [(midi or None, beats)]; a whole note is four beats"""
    out = []
    for tok in spec.split():
        tok = tok.strip().lower()
        i = 0
        while i < len(tok) and tok[i].isdigit():
            i += 1
        dur = int(tok[:i] or 4)
        rest = tok[i:]
        sharp = rest.startswith("#")
        if sharp:
            rest = rest[1:]
        if not rest:
            continue
        dot = rest.endswith(".")
        rest = rest.rstrip(".")
        beats = 4 / max(1, dur) * (1.5 if dot else 1)
        if rest[0] == "-":
            out.append((None, beats))
            continue
        name, octave = rest[0], int(rest[1:] or 1)
        if name not in NOTES:
            continue
        out.append((48 + 12 * (octave - 1) + NOTES[name] + (1 if sharp else 0), beats))
    return out


def melody(spec, path, bpm=160):
    beat = 60 / bpm
    parts = []
    for midi, beats in parse(spec):
        sec = beats * beat
        if midi is None:
            parts.append(np.zeros(int(RATE * sec)))
            continue
        tone = beeper(440 * 2 ** ((midi - 69) / 12), sec * 0.88)
        parts.append(np.concatenate([tone, np.zeros(int(RATE * sec) - len(tone))]))
    save(path, np.concatenate(parts) if parts else np.zeros(int(RATE * 0.1)))


def main():
    a = sys.argv[1:]
    if len(a) == 2 and a[0] == "pack":
        if not (Path(a[1]) / VERSION).exists():
            pack(a[1])
        return 0
    if len(a) == 3 and a[0] == "melody":
        melody(a[1], a[2])
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
