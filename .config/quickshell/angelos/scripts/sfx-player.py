#!/usr/bin/env python3
"""angelOS sounds through one long-lived audio stream (Sounds.qml starts it).

  stdin, one sound per line:  VOLUME<TAB>PATH[<TAB>PATH…]   (the first PATH that exists plays)

Why not one pw-play per sound: every click then makes a new stream and drops it a moment
later. Discord, sharing the screen with sound, opens a capture of its own for each new stream
and tears it down again; a few clicks a second for an hour made it freeze the share and grow to
13 GB (2026-10-07, logs: PulseAudioController "Creating stream for sink …" every second). Mixers
jumped for the same reason. Here the stream stays while sounds play and closes after a quiet
minute, so a share sees it come and go rarely, not per click.

Files are decoded once by ffmpeg (any format: ogg wav aiff caf mp3…) and kept in memory,
mixed here and fed to pacat as raw float PCM; the pipe paces the loop in real time.
"""
import fcntl
import os
import subprocess
import sys
import threading
import time

import numpy as np

RATE = 48000
CHANNELS = 2
BLOCK = 480                # frames per write: 10 ms
IDLE_CLOSE = 60.0          # s of silence before the stream closes
CACHE_MAX = 96             # decoded files kept
PIPE_SIZE = 8192           # bytes in the pipe to pacat (~21 ms): its latency on top of pacat's
F_SETPIPE_SZ = 1031

lock = threading.Condition()
voices = []                # [samples (n, 2) float32, position, volume]
cache = {}                 # (path, mtime) -> samples
done = False


def decode(path):
    try:
        key = (path, os.stat(path).st_mtime_ns)
    except OSError:
        return None
    if key in cache:
        return cache[key]
    try:
        out = subprocess.run(["ffmpeg", "-v", "quiet", "-i", path, "-f", "f32le", "-ac", str(CHANNELS),
                              "-ar", str(RATE), "-"], capture_output=True, timeout=10).stdout
    except (OSError, subprocess.SubprocessError):
        return None
    if not out:
        return None
    samples = np.frombuffer(out, dtype=np.float32).reshape(-1, CHANNELS)
    if len(cache) >= CACHE_MAX:
        cache.pop(next(iter(cache)))
    cache[key] = samples
    return samples


def reader():
    global done
    for line in sys.stdin:
        parts = line.rstrip("\n").split("\t")
        if len(parts) < 2:
            continue
        try:
            vol = max(0.0, min(2.0, float(parts[0])))
        except ValueError:
            continue
        path = next((p for p in parts[1:] if p and os.path.isfile(p)), None)
        samples = decode(path) if path else None
        if samples is None or vol == 0:
            continue
        with lock:
            voices.append([samples, 0, vol])
            lock.notify()
    with lock:
        done = True
        lock.notify()


def open_stream():
    proc = subprocess.Popen(["pacat", "--playback", "--raw", "--format=float32le", f"--rate={RATE}",
                             f"--channels={CHANNELS}", "--latency-msec=30", "--client-name=angelos-sfx",
                             "--stream-name=angelOS sounds", "--property=application.name=angelos-sfx",
                             "--property=media.role=event"], stdin=subprocess.PIPE)
    try:
        fcntl.fcntl(proc.stdin.fileno(), F_SETPIPE_SZ, PIPE_SIZE)
    except OSError:
        pass
    return proc


def close_stream(proc):
    try:
        proc.stdin.close()
    except OSError:
        pass
    try:
        proc.wait(timeout=2)
    except subprocess.TimeoutExpired:
        proc.kill()


def main():
    threading.Thread(target=reader, daemon=True).start()
    proc, last_sound = None, 0.0
    block = np.zeros((BLOCK, CHANNELS), dtype=np.float32)
    while True:
        with lock:
            if proc is None:
                while not voices and not done:
                    lock.wait()
            if done and not voices:
                break
            block.fill(0)
            for v in voices:
                samples, pos, vol = v
                chunk = samples[pos:pos + BLOCK]
                block[:len(chunk)] += chunk * vol
                v[1] = pos + BLOCK
            voices[:] = [v for v in voices if v[1] < len(v[0])]
            busy = bool(voices)
        now = time.monotonic()
        if busy:
            last_sound = now
        elif proc is not None and now - last_sound > IDLE_CLOSE:
            close_stream(proc)
            proc = None
            continue
        if proc is None or proc.poll() is not None:
            proc = open_stream()
            last_sound = now
        np.clip(block, -1.0, 1.0, out=block)
        try:
            proc.stdin.write(block.tobytes())
            proc.stdin.flush()
        except (BrokenPipeError, OSError):
            proc = None        # pacat died (pipewire-pulse restarted): a new one next block
    if proc is not None:
        close_stream(proc)


if __name__ == "__main__":
    main()
