#!/usr/bin/env python3
"""Why Discord fell, said once it falls (services/DiscordVoice starts it).

Discord sharing the screen with sound opens a capture of its own for every app's audio stream
and drops it when that stream ends; now and then its Voice thread dies right then (2026-10-21,
SIGTRAP: "sink … deleted", then "sample rate diff: 67797%", 8 s later the crash). angelOS keeps
its own stream open for good (sfx-player), but another app or a Discord update can bring it
back. This follows systemd-coredump in the journal and, when Discord dies, reads its WebRTC log
for audio streams that went away just before.

  stdout, one line a crash:  JSON {"pid": N, "apps": [name…]}   (apps empty: not that)
  discord-crash-watch.py --at UNIX_TIME   the apps for a crash at that time, then exits
"""
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

HOME = Path.home()
LOG_DIRS = [HOME / ".var/app/com.discordapp.Discord/config/discord/logs",
            HOME / ".config/discord/logs"]
# the log of the session that fell: current until Discord starts again, then "last"
LOGS = ["discord-webrtc_0", "discord-last-webrtc_0"]
WINDOW = 30.0              # s before the crash a stream that went counts
TAIL = 4 << 20             # bytes read from the end of a log
DEDUP = 60.0               # s: one crash takes several Discord processes along

CRASH = re.compile(r"^Process (\d+) \(Discord\) of user (\d+) terminated abnormally")
STAMP = re.compile(r"^\[(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\.\d{3})\]")
NAMED = re.compile(r"SinkIdentified name: (.*?)index: (\d+) pid: (\d+)")
GONE = re.compile(r"sink input deleted\. (\d+)")


def label(name, pid):
    """the stream's name, and its program when the name doesn't say ("Playback" is a browser)"""
    try:
        # Chromium & co. rewrite theirs into one space-joined string
        exe = Path(Path(f"/proc/{pid}/cmdline").read_bytes().split(b"\0")[0].decode().split(" ")[0]).name
    except (OSError, UnicodeDecodeError):
        return name
    return f"{name} ({exe})" if exe and exe.lower() not in name.lower() else name


def gone_apps(at):
    """the names of the audio streams Discord was capturing that ended in WINDOW before `at`"""
    names, gone = {}, []
    for d in LOG_DIRS:
        for name in LOGS:
            f = d / name
            try:
                with open(f, "rb") as fh:
                    fh.seek(max(0, f.stat().st_size - TAIL))
                    text = fh.read().decode("utf-8", "replace")
            except OSError:
                continue
            for line in text.splitlines():
                m = STAMP.match(line)
                if not m:
                    continue
                n = NAMED.search(line)
                if n:
                    names[n.group(2)] = label(n.group(1).strip(), n.group(3))
                    continue
                g = GONE.search(line)
                if g:
                    t = datetime.strptime(m.group(1), "%Y-%m-%d %H:%M:%S.%f").timestamp()
                    if at - WINDOW <= t <= at:
                        gone.append(g.group(1))
    apps = []
    for i in gone:
        app = names.get(i, "?")
        if app not in apps:
            apps.append(app)
    return apps


def watch():
    uid, last = str(os.getuid()), 0.0
    while True:
        j = subprocess.Popen(["journalctl", "-f", "-n", "0", "-o", "json", "-t", "systemd-coredump"],
                             stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        for raw in j.stdout:
            try:
                e = json.loads(raw)
            except ValueError:
                continue
            m = CRASH.match(str(e.get("MESSAGE", "")))
            if not m or m.group(2) != uid:
                continue
            at = int(e.get("__REALTIME_TIMESTAMP", 0)) / 1e6 or time.time()
            if at - last < DEDUP:
                continue
            last = at
            time.sleep(2)          # Discord's last lines reach the log
            print(json.dumps({"pid": int(m.group(1)), "apps": gone_apps(at)}), flush=True)
        j.wait()
        time.sleep(10)             # the journal went away: follow it again


if __name__ == "__main__":
    try:  # go away together with the shell, even on its SIGKILL (stand restarts left copies behind)
        import ctypes
        import signal
        ctypes.CDLL(None).prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG
    except (OSError, AttributeError):
        pass
    if len(sys.argv) == 3 and sys.argv[1] == "--at":
        print(json.dumps(gone_apps(float(sys.argv[2]))))
    else:
        watch()
