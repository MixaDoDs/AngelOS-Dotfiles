#!/usr/bin/env python3
"""Pick a file the way the desktop does: the XDG portal's file chooser (xdg-desktop-portal-gnome
or -gtk, packages/pacman.txt — on every install), else zenity or kdialog when one is there.

usage: pick-file.py [OPTIONS] TITLE [FILTER_NAME PATTERN...]
  --dir            a folder instead of a file
  --multi          several files at once: one path per line
  --start DIR      open in DIR (else the folder of the last pick, see --remember)
  --remember KEY   the folder of the last pick is remembered per KEY ("default" without it)
                   in $XDG_STATE_HOME/angelos/pick-dirs.json: the next chooser opens there,
                   not in ~ every time (the release wallpapers' six files from one folder)

Prints the chosen file's path. Exit 1: cancelled. Exit 2: no file chooser at all (why on stderr).
The avatar picker used zenity alone, which angelOS never installs: without it the button did
nothing at all.
"""
import json
import os
import shutil
import subprocess
import sys
from urllib.parse import unquote, urlparse

CANCELLED, NONE = 1, 2
DIRECTORY = False      # --dir: pick a folder
MULTI = False          # --multi: several files
START = ""             # the folder the chooser opens in
STATE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "angelos", "pick-dirs.json")


def remembered(key):
    try:
        d = json.load(open(STATE)).get(key, "")
    except (OSError, ValueError, AttributeError):
        return ""
    return d if d and os.path.isdir(d) else ""


def remember(key, paths):
    """the folder the pick came from (a picked folder's parent: the next opens beside it)"""
    d = os.path.dirname(paths[0].rstrip("/"))
    if not d:
        return
    try:
        all_ = json.load(open(STATE))
        if not isinstance(all_, dict):
            all_ = {}
    except (OSError, ValueError):
        all_ = {}
    all_[key] = d
    try:
        os.makedirs(os.path.dirname(STATE), exist_ok=True)
        tmp = STATE + ".tmp"
        with open(tmp, "w") as f:
            json.dump(all_, f, ensure_ascii=False, indent=1)
        os.replace(tmp, STATE)
    except OSError:
        pass


def portal(title, name, patterns):
    """org.freedesktop.portal.FileChooser.OpenFile: the paths, [] when cancelled, None without one"""
    try:
        from gi.repository import Gio, GLib
    except ImportError as e:
        print(f"portal: {e}", file=sys.stderr)
        return None
    try:
        bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    except GLib.Error as e:
        print(f"portal: {e.message}", file=sys.stderr)
        return None
    token = f"angelos_pick_{os.getpid()}"
    expected = "/org/freedesktop/portal/desktop/request/%s/%s" % (bus.get_unique_name()[1:].replace(".", "_"), token)
    loop = GLib.MainLoop()
    state = {"handle": expected}

    def response(_conn, _sender, path, _iface, _signal, params):
        if path not in (expected, state["handle"]):
            return
        code, results = params.unpack()
        state["code"], state["uris"] = code, results.get("uris") or []
        loop.quit()

    # subscribed before the call: the answer can't slip by in between
    sub = bus.signal_subscribe("org.freedesktop.portal.Desktop", "org.freedesktop.portal.Request", "Response",
                               None, None, Gio.DBusSignalFlags.NONE, response)
    options = {"handle_token": GLib.Variant("s", token), "modal": GLib.Variant("b", True)}
    if DIRECTORY:
        options["directory"] = GLib.Variant("b", True)
    if MULTI:
        options["multiple"] = GLib.Variant("b", True)
    if START:
        # a NUL-terminated byte string (the portal's "ay")
        options["current_folder"] = GLib.Variant("ay", os.fsencode(START) + b"\0")
    if patterns:
        flt = (name or "", [(0, p) for p in patterns])
        options["filters"] = GLib.Variant("a(sa(us))", [flt])
        options["current_filter"] = GLib.Variant("(sa(us))", flt)
    try:
        reply = bus.call_sync("org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop",
                              "org.freedesktop.portal.FileChooser", "OpenFile",
                              GLib.Variant("(ssa{sv})", ("", title, options)), GLib.VariantType("(o)"),
                              Gio.DBusCallFlags.NONE, -1, None)
    except GLib.Error as e:   # no portal, or one without a file chooser
        bus.signal_unsubscribe(sub)
        print(f"portal: {e.message}", file=sys.stderr)
        return None
    state["handle"] = reply.unpack()[0]
    if "code" not in state:
        loop.run()
    bus.signal_unsubscribe(sub)
    if state["code"] == 1:
        return []
    if state["code"] != 0:   # the backend failed to show it: let the others try
        print(f"portal: response {state['code']}", file=sys.stderr)
        return None
    return [unquote(u.path) for u in map(urlparse, state["uris"]) if u.scheme == "file"]


def tool(title, name, patterns):
    """zenity or kdialog: the paths, [] when cancelled, None without either"""
    if shutil.which("zenity"):
        cmd = ["zenity", "--file-selection", f"--title={title}"] + (["--directory"] if DIRECTORY else [])
        if MULTI:
            cmd += ["--multiple", "--separator=\n"]
        if START:
            cmd.append("--filename=" + START.rstrip("/") + "/")
        if patterns:
            cmd.append(f"--file-filter={name} | {' '.join(patterns)}")
    elif shutil.which("kdialog"):
        cmd = ["kdialog", "--title", title, "--getexistingdirectory" if DIRECTORY else "--getopenfilename", START or os.path.expanduser("~")]
        if patterns:
            cmd.append(f"{' '.join(patterns)}|{name}")
        if MULTI:
            cmd += ["--multiple", "--separate-output"]
    else:
        return None
    r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    return [l for l in r.stdout.splitlines() if l.strip()] if r.returncode == 0 else []


def main():
    global DIRECTORY, MULTI, START
    args, key = sys.argv[1:], "default"
    while args and args[0].startswith("--"):
        opt = args.pop(0)
        if opt == "--dir":
            DIRECTORY = True
        elif opt == "--multi":
            MULTI = True
        elif opt in ("--start", "--remember") and args:
            val = args.pop(0)
            if opt == "--start":
                START = os.path.expanduser(val) if os.path.isdir(os.path.expanduser(val)) else ""
            else:
                key = val or "default"
        else:
            sys.exit(__doc__)
    if not args:
        sys.exit(__doc__)
    START = START or remembered(key)
    title, name, patterns = args[0], (args[1] if len(args) > 1 else ""), args[2:]
    for way in (portal, tool):
        paths = way(title, name, patterns)
        if paths is None:
            continue
        if not paths:
            return CANCELLED
        remember(key, paths)
        print("\n".join(paths if MULTI else paths[:1]))
        return 0
    print("no file chooser: neither the XDG portal (xdg-desktop-portal-gnome / -gtk) nor zenity or kdialog",
          file=sys.stderr)
    return NONE


if __name__ == "__main__":
    sys.exit(main())
