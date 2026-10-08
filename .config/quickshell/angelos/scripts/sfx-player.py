#!/usr/bin/env python3
"""angelOS sounds through one long-lived audio stream (Sounds.qml starts it).

  stdin, one sound per line:  VOLUME<TAB>PATH[<TAB>PATH…]   (the first PATH that exists plays;
                              VOLUME 0 only decodes it ahead and opens the stream)

Why not one pw-play per sound: every click then makes a new stream and drops it a moment
later. Discord, sharing the screen with sound, opens a capture of its own for each new stream
and tears it down again; a few clicks a second for an hour made it freeze the share and grow to
13 GB (2026-10-07, logs: PulseAudioController "Creating stream for sink …" every second). Mixers
jumped for the same reason. Here the stream stays while sounds play and closes after a quiet
minute, so a share sees it come and go rarely, not per click.

Files are decoded once by ffmpeg (any format: ogg wav aiff caf mp3…) and kept in memory,
mixed here and fed to pacat as raw float PCM; the pipe paces the loop in real time.

Until the sound server answers with a real output (right after login PipeWire, or the
RØDECaster behind it, may not be up yet) a sound waits up to WAIT seconds instead of being
mixed into a stream that goes nowhere; a sound plays from its start once a write went through.
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
WAIT = 2.5                 # s a sound may wait for the sound server

WARM = np.zeros((BLOCK * 20, CHANNELS), dtype=np.float32)   # 200 ms of silence

lock = threading.Condition()
voices = []                # [samples (n, 2) float32, position, volume, wait-until (monotonic)]
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
        if samples is None:
            continue
        if vol == 0:
            # a warm-up (VOLUME 0): decoded now and kept, and the stream opened with a moment of
            # silence, so the real sound a second later starts on the dot
            samples = WARM
        with lock:
            voices.append([samples, 0, vol, time.monotonic() + WAIT])
            lock.notify()
    with lock:
        done = True
        lock.notify()


def server_ready():
    """The sound server answers and has a real output (not PipeWire's "auto_null" stand-in)."""
    try:
        r = subprocess.run(["pactl", "get-default-sink"], capture_output=True, text=True, timeout=WAIT)
    except FileNotFoundError:
        return True            # no pactl to ask: pacat finds out
    except (OSError, subprocess.SubprocessError):
        return False
    sink = r.stdout.strip()
    return r.returncode == 0 and sink not in ("", "auto_null")


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
    heard = False              # a write went through since the server was last missing
    block = np.zeros((BLOCK, CHANNELS), dtype=np.float32)
    while True:
        with lock:
            if proc is None:
                while not voices and not done:
                    lock.wait()
            if done and not voices:
                break
        now = time.monotonic()
        if proc is not None and proc.poll() is not None:
            proc, heard = None, False      # pacat died (pipewire-pulse restarted)
        if proc is None:
            # the server is asked only while it may be missing (start-up, after a failure)
            if not heard and not server_ready():
                with lock:
                    late = time.monotonic()
                    voices[:] = [v for v in voices if late <= v[3]]
                time.sleep(0.05)
                continue
            proc = open_stream()
            last_sound = now
        with lock:
            block.fill(0)
            mixed = list(voices)
            for samples, pos, vol, _ in mixed:
                chunk = samples[pos:pos + BLOCK]
                block[:len(chunk)] += chunk * vol
            busy = bool(mixed)
        if busy:
            last_sound = now
        elif now - last_sound > IDLE_CLOSE:
            close_stream(proc)
            proc = None
            continue
        np.clip(block, -1.0, 1.0, out=block)
        try:
            proc.stdin.write(block.tobytes())
            proc.stdin.flush()
        except (BrokenPipeError, OSError):
            proc, heard = None, False      # the block plays again on the next stream
            continue
        heard = True
        # only what went out moves on (a sound that came meanwhile starts with the next block)
        with lock:
            for v in mixed:
                v[1] += BLOCK
            voices[:] = [v for v in voices if v[1] < len(v[0])]
    if proc is not None:
        close_stream(proc)


if __name__ == "__main__":
    main()
