#!/usr/bin/env python3
"""Does any program really make a sound now? Prints 1 or 0 on stdout when that changes.

Listens to each program's own stream, so the scene's air (angelOS's own sounds) can't hear
itself and an open but silent Discord doesn't count. Read-only: it only records.
  sound-watch.py             run
  sound-watch.py --selftest  the checks
"""
import array
import ctypes
import json
import os
import selectors
import subprocess
import sys
import time

RATE = 8000     # enough to tell sound from silence, and cheap
FLOOR = 100     # peak of 32768, about -50 dB: under it is silence
HOLD = 2.0      # s a sound counts for after it stops: a gap between songs isn't silence
SCAN = 3.0      # s between looks for new streams
OWN = ("quickshell", "pw-play", "pw-cat", "angelos-sfx")  # the same list as Audio.isAppStream


def is_app_stream(s):
    p = s.get("properties", {})
    if s.get("corked") or str(p.get("node.virtual")) == "true":
        return False
    if str(p.get("node.link-group", "")).startswith("loopback"):
        return False
    if p.get("application.name", p.get("node.name", "")) in OWN:
        return False
    return "/angelos/sounds/" not in p.get("media.name", "")


def peak(data):
    a = array.array("h", data[:len(data) // 2 * 2])
    return max(map(abs, a), default=0)


def scan():
    try:
        out = subprocess.run(["pactl", "-f", "json", "list", "sink-inputs"], capture_output=True, text=True, timeout=5).stdout
        return {s["index"] for s in json.loads(out) if is_app_stream(s)}
    except (OSError, ValueError, KeyError, subprocess.TimeoutExpired):
        return set()  # the sound server restarting: next look


def die_with_parent():
    ctypes.CDLL(None).prctl(1, 9)  # PR_SET_PDEATHSIG, SIGKILL


def listen(index):
    return subprocess.Popen(["parec", "--monitor-stream=%d" % index, "--rate=%d" % RATE, "--channels=1", "--format=s16le", "--latency-msec=500",
                             "--client-name=angelos-sound-watch", "--property=node.name=angelos-sound-watch"],
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, preexec_fn=die_with_parent)


def run():
    die_with_parent()
    sel = selectors.DefaultSelector()
    procs = {}
    heard, said, scanned = 0.0, None, 0.0

    def drop(index):
        p = procs.pop(index)
        sel.unregister(p.stdout)
        p.kill()
        p.stdout.close()
        p.wait()

    while True:
        now = time.monotonic()
        if now - scanned >= SCAN:
            scanned = now
            streams = scan()
            for index in set(procs) - streams:
                drop(index)
            for index in streams - set(procs):
                procs[index] = listen(index)
                sel.register(procs[index].stdout, selectors.EVENT_READ, index)
        for key, _ in sel.select(1.0):
            data = os.read(key.fileobj.fileno(), 8192)
            if not data:
                drop(key.data)
            elif peak(data) > FLOOR:
                heard = time.monotonic()
        loud = time.monotonic() - heard < HOLD and heard > 0
        if loud != said:
            said = loud
            print("1" if loud else "0", flush=True)


def selftest():
    app = {"corked": False, "properties": {"application.name": "Spotify", "media.name": "Spotify"}}
    assert is_app_stream(app)
    assert not is_app_stream({**app, "corked": True})
    assert not is_app_stream({"properties": {"application.name": "angelos-sfx"}})
    assert not is_app_stream({"properties": {"node.virtual": "true"}})
    assert not is_app_stream({"properties": {"node.link-group": "loopback-1"}})
    assert not is_app_stream({"properties": {"application.name": "x", "media.name": "/a/angelos/sounds/b.ogg"}})
    assert peak(array.array("h", [0, -500, 20]).tobytes()) == 500
    assert peak(b"") == 0 and peak(b"\x01") == 0
    print("ok")


if __name__ == "__main__":
    selftest() if "--selftest" in sys.argv else run()
