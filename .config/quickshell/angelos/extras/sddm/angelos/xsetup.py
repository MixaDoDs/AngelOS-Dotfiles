#!/usr/bin/python3 -I
"""angelOS: the main screen of the login (SDDM's Xsetup, run as root before the greeter).

People did not see where to type the password: X starts the pointer in the middle of all the
screens put together (on a side monitor, often), and the greeter's password field is on X's
primary output, which X picks by itself. This makes the screen picked in angelOS (Settings →
Monitor → Main screen, the installer, the wizard) X's primary and puts the pointer in its middle.

What it reads is walls/theme.conf.user, the user's own file (the keys primary, primaryModel,
primarySerial, written by `angelos sddm primary`): so it is only ever compared, never run or
passed to a shell. niri's names (DP-1) are not X's (DP-0 on NVIDIA, DisplayPort-0 on AMD): the
screen is found by its EDID (monitor name, serial), the name only when no EDID says.

Anything wrong: nothing is changed and the login goes on as it would have."""
import ctypes
import ctypes.util
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CONF = os.path.join(HERE, "walls", "theme.conf.user")
XRANDR = os.environ.get("ANGELOS_XRANDR", "xrandr")       # the tests put a stand-in here


def read_conf(path=CONF):
    out = {}
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f.read(65536).splitlines():
                if "=" in line and not line.startswith(("[", "#", ";")):
                    k, v = line.split("=", 1)
                    out[k.strip()] = v.strip()[:200]
    except OSError:
        pass
    return out


def edid_strings(raw):
    """(monitor name, serial string) from an EDID's descriptors."""
    name = serial = ""
    for at in (54, 72, 90, 108):
        d = raw[at:at + 18]
        if len(d) == 18 and d[0] == 0 and d[1] == 0 and d[3] in (0xFC, 0xFF):
            text = d[5:18].split(b"\n")[0].decode("ascii", "replace").strip()
            if d[3] == 0xFC:
                name = text
            else:
                serial = text
    return name, serial


def outputs(text):
    """The connected outputs of `xrandr --verbose`: name, geometry, EDID strings."""
    found, cur, edid = [], None, None
    for line in text.splitlines():
        m = re.match(r"^(\S+) connected(?: primary)?(?: (\d+)x(\d+)\+(-?\d+)\+(-?\d+))?", line)
        if m:
            cur = {"name": m.group(1), "geo": tuple(int(g) for g in m.groups()[1:]) if m.group(2) else None, "model": "", "serial": ""}
            found.append(cur)
            edid = None
            continue
        if re.match(r"^\S+ disconnected", line) or re.match(r"^Screen \d+:", line):
            cur, edid = None, None
            continue
        if cur is None:
            continue
        s = line.strip()
        if s == "EDID:":
            edid = []
            continue
        if edid is not None:
            if re.fullmatch(r"[0-9a-fA-F]{32}", s):
                edid.append(s)
                continue
            if edid:
                cur["model"], cur["serial"] = edid_strings(bytes.fromhex("".join(edid)))
            edid = None
    return found


def pick(outs, conf):
    """The output that is the main screen, or None."""
    want, model, serial = conf.get("primary", ""), conf.get("primaryModel", ""), conf.get("primarySerial", "")
    if serial:
        hits = [o for o in outs if o["serial"] and o["serial"] == serial]
        if len(hits) == 1:
            return hits[0]
    if model:
        hits = [o for o in outs if o["model"] and o["model"] == model]
        if len(hits) == 1:
            return hits[0]
    if want:
        hits = [o for o in outs if o["name"] == want]
        if len(hits) == 1:
            return hits[0]
    return None


def warp(x, y):
    """The pointer to (x, y) of the root window: libX11 itself, no xdotool needed."""
    if os.environ.get("ANGELOS_XSETUP_TEST"):
        print("warp %d %d" % (x, y))
        return True
    lib = ctypes.util.find_library("X11")
    if not lib:
        return False
    x11 = ctypes.CDLL(lib)
    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XDefaultRootWindow.restype = ctypes.c_ulong
    x11.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
    x11.XWarpPointer.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_ulong, ctypes.c_int, ctypes.c_int,
                                 ctypes.c_uint, ctypes.c_uint, ctypes.c_int, ctypes.c_int]
    x11.XFlush.argtypes = [ctypes.c_void_p]
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    dpy = x11.XOpenDisplay(None)
    if not dpy:
        return False
    try:
        x11.XWarpPointer(dpy, 0, x11.XDefaultRootWindow(dpy), 0, 0, 0, 0, int(x), int(y))
        x11.XFlush(dpy)
    finally:
        x11.XCloseDisplay(dpy)
    return True


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=10)


def main():
    conf = read_conf()
    if not any(conf.get(k) for k in ("primary", "primaryModel", "primarySerial")):
        return 0
    try:
        outs = outputs(run([XRANDR, "--verbose"]).stdout)
    except (OSError, subprocess.SubprocessError):
        return 0
    main_out = pick(outs, conf)
    if not main_out:
        print("angelOS xsetup: the main screen (%s / %s) is not connected" % (conf.get("primary", ""), conf.get("primaryModel", "")), file=sys.stderr)
        return 0
    try:
        run([XRANDR, "--output", main_out["name"], "--primary"])
    except (OSError, subprocess.SubprocessError):
        pass
    # the geometry after the system's own Xsetup moved and turned screens
    try:
        now = next((o for o in outputs(run([XRANDR, "--verbose"]).stdout) if o["name"] == main_out["name"]), main_out)
    except (OSError, subprocess.SubprocessError):
        now = main_out
    if now.get("geo"):
        w, h, x, y = now["geo"]
        warp(x + w // 2, y + h // 2)
    print("angelOS xsetup: main screen %s" % main_out["name"], file=sys.stderr)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:                  # the login must come whatever happens here
        print("angelOS xsetup: %s" % e, file=sys.stderr)
        sys.exit(0)
