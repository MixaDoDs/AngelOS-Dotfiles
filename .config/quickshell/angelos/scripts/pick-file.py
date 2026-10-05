#!/usr/bin/env python3
"""Pick a file the way the desktop does: the XDG portal's file chooser (xdg-desktop-portal-gnome
or -gtk, packages/pacman.txt — on every install), else zenity or kdialog when one is there.

usage: pick-file.py TITLE [FILTER_NAME PATTERN...]

Prints the chosen file's path. Exit 1: cancelled. Exit 2: no file chooser at all (why on stderr).
The avatar picker used zenity alone, which angelOS never installs: without it the button did
nothing at all.
"""
import os
import shutil
import subprocess
import sys
from urllib.parse import unquote, urlparse

CANCELLED, NONE = 1, 2


def portal(title, name, patterns):
    """org.freedesktop.portal.FileChooser.OpenFile: the path, "" when cancelled, None without one"""
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
        return ""
    if state["code"] != 0:   # the backend failed to show it: let the others try
        print(f"portal: response {state['code']}", file=sys.stderr)
        return None
    for uri in state["uris"]:
        u = urlparse(uri)
        if u.scheme == "file":
            return unquote(u.path)
    return ""


def tool(title, name, patterns):
    """zenity or kdialog: the path, "" when cancelled, None without either"""
    if shutil.which("zenity"):
        cmd = ["zenity", "--file-selection", f"--title={title}"]
        if patterns:
            cmd.append(f"--file-filter={name} | {' '.join(patterns)}")
    elif shutil.which("kdialog"):
        cmd = ["kdialog", "--title", title, "--getopenfilename", os.path.expanduser("~")]
        if patterns:
            cmd.append(f"{' '.join(patterns)}|{name}")
    else:
        return None
    r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    return r.stdout.strip() if r.returncode == 0 else ""


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    title, name, patterns = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else ""), sys.argv[3:]
    for way in (portal, tool):
        path = way(title, name, patterns)
        if path is None:
            continue
        if not path:
            return CANCELLED
        print(path)
        return 0
    print("no file chooser: neither the XDG portal (xdg-desktop-portal-gnome / -gtk) nor zenity or kdialog",
          file=sys.stderr)
    return NONE


if __name__ == "__main__":
    sys.exit(main())
