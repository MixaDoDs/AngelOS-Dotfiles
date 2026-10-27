#!/usr/bin/python3 -I
"""A borderless 4:3 game stretched to the whole screen on XWayland: niri-game-mode runs this
while a window of such a game is open (`game-stretch.py cs2`), nothing to set in Steam.

CS2 in "Fullscreen windowed" draws its own resolution into the top-left corner of a
monitor-sized window and does not say so. Each second this reads that resolution from the
game's own settings and puts it into _ANGEL_SATELLITE_STRETCH on the game's window —
angel-satellite stretches that corner over the whole window (the game moves its cursor
itself). In the game's other modes the property goes. Games that change the screen's mode
need none of this: angel-satellite stretches those by itself.

After Apply in its video settings CS2 may start drawing over the whole window instead of the
corner and says nothing either — the stretched corner then cuts the picture. So settings
changed mid-game, stretched after, bring a "restart CS2" notification."""
import ctypes
import ctypes.util
import glob
import os
import re
import subprocess
import sys
import time

XA_CARDINAL = 6
PROP_MODE_REPLACE = 0
# the game's windows gone this many seconds in a row: it has quit
GONE = 5


def cs2_settings():
    """the newest cs2_video.txt (several Steam accounts: the one played last)"""
    files = glob.glob(os.path.expanduser("~/.local/share/Steam/userdata/*/730/local/cfg/cs2_video.txt"))
    if not files:
        return {}
    with open(max(files, key=os.path.getmtime), errors="replace") as f:
        return dict(re.findall(r'"(setting\.[\w.]+)"\s+"([^"]*)"', f.read()))


def cs2_corner(s):
    if s.get("setting.fullscreen") != "0" or s.get("setting.nowindowborder") != "1":
        return None
    try:
        return [int(s["setting.defaultres"]), int(s["setting.defaultresheight"])]
    except (KeyError, ValueError):
        return None


# WM_CLASS of the game's window → (its name, its settings, the corner it draws with them);
# niri-game-mode's STRETCH_GAMES names the same
GAMES = {"cs2": ("CS2", cs2_settings, cs2_corner)}


class XClassHint(ctypes.Structure):
    _fields_ = [("res_name", ctypes.c_void_p), ("res_class", ctypes.c_void_p)]


def libx11():
    x11 = ctypes.CDLL(ctypes.util.find_library("X11") or "libX11.so.6")
    dpy, win, atom = ctypes.c_void_p, ctypes.c_ulong, ctypes.c_ulong
    x11.XOpenDisplay.restype = dpy
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XDefaultRootWindow.restype = win
    x11.XDefaultRootWindow.argtypes = [dpy]
    x11.XInternAtom.restype = atom
    x11.XInternAtom.argtypes = [dpy, ctypes.c_char_p, ctypes.c_int]
    x11.XQueryTree.argtypes = [dpy, win, ctypes.POINTER(win), ctypes.POINTER(win),
                               ctypes.POINTER(ctypes.POINTER(win)), ctypes.POINTER(ctypes.c_uint)]
    x11.XGetClassHint.argtypes = [dpy, win, ctypes.POINTER(XClassHint)]
    x11.XGetWindowProperty.argtypes = [dpy, win, atom, ctypes.c_long, ctypes.c_long, ctypes.c_int, atom,
                                       ctypes.POINTER(atom), ctypes.POINTER(ctypes.c_int),
                                       ctypes.POINTER(ctypes.c_ulong), ctypes.POINTER(ctypes.c_ulong),
                                       ctypes.POINTER(ctypes.POINTER(ctypes.c_ulong))]
    x11.XChangeProperty.argtypes = [dpy, win, atom, atom, ctypes.c_int, ctypes.c_int,
                                    ctypes.POINTER(ctypes.c_ulong), ctypes.c_int]
    x11.XDeleteProperty.argtypes = [dpy, win, atom]
    x11.XFree.argtypes = [ctypes.c_void_p]
    x11.XSync.argtypes = [dpy, ctypes.c_int]
    return x11


# a window gone between the query and the property is no reason to quit (Xlib's default handler exits)
ON_ERROR = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_void_p, ctypes.c_void_p)(lambda *_: 0)


def windows(x11, dpy, wm_class):
    root, parent = ctypes.c_ulong(), ctypes.c_ulong()
    children, n = ctypes.POINTER(ctypes.c_ulong)(), ctypes.c_uint()
    if not x11.XQueryTree(dpy, x11.XDefaultRootWindow(dpy), root, parent, children, n):
        return []
    found = []
    for i in range(n.value):
        hint = XClassHint()
        if x11.XGetClassHint(dpy, children[i], hint):
            names = [ctypes.string_at(p).decode(errors="replace") for p in (hint.res_name, hint.res_class) if p]
            if wm_class in names:
                found.append(children[i])
            for p in (hint.res_name, hint.res_class):
                if p:
                    x11.XFree(p)
    if children:
        x11.XFree(children)
    return found


def stretch_of(x11, dpy, w, atom):
    kind, fmt = ctypes.c_ulong(), ctypes.c_int()
    n, after = ctypes.c_ulong(), ctypes.c_ulong()
    data = ctypes.POINTER(ctypes.c_ulong)()
    if x11.XGetWindowProperty(dpy, w, atom, 0, 2, 0, XA_CARDINAL, kind, fmt, n, after, data) != 0:
        return None
    have = [data[i] for i in range(n.value)] if data and kind.value == XA_CARDINAL else None
    if data:
        x11.XFree(data)
    return have


def ask_restart(name):
    # critical: an ordinary one over a fullscreen game only goes to the bell
    subprocess.Popen(["notify-send", "-u", "critical", "-a", name, f"Перезапусти {name}",
                      "Видео-настройки поменялись — до перезапуска картинку может растянуть и обрезать справа"])


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in GAMES:
        sys.exit(f"usage: game-stretch.py {'|'.join(GAMES)}")
    wm_class = sys.argv[1]
    name, settings, corner = GAMES[wm_class]
    x11 = libx11()
    dpy = x11.XOpenDisplay(None)
    if not dpy:
        sys.exit("game-stretch: no X display")
    x11.XSetErrorHandler(ON_ERROR)
    atom = x11.XInternAtom(dpy, b"_ANGEL_SATELLITE_STRETCH", 0)
    seen = None  # the settings the game drew with when its window showed
    gone = 0
    while gone < GONE:
        wins = windows(x11, dpy, wm_class)
        gone = 0 if wins else gone + 1
        if wins:
            s = settings()
            size = corner(s)
            if seen is None:
                seen = s
            elif s != seen:
                # not stretched now: nothing to cut
                if size:
                    ask_restart(name)
                seen = s
            for w in wins:
                if stretch_of(x11, dpy, w, atom) != size:
                    if size:
                        x11.XChangeProperty(dpy, w, atom, XA_CARDINAL, 32, PROP_MODE_REPLACE,
                                            (ctypes.c_ulong * 2)(*size), 2)
                    else:
                        x11.XDeleteProperty(dpy, w, atom)
            x11.XSync(dpy, 0)
        time.sleep(1)


if __name__ == "__main__":
    main()
