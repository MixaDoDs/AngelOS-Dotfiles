#!/usr/bin/env python3
"""The first run's intro (modules/settings/SetupIntro.qml): its minute of sound, mixed here.

  intro-sounds.py <dir>     writes prequel.ogg intro.ogg plink.ogg (once: again when VERSION or the
                            user's name changes) and timeline.json, prints JSON. Yours of the same
                            name in <dir>/../intro-own/ (prequel intro plink doki; ogg wav mp3 flac
                            opus) play instead.

prequel.ogg the minutes before that one (SetupPrequel): her room on the night of 31.12.2002. Three
            places in it. Her room, near and plain: the machine's hum and whine, the disk, her music
            from small speakers, his messages arriving, her keys, the pills out of their foil — and
            she herself (recordings, SOURCES.md): a swallow, a cough, a long breath out, and once the
            pills are in, her laugh. Behind the wall, the neighbours' party, muffled: people, a dance
            tune of those years (made here: nobody's song) turned down for the television — the
            author's voice as its announcer, every word to be made out — twelve strokes, a cheer,
            glasses, the tune again. Outside her window: the winter wind in gusts, whistling in the
            frame; fireworks, one now and then and from midnight all of them (the shell lights her
            window by each: PRE["fireworks"]). And in her head, him: the author's voice, a little
            hollow. Then the game's tune in the goggles going wrong cut by cut, the fire nobody
            hears, the tape breaking up, the tone of no signal — a few seconds of it, dying away
            — and what a television of that country played when something had happened and it
            would not say what: «Swan Lake», the little swans, a quarter of a minute (an old
            public-domain record, SOURCES.md; the shell has four of them dance to it:
            PRE["swan"]). A breath before the minute.
            What it builds to is the last second: the game saving, 99 %, his voice cut off in the
            middle of a word. Two quiets on the way: the papers catching (seen close, before she
            laughs), her room burning seen whole.

intro.ogg   the minute before the setup wizard, exactly LENGTH seconds, cut off at its loudest. From
            data/sounds/intro (CC0, SOURCES.md): an endless Shepard tone rising all the way, a dark
            atmosphere, a horror violin from the middle, a heartbeat ever faster, a fire catching and
            crackling nearer, women screaming far, far away and a crowd in agony behind them, booms
            with the screen's shakes, a big burning tree falling with «Я тут», a whisper played
            backwards into each of the four frames the ophanim flashes in (from where it flashes), a
            riser, a choir swelling backwards into a choir and a bell and a boom as it is lit for good,
            then the ophanim reading the user's name a letter at a time (the author's voice, low,
            twice over, in a hall; the rest ducks under it), the long riser peaking right at the cut
            with a sub under it.
            Synthesised: a noise riser, a sub-bass drone, the ears ringing after the fall, a breath in.
plink.ogg   the 8-bit plink as it all stops
            (the wizard's tune is data/sounds/intro/music.ogg as it is: a seamless loop)
timeline.json  when the shakes, the words, the ophanim and the end come (the shell plays the
            pictures to it) and which files play

Everything is seeded: the same files every time. The version goes into <dir>/.version last;
they are made again when it is older (VERSION) or missing.
"""
import getpass
import json
import math
import os
import shutil
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

VERSION = "16"
RATE = 48000
LENGTH = 60.0
HELLO = 15.0
HERE = 25.0
FIRE = 18.0
OPHANIM = 40.0
# whose name the ophanim reads (ANGELOS_INTRO_NAME: another, trying it)
LOGIN = os.environ.get("ANGELOS_INTRO_NAME") or getpass.getuser()
# the ophanim flashing in for a frame (SetupIntroScreen), half out of sight at an edge:
# (time, x, y) — x, y 0…1 across the screen, one of them 0 or 1 (that edge)
GLIMPSES = [(22.0, 0.0, 0.3), (28.0, 1.0, 0.75), (33.0, 0.35, 0.0), (37.0, 1.0, 0.2)]
# the shakes: (time, strength 0…1); the tree's fall and the ophanim are the big ones
SHAKES = [(8.0, 0.25), (17.5, 0.35), (HERE, 0.9), (35.0, 0.4), (OPHANIM, 0.85), (50.0, 0.55),
          (53.0, 0.65), (55.0, 0.7), (56.5, 0.75), (57.5, 0.8), (58.5, 0.9), (59.2, 1.0)]
# eyelids closing for a moment early on (waking up)
BLINKS = [1.6, 4.4, 7.4]
# the screams far away: (time, voice, pan)
SCREAMS = [(12.0, "scream-woman", -0.6), (20.5, "scream-girl", 0.5), (29.5, "scream-macbeth", -0.2),
           (35.5, "scream-woman", 0.7), (40.0, "scream-girl", -0.7), (46.0, "scream-macbeth", 0.3),
           (49.5, "scream-woman", -0.4), (52.5, "scream-girl", 0.6), (55.0, "scream-macbeth", -0.1),
           (56.8, "scream-woman", 0.4)]
SRC = Path(__file__).resolve().parent.parent / "data" / "sounds" / "intro"
PRE_CPS = 26.0      # her thoughts: letters a second (SetupPrequel types them at this too)
# the minute before (SetupPrequel draws it by these, SetupIntro.preBeats): s into it
def _msg(at, until, x, y, ru, en):
    return {"at": at, "until": until, "x": x, "y": y, "ru": ru, "en": en}


PRE = {
    "length": 245.0,                                 # the scene is over at `cut` + 1.4; then no signal
    # the shots: from when, which side of her room (her desk close; her screen, whole), which
    # picture of it. Long ones, and a cut only when she does something
    "shots": [[0.0, "window", 1], [14.0, "screen", 0], [66.0, "monitor", 1], [76.0, "screen", 0], [124.0, "rear", 1],
              [136.0, "window", 1], [157.0, "desk", 6], [163.5, "desk", 5], [170.0, "desk", 4], [177.0, "screen", 0],
              [186.0, "monitor", 2], [196.2, "ash", 3], [200.0, "rear", 3], [207.5, "window", 3], [215.0, "rear", 3]],
    # his messages over the board (where on her 320×240 screen), and when she shuts each: more
    # and more of them, the last three one on another
    "messages": [_msg(25.0, 33.5, 190, 20, "ты дома?", "are you home?"),
                 _msg(44.0, 51.5, 194, 62, "алис, возьми трубку", "Alice, pick up the phone"),
                 _msg(77.0, 85.0, 190, 34, "я же вижу, что ты в сети", "I can see you are online"),
                 _msg(110.0, 113.5, 192, 26, "ответь", "answer me"),
                 _msg(115.5, 121.5, 184, 40, "алис", "alice"),
                 _msg(117.0, 122.3, 192, 66, "я же волнуюсь", "I am worried, you know"),
                 _msg(118.5, 123.1, 200, 92, "АЛИСА", "ALICE")],
    # what matters gets the camera's lean and the dark closing round it — the first message (after
    # it one knows where they come), the answer with the game in it, the last three at once — not
    # every message: from, to, and where on her screen (x0 y0 x1 y1)
    "focus": [[25.0, 33.0, 184, 14, 320, 88], [92.0, 100.5, 4, 112, 244, 178], [115.5, 121.2, 178, 34, 320, 160]],
    # her answer in the thread: typed in two goes (he writes in between), a sentence more —
    # rubbed out again — and sent; the two answers to it
    "typing": [[23.0, 24.2], [40.0, 43.0], [53.0, 56.5]],
    "erase": [58.0, 59.5],
    "send": 60.5,
    "replies": [92.0, 107.5],
    "download": 101.0,                               # the link in the answer: the game coming down
    "pills": [163.5, 170.0],                         # out of the blister on her desk, one, another
    "high": [170.0, 205.0],                          # …and what they do to the picture, from none to all
    "disc": 177.5,                                   # …down: it starts, «Наденьте очки»
    "goggles": 188.5,
    # what she sees in them. The last ends with the game at 99 % of saving: then her room, all
    # of it burning, the tape breaking up over it
    "inserts": [[193.0, 196.2], [204.5, 207.5], [218.0, 223.0]],
    # the papers by the ashtray: seen close and in quiet, before she laughs — one knows by then
    "caught": 196.8,
    "midnight": 208.5,
    "cut": 223.6,                                    # the recording breaks up
    "hint": 30.0,                                    # no way out before this
    # what she thinks, a line at a time, as a novel shows it: it is why she does each thing.
    # The author's words. After the second pill there is next to nothing left of them.
    "says": [
        [1.0, "31 декабря...", "December the 31st..."],
        [6.0, "У всех за стеной праздник, а я... У меня — три монитора.", "Everyone behind the wall has a holiday, and I... I have three monitors."],
        [18.0, "Тред одиноких: Вы тоже одиноки?", "The thread of the lonely: “Are you lonely too?”"],
        [28.0, "Десять дней молчал. А теперь — тебе не похуй?", "Ten days of silence. And now — like you give a fuck?"],
        [34.5, "В любом случае тебя это волновать не должно.", "Either way, it should not concern you."],
        [47.0, "Пошел он... Задолбал", "Screw him... I am so sick of him"],
        [61.5, "Хотя бы сегодня... Без него.", "At least tonight... Without him."],
        [67.5, "Если ответить — то может... Все будет лучше?", "If I answer — then maybe... It all gets better?"],
        [80.0, "И поверь тебя это ебать не должно", "And believe me, it is none of your fucking business"],
        [86.5, "Надо просто чем-то занять голову.", "I just need something to keep my head busy."],
        [95.0, "«Сохрани себя»? Та игра с закрытого форума. Попробую скачать.", "“Save Yourself”? That game from the closed forum. I will try downloading it."],
        [102.5, "Очки-то у меня есть.", "I do have the goggles, after all."],
        [127.0, "Как же тихо.", "It is so quiet."],
        [152.0, "Одна минута. И потом ещё целый год.", "One minute. And then a whole year more."],
        [158.0, "Сначала это, один раз можно, блять!", "This first, once is allowed, fuck!"],
        [165.0, "Кхх... Бесит все", "Khh... Everything pisses me off"],
        [172.0, "Аааагх... Боже, наконец тихо", "Aaaagh... God, quiet at last"],
        [179.5, "Очки...", "Goggles..."],
        [186.6, "Пять минут...", "Five minutes..."],
        [194.2, "Ого... красиво", "Wow... pretty"],
        [200.6, "АХАХАХАХАХА", "AHAHAHAHAHA"],
        [204.8, "Ещё кружок", "One more circle"],
        [218.4, "Жарко...", "Hot..."],
        [221.0, "Сохранить", "Save"],
    ],
}

LAUGH = 200.2      # she laughs: no reason for it but the pills (her words for it come up after)
LAST = 1.66        # s into the author's «С Новым годом, Алис. Позвони мне»: where the tape cuts him off
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


def box(x, w):
    """a moving average over `w` samples (np.convolve takes seconds on a minute of sound)."""
    w = max(1, min(int(w), len(x)))
    c = np.cumsum(np.concatenate([np.zeros(1), x]))
    y = (c[w:] - c[:-w]) / w
    pad = len(x) - len(y)
    return np.concatenate([np.full(pad // 2, y[0]), y, np.full(pad - pad // 2, y[-1])])


_envelopes = {}


def envelope(name):
    if name not in _envelopes:
        _envelopes[name] = box(np.abs(sample(name)).mean(axis=1), n_of(0.05))
    return _envelopes[name]


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
    # it reads the user's name; everything else gives way to it
    said = spelled(LOGIN)
    if said is not None:
        track = np.zeros((n, 2))
        add(track, OPHANIM + 1.6, said)
        under = box(np.abs(track).max(axis=1), n_of(0.15))
        mix *= (1 - 0.6 * np.clip(under * 3, 0, 1))[:, None]
        mix += track * 1.1
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


# ---------------------------------------------------------------- the minute before

def voice(name):
    """one of the author's recordings (data/sounds/intro/voice), or nothing."""
    return sample(f"voice/{name}") if (SRC / "voice" / f"{name}.ogg").is_file() else None


def unit(x):
    return x / (np.abs(x).max() + 1e-9)


def blip(freq, sec, decay):
    tt = t_axis(n_of(sec))
    return np.sin(2 * np.pi * freq * tt) * np.minimum(1, tt / 0.003) * np.exp(-tt / decay)


def tick(gain=1.0):
    """a switch under a finger."""
    m = n_of(0.02)
    return fft_filter(rng.standard_normal((m, 2)), band(1800, 7000)) * exp_env(m, 0.004)[:, None] * gain * 2.5


def her_music(n, until):
    """a slow sad thing of that year from small speakers, till the goggles go on."""
    tt = t_axis(n)
    step = 60 / 69 / 2
    k = np.floor(tt / step).astype(int)
    roots = np.array([220.0, 174.61, 130.81, 196.0])[(k // 16) % 4]
    arp = np.array([1, 1.5, 2, 2.4, 3, 2.4, 2, 1.5])[k % 8]
    phase = 2 * np.pi * np.cumsum(roots * arp) / RATE
    x = (np.sin(phase) + 0.3 * ((phase / (2 * np.pi)) % 1 * 2 - 1)) * np.exp(-(tt % step) / 0.3)
    bar = tt % (step * 16)
    x += 0.7 * np.sin(2 * np.pi * np.cumsum(roots / 2) / RATE) * np.minimum(1, bar / 0.4) * np.exp(-bar / 3.0)
    x = fft_filter(x, band(180, 3200))
    return pan(unit(x), -0.2) * ramp(n, until, until + 1.5, 1, 0)


def cut(name, a, b, fin=0.01, fout=0.08):
    """seconds a…b of a recording, its peak at 1."""
    return unit(faded(sample(name)[n_of(a):n_of(b)], fin, fout))


def near(x):
    """in her room, by the microphone: as it is, the room's short ring after it."""
    out = convolve(x, reverb_ir(0.4, 0.07, 5000)) * 0.16
    out[: len(x)] += x
    return out


def inhead(v):
    """him as she hears him in her head: the voice of a telephone's receiver — she has heard
    these words down the line — a short hollow room behind it. Every word of it plain."""
    m = len(v) + n_of(1.0)
    x = np.zeros((m, 2))
    x[: len(v)] = fft_filter(v, band(300, 3400))
    return x * 0.85 + convolve(x, reverb_ir(1.0, 0.22, 2600))[:m] * 0.2


def telly(v):
    """the neighbours' television through the wall: its small speaker, the wall taking the highs
    — not all of them: the words are to be made out — their room ringing a little."""
    v = fft_filter(v, lambda f: highpass(230)(f) * (0.3 + 0.7 * lowpass(1100, 1)(f)) * lowpass(3600, 2)(f))
    return v + convolve(v, reverb_ir(0.5, 0.12, 1800))[: len(v)] * 0.3


def dance(sec, bpm, roots, hook):
    """a dance tune of those years as the neighbours' stereo plays it: four on the floor, the bass
    off the beat, a saw's hook over them, a clap on two and four. Made here: nobody's song."""
    n = n_of(sec)
    pos = t_axis(n) * bpm / 60                               # beats
    root = np.array(roots)[(pos // 4).astype(int) % len(roots)]
    saw = lambda f: (np.cumsum(f) / RATE) % 1 * 2 - 1
    b = (pos % 1) * 60 / bpm                                 # s into the beat
    kick = np.sin(2 * np.pi * (48 * b + 2.46 * (1 - np.exp(-b / 0.03)))) * np.exp(-b / 0.16)
    o = ((pos + 0.5) % 1) * 60 / bpm                         # s since the off-beat
    bass = saw(root) * np.minimum(1, o / 0.005) * np.exp(-o / 0.12)
    e = (pos * 2 % 1) * 30 / bpm                             # s into the eighth
    note = root * 4 * 2 ** (np.array(hook)[(pos * 2).astype(int) % len(hook)] / 12)
    lead = (saw(note) + saw(note * 1.007)) * np.exp(-e / 0.14)
    clap = fft_filter(rng.standard_normal(n) * np.exp(-((pos + 1) % 2) * 60 / bpm / 0.05), band(900, 3000))
    return kick * 0.9 + bass * 0.5 + lead * 0.18 + clap * 0.25


def wind(n):
    """the winter wind at her window, all night: the recording coming and going in gusts, and
    the whistle a gust makes in the frame's gaps — higher as it blows harder."""
    m = n // 2400 + 2                                        # the gusts: slow noise, 20 a second
    g = box(box(rng.standard_normal(m), 50), 30)
    g = np.interp(np.arange(n) / 2400, np.arange(m), (g - g.min()) / (g.max() - g.min()))
    out = bed("wind", n, 0.0, 2.0) * (0.3 + 0.7 * g)[:, None] * 0.6
    block = n_of(0.05)
    win = np.hanning(block * 2)
    noise = rng.standard_normal((n + block * 2, 2))
    for b in range(0, n, block):
        k = g[b]
        if k < 0.45:
            continue
        fc = 380 + 520 * k
        seg = fft_filter(noise[b:b + block * 2] * win[:, None], lambda f: peak(fc, fc * 0.05)(f) + 0.4 * peak(fc * 1.52, fc * 0.06)(f))
        j = min(n, b + block * 2)
        out[b:j] += seg[: j - b] * ((k - 0.45) / 0.55) ** 2 * 1.6
    return out


_shells = None


def fireworks():
    """the fireworks over her yard: (when its bang is heard, how big 0…1, which of four colours,
    where it is in the recording — data/sounds/intro/fireworks.ogg). One now and then, oftener as
    midnight nears: single bangs of the recording; from midnight its thickest stretch, and every
    bang in that. The shell lights her window by these (PRE["fireworks"])."""
    global _shells
    if _shells is None:
        x = np.abs(sample("fireworks")).mean(axis=1)
        hop = n_of(0.01)
        e = np.array([x[a:a + 2 * hop].max() for a in range(0, len(x) - 2 * hop, hop)])
        rise = np.maximum(0, e[3:] - e[:-3])
        bangs = []
        for i in np.argsort(-rise):
            if rise[i] < 0.12 * rise.max():
                break
            if all(abs(i - j) > 35 for j, _ in bangs):
                bangs.append((int(i), float(rise[i] / rise.max())))
        bangs.sort()
        alone = [i / 100 for (i, k), (j, _) in zip(bangs, bangs[1:]) if k > 0.5 and j - i > 140 and i < 4500]
        hues = np.random.default_rng(2003)
        mid = PRE["midnight"]
        early = [3.4, 9.8, 31.0, 52.0, 70.2, 88.0, 109.0, 126.5, 131.8, 138.0, 143.5, 149.8, 154.6, 161.0, 168.5, 180.0,
                 186.5, 191.0, 197.2, 201.5, 204.4, 206.6]
        _shells = [(at, float(hues.uniform(0.5, 0.8) + 0.2 * at / mid), int(hues.integers(4)), alone[k % len(alone)]) for k, at in enumerate(early)]
        _shells += [(mid - 0.4 + i / 100 - THICK, 0.55 + 0.45 * k, int(hues.integers(4)), None) for i, k in bangs
                    if THICK <= i / 100 < THICK + PRE["cut"] + 1.4 - mid and k > 0.3]
    return _shells


LAUGHS = (2.9, 8.9)     # s of girl-laugh.ogg: the laugh
SWAN = 0.265            # s: a step of the little swans on that record (an eighth note)


def laughing():
    """how loud her laugh is, 20 times a second, 0…1: the shell shakes the picture by it."""
    env = box(np.abs(cut("girl-laugh", *LAUGHS, fout=0.4)).mean(axis=1), n_of(0.08))[:: n_of(0.05)]
    return [round(float(v), 2) for v in env / env.max()]


THICK = 46.0        # s into fireworks.ogg: from here it is one bang on another
FLASH = 0.3         # the light is this much ahead of the bang (a few streets away)


def game_tune(n):
    """the game's tune in the goggles from PRE["goggles"] on: loud in each cut to them, a leak from
    her headphones between; every cut slower, lower, coarser, and in the last it sticks."""
    tt = t_axis(n)
    cuts = PRE["inserts"]
    wrong = np.interp(tt, [cuts[0][1]] + [c[0] for c in cuts[1:]] + [PRE["length"]],
                      [0.0] + list(np.linspace(0.45, 1.0, len(cuts) - 1)) + [1.0])
    notes = 4 * (1 - 0.45 * wrong)
    k = np.floor(np.cumsum(notes) / RATE).astype(int)
    scale = np.array([523.25, 659.25, 783.99, 659.25, 880.0, 783.99, 659.25, 587.33,
                      523.25, 587.33, 659.25, 783.99, 1046.5, 880.0, 783.99, 659.25])[k % 16]
    freq = scale * 2 ** (-(5 * wrong + 1.2 * wrong * np.sin(2 * np.pi * 0.7 * tt)) / 12)
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    x = np.sign(np.sin(phase)) * 0.6 + np.sign(np.sin(phase / 2)) * 0.4
    # coarser: fewer and fewer samples a second
    for (a, _b), hold in zip(cuts[-2:], (4, 9)):
        i = np.arange(n_of(a), n)
        x[i] = x[n_of(a) + (i - n_of(a)) // hold * hold]
    # stuck: the same eighth of a second, over and over
    a, piece = n_of(cuts[-1][0] + 1.0), n_of(0.125)
    i = np.arange(a, n)
    x[i] = x[a + (i - a) % piece]
    x[: n_of(PRE["goggles"])] = 0
    loud = np.zeros(n)
    for a, b in cuts:
        loud[n_of(a):n_of(b)] = 1
    loud = box(loud, n_of(0.03))
    leak = fft_filter(x, highpass(2500)) * 0.03
    return pan(x * loud * 0.3 + leak, 0), loud


def prequel():
    L = PRE["cut"] + 1.4                 # the scene; what is left of PRE["length"] is no signal
    n = n_of(PRE["length"])
    tt = t_axis(n)
    mid = PRE["midnight"]
    mix = np.zeros((n, 2))
    # ---- her room: the machine — the mains' hum, the tube's whine, the fans, the disk now and then
    mix += pan(0.5 * np.sin(2 * np.pi * 50 * tt) + 0.3 * np.sin(2 * np.pi * 100 * tt) + 0.12 * np.sin(2 * np.pi * 150 * tt), 0) * 0.025
    mix += pan(np.sin(2 * np.pi * 15625 * tt), 0.3) * 0.004
    mix += unit(fft_filter(rng.standard_normal((n, 2)), band(120, 900))) * 0.028
    seek = np.zeros(n)
    for at in rng.uniform(0.5, L - 2, 55):
        for j in range(int(rng.integers(5, 18))):
            i = n_of(at + j * rng.uniform(0.008, 0.03))
            if i < n:
                seek[i] = rng.uniform(0.4, 1)
    m = n_of(0.004)
    mix += pan(convolve(seek, fft_filter(rng.standard_normal(m), band(900, 3500)) * exp_env(m, 0.0012))[:n], 0.35) * 0.05
    # what is behind — her music, the neighbours, the wind, the fireworks — gives way while she
    # thinks, laughs, or he writes: one thing at a time
    front = np.zeros(n)
    for at, ru, _en in PRE["says"]:
        front[n_of(at):n_of(at + len(ru) / PRE_CPS + 1.0)] = 1
    for msg in PRE["messages"]:
        front[n_of(msg["at"]):n_of(msg["at"] + 2.0)] = 1
    front[n_of(LAUGH):n_of(LAUGH + 5.5)] = 1
    front = box(front, n_of(0.5))
    behind = her_music(n, PRE["goggles"]) * 0.07
    # his messages: two notes each; her finger on the mouse at every cross and button
    for msg in PRE["messages"]:
        note = np.concatenate([blip(1318.5, 0.09, 0.05), blip(1046.5, 0.22, 0.09)])
        add(mix, msg["at"], pan(note, -0.1) * 0.16)
        add(mix, msg["until"], tick(0.5))
    add(mix, PRE["send"], tick(0.6))
    # her keys: slow, in goes; what she rubs out goes faster
    for (a, b), rate in [(go, 5.5) for go in PRE["typing"]] + [(PRE["erase"], 13.0)]:
        at = a
        while at < b:
            add(mix, at, tick(rng.uniform(0.18, 0.34)) * np.array([1.0, 0.8]))
            at += rng.uniform(0.7, 1.4) / rate
    # her thoughts appearing, letter by letter: a soft patter, as a novel's text has
    for at, ru, _en in PRE["says"]:
        for k in range(0, len(ru), 3):
            add(mix, at + k / PRE_CPS, pan(blip(1760, 0.03, 0.008), 0.0) * 0.022)
    # ---- she herself, near: no words, only what a body does
    # the three windows shut: a breath out
    add(mix, 123.6, near(cut("girl-sigh-2", 0.05, 1.2)) * 0.3)
    # the pills: the foil gives, a swallow of water, the glass back on the desk; the first one
    # scrapes her throat, after the second she lets all her breath go
    for at in PRE["pills"]:
        add(mix, at - 0.1, near(cut("blister", 0.1, 0.8)) * 0.4)
        add(mix, at + 0.95, near(cut("girl-gulp", 0.05, 0.5)) * 0.34)
        add(mix, at + 1.6, pan(blip(2350, 0.25, 0.05) + 0.5 * blip(3900, 0.25, 0.03), 0.35) * 0.05)
    add(mix, PRE["pills"][0] + 1.5, near(cut("girl-cough", 0.05, 1.1)) * 0.42)
    add(mix, PRE["pills"][1] + 2.0 - 2.1, near(cut("girl-sigh", 0.0, 3.6, fout=0.5)) * 0.5)
    # the goggles on: a strap, a click
    m = n_of(0.3)
    add(mix, PRE["goggles"] - 0.25, unit(fft_filter(rng.standard_normal((m, 2)), highpass(3000))) * exp_env(m, 0.09, 0.05)[:, None] * 0.07)
    add(mix, PRE["goggles"], tick(0.9))
    # in the game: her breath caught at the sight of it, a giggle — and, the papers already
    # alight behind her back, the laugh: the pills', no more reason to it; it dies down into the
    # next circle. (Later, smoke in her throat: one cough, and she plays on — below.)
    add(mix, 194.3, near(cut("girl-gasp", 0.1, 0.55)) * 0.3)
    add(mix, 194.9, near(cut("girl-laugh", 20.85, 22.1, fout=0.3)) * 0.45)
    add(mix, LAUGH, near(cut("girl-laugh", *LAUGHS, fout=0.4)) * 0.75)
    add(mix, 206.3, near(cut("girl-laugh", 28.55, 31.4, fout=0.3)) * 0.45)
    # ---- behind the wall: the neighbours' party. People all night; a dance tune of those years,
    # turned down when the television speaks and off for its last minute; twelve strokes; at
    # midnight a cheer, a cork, glasses — and another tune, louder
    party = np.zeros((n, 2))
    tune = np.zeros(n)
    one = dance(mid - 62, 132, [110.0, 87.31, 130.81, 98.0], [0, 0, 7, 0, 3, 0, 7, 10, 0, 0, 7, 0, 12, 10, 7, 3])
    tune[: len(one)] = one * np.interp(t_axis(len(one)), [0, 10.8, 11.5, 17.2, 18.5, mid - 66, mid - 62], [1, 1, 0.3, 0.3, 1, 1, 0])
    two = dance(L - mid - 3, 140, [73.42, 58.27, 87.31, 65.41], [12, 7, 3, 7, 12, 7, 15, 12, 10, 7, 3, 7, 10, 7, 14, 10])
    tune[n_of(mid + 3):n_of(mid + 3) + len(two)] = two * np.minimum(1, t_axis(len(two)) / 1.5) * 1.5
    party += pan(fft_filter(tune, lambda f: lowpass(250, 2)(f) + 0.1 * band(250, 1400)(f)), 0.3) * 0.15
    people = fft_filter(bed("party", n, 0.0, 3.0), lowpass(750, 2))
    party += people * np.interp(tt, [0, mid - 62, mid - 58, mid - 8, mid, mid + 6, L], [0.6, 0.6, 0.3, 0.45, 1.5, 1.0, 1.0])[:, None] * np.array([0.3, 0.5])
    wallring = lowpass(1300, 2)
    for name, at, gain in (("cheer", mid + 0.2, 0.3), ("cork", mid + 1.1, 0.2), ("clink", mid + 2.0, 0.12), ("clink", mid + 2.7, 0.09), ("cheer", mid + 9.0, 0.15)):
        add(party, at, fft_filter(sample(name), wallring) * np.array([0.6, 1.0]) * gain)
    bell = fft_filter(sample("bell"), lowpass(1100))
    for i in range(12):
        add(party, mid - (11 - i) * 2.2 - onset("bell"), bell * np.array([0.18, 0.36]) * (0.5 + 0.5 * i / 11))
    behind += party
    # ---- outside her window: the wind; fireworks (their light is in the picture a moment before)
    behind += wind(n) * np.array([1.0, 0.6]) * 0.75
    shots = np.zeros((n, 2))
    fw = sample("fireworks")
    for at, size, _hue, where in fireworks():
        if where is not None:
            add(shots, at - 0.05, faded(fw[n_of(where - 0.05):n_of(where + 1.5)], 0.02, 0.9) * (0.16 + 0.24 * size))
    add(shots, mid - 0.4, faded(fw[n_of(THICK):n_of(THICK + L - mid + 0.4)], 0.3, 0.1) * 0.42)
    behind += fft_filter(shots, lowpass(3000, 1)) * np.array([1.0, 0.55])
    mix += behind * (1 - 0.6 * front)[:, None]
    # the pills taking hold: a low swim under everything
    a, b = PRE["high"]
    mix += pan(np.sin(2 * np.pi * 110 * tt) + np.sin(2 * np.pi * 111.3 * tt) + 0.5 * np.sin(2 * np.pi * 165.4 * tt), 0) * (np.interp(tt, [a, b, PRE["cut"]], [0, 0.03, 0.03]) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.23 * tt)))[:, None]
    # the game coming down: her press on the link; done — two notes
    add(mix, PRE["download"], tick(0.6))
    add(mix, PRE["disc"], pan(np.concatenate([blip(880, 0.12, 0.06), blip(1318.5, 0.3, 0.12)]), -0.1) * 0.13)
    # the game in the goggles, and the fall's wind in each cut
    tune, loud = game_tune(n)
    mix += tune
    mix += unit(fft_filter(rng.standard_normal((n, 2)), band(70, 600))) * (loud * np.interp(tt, [PRE["inserts"][0][1], L], [0.0, 0.16]))[:, None]
    # the fire nobody hears: the papers, then the curtain
    mix += bed("fire", n, PRE["caught"], 2.0) * ramp(n, PRE["caught"], L, 0.03, 0.5, 1.6)
    mix += bed("fire-roar", n, PRE["caught"] + 9, 4.0) * ramp(n, PRE["caught"] + 9, L, 0.0, 0.4, 1.3)
    # two quiets: while the papers catch (seen close: nothing else matters), and her room
    # burning, seen whole, before the last of it. That swells; steps back for his last words
    # (below); and where the tape cuts him off comes down on the cut the loudest there is
    end = PRE["inserts"][-1][1]
    mix *= np.interp(tt, [196.0, 196.5, 199.7, 200.2, 214.6, 215.4, 217.6, end - LAST - 0.5, end - LAST - 0.2, end - 0.01, end],
                     [1, 0.35, 0.35, 1, 1, 0.45, 0.45, 1.1, 0.3, 0.3, 1.6])[:, None]
    add(mix, PRE["caught"], faded(sample("fire-roar")[: n_of(2.4)], 0.05, 1.8) * 0.16)
    add(mix, PRE["caught"] + 0.1, faded(sample("fire")[: n_of(3.3)], 0.3, 0.6) * 0.3)
    add(mix, 216.2, near(cut("girl-cough", 0.05, 1.1)) * 0.36)
    # ---- the author's voice: the neighbours' television (the minute it gives is the minute it
    # is), and him, in her head — only once the pills are in: a sign she is no longer here.
    # Every word of both is to be made out: all the rest steps back under them
    said = np.zeros((n, 2))
    for name, at in (("tv-1", 11.5), ("tv-2", mid - 60), ("tv-3", mid + 0.6)):
        v = voice(name)
        if v is not None:
            add(said, at, telly(v) * np.array([0.5, 0.8]) * 0.7)
    for name, at in (("ex-1", 183.6), ("ex-2", 190.3)):
        v = voice(name)
        if v is not None:
            add(said, at, inhead(v) * 0.75)
    under = box(np.abs(said).max(axis=1), n_of(0.4))
    mix *= (1 - 0.9 * np.clip(under * 25, 0, 1))[:, None]
    mix += said
    # his last words to her, as the game saves: cut off in the middle of one, with the picture
    v = voice("ex-3")
    if v is not None:
        last = inhead(v)[: n_of(LAST)] * 0.95
        last[-n_of(0.006):] *= np.linspace(1, 0, n_of(0.006))[:, None]
        add(mix, end - LAST, last)
    # the tape breaks up: everything under snow, cut to pieces; then the tone of no signal, dying
    # away after a few seconds — and «Swan Lake» from where the tone was, a quarter of a minute
    cut_at = PRE["cut"]
    mix *= ramp(n, cut_at - 0.2, cut_at + 0.9, 1, 0)
    m = n_of(1.5)
    gate = np.repeat(rng.random(m // n_of(0.03) + 1) < 0.7, n_of(0.03))[:m]
    add(mix, cut_at - 0.6, rng.standard_normal((m, 2)) * (gate * np.linspace(0, 1, m) ** 1.5)[:, None] * 0.12)
    m = n_of(5.5)
    add(mix, cut_at + 0.9, pan(np.sin(2 * np.pi * 1000 * t_axis(m)) * np.minimum(1, t_axis(m) / 0.02) * np.clip((5.5 - t_axis(m)) / 1.5, 0, 1), 0) * 0.07)
    add(mix, cut_at + 0.9 + 5.0, faded(sample("swan")[: n_of(15.0)], 1.5, 2.5) * 0.5)
    mix = np.tanh(1.2 * mix) / math.tanh(1.2)
    return mix * min(1.0, 0.89 / (np.abs(mix).max() + 1e-9))


def spelled(login):
    """the ophanim reading a name, a letter at a time: the author's voice low, twice over, in a
    hall; or nothing (no letters of it recorded)."""
    keys = {"-": "dash", "_": "underscore", ".": "dot"}
    said = [voice(keys.get(ch, ch)) for ch in login.lower()[:12] if ch.isascii() and (ch.isalnum() or ch in keys)]
    said = [v for v in said if v is not None]
    if not said:
        return None
    gap = 0.8
    dry = np.zeros((n_of(gap * len(said) + 1.5), 2))
    for i, v in enumerate(said):
        add(dry, i * gap, pitched(v, -5) * 0.8)
        add(dry, i * gap, pitched(v, -12) * 0.55)
    dry = np.tanh(1.6 * dry)
    wet = convolve(dry, reverb_ir(4.0, 1.4, 3200))
    wet[: len(dry)] += dry / 0.45
    return unit(wet)


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
    names = (("plink", plink), ("prequel", prequel), ("intro", intro))
    have = {p.stem: p for p in out.iterdir() if p.suffix in (".ogg", ".wav")}
    stamp = f"{VERSION} {LOGIN}"
    current = (out / ".version").is_file() and (out / ".version").read_text().strip() == stamp
    if not current or any(n not in have for n, _ in names):
        (out / ".version").unlink(missing_ok=True)
        for name, make in names:
            have[name] = write(out / name, make())
        (out / ".version").write_text(stamp)
    files = {name: str(own_file(out, name) or have[name]) for name, _ in names}
    files["doki"] = str(own_file(out, "doki") or SRC / "music.ogg")
    PRE["laugh"] = {"at": LAUGH, "env": laughing()}
    PRE["swan"] = {"at": PRE["cut"] + 0.9 + 5.0, "step": SWAN}
    PRE["fireworks"] = sorted([round(at - FLASH, 2), round(size, 2), hue] for at, size, hue, _ in fireworks())
    timeline = {"length": LENGTH, "hello": HELLO, "here": HERE, "ophanim": OPHANIM, "shakes": SHAKES,
                "glimpses": [{"t": t, "x": x, "y": y} for t, x, y in GLIMPSES],
                "blinks": BLINKS, "screams": [s[0] for s in SCREAMS], "pre": dict(PRE, cps=PRE_CPS), "files": files}
    (out / "timeline.json").write_text(json.dumps(timeline))
    print(json.dumps({"dir": str(out), "files": files}))


if __name__ == "__main__":
    main()
