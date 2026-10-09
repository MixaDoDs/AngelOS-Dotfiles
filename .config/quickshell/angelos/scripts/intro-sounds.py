#!/usr/bin/env python3
"""The first run's intro (modules/settings/SetupIntro.qml): its minute of sound, mixed here.

  intro-sounds.py <dir>     writes intro.ogg plink.ogg (once: again when VERSION changes) and
                            timeline.json, prints JSON. Yours of the same name in
                            <dir>/../intro-own/ (intro plink doki; ogg wav mp3 flac opus) play instead.

intro.ogg   the minute before the setup wizard, exactly LENGTH seconds, cut off at its loudest. From
            data/sounds/intro (CC0, SOURCES.md): an endless Shepard tone rising all the way, a dark
            atmosphere, a horror violin from the middle, a heartbeat ever faster, a fire catching and
            crackling nearer, women screaming far, far away and a crowd in agony behind them, booms
            with the screen's shakes, a big burning tree falling with «Я тут», a whisper played
            backwards into each of the four frames the ophanim flashes in (from where it flashes), a
            riser, a choir swelling backwards into a choir and a bell and a boom as it rises for good,
            the long riser peaking right at the cut with a sub under it.
            Synthesised: a noise riser, a sub-bass drone, the ears ringing after the fall, a breath in.
plink.ogg   the 8-bit plink as it all stops
            (the wizard's tune is data/sounds/intro/music.ogg as it is: a seamless loop)
timeline.json  when the shakes, the words, the ophanim and the end come (the shell plays the
            pictures to it) and which files play

Everything is seeded: the same files every time. The version goes into <dir>/.version last;
they are made again when it is older (VERSION) or missing.
"""
import json
import math
import shutil
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

VERSION = "5"
RATE = 48000
LENGTH = 60.0
HELLO = 15.0
HERE = 25.0
FIRE = 18.0
OPHANIM = 50.0
# the ophanim flashing in for a frame (SetupIntroScreen), half out of sight at an edge:
# (time, x, y) — x, y 0…1 across the screen, one of them 0 or 1 (that edge)
GLIMPSES = [(22.0, 0.0, 0.3), (33.0, 1.0, 0.75), (41.0, 0.35, 0.0), (47.0, 1.0, 0.2)]
# the shakes: (time, strength 0…1); the tree's fall and the ophanim are the big ones
SHAKES = [(8.0, 0.25), (17.5, 0.35), (HERE, 0.9), (35.0, 0.4), (39.0, 0.5), (44.0, 0.55), (47.0, 0.6),
          (OPHANIM, 0.85), (53.0, 0.65), (55.0, 0.7), (56.5, 0.75), (57.5, 0.8), (58.5, 0.9), (59.2, 1.0)]
# eyelids closing for a moment early on (waking up)
BLINKS = [1.6, 4.4, 7.4]
# the screams far away: (time, voice, pan)
SCREAMS = [(12.0, "scream-woman", -0.6), (20.5, "scream-girl", 0.5), (29.5, "scream-macbeth", -0.2),
           (35.5, "scream-woman", 0.7), (40.0, "scream-girl", -0.7), (46.0, "scream-macbeth", 0.3),
           (49.5, "scream-woman", -0.4), (52.5, "scream-girl", 0.6), (55.0, "scream-macbeth", -0.1),
           (56.8, "scream-woman", 0.4)]
SRC = Path(__file__).resolve().parent.parent / "data" / "sounds" / "intro"

rng = np.random.default_rng(1108)


def n_of(sec):
    return int(round(sec * RATE))


def t_axis(n):
    return np.arange(n) / RATE


def nextpow2(n):
    return 1 << (int(n) - 1).bit_length()


def fft_filter(x, gain):
    """x (n,) or (n, 2) filtered by gain(freqs)."""
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


def peak(fc, bw):
    return lambda f: 1 / (1 + ((f - fc) / (bw / 2)) ** 2)


def band(lo, hi):
    return lambda f: highpass(lo)(f) * lowpass(hi)(f)


def convolve(x, ir):
    n = len(x) + len(ir) - 1
    size = nextpow2(n)
    return np.fft.irfft(np.fft.rfft(x, size, axis=0) * np.fft.rfft(ir, size, axis=0), size, axis=0)[:n]


def reverb_ir(sec, decay, bright):
    n = n_of(sec)
    tt = t_axis(n)
    ir = rng.standard_normal((n, 2)) * np.exp(-tt / decay)[:, None]
    ir = fft_filter(ir, lowpass(bright, 1))
    ir[0] += 0.0
    return ir / np.sqrt((ir ** 2).sum(axis=0, keepdims=True))


def pan(x, p):
    """mono → stereo, p −1 (left) … 1 (right), equal power."""
    a = (p + 1) * math.pi / 4
    return np.stack([x * math.cos(a), x * math.sin(a)], axis=1)


def add(track, at, sound):
    i = n_of(at)
    if i >= len(track):
        return
    j = min(len(track), i + len(sound))
    track[i:j] += sound[: j - i]


def exp_env(n, decay, attack=0.002):
    tt = t_axis(n)
    return np.minimum(1, tt / attack) * np.exp(-tt / decay)



# ---------------------------------------------------------------- synthesised

def noise_riser(n):
    """white noise through a band climbing 300 Hz → 9 kHz over the last 30 s, louder and louder."""
    out = np.zeros((n, 2))
    block = n_of(0.05)
    win = np.hanning(block * 2)
    noise = rng.standard_normal((n + block * 2, 2))
    start = LENGTH - 30
    for b in range(0, n, block):
        tsec = b / RATE
        if tsec < start:
            continue
        k = (tsec - start) / 30
        fc = 300 * (30 ** k)
        seg = noise[b:b + block * 2] * win[:, None]
        seg = fft_filter(seg, peak(fc, fc * 0.9))
        j = min(n, b + block * 2)
        out[b:j] += seg[: j - b] * (k ** 2.2)
    return out * 0.11


def drone(n):
    tt = t_axis(n)
    k = tt / LENGTH
    x = np.sin(2 * np.pi * 41.2 * tt) + np.sin(2 * np.pi * 41.7 * tt + 1) + 0.35 * np.sin(2 * np.pi * 82.4 * tt)
    x = np.tanh(1.6 * x) * (0.05 + 0.95 * k ** 1.4)
    return pan(x, 0) * 0.26



# ---------------------------------------------------------------- the recordings

_cache = {}


def sample(name):
    """a sound of SRC as float stereo at RATE, its peak at 1."""
    if name not in _cache:
        raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", str(SRC / f"{name}.ogg"), "-f", "f32le", "-ac", "2",
                              "-ar", str(RATE), "-"], capture_output=True).stdout
        x = np.frombuffer(raw, np.float32).reshape(-1, 2).astype(np.float64)
        _cache[name] = x / (np.abs(x).max() + 1e-9)
    return _cache[name]


def faded(x, fin=0.0, fout=0.0):
    x = x.copy()
    a, b = min(len(x), n_of(fin)), min(len(x), n_of(fout))
    if a:
        x[:a] *= np.linspace(0, 1, a)[:, None]
    if b:
        x[-b:] *= np.linspace(1, 0, b)[:, None]
    return x


def bed(name, n, at, fin, cross=2.0, until=None):
    """a sound laid from `at` (to `until` or the end), looped with a crossfade when short."""
    x = sample(name)
    end = n if until is None else min(n, n_of(until))
    out = np.zeros((n, 2))
    pos = n_of(at)
    first = True
    c = n_of(cross)
    while pos < end:
        piece = faded(x, fin if first else cross, cross)
        j = min(end, pos + len(piece))
        out[pos:j] += piece[: j - pos]
        pos += len(piece) - c
        first = False
    if until is not None:
        f = n_of(cross)
        out[max(0, end - f):end] *= np.linspace(1, 0, end - max(0, end - f))[:, None]
    return out


def envelope(name):
    x = np.abs(sample(name)).mean(axis=1)
    w = n_of(0.05)
    return np.convolve(x, np.ones(w) / w, "same")


def loudest(name):
    """where a sound is loudest, s."""
    return int(np.argmax(envelope(name))) / RATE


def onset(name, frac=0.3):
    """where a sound really starts, s."""
    env = envelope(name)
    return int(np.argmax(env > env.max() * frac)) / RATE


def land(track, name, at, gain, by=loudest):
    """lay a sound so that its loudest moment (or its start) falls on `at`."""
    add(track, at - by(name), sample(name) * gain)


def riser(track, name, at, gain):
    """lay a riser so that it peaks on `at`, cut off right there."""
    p = loudest(name)
    add(track, at - p, sample(name)[: n_of(p)] * gain)


def ramp(n, at, to, a, b, power=1.0):
    """a gain from `a` at `at` to `b` at `to` (s), held outside."""
    tt = t_axis(n)
    k = np.clip((tt - at) / max(1e-6, to - at), 0, 1) ** power
    return (a + (b - a) * k)[:, None]


def far(x, n):
    """far, far away: the lows and the highs gone, mostly the hall's echo."""
    x = fft_filter(x, band(250, 1800))
    wet = convolve(x, reverb_ir(3.2, 0.95, 2400))[:n]
    return x * 0.2 + wet * 0.6


def heartbeat(n):
    """one beat, again and again, ever faster and louder."""
    beat = sample("heartbeat")
    out = np.zeros((n, 2))
    t = 2.0
    while t < LENGTH - 0.3:
        k = t / LENGTH
        bpm = 56 + 100 * k ** 1.8
        add(out, t, beat * (0.3 + 0.7 * k))
        t += 60 / bpm
    return out


def screams(n):
    out = np.zeros((n, 2))
    for i, (at, name, p) in enumerate(SCREAMS):
        x = sample(name)
        if len(x) > n_of(3.5):          # a piece of a long one
            a = n_of(rng.uniform(0, len(x) / RATE - 3.0))
            x = x[a:a + n_of(rng.uniform(1.8, 3.0))]
        x = faded(x, 0.05, 0.4).mean(axis=1)
        add(out, at, pan(x * (0.55 + 0.45 * at / LENGTH), p))
    # a crowd in agony behind them, from the middle on
    out += bed("crowd", n, 34.0, 6.0) * ramp(n, 34, 60, 0.15, 0.5)
    mix = far(out, n)
    return mix / (np.abs(mix).max() + 1e-9)


def ringing():
    """the ears ringing after the fall."""
    m = n_of(6.0)
    tt = t_axis(m)
    x = np.sin(2 * np.pi * 4150 * tt) * np.exp(-tt / 1.8) * np.minimum(1, tt / 0.05)
    return pan(x * 0.05, 0)


def whisper(i, p):
    """a breath of whispering played backwards: it swells and stops dead on the frame, close by,
    from `p` (pan), a short room after it."""
    x = sample("whisper" if i % 2 == 0 else "whisper-2").mean(axis=1)
    c = np.concatenate([[0], np.cumsum(np.abs(x))])
    env = c[n_of(0.9):] - c[: -n_of(0.9)]
    loud = np.flatnonzero(env > env.max() * 0.6)
    a = int(loud[rng.integers(len(loud))])
    piece = x[a:a + n_of(0.9)][::-1].copy()
    piece *= np.linspace(0, 1, len(piece)) ** 2.5
    piece[-n_of(0.004):] *= np.linspace(1, 0, n_of(0.004))
    piece = fft_filter(piece, highpass(180))
    dry = pan(piece / (np.abs(piece).max() + 1e-9), p)
    wet = convolve(dry, reverb_ir(1.4, 0.35, 5000))
    out = wet * 0.35
    out[: len(dry)] += dry
    return out, len(dry) / RATE


def pitched(x, semitones):
    """slower and lower (or faster and higher), like a tape."""
    r = 2 ** (semitones / 12)
    src = np.arange(0, len(x) - 1, r)
    return np.stack([np.interp(src, np.arange(len(x)), x[:, c]) for c in range(x.shape[1])], axis=1)


def choir():
    """the ophanim's choir: the chord swelling backwards into it, then the choir itself a tone
    low, a little burnt, in a big hall. Laid with its turn on the start."""
    body = sample("choir") * 0.8
    swell = sample("choir-swell")[: len(body)]
    body[: len(swell)] += swell * 0.6
    fwd = pitched(body, -2)
    fwd = np.tanh(2.2 * fwd) / math.tanh(2.2)
    back = fwd[::-1] * (np.linspace(0, 1, len(fwd)) ** 2)[:, None]
    hall = reverb_ir(4.5, 1.6, 3800)
    wet = convolve(fwd, hall)
    out = np.zeros((len(back) + len(wet), 2))
    out[: len(back)] += back
    out[len(back): len(back) + len(fwd)] += fwd
    out[len(back):] += wet * 0.5
    return out / (np.abs(out).max() + 1e-9), len(back) / RATE


BOOMS = ["boom-1", "boom-2", "boom-4", "boom-3"]


def intro():
    n = n_of(LENGTH)
    mix = np.zeros((n, 2))
    # the rise: the Shepard tone all the way, louder and louder
    shepard = np.zeros((n, 2))
    sh = sample("shepard")[:n]
    shepard[: len(sh)] = sh
    mix += shepard * ramp(n, 0, LENGTH, 0.18, 0.75, 1.3)
    mix += bed("atmosphere", n, 0.0, 3.0) * ramp(n, 0, LENGTH, 0.35, 0.25)
    mix += bed("violin", n, 28.0, 4.0, until=57.0) * 0.3
    mix += heartbeat(n) * 0.55
    # the fire: it catches, crackles nearer, roars at the end
    mix += bed("fire", n, FIRE, 3.0) * ramp(n, FIRE, LENGTH, 0.15, 0.5)
    mix += bed("fire-roar", n, 30.0, 6.0) * ramp(n, 30, LENGTH, 0.1, 0.45)
    add(mix, FIRE - 0.2, faded(sample("fire-roar")[: n_of(2.5)], 0.4, 1.5) * 0.4)
    mix += screams(n) * 0.28
    mix += noise_riser(n) * 0.5 + drone(n) * 0.8
    # the shakes' booms
    for i, (at, s) in enumerate(SHAKES):
        if at in (HERE, OPHANIM):
            continue
        land(mix, BOOMS[i % len(BOOMS)], at, 0.2 + 0.55 * s, by=onset if BOOMS[i % len(BOOMS)] != "boom-3" else loudest)
    # the tree: it creaks, cracks and falls on «Я тут», the fire flares, the ears ring
    land(mix, "tree", HERE, 0.9)
    land(mix, "tree-crack", HERE - 0.15, 0.55)
    land(mix, "boom-2", HERE, 0.5, by=onset)
    add(mix, HERE + 0.1, faded(sample("fire-roar")[: n_of(3.0)], 0.2, 2.0) * 0.45)
    add(mix, HERE + 0.4, ringing())
    # the ophanim's frames: a whisper backwards into each, from its side
    for i, (at, x, _y) in enumerate(GLIMPSES):
        w, turn = whisper(i, (x * 2 - 1) * 0.85)
        add(mix, at - turn, w * (0.6 + 0.4 * at / LENGTH))
    # the ophanim rising for good: a riser into it, the choir swelling backwards into the choir,
    # the bell, a boom
    riser(mix, "rise-mid", OPHANIM, 0.4)
    c, turn = choir()
    add(mix, OPHANIM - turn, c * 0.9)
    land(mix, "bell", OPHANIM, 0.75, by=onset)
    land(mix, "boom-4", OPHANIM, 0.55, by=onset)
    # the end: the long riser peaks right at the cut, the sub under it, a breath in
    riser(mix, "rise-final", LENGTH, 0.8)
    sub = sample("sub")
    add(mix, LENGTH - len(sub) / RATE, sub * 0.7)
    m = n_of(1.2)
    tt = t_axis(m)
    gasp = fft_filter(rng.standard_normal((m, 2)), band(900, 6000)) * ((tt / 1.2) ** 3)[:, None]
    add(mix, LENGTH - 1.2, gasp / (np.abs(gasp).max() + 1e-9) * 0.15)
    mix = np.tanh(1.25 * mix) / math.tanh(1.25)
    return mix / (np.abs(mix).max() + 1e-9) * 0.8


def plink():
    return sample("plink") * 0.75


# ---------------------------------------------------------------- writing

def write(path, x):
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    wav = path.with_suffix(".wav")
    with wave.open(str(wav), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    if shutil.which("ffmpeg"):
        ogg = path.with_suffix(".ogg")
        r = subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "6", str(ogg)])
        if r.returncode == 0:
            wav.unlink()
            return ogg
    return wav


def own_file(out, name):
    """yours first: <dir>/../intro-own/<name>.(ogg|wav|mp3|flac|opus)"""
    for ext in ("ogg", "wav", "mp3", "flac", "opus"):
        p = out.parent / "intro-own" / f"{name}.{ext}"
        if p.is_file():
            return p
    return None


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    names = (("plink", plink), ("intro", intro))
    have = {p.stem: p for p in out.iterdir() if p.suffix in (".ogg", ".wav")}
    current = (out / ".version").is_file() and (out / ".version").read_text().strip() == VERSION
    if not current or any(n not in have for n, _ in names):
        (out / ".version").unlink(missing_ok=True)
        for name, make in names:
            have[name] = write(out / name, make())
        (out / ".version").write_text(VERSION)
    files = {name: str(own_file(out, name) or have[name]) for name, _ in names}
    files["doki"] = str(own_file(out, "doki") or SRC / "music.ogg")
    timeline = {"length": LENGTH, "hello": HELLO, "here": HERE, "ophanim": OPHANIM, "shakes": SHAKES,
                "glimpses": [{"t": t, "x": x, "y": y} for t, x, y in GLIMPSES],
                "blinks": BLINKS, "screams": [s[0] for s in SCREAMS], "files": files}
    (out / "timeline.json").write_text(json.dumps(timeline))
    print(json.dumps({"dir": str(out), "files": files}))


if __name__ == "__main__":
    main()
