#!/usr/bin/env python3
"""Hell's circles: each sin's two sounds, put on a stage (services/CircleFx plays one of them,
by chance, under the low blow in the dark between the circles — Sounds.playSin).

  hell-sounds.py [OUT]      writes OUT/<circle>-1.ogg and OUT/<circle>-2.ogg
                            (OUT: data/sounds/hell, next to the sources in src/)

The sources are CC0 recordings from Freesound (data/sounds/hell/SOURCES.md). Each one is made
mono, trimmed, and then staged: a path across the stereo field (equal power plus the delay
between the ears, so it sits outside the head and moves), a few early reflections from the
walls on the other side, a stereo reverb of its own length and brightness (four decorrelated
tails, the highs dying first) and for some a ping-pong echo answering from the far side.
The levels are evened out so the sins stand at one loudness over the blow.

Everything is seeded: the same files every time.
"""
import math
import subprocess
import sys
from pathlib import Path

import numpy as np

RATE = 48000
HERE = Path(__file__).resolve().parent.parent / "data" / "sounds" / "hell"
SRC = HERE / "src"

# circle: two sounds — (source, length s, pan path, reverb: seconds / wet / brightness Hz,
# pre-delay ms, echo: (delay s, feedback) or None). A pan path is a list of points −1…1 spread
# over the sound; "orbit" circles round the head.
SINS = {
    "limbo": [
        ("limbo-whisper", 4.0, [-0.9, 0.2, 0.9, -0.3], (3.8, 0.55, 5000, 45), None),
        ("limbo-bell", 6.0, [-0.55, -0.35], (4.5, 0.5, 3500, 60), (0.42, 0.3)),
    ],
    "lust": [
        ("lust-kiss", 0.7, [0.75], (2.2, 0.35, 7000, 20), (0.24, 0.45)),
        ("lust-sigh", 4.0, [-0.7, 0.0, 0.65], (2.6, 0.38, 6000, 25), None),
    ],
    "gluttony": [
        ("gluttony-burp", 1.0, [-0.25, -0.45], (3.0, 0.42, 4000, 35), (0.3, 0.3)),
        ("gluttony-bite", 0.9, [0.55], (2.0, 0.33, 7000, 20), (0.2, 0.4)),
    ],
    "greed": [
        ("greed-coins", 3.2, [-0.9, -0.2, 0.4, 0.9], (2.2, 0.32, 9000, 18), None),
        ("greed-register", 2.8, [0.65], (2.4, 0.33, 8000, 22), (0.26, 0.42)),
    ],
    "wrath": [
        ("wrath-punch", 0.9, [-0.55], (3.0, 0.38, 6000, 15), (0.18, 0.4)),
        ("wrath-yell", 5.0, [0.35, -0.35], (3.6, 0.45, 4500, 40), None),
    ],
    "heresy": [
        ("heresy-fire", 4.9, [0.9, 0.0, -0.9], (2.6, 0.3, 6000, 20), None),
        ("heresy-choir", 4.2, "wide", (4.2, 0.5, 4000, 50), None),
    ],
    "violence": [
        ("violence-slash", 1.4, [-0.85, 0.85], (2.4, 0.32, 8000, 15), (0.22, 0.38)),
        ("violence-bones", 2.3, [0.45, 0.2], (2.2, 0.32, 6000, 18), None),
    ],
    "fraud": [
        ("fraud-laugh", 2.1, "orbit", (3.2, 0.45, 6000, 30), (0.31, 0.35)),
        ("fraud-chuckle", 3.0, [-0.75, -0.6], (2.4, 0.35, 6500, 20), (0.27, 0.4)),
    ],
    "treachery": [
        ("treachery-stab", 2.7, [-0.6, -0.75], (3.0, 0.38, 6000, 25), (0.24, 0.35)),
        ("treachery-ice", 2.5, [-0.7, 0.1, 0.8], (3.8, 0.48, 11000, 35), None),
    ],
}
TAIL = 1.6            # s let ring after the sound, at most (the reverb fades on its own)
PEAK = 10 ** (-3.0 / 20)    # the encoder overshoots a little
LOUD = 10 ** (-15.0 / 20)   # the loudest 300 ms window's RMS
MAX_ITD = 0.00055     # s, the far ear hears it this much later at the side


def load(name):
    out = subprocess.run(["ffmpeg", "-v", "quiet", "-i", str(SRC / (name + ".ogg")), "-f", "f32le", "-ac", "2",
                          "-ar", str(RATE), "-"], capture_output=True, check=True).stdout
    return np.frombuffer(out, dtype=np.float32).reshape(-1, 2).astype(np.float64)


def nextpow2(n):
    return 1 << (int(n) - 1).bit_length()


def fft_filter(x, gain):
    n = len(x)
    size = nextpow2(n)
    spec = np.fft.rfft(x, size, axis=0)
    g = gain(np.fft.rfftfreq(size, 1 / RATE))
    spec *= g[:, None] if x.ndim == 2 else g
    return np.fft.irfft(spec, size, axis=0)[:n]


def lowpass(fc, order=2):
    return lambda f: 1 / np.sqrt(1 + (f / fc) ** (2 * order))


def highpass(fc, order=2):
    return lambda f: 1 / np.sqrt(1 + (fc / np.maximum(f, 1e-3)) ** (2 * order))


def convolve(x, ir):
    n = len(x) + len(ir) - 1
    size = nextpow2(n)
    return np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:n]


def trim(x, sec):
    """from the first sound on, `sec` long, the end faded out."""
    mono = np.abs(x).max(axis=1)
    on = np.flatnonzero(mono > mono.max() * 0.02)
    start = max(0, (on[0] if len(on) else 0) - int(0.004 * RATE))
    x = x[start:start + int(sec * RATE)].copy()
    fade = min(len(x), int(0.25 * RATE))
    x[-fade:] *= np.linspace(1, 0, fade)[:, None] ** 2
    x[: int(0.003 * RATE)] *= np.linspace(0, 1, int(0.003 * RATE))[:, None]
    return x


def path_of(spec, x):
    """pan −1…1 for every sample. A path's points are spread over the sound's energy, not its
    time: a slash that is over in 0.2 s crosses the whole field in those 0.2 s."""
    n = len(x)
    t = np.arange(n) / RATE
    if spec == "orbit":
        # round the head: right, behind to the left, back — a little faster as it goes
        return 0.85 * np.sin(2 * math.pi * (0.55 * t + 0.12 * t * t) + 0.6)
    pts = np.asarray(spec, dtype=float)
    if len(pts) == 1:
        return np.full(n, pts[0])
    energy = np.cumsum(fft_filter(x ** 2, lowpass(8, 1)).clip(0))
    i = energy / (energy[-1] + 1e-12) * (n - 1)
    xs = np.linspace(0, n - 1, len(pts))
    # eased between the points, so a move starts and lands softly
    seg = np.minimum(np.searchsorted(xs, i, side="right") - 1, len(pts) - 2)
    u = (i - xs[seg]) / (xs[seg + 1] - xs[seg])
    u = u * u * (3 - 2 * u)
    return pts[seg] + (pts[seg + 1] - pts[seg]) * u


def delayed(x, d):
    """x read `d` samples late (a fractional delay per sample)."""
    i = np.arange(len(x)) - d
    return np.interp(i, np.arange(len(x)), x, left=0.0)


def place(mono, pan):
    """mono → stereo at `pan` (per sample): equal power, the far ear late and a bit dull."""
    a = (pan + 1) * math.pi / 4
    gl, gr = np.cos(a), np.sin(a)
    itd = np.abs(pan) * MAX_ITD * RATE
    dull = fft_filter(mono, lowpass(5500, 1))
    far = lambda side: (1 - 0.35 * side) * mono + 0.35 * side * dull   # side 0…1: how far round
    left = gl * delayed(far(np.clip(pan, 0, 1)), np.where(pan > 0, itd, 0))
    right = gr * delayed(far(np.clip(-pan, 0, 1)), np.where(pan < 0, itd, 0))
    return np.stack([left, right], axis=1)


def widen(x, k=1.6):
    """a stereo source made wider (mid/side)."""
    m, s = (x[:, 0] + x[:, 1]) / 2, (x[:, 0] - x[:, 1]) / 2
    return np.stack([m + k * s, m - k * s], axis=1)


def tail_ir(sec, bright, rng):
    n = int((sec + 0.1) * RATE)
    t = np.arange(n) / RATE
    noise = rng.standard_normal(n)
    # the highs die first: two bands, the upper one at half the time
    lo = fft_filter(noise, lowpass(1200, 2)) * np.exp(-6.91 * t / sec)
    hi = fft_filter(noise, lambda f: highpass(1200, 2)(f) * lowpass(bright, 1)(f)) * np.exp(-6.91 * t / (sec * 0.5))
    ir = lo + hi
    ir[: int(0.006 * RATE)] *= np.linspace(0, 1, int(0.006 * RATE))
    return ir / np.sqrt((ir ** 2).sum())


def reverb(dry, sec, bright, predelay_ms, rng):
    """a stereo hall: four decorrelated tails (each side its own, a third of the other side),
    early reflections from the walls, mostly from the far side of the sound."""
    a, b, c, d = (tail_ir(sec, bright, rng) for _ in range(4))
    pre = int(predelay_ms / 1000 * RATE)
    n = len(dry) + pre + len(a)
    wet = np.zeros((n, 2))
    left = convolve(dry[:, 0], a) + 0.35 * convolve(dry[:, 1], b)
    right = convolve(dry[:, 1], c) + 0.35 * convolve(dry[:, 0], d)
    wet[pre:pre + len(left), 0] += left
    wet[pre:pre + len(right), 1] += right
    # early reflections: 6 taps 9–48 ms, the louder side swapped (the far wall answers)
    bal = np.sqrt((dry ** 2).mean(axis=0) + 1e-12)
    far = 0 if bal[1] > bal[0] else 1
    mono = dry.mean(axis=1)
    for k in range(6):
        ms = 9 + k * 7.5 + rng.uniform(-2, 2)
        i = int(ms / 1000 * RATE)
        g = 0.32 * (0.82 ** k)
        side = far if k % 3 != 2 else 1 - far
        wet[i:i + len(mono), side] += g * mono
    return wet


def echo(dry, pan_end, delay, fb):
    """a ping-pong echo: first from the far side of where the sound ended, then back and forth."""
    mono = fft_filter(dry.mean(axis=1), lambda f: highpass(250, 1)(f) * lowpass(4500, 1)(f))
    taps = 5
    n = len(dry) + int(delay * taps * RATE) + 1
    out = np.zeros((n, 2))
    side = 0 if pan_end > 0 else 1
    g = 0.55
    for k in range(1, taps + 1):
        i = int(delay * k * RATE)
        out[i:i + len(mono), side] += g * mono
        out[i:i + len(mono), 1 - side] += g * 0.25 * mono
        side = 1 - side
        g *= fb
    return out


def stage(spec, rng):
    name, sec, pan, (rv, wet, bright, pre), ech = spec
    x = trim(load(name), sec)
    if pan == "wide":
        dry = widen(x)
        pan_end = 0.0
    else:
        p = path_of(pan, x.mean(axis=1))
        dry = place(x.mean(axis=1), p)
        pan_end = float(p[-1])
    dry /= np.abs(dry).max() + 1e-9
    rev = reverb(dry, rv, bright, pre, rng)
    # the hall should sit as loud as the sound itself, scaled by `wet`
    rev *= np.sqrt((dry ** 2).sum() / ((rev ** 2).sum() + 1e-12))
    n = len(dry) + int(TAIL * RATE)
    out = np.zeros((max(n, len(dry)), 2))
    out[: len(dry)] += (1 - wet * 0.5) * dry
    m = min(len(out), len(rev))
    out[:m] += wet * 1.4 * rev[:m]
    if ech:
        e = echo(dry, pan_end, *ech)
        m = min(len(out), len(e))
        out[:m] += 0.5 * e[:m]
    # the end of the tail fades to nothing
    fade = int(0.6 * RATE)
    out[-fade:] *= np.linspace(1, 0, fade)[:, None] ** 2
    return level(out)


def level(x):
    w = int(0.3 * RATE)
    power = np.convolve((x ** 2).mean(axis=1), np.ones(w) / w, mode="valid")
    loud = math.sqrt(power.max())
    x = x * (LOUD / (loud + 1e-12))
    pk = np.abs(x).max()
    if pk > PEAK:
        # a soft knee over the peaks (a punch's crack) instead of turning the whole thing down
        x = PEAK * np.tanh(x / PEAK)
    return x


def write(path, x):
    pcm = np.clip(x, -1, 1).astype(np.float32).tobytes()
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ac", "2", "-ar", str(RATE), "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "5", str(path)], input=pcm, check=True)


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE
    out.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(666)
    for circle, two in SINS.items():
        for i, spec in enumerate(two, 1):
            write(out / f"{circle}-{i}.ogg", stage(spec, rng))
            print(f"{circle}-{i}: {spec[0]}")


if __name__ == "__main__":
    main()
