#!/usr/bin/env python3
"""Drive a terminal program in a pseudo terminal for a recording: wait until its screen is quiet
for a moment, press the next key, and so on (the installer's GIF; scripts/demo/shots.sh).
The program draws into this terminal as usual.

  drive.py '["\\r", "\\u001b[B\\r"]' COMMAND…     keys as a JSON list (\\u001b[B = arrow down)
"""
import json
import os
import pty
import select
import sys
import time

keys = json.loads(sys.argv[1])
pid, fd = pty.fork()
if pid == 0:
    os.execvp(sys.argv[2], sys.argv[2:])
try:
    import fcntl, struct, termios  # noqa: E401
    size = fcntl.ioctl(sys.stdout.fileno(), termios.TIOCGWINSZ, b"\0" * 8)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, size)
except OSError:
    pass
ki, last = 0, time.time()
while True:
    r, _, _ = select.select([fd], [], [], 0.2)
    if r:
        try:
            data = os.read(fd, 65536)
        except OSError:
            break
        if not data:
            break
        os.write(sys.stdout.fileno(), data)
        last = time.time()
    elif time.time() - last > float(os.environ.get("DRIVE_PAUSE", "1.4")) and ki < len(keys):
        os.write(fd, keys[ki].encode())
        ki, last = ki + 1, time.time()
os.waitpid(pid, 0)
