#!/usr/bin/env python3
"""Programs' volumes back as they were, if the shell went away while hell's circles had them
turned down (services/AppDuck).

  duck-restore.py [STATE]     STATE: ~/.local/state/angelos/duck.json

AppDuck writes STATE before it turns anything down and empties it once every program is back.
A STATE with streams in it therefore means the shell died, was stopped or restarted in the
middle: `angelos reap` (systemd's ExecStopPost) and the shell's own start run this. Each stream
still there under the same name gets its volume back through pactl; the percent there is the
same fader scale as Quickshell's volume (cubic), so 0.62 → 62 %. Prints what it restored.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

state = Path(sys.argv[1] if len(sys.argv) > 1 else
             os.path.expanduser("~/.local/state/angelos/duck.json"))


def main():
    try:
        saved = json.loads(state.read_text() or "{}").get("streams") or {}
    except (OSError, ValueError, AttributeError):
        return
    if not saved:
        return
    try:
        out = subprocess.run(["pactl", "-f", "json", "list", "sink-inputs"], capture_output=True,
                             text=True, timeout=5).stdout
        # keyed by PipeWire's object id (what Quickshell calls a node's id); pactl's own index
        # is the object's serial, a different number
        live = {str((s.get("properties") or {}).get("object.id")): s for s in json.loads(out or "[]")}
    except (OSError, ValueError, subprocess.SubprocessError):
        return                       # no sound server to ask: STATE stays for the next try
    done = []
    for sid, entry in saved.items():
        s = live.get(sid)
        if not s:
            continue
        props = s.get("properties") or {}
        if entry.get("name") and entry["name"] not in (props.get("node.name"), props.get("application.name")):
            continue                 # the id went to another program meanwhile
        vol = max(0.0, min(1.5, float(entry.get("vol", 1))))
        subprocess.run(["pactl", "set-sink-input-volume", str(s.get("index")), f"{vol * 100:.1f}%"], timeout=5)
        done.append(f"{entry.get('name') or sid} {vol * 100:.0f}%")
    try:
        state.write_text("{}")
    except OSError:
        pass
    if done:
        print("restored: " + ", ".join(done))


if __name__ == "__main__":
    main()
