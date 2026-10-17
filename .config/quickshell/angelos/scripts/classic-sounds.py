#!/usr/bin/env python3
"""Classic sounds any event may play (Settings → System sounds → the sound list: "ICQ «о-оу»").
Synthesised here, nothing recorded or copied: original works of angelOS, CC0 1.0.

  icq   a two-note "uh-oh" of the 2000s messenger: a short high "у", a breath, a lower "оу"
        that bends up and settles. A voice-like harmonic tone (the second harmonic carries it,
        the third fades as the vowel closes), not the real recording: a file of the same name
        (icq.ogg / .mp3 / .wav …) in ~/.local/share/angelos/sounds/classic plays first.

  classic-sounds.py [dir] [name…]   writes them as .ogg (Vorbis through ffmpeg; .wav without it)
                                    into dir (default: data/sounds/classic), prints JSON
Seeded: the same files every time.
"""
import importlib.util
import json
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("mac_sounds", HERE / "mac-sounds.py")
mac = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(mac)
RATE, t_axis, place, noise, onepole, band, room, level, master = (
    mac.RATE, mac.t_axis, mac.place, mac.noise, mac.onepole, mac.band, mac.room, mac.level, mac.master)


def curve(points, n):
    """a smooth line through (share of the length, value) points, n samples long"""
    xs, ys = zip(*points)
    return np.interp(np.linspace(0, 1, n), xs, ys)


def syllable(sec, f0, harmonics, attack=0.008, release=0.03, seed=1):
    """a sung vowel: harmonics of a gliding pitch with a little vibrato and breath.
    f0: [(share, Hz)]; harmonics: [[(share, dB)] per harmonic]"""
    n = int(sec * RATE)
    t = t_axis(sec)
    rng = np.random.default_rng(seed)
    pitch = curve(f0, n) * (1 + 0.006 * np.sin(2 * np.pi * 7.5 * t + rng.uniform(0, 6)))
    phase = 2 * np.pi * np.cumsum(pitch) / RATE
    out = np.zeros(n)
    for k, levels in enumerate(harmonics, start=1):
        gain = 10 ** (curve(levels, n) / 20)
        gain[k * pitch > 9000] = 0
        out += np.sin(k * phase + rng.uniform(0, 6)) * gain
    out += band(noise(sec, seed), 1500, 6000) * 0.04          # breath
    a, r = int(attack * RATE), int(release * RATE)
    shape = np.ones(n)
    shape[:a] = np.linspace(0, 1, a) ** 1.5
    shape[-r:] = np.linspace(1, 0, r) ** 2
    return out * shape


def icq():
    buf = np.zeros(int(0.62 * RATE))
    # "у": high and bright, a hair of rise, cut short by the glottal stop
    uh = syllable(0.09, [(0, 700), (0.25, 724), (1, 706)],
                  [[(0, -6)], [(0, 0)], [(0, -10)], [(0, -22)], [(0, -23)], [(0, -22)], [(0, -26)], [(0, -32)]],
                  attack=0.006, release=0.022, seed=3)
    # "оу": lower, bending up into the vowel, then a slow settle; it rounds (the 3rd harmonic goes)
    oh = syllable(0.30, [(0, 625), (0.06, 566), (0.2, 598), (0.5, 580), (1, 563)],
                  [[(0, -9), (1, -3)], [(0, 0)], [(0, -6), (0.25, -10), (0.35, -21), (1, -24)],
                   [(0, -10), (0.3, -28), (1, -33)], [(0, -22), (0.3, -40), (1, -45)],
                   [(0, -22), (0.3, -36), (1, -40)], [(0, -18), (0.3, -29), (1, -32)], [(0, -20), (1, -30)]],
                  attack=0.012, release=0.05, seed=4)
    place(buf, uh * 0.75, 0.0)
    place(buf, oh, 0.125)
    return room(onepole(buf, 7000), 0.08)


SOUNDS = {"icq": icq}


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE.parent / "data/sounds/classic"
    out.mkdir(parents=True, exist_ok=True)
    only = set(sys.argv[2:])
    ffmpeg = shutil.which("ffmpeg")
    made = {}
    for name, fn in SOUNDS.items():
        if only and name not in only:
            continue
        x = level(master(fn()), -6.0, -18.0)
        wav = out / (name + ".wav")
        mac.write_wav(wav, x)
        if ffmpeg:
            ogg = out / (name + ".ogg")
            r = subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "6",
                                "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact", str(ogg)])
            if r.returncode == 0:
                wav.unlink()
                made[name] = str(ogg)
                continue
        made[name] = str(wav)
    print(json.dumps({"ok": True, "sounds": made}))


if __name__ == "__main__":
    main()
