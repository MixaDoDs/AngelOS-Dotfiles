#!/usr/bin/env python3
"""The "2000s PC" sound pack (Settings → Sounds → Pack → «Нулевые»): a home computer of 2002.
The tones are synthesised here (the PC speaker's beep, polyphonic-ringtone jingles, messenger
blips: original, none copied from a real OS or messenger); the machine itself is CC0 recordings
from Freesound (data/sounds/pc2k/SOURCES.md, trimmed into src/): a ball mouse, a membrane
keyboard, the floppy drive, the CD tray, a disposable camera, a hard disk spinning up and down,
a CRT's degauss.

  pc2k-sounds.py [dir] [name…]   writes the events below as .ogg (Vorbis through ffmpeg; .wav
                                 without it) into dir (default: data/sounds/pc2k), prints JSON

The shell ships the result and plays it (services/Sounds, pack "pc2k"); a file of the same name
in ~/.local/share/angelos/sounds/pc2k wins, and an event the pack has no file for plays the Y2K
one. Levelled like the other packs: peaks about -6 dBFS, the RMS capped per event.
Everything is seeded: the same files every time.
"""
import importlib.util
import json
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
SRC = HERE.parent / "data/sounds/pc2k/src"
_spec = importlib.util.spec_from_file_location("mac_sounds", HERE / "mac-sounds.py")
mac = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(mac)
RATE, t_axis, env, fade, place, noise = mac.RATE, mac.t_axis, mac.env, mac.fade, mac.place, mac.noise
onepole, band, lowpass, resonator, room, level, master = mac.onepole, mac.band, mac.lowpass, mac.resonator, mac.room, mac.level, mac.master
PACK_VERSION = "1"


def rec(name):
    """a source recording (src/NAME.ogg) as mono float"""
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(SRC / (name + ".ogg")), "-f", "s16le",
                          "-ac", "1", "-ar", str(RATE), "-"], capture_output=True, check=True).stdout
    x = np.frombuffer(raw, dtype="<i2").astype(float) / 32768
    # no silence before the sound (a click must answer at once): from 2 ms before it's 40 dB under its peak
    loud = np.flatnonzero(np.abs(x) > np.max(np.abs(x)) * 0.01)
    return x[max(0, loud[0] - int(0.002 * RATE)):] if len(loud) else x


def note(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def pulse(freq, sec, duty=0.25, top=7000.0):
    """a band-limited pulse wave: the sound of a 2002 phone's polyphony and of chiptune blips"""
    t = t_axis(sec)
    out = np.zeros_like(t)
    k = 1
    while k * freq < top:
        out += (2 / (k * np.pi)) * np.sin(k * np.pi * duty) * np.cos(2 * np.pi * k * freq * t)
        k += 1
    return out


def beep(freq, sec, duty=0.5, attack=0.002, release=0.03, decay=0.0):
    x = pulse(freq, sec, duty) * env(int(sec * RATE), attack, release)
    return x * np.exp(-t_axis(sec) * decay) if decay else x


def tune(notes, step, duty=0.25, length=0.9, decay=5.0, bass=None):
    """a polyphonic ringtone: (midi note, beats) for the lead, an optional bass under it"""
    total = sum(b for _, b in notes) * step + 0.5
    buf = np.zeros(int(total * RATE))
    at = 0.0
    for n, beats in notes:
        if n is not None:
            place(buf, beep(note(n), beats * step * length, duty, decay=decay) * 0.5, at)
        at += beats * step
    if bass:
        at = 0.0
        for n, beats in bass:
            place(buf, beep(note(n), beats * step * 0.95, 0.5, decay=3.0) * 0.22, at)
            at += beats * step
    return onepole(buf, 5200)


def echo(x, delay, gain, times=2):
    out = np.concatenate([x, np.zeros(int(delay * times * RATE))])
    for i in range(1, times + 1):
        place(out, x * gain ** i, delay * i)
    return out


# ---- the sounds ----

def startup():
    # the box comes on: the BIOS's one short beep, the hard disk spinning up, then a warm
    # chord and a rising messenger-bright arpeggio over it
    sec = 4.4
    buf = np.zeros(int(sec * RATE))
    hdd = fade(rec("hdd-up")[:int(3.6 * RATE)], 700)
    place(buf, lowpass(hdd, 5000, 1) * np.clip(t_axis(len(hdd) / RATE) / 0.4, 0, 1) * 0.55, 0.0)
    place(buf, beep(1000.0, 0.16, 0.5) * 0.35, 0.35)
    t = t_axis(2.9)
    pad = np.zeros_like(t)
    for n, g in ((44, 0.5), (51, 0.4), (56, 0.34), (60, 0.3), (63, 0.24)):      # A♭ add9, low and open
        for d in (-0.003, 0.003):
            pad += np.sin(2 * np.pi * note(n) * (1 + d) * t) * g
    swell = np.clip(t / 0.5, 0, 1) * np.exp(-np.clip(t - 0.6, 0, None) * 1.3)
    place(buf, onepole(pad * swell, 2400) * 0.3, 1.2)
    for i, n in enumerate((72, 75, 80, 82, 87)):
        place(buf, beep(note(n), 0.5, 0.25, decay=6.0) * 0.16, 1.3 + i * 0.12)
    return room(fade(buf, 200), 0.18)


def shutdown():
    # good night: the arpeggio falls over a fading chord, and the disk winds down under it
    sec = 6.0
    buf = np.zeros(int(sec * RATE))
    for i, n in enumerate((87, 82, 80, 75, 72)):
        place(buf, beep(note(n), 0.5, 0.25, decay=6.0) * 0.16, i * 0.14)
    t = t_axis(2.4)
    pad = np.zeros_like(t)
    for n, g in ((49, 0.5), (56, 0.4), (61, 0.32), (65, 0.26)):                # D♭, dimming
        pad += np.sin(2 * np.pi * note(n) * t) * g
    place(buf, onepole(pad * np.clip(t / 0.2, 0, 1) * np.exp(-t * 1.6), 2000) * 0.3, 0.1)
    hdd = rec("hdd-down")
    place(buf, fade(lowpass(hdd, 4000, 1)[:int(5.0 * RATE)], 800) * 0.5, 0.6)
    return room(fade(buf, 400), 0.15)


def notify():
    # a message came: two round blips a fifth up, a small echo — a messenger of the time
    buf = np.zeros(int(0.7 * RATE))
    place(buf, beep(note(77), 0.09, 0.25, decay=12) * 0.6, 0.0)
    place(buf, beep(note(84), 0.2, 0.25, decay=10) * 0.6, 0.1)
    return echo(onepole(buf, 4200), 0.13, 0.28, 2)


def error():
    # the PC speaker says no: two short square beeps, the second lower
    buf = np.zeros(int(0.42 * RATE))
    place(buf, beep(440.0, 0.11, 0.5) * 0.5, 0.0)
    place(buf, beep(330.0, 0.17, 0.5) * 0.5, 0.15)
    return onepole(buf, 3000)


def click():
    return rec("mouse-click")


def click_right():
    return rec("mouse-click-2")


def key(i=0):
    return rec("key-%d" % (i + 1))


def toggle():
    return rec("key-switch")


def open_():
    # up: three quick blips, a little brighter each
    buf = np.zeros(int(0.3 * RATE))
    for i, n in enumerate((72, 76, 79)):
        place(buf, beep(note(n), 0.05, 0.25, decay=20) * (0.4 + i * 0.1), i * 0.045)
    return onepole(buf, 4500)


def window_open():
    # a soft whoosh up with one blip on top
    sec = 0.32
    t = t_axis(sec)
    w = band(noise(sec, 61), 700, 3500, 2) * np.sin(np.pi * t / sec) ** 2 * 0.25
    place(w, beep(note(84), 0.06, 0.25, decay=25) * 0.25, 0.16)
    return w


def window_close():
    # down: two blips falling, then gone
    buf = np.zeros(int(0.25 * RATE))
    place(buf, beep(note(79), 0.05, 0.25, decay=20) * 0.45, 0.0)
    place(buf, beep(note(72), 0.08, 0.25, decay=18) * 0.4, 0.05)
    return onepole(buf, 4000)


def workspace():
    # a quick sideways swish
    sec = 0.22
    t = t_axis(sec)
    f = band(noise(sec, 71), 1200, 5000, 2)
    return f * np.sin(np.pi * t / sec) ** 3 * 0.3


def screenshot():
    # a disposable camera: the shutter, then the thumb winding the film on
    shutter = rec("camera-shutter")
    wind = rec("camera-wind")
    buf = np.zeros(len(shutter) + int(0.15 * RATE) + len(wind))
    place(buf, shutter, 0.0)
    place(buf, wind * 0.6, len(shutter) / RATE * 0.55)
    return buf


def volume():
    # one small round tick, as the old tray volume did (not its sound)
    sec = 0.06
    return np.sin(2 * np.pi * 1320 * t_axis(sec)) * np.exp(-t_axis(sec) * 70) * env(int(sec * RATE), 0.001, 0.01)


def wallpaper():
    # the CRT degausses: the deep "bwoom" and its buzz dying away
    return rec("crt-degauss")


def lock():
    # the floppy comes out
    return rec("floppy-out")


def unlock():
    # the floppy goes in, and a small two-note hello
    disk = rec("floppy-in")
    buf = np.zeros(len(disk) + int(0.5 * RATE))
    place(buf, disk, 0.0)
    place(buf, beep(note(76), 0.08, 0.25, decay=14) * 0.3, len(disk) / RATE - 0.05)
    place(buf, beep(note(83), 0.18, 0.25, decay=10) * 0.3, len(disk) / RATE + 0.05)
    return buf


def usb_in():
    # a device plugged in: low to high, two blips
    buf = np.zeros(int(0.35 * RATE))
    place(buf, beep(note(67), 0.07, 0.5, decay=14) * 0.4, 0.0)
    place(buf, beep(note(79), 0.14, 0.25, decay=12) * 0.45, 0.08)
    return onepole(buf, 3800)


def usb_out():
    buf = np.zeros(int(0.35 * RATE))
    place(buf, beep(note(79), 0.07, 0.25, decay=14) * 0.4, 0.0)
    place(buf, beep(note(67), 0.14, 0.5, decay=12) * 0.45, 0.08)
    return onepole(buf, 3400)


def achievement():
    # a ringtone's fanfare
    return tune([(72, 1), (76, 1), (79, 1), (84, 2), (79, 1), (84, 3)], 0.09,
                bass=[(48, 3), (55, 3), (48, 3)])


def stars():
    # two quiet high glints
    buf = np.zeros(int(0.5 * RATE))
    place(buf, beep(note(96), 0.12, 0.125, decay=20) * 0.3, 0.0)
    place(buf, beep(note(103), 0.2, 0.125, decay=16) * 0.3, 0.09)
    return echo(onepole(buf, 6000), 0.11, 0.3, 2)


def chest_open():
    # the CD tray slides out
    return rec("cd-tray")


def chest_tick():
    # the roll's tick: one PC-speaker click
    sec = 0.012
    return pulse(2000.0, sec, 0.5) * np.exp(-t_axis(sec) * 300)


def chest_prize():
    return tune([(79, 1), (84, 1), (88, 2)], 0.08)


def chest_legend():
    return tune([(72, 1), (79, 1), (84, 1), (88, 1), (91, 1), (96, 4)], 0.085,
                bass=[(48, 2), (53, 2), (55, 2), (60, 3)])


SOUNDS = {"startup": startup, "shutdown": shutdown, "notify": notify, "error": error, "click": click,
          "clickRight": click_right, "key": key, "key2": lambda: key(1), "key3": lambda: key(2),
          "toggle": toggle, "open": open_, "windowOpen": window_open, "windowClose": window_close,
          "workspace": workspace, "screenshot": screenshot, "volume": volume, "wallpaper": wallpaper,
          "lock": lock, "unlock": unlock, "usbIn": usb_in, "usbOut": usb_out, "achievement": achievement,
          "stars": stars, "chestOpen": chest_open, "chestTick": chest_tick, "chestPrize": chest_prize,
          "chestLegend": chest_legend}
# RMS ceilings, dBFS (the same places as the Y2K pack's: typing and ticks under everything)
LOUDNESS = {"key": -27.0, "key2": -27.0, "key3": -27.0, "clickRight": -22.0, "workspace": -24.0,
            "achievement": -23.0, "stars": -31.0, "chestOpen": -27.0, "chestTick": -32.0,
            "chestPrize": -26.0, "chestLegend": -24.0, "startup": -21.0, "shutdown": -22.0,
            "volume": -18.0, "wallpaper": -22.0}


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE.parent / "data/sounds/pc2k"
    out.mkdir(parents=True, exist_ok=True)
    only = set(sys.argv[2:])
    ffmpeg = shutil.which("ffmpeg")
    made = {}
    for name, fn in SOUNDS.items():
        if only and name not in only:
            continue
        x = level(master(fn()), -6.0, LOUDNESS.get(name, -20.0))
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
    if not only:
        (out / ".version").write_text(PACK_VERSION + "\n")
    print(json.dumps({"ok": True, "sounds": made}))


if __name__ == "__main__":
    main()
