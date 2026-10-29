#!/usr/bin/python3 -I
"""A borderless 4:3 game stretched to the whole screen on XWayland: niri-game-mode runs this
while a window of such a game is open (`game-stretch.py cs2`), nothing to set in Steam.

CS2 in "Fullscreen windowed" at 4:3 either stretches its picture over its monitor-sized window
itself or draws it into the top-left corner and leaves the rest black — the same settings, the
same build, it said nothing either way (corner on 27.10, whole window on 28.10, whole window
after Apply in its video settings). So the resolution comes from the game's own settings and
the way it draws from the window's pixels: only while the part right of the corner is black
and the corner is not, _ANGEL_SATELLITE_STRETCH on the window says that corner — angel-satellite
stretches it over the whole window (the game moves its cursor itself). Otherwise the property
says the window's own size, which stretches nothing. Games that change the screen's mode need
none of this: angel-satellite stretches those by itself."""
import ctypes
import ctypes.util
import glob
import os
import re
import sys
import time

XA_CARDINAL = 6
PROP_MODE_REPLACE = 0
Z_PIXMAP = 2
ALL_PLANES = 0xFFFFFFFF
# the game's windows gone this many seconds in a row: it has quit
GONE = 5
# a channel no brighter than this is black; the way the game draws must hold this many seconds
# in a row before the stretch follows it (a dark corner of a map is no reason to jump)
DARK = 8
SURE = 3
# reading pixels stalls Xwayland's GPU for a few ms: only this many seconds after the window shows
# or the settings change (Apply), and until the way it draws is known
PROBE = 10


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


# WM_CLASS of the game's window → (its settings, the corner it may draw into with them);
# niri-game-mode's STRETCH_GAMES names the same
GAMES = {"cs2": (cs2_settings, cs2_corner)}


class XClassHint(ctypes.Structure):
    _fields_ = [("res_name", ctypes.c_void_p), ("res_class", ctypes.c_void_p)]


class XImage(ctypes.Structure):
    # the head of Xlib's XImage, as far as the pixels
    _fields_ = [(n, ctypes.c_int) for n in ("width", "height", "xoffset", "format")] + [
        ("data", ctypes.c_void_p)] + [(n, ctypes.c_int) for n in (
            "byte_order", "bitmap_unit", "bitmap_bit_order", "bitmap_pad", "depth",
            "bytes_per_line", "bits_per_pixel")]


def libx11():
    x11 = ctypes.CDLL(ctypes.util.find_library("X11") or "libX11.so.6")
    dpy, win, atom = ctypes.c_void_p, ctypes.c_ulong, ctypes.c_ulong
    uint, int_ = ctypes.POINTER(ctypes.c_uint), ctypes.POINTER(ctypes.c_int)
    x11.XOpenDisplay.restype = dpy
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XDefaultRootWindow.restype = win
    x11.XDefaultRootWindow.argtypes = [dpy]
    x11.XInternAtom.restype = atom
    x11.XInternAtom.argtypes = [dpy, ctypes.c_char_p, ctypes.c_int]
    x11.XQueryTree.argtypes = [dpy, win, ctypes.POINTER(win), ctypes.POINTER(win),
                               ctypes.POINTER(ctypes.POINTER(win)), ctypes.POINTER(ctypes.c_uint)]
    x11.XGetClassHint.argtypes = [dpy, win, ctypes.POINTER(XClassHint)]
    x11.XGetGeometry.argtypes = [dpy, win, ctypes.POINTER(win), int_, int_, uint, uint, uint, uint]
    x11.XGetImage.restype = ctypes.POINTER(XImage)
    x11.XGetImage.argtypes = [dpy, win, ctypes.c_int, ctypes.c_int, ctypes.c_uint, ctypes.c_uint,
                              ctypes.c_ulong, ctypes.c_int]
    x11.XDestroyImage.argtypes = [ctypes.POINTER(XImage)]
    x11.XGetWindowProperty.argtypes = [dpy, win, atom, ctypes.c_long, ctypes.c_long, ctypes.c_int, atom,
                                       ctypes.POINTER(atom), ctypes.POINTER(ctypes.c_int),
                                       ctypes.POINTER(ctypes.c_ulong), ctypes.POINTER(ctypes.c_ulong),
                                       ctypes.POINTER(ctypes.POINTER(ctypes.c_ulong))]
    x11.XChangeProperty.argtypes = [dpy, win, atom, atom, ctypes.c_int, ctypes.c_int,
                                    ctypes.POINTER(ctypes.c_ulong), ctypes.c_int]
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


def size_of(x11, dpy, w):
    root, x, y = ctypes.c_ulong(), ctypes.c_int(), ctypes.c_int()
    width, height, border, depth = (ctypes.c_uint() for _ in range(4))
    if not x11.XGetGeometry(dpy, w, root, x, y, width, height, border, depth):
        return None
    return [width.value, height.value]


def brightest(row, lsb_first):
    """the brightest colour channel in a row of 32-bit pixels, the padding byte left out"""
    return max(max(row[i::4], default=0) for i in ((0, 1, 2) if lsb_first else (1, 2, 3)))


def in_corner(left, right):
    """True: the game draws only its corner (the rest of the window is black), False: the whole
    window, None: can't tell (all black: loading, a fade)"""
    if right > DARK:
        return False
    return True if left > DARK else None


def draws_in_corner(x11, dpy, w, size, corner_w):
    """in_corner on a few full-width rows of the window's pixels (a few KB a second)"""
    left = right = 0
    for k in range(1, 6):
        img = x11.XGetImage(dpy, w, 0, size[1] * k // 6, size[0], 1, ALL_PLANES, Z_PIXMAP)
        if not img:
            return None
        im = img.contents
        row = ctypes.string_at(im.data, size[0] * 4) if im.bits_per_pixel == 32 else None
        lsb_first = im.byte_order == 0
        x11.XDestroyImage(img)
        if row is None:
            return None
        left = max(left, brightest(row[:corner_w * 4], lsb_first))
        right = max(right, brightest(row[corner_w * 4:], lsb_first))
    return in_corner(left, right)


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


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in GAMES:
        sys.exit(f"usage: game-stretch.py {'|'.join(GAMES)}")
    wm_class = sys.argv[1]
    settings, corner = GAMES[wm_class]
    x11 = libx11()
    dpy = x11.XOpenDisplay(None)
    if not dpy:
        sys.exit("game-stretch: no X display")
    x11.XSetErrorHandler(ON_ERROR)
    atom = x11.XInternAtom(dpy, b"_ANGEL_SATELLITE_STRETCH", 0)
    stretched = {}  # window → stretched now
    seen = {}  # window → (the way it draws, seconds in a row)
    probe = {}  # window → probe till
    last = None
    gone = 0
    while gone < GONE:
        wins = windows(x11, dpy, wm_class)
        gone = 0 if wins else gone + 1
        if wins:
            s = settings()
            crop = corner(s)
            if s != last:
                last, seen, probe = s, {}, {}
            for w in wins:
                size = size_of(x11, dpy, w)
                if not size:
                    continue
                now = None
                if crop and crop[0] < size[0]:
                    if time.monotonic() < probe.setdefault(w, time.monotonic() + PROBE) or w not in stretched:
                        now = draws_in_corner(x11, dpy, w, size, crop[0])
                else:
                    stretched[w] = False
                if now is not None:
                    was, n = seen.get(w, (None, 0))
                    seen[w] = (now, n + 1 if now == was else 1)
                    if seen[w][1] >= SURE:
                        stretched[w] = now
                # the window's own size, not a deleted property: satellite keeps the last crop then
                want = crop if stretched.get(w) else size
                if stretch_of(x11, dpy, w, atom) != want:
                    x11.XChangeProperty(dpy, w, atom, XA_CARDINAL, 32, PROP_MODE_REPLACE,
                                        (ctypes.c_ulong * 2)(*want), 2)
            x11.XSync(dpy, 0)
        time.sleep(1)


if __name__ == "__main__":
    main()
