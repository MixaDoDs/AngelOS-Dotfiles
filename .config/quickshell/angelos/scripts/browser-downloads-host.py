#!/usr/bin/env python3
"""angelOS: the native messaging host of the browser extension data/browser-downloads.

Chromium starts it when the extension connects and talks over stdin (4-byte length + JSON).
Each message — {at, list: [{id, file, received, total, paused}]} — goes as it is into
$XDG_RUNTIME_DIR/angelos-browser-downloads.json, which services/Downloads watches for the Halo's
progress. When the browser lets go (nothing downloads, or it quits) the list is written empty.
"""
import json
import os
import struct
import sys
import time

# a browser started from a launcher may have no XDG_RUNTIME_DIR: the shell's is /run/user/<uid>
OUT = os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/run/user/%d" % os.getuid(), "angelos-browser-downloads.json")


def write(data):
    tmp = OUT + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f)
    os.replace(tmp, OUT)


def main():
    inp = sys.stdin.buffer
    while True:
        head = inp.read(4)
        if len(head) < 4:
            break
        n = struct.unpack("=I", head)[0]
        body = inp.read(n)
        if len(body) < n:
            break
        try:
            msg = json.loads(body)
        except ValueError:
            continue
        if isinstance(msg, dict) and isinstance(msg.get("list"), list):
            write(msg)
    write({"at": int(time.time() * 1000), "list": []})


if __name__ == "__main__":
    main()
