#!/usr/bin/env python3
"""The Golden Gate skin's system sounds: original, synthesised here, in the spirit of a Mac
(short, soft, glassy) — none of Apple's sounds, no samples, nothing downloaded.

  mac-sounds.py [dir] [name…]   writes notify error volume screenshot trash usbIn usbOut
                                power lock login as .ogg (Vorbis through ffmpeg; .wav without
                                it) into dir (default: data/sounds/macos next to this script),
                                prints JSON

The shell ships the result (data/sounds/macos) and plays it with pw-play; a file of the same
name in ~/.local/share/angelos/sounds/macos (yours, e.g. copied from your own Mac) wins
(services/Sounds). The waveforms are numpy, ffmpeg only encodes. Levelled like the Y2K pack
(scripts/y2k-sounds.py): peaks about -6 dBFS, RMS at most -20 dBFS, so they sit under music.
These files are original works of angelOS, dedicated to the public domain (CC0 1.0).
"""
import json
import shutil
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 48000
PACK_VERSION = "1"


def t_axis(sec):
    return np.arange(int(sec * RATE)) / RATE


def env(n, attack=0.003, release=0.05):
    t = np.arange(n) / RATE
    total = n / RATE
    return np.clip(t / max(attack, 1e-4), 0, 1) * np.clip((total - t) / max(release, 1e-4), 0, 1)


def fade(x, ms=6):
    n = min(len(x), int(ms / 1000 * RATE))
    x = x.copy()
    x[-n:] *= np.linspace(1, 0, n)
    return x


def place(buf, sound, at):
    i = int(at * RATE)
    end = min(len(buf), i + len(sound))
    buf[i:end] += sound[:end - i]


def noise(sec, seed):
    return np.random.default_rng(seed).uniform(-1, 1, int(sec * RATE))


def onepole(x, cutoff, high=False):
    """first-order low/high pass"""
    a = np.exp(-2 * np.pi * cutoff / RATE)
    y = np.zeros_like(x)
    prev = 0.0
    for i, v in enumerate(x):
        prev = (1 - a) * v + a * prev
        y[i] = prev
    return x - y if high else y


def band(x, lo, hi, order=1):
    for _ in range(order):
        x = onepole(onepole(x, hi), lo, high=True)
    return x


def lowpass(x, cutoff, order=2):
    for _ in range(order):
        x = onepole(x, cutoff)
    return x


def resonator(x, freq, q):
    """two-pole resonant band pass (a struck plate, a body)"""
    w = 2 * np.pi * freq / RATE
    r = np.exp(-w / (2 * q))
    b1, b2 = 2 * r * np.cos(w), -r * r
    y = np.zeros_like(x)
    y1 = y2 = 0.0
    for i, v in enumerate(x):
        y0 = (1 - r) * v + b1 * y1 + b2 * y2
        y[i] = y0
        y2, y1 = y1, y0
    return y


def partials(freq, sec, spec, glide=0.0):
    """a struck glassy tone: [(ratio, gain, decay per s)], the pitch bending by `glide` (octaves) at the attack"""
    t = t_axis(sec)
    bend = 2 ** (glide * np.exp(-t * 60))
    out = np.zeros_like(t)
    for ratio, gain, decay in spec:
        phase = 2 * np.pi * np.cumsum(freq * ratio * bend) / RATE
        out += np.sin(phase) * gain * np.exp(-t * decay)
    return fade(out, 25)                     # never cut off mid-ring (a click)


GLASS = [(1.0, 1.0, 7.0), (2.76, 0.32, 14.0), (5.4, 0.12, 26.0), (8.93, 0.05, 40.0)]
SOFT = [(1.0, 1.0, 9.0), (2.0, 0.18, 16.0), (3.01, 0.06, 26.0)]


def room(x, mix=0.16):
    """a small, bright room: a few early reflections and a short diffuse tail"""
    out = x.copy()
    for k, (d, g) in enumerate(((0.013, 0.5), (0.021, 0.38), (0.034, 0.27), (0.047, 0.2), (0.071, 0.12))):
        n = int(d * RATE)
        if n < len(x):
            out[n:] += x[:-n] * g * mix * 2
    tail = lowpass(noise(0.25, 7) * np.exp(-t_axis(0.25) * 18), 2800, 3)
    return out + np.convolve(x, tail * 0.003 * mix, mode="full")[:len(x)]


def level(x, peak_db=-6.0, rms_db=-20.0):
    m = np.max(np.abs(x)) or 1.0
    x = x / m * 10 ** (peak_db / 20)
    rms = float(np.sqrt(np.mean(x * x))) or 1.0
    cap = 10 ** (rms_db / 20)
    return x * (cap / rms) if rms > cap else x


def master(x):
    """no DC or rumble (a 35 Hz high pass), no click at either end"""
    x = onepole(x, 35, high=True)
    n = int(0.0004 * RATE)
    x[:n] *= np.linspace(0, 1, n)
    return fade(x, 15)


# ---- the sounds ----

def notify():
    # two glass taps a sixth apart, the second one ringing: light, "something arrived"
    buf = np.zeros(int(0.9 * RATE))
    place(buf, partials(1318.5, 0.5, GLASS) * 0.55, 0.0)
    place(buf, partials(2093.0, 0.85, GLASS, glide=0.02) * 0.8, 0.075)
    return room(buf)


def error():
    # a muted, woody knock and its lower echo: "no" without a buzzer
    buf = np.zeros(int(0.5 * RATE))
    for at, f, g in ((0.0, 311.1, 1.0), (0.11, 233.1, 0.75)):
        tone = partials(f, 0.35, [(1.0, 1.0, 22.0), (2.32, 0.35, 40.0), (4.1, 0.1, 70.0)])
        knock = resonator(noise(0.03, 3) * np.exp(-t_axis(0.03) * 160), f * 2.1, 8) * 1.4
        place(buf, tone * g, at)
        place(buf, knock * g, at)
    return room(onepole(buf, 3200), 0.1)


def volume():
    # the "pop": a short bubble, pitch falling fast, with a tiny click on top
    sec = 0.09
    t = t_axis(sec)
    f = 520 + 640 * np.exp(-t * 70)
    body = np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * 48)
    click = band(noise(0.004, 11), 1500, 5000, 2) * 0.25
    out = body.copy()
    place(out, click, 0.0)
    return fade(out * env(len(out), 0.0015, 0.02))


def screenshot():
    # a camera shutter: the blades opening (a dry click), the mirror's thump, closing (a second click)
    buf = np.zeros(int(0.32 * RATE))

    def blade(seed, bright):
        n = noise(0.018, seed) * np.exp(-t_axis(0.018) * 260)
        return resonator(n, bright, 6) * 2.2 + band(n, 1500, 6000, 2) * 0.35

    place(buf, blade(21, 3600), 0.0)
    thump = resonator(noise(0.05, 22) * np.exp(-t_axis(0.05) * 90), 180, 3) * 1.6
    place(buf, thump, 0.004)
    # the spring's short whirr between the two
    w = band(noise(0.06, 23), 900, 2600, 3) * np.hanning(int(0.06 * RATE)) * 0.12
    place(buf, w, 0.03)
    place(buf, blade(24, 4300) * 0.85, 0.105)
    place(buf, thump * 0.5, 0.108)
    return room(lowpass(buf, 7000, 2), 0.08)


def trash():
    # paper crumpled and dropped: a burst of crackles thinning out, then a soft landing
    sec = 0.85
    buf = np.zeros(int(sec * RATE))
    rng = np.random.default_rng(31)
    t = 0.0
    while t < 0.6:
        density = 1 - t / 0.6
        size = rng.uniform(0.004, 0.018)
        burst = noise(size, int(rng.integers(1 << 30))) * np.exp(-t_axis(size) * rng.uniform(150, 400))
        # paper crinkles: a short ring in the 1.5–3.5 kHz band over a band-limited scratch
        crackle = resonator(burst, rng.uniform(1500, 3500), 5) * 1.6 + band(burst, 700, 4200, 2) * 0.5
        place(buf, crackle * rng.uniform(0.3, 1.0) * (0.35 + density * 0.65), t)
        t += rng.uniform(0.01, 0.04) / (0.4 + density)
    # the rustle under it
    rustle = band(noise(0.6, 32), 800, 3000, 2) * np.exp(-t_axis(0.6) * 5) * 0.12
    place(buf, rustle, 0.0)
    # into the can: a dull, short thud with a little rattle
    thud = resonator(noise(0.12, 33) * np.exp(-t_axis(0.12) * 40), 140, 2.5) * 1.3
    place(buf, thud, 0.62)
    place(buf, band(noise(0.05, 34), 1500, 4000, 2) * np.exp(-t_axis(0.05) * 80) * 0.25, 0.625)
    return room(fade(lowpass(buf, 6500, 2), 40), 0.1)


def usb_in():
    # plugged in: a quick glassy step up
    buf = np.zeros(int(0.5 * RATE))
    place(buf, partials(1046.5, 0.25, SOFT) * 0.7, 0.0)
    place(buf, partials(1568.0, 0.45, GLASS) * 0.8, 0.07)
    return room(buf)


def usb_out():
    # unplugged: the same step, down and softer
    buf = np.zeros(int(0.5 * RATE))
    place(buf, partials(1568.0, 0.25, SOFT) * 0.6, 0.0)
    place(buf, partials(1046.5, 0.45, SOFT) * 0.7, 0.075)
    return room(onepole(buf, 6000))


def power():
    # a charger plugged in: one clear, bright drop of a chime, gliding up a little, with an airy shimmer
    sec = 1.1
    tone = partials(1760.0, sec, [(1.0, 1.0, 4.2), (2.0, 0.22, 7.0), (3.0, 0.08, 11.0), (4.97, 0.05, 18.0)], glide=-0.08)
    shimmer = partials(3520.0 * 1.003, sec, [(1.0, 0.18, 9.0)])
    air = band(noise(sec, 41), 5000, 9000, 2) * np.exp(-t_axis(sec) * 14) * 0.03
    return room(tone + shimmer + air, 0.2)


def lock():
    # the session locked: a small, solid latch — a low click and a higher tick right after
    buf = np.zeros(int(0.22 * RATE))
    low = resonator(noise(0.03, 51) * np.exp(-t_axis(0.03) * 200), 620, 7) * 2.0
    high = resonator(noise(0.02, 52) * np.exp(-t_axis(0.02) * 300), 2400, 9) * 1.2
    body = partials(392.0, 0.12, [(1.0, 1.0, 45.0)]) * 0.35
    place(buf, low, 0.0)
    place(buf, body, 0.0)
    place(buf, high, 0.045)
    return room(buf, 0.06)


def login():
    # logged in (or unlocked): a warm open chord blooming in, a bell on top — calm, not a fanfare
    sec = 1.6
    t = t_axis(sec)
    n = len(t)
    pad = np.zeros(n)
    # D, A, E, F# (an open Dmaj9 voicing), slightly detuned pairs
    for f, g in ((146.83, 0.5), (220.0, 0.42), (329.63, 0.35), (369.99, 0.28), (440.0, 0.22)):
        for d in (-0.0025, 0.0025):
            pad += np.sin(2 * np.pi * f * (1 + d) * t) * g
    swell = np.clip(t / 0.35, 0, 1) ** 1.5 * np.exp(-np.clip(t - 0.35, 0, None) * 2.4)
    pad = onepole(pad * swell, 2600) * 0.32
    buf = pad.copy()
    place(buf, partials(1174.66, 1.2, GLASS) * 0.4, 0.12)
    place(buf, partials(1760.0, 1.0, GLASS) * 0.22, 0.2)
    return room(fade(buf, 120), 0.22)


SOUNDS = {"notify": notify, "error": error, "volume": volume, "screenshot": screenshot, "trash": trash,
          "usbIn": usb_in, "usbOut": usb_out, "power": power, "lock": lock, "login": login}
# RMS ceilings, dBFS: the pop and the latch are tiny, the login chime fuller
LOUDNESS = {"volume": -18.0, "lock": -20.0, "login": -21.0, "trash": -21.0}


def write_wav(path, x):
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    stereo = np.repeat(pcm[:, None], 2, axis=1)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(stereo.tobytes())


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "data/sounds/macos"
    out.mkdir(parents=True, exist_ok=True)
    only = set(sys.argv[2:])
    ffmpeg = shutil.which("ffmpeg")
    made = {}
    for name, fn in SOUNDS.items():
        if only and name not in only:
            continue
        x = master(fn())
        x = level(x, -6.0, LOUDNESS.get(name, -20.0))
        wav = out / (name + ".wav")
        write_wav(wav, x)
        if ffmpeg:
            ogg = out / (name + ".ogg")
            r = subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "6",
                                "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact", str(ogg)])
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
