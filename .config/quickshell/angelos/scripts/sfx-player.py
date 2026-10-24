#!/usr/bin/env python3
"""angelOS sounds through one long-lived audio stream (Sounds.qml starts it).

  stdin, one sound per line:  VOLUME<TAB>PATH[<TAB>PATH…]   (the first PATH that exists plays;
                              VOLUME 0 only decodes it ahead and opens the stream)
         or a loop (music):   loop<TAB>VOLUME<TAB>PATH          (plays round and round, gliding to
                              VOLUME over FADE seconds; VOLUME 0 fades it out and stops it)

Why not one pw-play per sound: every click then makes a new stream and drops it a moment
later. Discord, sharing the screen with sound, opens a capture of its own for each new stream
and tears it down again; a few clicks a second for an hour made it freeze the share and grow to
13 GB (2026-10-07, logs: PulseAudioController "Creating stream for sink …" every second). Mixers
jumped for the same reason. Here the stream stays for good: after a quiet minute it is only no
longer fed (an underrun, no CPU), never closed. Closing it once a minute still crashed Discord
mid-share: its Voice thread died right after the stream went (2026-10-21, SIGTRAP, logs:
"sink … deleted", then "sample rate diff: 67797%").

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
IDLE_STOP = 60.0           # s of silence before the stream stops being fed (it stays open)
CACHE_MAX = 96             # decoded files kept
PIPE_SIZE = 8192           # bytes in the pipe to pacat (~21 ms): its latency on top of pacat's
F_SETPIPE_SZ = 1031
WAIT = 2.5                 # s a sound may wait for the sound server
FADE = 1.2                 # s a loop takes to glide to a new volume

WARM = np.zeros((BLOCK * 20, CHANNELS), dtype=np.float32)   # 200 ms of silence

lock = threading.Condition()
voices = []                # [samples (n, 2) float32, position, volume, wait-until (monotonic)]
cache = {}                 # (path, mtime) -> samples
loop = None                # {"stream", "path", "vol", "target"}: the one loop playing
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


class LoopStream:
    """A long tune read from disk as it plays (minutes of float would be hundreds of MB):
    ffmpeg decodes ahead into a couple of seconds of blocks, from a random place the first
    time, from the start at every end after that; the blocks ahead hide the restart."""

    AHEAD = 200            # blocks decoded ahead (2 s)

    def __init__(self, path):
        self.path = path
        self.blocks = []
        self.cv = threading.Condition()
        self.stop = False
        try:
            r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
                               capture_output=True, text=True, timeout=5)
            length = float(r.stdout.strip() or 0)
        except (OSError, ValueError, subprocess.SubprocessError):
            length = 0
        self.start = float(np.random.uniform(0, length * 0.9)) if length > 30 else 0.0
        threading.Thread(target=self.run, daemon=True).start()

    def run(self):
        start = self.start
        size = BLOCK * CHANNELS * 4
        while not self.stop:
            try:
                proc = subprocess.Popen(["ffmpeg", "-v", "quiet", "-ss", str(start), "-i", self.path, "-f", "f32le",
                                         "-ac", str(CHANNELS), "-ar", str(RATE), "-"], stdout=subprocess.PIPE)
            except OSError:
                return
            start = 0.0
            got = False
            while not self.stop:
                data = proc.stdout.read(size)
                if not data:
                    break
                got = True
                if len(data) < size:
                    data += bytes(size - len(data))
                blk = np.frombuffer(data, dtype=np.float32).reshape(-1, CHANNELS)
                with self.cv:
                    while len(self.blocks) >= self.AHEAD and not self.stop:
                        self.cv.wait()
                    self.blocks.append(blk)
            proc.kill()
            proc.wait()
            if not got:
                return             # the file can't be read: no endless retries

    def next(self):
        with self.cv:
            blk = self.blocks.pop(0) if self.blocks else None
            self.cv.notify()
        return blk

    def close(self):
        with self.cv:
            self.stop = True
            self.cv.notify()


def set_loop(parts):
    global loop
    try:
        vol = max(0.0, min(2.0, float(parts[1])))
    except (IndexError, ValueError):
        return
    path = parts[2] if len(parts) > 2 else ""
    with lock:
        if loop is not None and (vol == 0 or path == loop["path"]):
            loop["target"] = vol
            lock.notify()
            return
    if vol == 0 or not os.path.isfile(path):
        return
    with lock:
        if loop is not None:
            loop["stream"].close()
        # another tune: up from silence
        loop = {"stream": LoopStream(path), "path": path, "vol": 0.0, "target": vol}
        lock.notify()


def mix_loop(block):
    """The loop's next block into `block`, its volume gliding; False with no loop."""
    if loop is None:
        return False
    blk = loop["stream"].next()
    step = BLOCK / RATE / FADE
    v0, t = loop["vol"], loop["target"]
    v1 = min(t, v0 + step) if t > v0 else max(t, v0 - step)
    if blk is not None:
        block += blk * np.linspace(v0, v1, BLOCK, dtype=np.float32)[:, None]
    loop["vol"] = v1
    return True


def reader():
    global done
    for line in sys.stdin:
        parts = line.rstrip("\n").split("\t")
        if parts[0] == "loop":
            set_loop(parts)
            continue
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
    global loop
    threading.Thread(target=reader, daemon=True).start()
    proc, last_sound = None, 0.0
    heard = False              # a write went through since the server was last missing
    block = np.zeros((BLOCK, CHANNELS), dtype=np.float32)
    while True:
        with lock:
            if proc is None:
                while not voices and loop is None and not done:
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
            looping = mix_loop(block)
            busy = bool(mixed) or looping
        if busy:
            last_sound = now
        elif now - last_sound > IDLE_STOP:
            with lock:
                while not voices and loop is None and not done:
                    lock.wait()
            last_sound = time.monotonic()
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
            if loop is not None and loop["vol"] == 0 and loop["target"] == 0:
                loop["stream"].close()
                loop = None
    if proc is not None:
        close_stream(proc)


if __name__ == "__main__":
    main()
