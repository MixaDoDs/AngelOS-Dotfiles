#!/usr/bin/env python3
"""Windows in Desktop open where and as big as they were closed (Settings → Windows → Program
places → «Every program where it was closed»; off by default: the owner's way is pins by hand).

Listens to `niri msg -j event-stream`. Every floating window's last place (tile_pos_in_workspace_view)
and size (window_size) is kept; at its closing, written by app-id to
~/.local/state/angelos/window-memory.json. When a program opens its first window (none of its own
open) in Desktop, the window goes to that place and size (set-window-width/height,
move-floating-window by id). Programs pinned by hand (angel-niri's windows.json) are left to
their pins. The shell says whether Desktop is on: a line "desk on" / "desk off" on stdin.

  window-memory.py            the watcher (services/WindowConfig runs it)
  window-memory.py list       what is kept
  window-memory.py forget [APP_ID]   forget one program, or all
"""
import json
import os
import subprocess
import sys
import threading
import time
from pathlib import Path

HOME = Path.home()
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME") or HOME / ".local/state")
STATE = STATE_DIR / "angelos/window-memory.json"
PINS = STATE_DIR / "angel-niri/windows.json"
# the shell's own windows and the like
SKIP = {"", "quickshell", "org.quickshell"}
MIN_W, MIN_H = 200, 120
desk = False


def load():
    try:
        return json.loads(STATE.read_text())
    except (OSError, ValueError):
        return {}


def save(mem):
    STATE.parent.mkdir(parents=True, exist_ok=True)
    tmp = STATE.with_suffix(".tmp")
    tmp.write_text(json.dumps(mem, ensure_ascii=False, indent=1, sort_keys=True))
    tmp.replace(STATE)


def pinned(app):
    try:
        return app in (json.loads(PINS.read_text()).get("pins") or {})
    except (OSError, ValueError, AttributeError):
        return False


def niri(*args):
    return subprocess.run(["niri", "msg", *args], capture_output=True, text=True)


def outputs():
    try:
        out = {}
        for name, o in json.loads(niri("-j", "outputs").stdout).items():
            lg = o.get("logical") or {}
            if lg:
                out[name] = (lg["width"], lg["height"])
        return out
    except (ValueError, AttributeError, KeyError):
        return {}


class Memory:
    def __init__(self):
        self.mem = load()
        self.windows = {}      # id -> the window as last known
        self.geo = {}          # id -> {"x","y","w","h","output"}
        self.workspaces = {}   # id -> output
        self.seen = set()      # there at the start, or done with
        self.started = False

    def on_workspaces(self, wss):
        self.workspaces = {w["id"]: w.get("output") for w in wss}

    def note(self, w):
        self.windows[w["id"]] = w
        lay = w.get("layout") or {}
        pos, size = lay.get("tile_pos_in_workspace_view"), lay.get("window_size")
        if w.get("is_floating") and pos and size:
            self.geo[w["id"]] = {
                "x": round(pos[0]), "y": round(pos[1]),
                "w": int(size[0]), "h": int(size[1]),
                "output": self.workspaces.get(w.get("workspace_id")),
            }

    def on_windows(self, ws):
        for w in ws:
            self.note(w)
            if not self.started:
                self.seen.add(w["id"])
        self.started = True

    def on_opened_or_changed(self, w):
        new = w["id"] not in self.windows and w["id"] not in self.seen
        self.note(w)
        if new:
            self.seen.add(w["id"])
            self.restore(w)

    def on_layouts(self, changes):
        for wid, lay in changes:
            w = self.windows.get(wid)
            if w is not None:
                self.note(dict(w, layout=lay))

    def on_closed(self, wid):
        w = self.windows.pop(wid, None)
        g = self.geo.pop(wid, None)
        self.seen.discard(wid)
        if not w or not g or not w.get("is_floating") or not desk or w.get("is_minimized"):
            return
        app = w.get("app_id") or ""
        if app in SKIP or g["w"] < MIN_W or g["h"] < MIN_H:
            return
        self.mem[app] = g
        save(self.mem)

    def restore(self, w):
        app = w.get("app_id") or ""
        g = self.mem.get(app)
        if not g or app in SKIP or not desk or pinned(app):
            return
        # the program's first window only: a second one and dialogs open as usual
        if any(o.get("app_id") == app and o["id"] != w["id"] for o in self.windows.values()):
            return
        threading.Thread(target=self.place, args=(w["id"], g), daemon=True).start()

    def place(self, wid, g):
        # let angel-niri show the window (and its throw) first
        time.sleep(0.15)
        w = self.windows.get(wid)
        if not w or not w.get("is_floating"):
            return
        outs = outputs()
        out = self.workspaces.get(w.get("workspace_id"))
        sw, sh = outs.get(out) or next(iter(outs.values()), (1920, 1080))
        ww, wh = min(g["w"], sw), min(g["h"], sh)
        # kept on the screen (another monitor, another resolution)
        x = max(0, min(g["x"], sw - min(ww, 120)))
        y = max(0, min(g["y"], sh - 60))
        i = str(wid)
        niri("action", "set-window-width", "--id", i, str(ww))
        niri("action", "set-window-height", "--id", i, str(wh))
        niri("action", "move-floating-window", "--id", i, "-x", str(x), "-y", str(y))
        # move-floating-window counts from the working area (no bars), the IPC position from the
        # screen's edge: see where it stood and move it by the difference
        time.sleep(0.1)
        pos = self.pos_of(wid)
        if pos:
            dx, dy = x - round(pos[0]), y - round(pos[1])
            if dx or dy:
                niri("action", "move-floating-window", "--id", i, "-x", f"{dx:+d}", "-y", f"{dy:+d}")

    def pos_of(self, wid):
        try:
            for w in json.loads(niri("-j", "windows").stdout):
                if w["id"] == wid:
                    return (w.get("layout") or {}).get("tile_pos_in_workspace_view")
        except (ValueError, KeyError):
            pass
        return None


def read_shell():
    global desk
    for line in sys.stdin:
        if line.startswith("desk "):
            desk = line.split()[1] == "on"
    os._exit(0)   # the shell is gone


def serve():
    threading.Thread(target=read_shell, daemon=True).start()
    m = Memory()
    while True:
        p = subprocess.Popen(["niri", "msg", "-j", "event-stream"], stdout=subprocess.PIPE, text=True)
        for line in p.stdout:
            try:
                ev = json.loads(line)
                k, v = next(iter(ev.items()))
            except (ValueError, StopIteration, AttributeError):
                continue
            if k == "WorkspacesChanged":
                m.on_workspaces(v["workspaces"])
            elif k == "WindowsChanged":
                m.on_windows(v["windows"])
            elif k == "WindowOpenedOrChanged":
                m.on_opened_or_changed(v["window"])
            elif k == "WindowLayoutsChanged":
                m.on_layouts(v["changes"])
            elif k == "WindowClosed":
                m.on_closed(v["id"])
        p.wait()
        time.sleep(2)  # niri restarted: connect again


def main():
    a = sys.argv[1:]
    if not a:
        serve()
    elif a[0] == "list":
        for app, g in sorted(load().items()):
            print(f"{app}: {g['w']}x{g['h']} at ({g['x']}, {g['y']}) on {g.get('output')}")
    elif a[0] == "forget":
        mem = load()
        if len(a) > 1:
            mem.pop(a[1], None)
        else:
            mem = {}
        save(mem)
    else:
        print(__doc__)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
