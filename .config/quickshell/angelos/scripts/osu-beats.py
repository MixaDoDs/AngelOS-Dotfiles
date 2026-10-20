#!/usr/bin/env python3
"""Beat tracker for osu!mini's music mode.

  osu-beats.py spotify|system

Records what plays — Spotify's own stream, or everything the computer plays
(the cava widget's "auto": a multichannel interface such as the RØDECaster is
summed) — finds the beat and prints a JSON line about four times a second:

  {"bpm": 128.0, "beat": <epoch ms of a recent beat>, "conf": 0..1, "fit": 1.., "level": 0..1}
  {"idle": true, "why": "silence" | "no-spotify" | "no-output"}

Onsets come from a bass-weighted spectral flux; the tempo from its
autocorrelation over the last six seconds (with a soft preference for ~120 BPM),
the phase from a comb over the same window. Read-only: it only records, on a
stream that never moves to another node.
"""
import importlib.util
import json
import os
import signal
import subprocess
import sys
import time

import numpy as np

RATE = 22050
HOP = 512
WIN = 1024
FPS = RATE / HOP
HISTORY = int(6 * FPS)

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("audio_tap", os.path.join(HERE, "audio-tap.py"))
tap = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tap)


def say(obj):
    print(json.dumps(obj), flush=True)


def spotify_node():
    """the Spotify playback stream: (node name, channel positions) or None"""
    for o in tap.pw_dump():
        if o.get("type") != "PipeWire:Interface:Node":
            continue
        info = o.get("info") or {}
        p = info.get("props") or {}
        if p.get("media.class") != "Stream/Output/Audio":
            continue
        who = " ".join(str(p.get(k, "")) for k in ("application.name", "application.process.binary", "node.name")).lower()
        if "spotify" in who:
            return p.get("node.name"), tap.positions(p, info) or ["FL", "FR"]
    return None


def target(mode):
    if mode == "spotify":
        s = spotify_node()
        return (s[0], False, s[1]) if s else None
    r = tap.resolve("auto")
    return (r[0], r[1], r[2]) if r else None


def recorder(node, sink, pos):
    props = ("{ node.name = angelos-osu node.description = \"osu!mini beat tracker\" media.role = Music "
             "node.always-process = true node.dont-fallback = true node.dont-reconnect = true node.dont-move = true "
             + ("stream.capture.sink = true " if sink else "") + "}")
    cmd = ["pw-record", "--target", node, "-P", props, "--rate", str(RATE), "--channels", str(len(pos)),
           "--channel-map", ",".join(pos), "--format", "s16", "--latency", "20ms", "--raw", "-"]
    return subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL,
                            preexec_fn=tap.die_with_parent)


class Tracker:
    def __init__(self):
        self.window = np.hanning(WIN).astype(np.float32)
        freqs = np.fft.rfftfreq(WIN, 1 / RATE)
        # the beat sits on the kick: low-band flux counts most, the whole band
        # (snare, hats on the off-beats) less; each normalised by its bin count
        self.low = freqs < 180
        self.nlow = max(1, int(self.low.sum()))
        self.nall = len(freqs)
        self.prev = None
        self.odf = []
        self.times = []
        self.samples = np.zeros(0, np.float32)
        self.bpm = 0.0
        self.pending = 0.0
        self.quiet_since = None

    def feed(self, mono, t_end):
        """mono float32 samples whose last one was heard at t_end (epoch s)"""
        self.samples = np.concatenate([self.samples, mono])
        n_hops = (len(self.samples) - WIN) // HOP + 1
        if n_hops <= 0:
            return
        for i in range(n_hops):
            frame = self.samples[i * HOP:i * HOP + WIN] * self.window
            mag = np.log1p(np.abs(np.fft.rfft(frame)) * 20)
            if self.prev is None:
                flux = 0.0
            else:
                rise = np.maximum(mag - self.prev, 0)
                flux = float(rise[self.low].sum() / self.nlow * 3 + rise.sum() / self.nall)
            self.prev = mag
            # time of this hop's newest sample
            left = len(self.samples) - (i * HOP + WIN)
            self.odf.append(flux)
            self.times.append(t_end - left / RATE)
        self.samples = self.samples[n_hops * HOP:]
        if len(self.odf) > HISTORY:
            self.odf = self.odf[-HISTORY:]
            self.times = self.times[-HISTORY:]

    def estimate(self):
        if len(self.odf) < int(3 * FPS):
            return None
        x = np.asarray(self.odf, np.float64)
        # local mean removed, only rises count
        k = 8
        smooth = np.convolve(x, np.ones(k) / k, mode="same")
        x = np.maximum(x - smooth, 0)
        if not x.any():
            return None
        x = x / (np.max(x) or 1)
        lo, hi = int(FPS * 60 / 190), int(FPS * 60 / 70) + 1
        ac = np.array([np.dot(x[:-lag], x[lag:]) for lag in range(lo, hi)])
        lags = np.arange(lo, hi)
        bpms = 60 * FPS / lags
        prior = np.exp(-0.5 * (np.log2(bpms / 120.0) / 0.9) ** 2)
        score = ac * prior
        i = int(np.argmax(score))
        # parabolic refinement of the lag
        if 0 < i < len(score) - 1:
            a, b, c = score[i - 1], score[i], score[i + 1]
            d = 0.5 * (a - c) / (a - 2 * b + c) if (a - 2 * b + c) else 0
        else:
            d = 0
        lag = lags[i] + d
        bpm = 60 * FPS / lag
        conf = float(ac[i] / (np.dot(x, x) or 1))
        # tempo and phase together: a comb with a fractional lag near the peak,
        # sampled between frames, that collects the most onset energy
        pos = np.arange(len(x), dtype=np.float64)
        best, best_lag, best_off, best_mean = -1.0, lag, 0.0, 1.0
        for L in np.arange(lag - 1.2, lag + 1.25, 0.05):
            if L < lo:
                continue
            offs = np.arange(0, L, 0.5)[:, None]
            ks = np.arange(0, (len(x) - 1) / L)[None, :]
            idx = (len(x) - 1) - offs - ks * L
            vals = np.interp(idx, pos, x, left=0.0) * (idx >= 0)
            sums = vals.sum(1)
            j = int(np.argmax(sums))
            if sums[j] > best:
                best, best_lag, best_off, best_mean = float(sums[j]), float(L), float(offs[j, 0]), float(sums.mean())
        bpm = 60 * FPS / best_lag
        beat_idx = int(round(len(x) - 1 - best_off))
        # the flux peaks once the attack is inside the analysis window, ~20 ms late
        beat_ms = self.times[beat_idx] * 1000 - 20
        # hold a tempo unless a different one shows up twice in a row
        if self.bpm and abs(bpm - self.bpm) / self.bpm > 0.04:
            if self.pending and abs(bpm - self.pending) / self.pending < 0.04:
                self.bpm = bpm
                self.pending = 0
            else:
                self.pending = bpm
                bpm = self.bpm
        else:
            self.bpm = bpm if not self.bpm else self.bpm * 0.7 + bpm * 0.3
            bpm = self.bpm
            self.pending = 0
        # how much the onsets gather on the grid: the comb's best phase over its average one
        # (a steady beat stands far out; free time, rubato, only noise hardly: the rhythm mode
        # turns a track down on it)
        fit = best / best_mean if best_mean > 0 else 0.0
        return {"bpm": round(bpm, 2), "beat": round(beat_ms, 1), "conf": round(min(1.0, conf * 4), 3), "fit": round(fit, 2)}


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "system"
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    tracker = Tracker()
    proc = None
    last_report = 0.0
    while True:
        if proc is None or proc.poll() is not None:
            t = target(mode)
            if not t:
                say({"idle": True, "why": "no-spotify" if mode == "spotify" else "no-output"})
                time.sleep(2)
                continue
            node, sink, pos = t
            proc = recorder(node, sink, pos)
            channels = len(pos)
        chunk = proc.stdout.read(HOP * channels * 2)
        if not chunk:
            proc = None
            continue
        now = time.time()
        a = np.frombuffer(chunk, "<i2").reshape(-1, channels).astype(np.float32).sum(1) / (32768.0 * channels)
        tracker.feed(a, now)
        rms = float(np.sqrt(np.mean(a * a))) if len(a) else 0.0
        if rms < 0.003:
            tracker.quiet_since = tracker.quiet_since or now
        else:
            tracker.quiet_since = None
        if now - last_report >= 0.25:
            last_report = now
            if tracker.quiet_since and now - tracker.quiet_since > 1.5:
                say({"idle": True, "why": "silence"})
                continue
            est = tracker.estimate()
            if est:
                est["level"] = round(min(1.0, rms * 8), 3)
                say(est)


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        pass
