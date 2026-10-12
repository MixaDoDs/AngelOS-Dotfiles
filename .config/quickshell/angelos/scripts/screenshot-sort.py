#!/usr/bin/env python3
"""Screenshots sorted by month: <shots>/2026-10 Октябрь/Screenshot from ….png

  screenshot-sort.py dir            make and print the folder for a new shot (this month)
  screenshot-sort.py place FILE     move FILE into its month (from its name's date, else its time)
  screenshot-sort.py watch          niri's own shots (Print, screenshot-window/-screen): the file
                                    niri saved into <shots> goes into its month. Run by the shell
                                    (services/Capture) while it runs; it tidies once first (below)
  screenshot-sort.py tidy           the old layouts into months: loose pictures in <shots> and the
                                    per-app folders of before (<App>/<MM.YYYY>/…); emptied folders go

<shots> = settings.json capture.shotDir, else ~/Pictures/Screenshots. The month folder starts
with year-month, so a file manager lists them in order; the name is in the interface language.
Only pictures are moved; anything else stays where it is."""
from __future__ import annotations

import ctypes
import json
import os
import re
import signal
import socket
import sys
import time

PICTURES = (".png", ".jpg", ".jpeg", ".webp", ".ppm")
MONTHS_RU = ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь",
             "Октябрь", "Ноябрь", "Декабрь"]
MONTHS_EN = ["January", "February", "March", "April", "May", "June", "July", "August", "September",
             "October", "November", "December"]
MONTH_DIR = re.compile(r"^(\d{4})-(\d{2})(?: .*)?$")  # this layout's month folders
OLD_MONTH = re.compile(r"^(\d{2})\.(\d{4})$")          # the per-app layout's MM.YYYY
STATE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"),
                     "angelos/screenshot-sort-months")


def settings():
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    try:
        with open(os.path.join(base, "angelos/settings.json")) as f:
            return json.load(f)
    except Exception:
        return {}


def shots_root():
    d = (settings().get("capture") or {}).get("shotDir")
    return os.path.expanduser(d or "~/Pictures/Screenshots")


def english():
    return (settings().get("appearance") or {}).get("language") == "en"


def month_name(year, month):
    names = MONTHS_EN if english() else MONTHS_RU
    return f"{year:04d}-{month:02d} {names[month - 1]}"


def month_of(path=None, when=None):
    """(year, month) of a shot: the date in its name ("Screenshot from 2026-10-12 …"), else its
    modification time, else now."""
    if when is None and path:
        m = re.search(r"(20\d{2})-(\d{2})-\d{2}", os.path.basename(path))
        if m and 1 <= int(m.group(2)) <= 12:
            return int(m.group(1)), int(m.group(2))
        try:
            when = os.path.getmtime(path)
        except OSError:
            when = None
    t = time.localtime(when)
    return t.tm_year, t.tm_mon


def month_dir(root, year, month):
    """The folder of that month: an existing one of the same year-month is kept whatever its
    name says (the language changed), else a new one."""
    key = f"{year:04d}-{month:02d}"
    try:
        for f in sorted(os.listdir(root)):
            if (f == key or f.startswith(key + " ")) and os.path.isdir(os.path.join(root, f)):
                return os.path.join(root, f)
    except FileNotFoundError:
        pass
    return os.path.join(root, month_name(year, month))


def target_dir(path=None):
    root = shots_root()
    d = month_dir(root, *month_of(path))
    os.makedirs(d, exist_ok=True)
    return d


def place(path, root=None):
    d = target_dir(path) if root is None else month_dir(root, *month_of(path))
    os.makedirs(d, exist_ok=True)
    stem, ext = os.path.splitext(os.path.basename(path))
    dest, n = os.path.join(d, stem + ext), 1
    if os.path.abspath(dest) == os.path.abspath(path):
        return dest
    while os.path.exists(dest):
        n += 1
        dest = os.path.join(d, f"{stem} ({n}){ext}")
    os.rename(path, dest)
    return dest


def is_picture(name):
    return name.lower().endswith(PICTURES) and not name.startswith(".")


def tidy(root=None, quiet=False):
    """Loose pictures in <shots> and the per-app layout (<App>/<MM.YYYY>/…, <App>/…) → months.
    A folder of this layout (2026-10 …) is left alone; so is a folder with no picture in
    an MM.YYYY of it (somebody's own folder, not the sorter's)."""
    root = root or shots_root()
    if not os.path.isdir(root):
        return 0
    moved = 0
    for f in sorted(os.listdir(root)):
        p = os.path.join(root, f)
        if os.path.isfile(p) and is_picture(f):
            place(p, root)
            moved += 1
            continue
        if not os.path.isdir(p) or os.path.islink(p) or MONTH_DIR.match(f):
            continue
        months = [m for m in os.listdir(p) if OLD_MONTH.match(m) and os.path.isdir(os.path.join(p, m))]
        if not months:
            continue  # not the old sorter's folder
        for m in months:
            mp = os.path.join(p, m)
            for shot in sorted(os.listdir(mp)):
                sp = os.path.join(mp, shot)
                if os.path.isfile(sp) and is_picture(shot):
                    place(sp, root)
                    moved += 1
            _rmdir(mp)
        _rmdir(p)
    if not quiet:
        print(f"{moved} → {root}")
    return moved


def _rmdir(p):
    try:
        os.rmdir(p)  # only when empty
    except OSError:
        pass


def tidy_once():
    """The first watch after the switch to months tidies the old layout up, once."""
    if os.path.exists(STATE):
        return
    try:
        n = tidy(quiet=True)
        os.makedirs(os.path.dirname(STATE), exist_ok=True)
        with open(STATE, "w") as f:
            f.write(f"{int(time.time())} {n}\n")
        if n:
            print(f"tidied {n} shots into months", flush=True)
    except OSError as e:
        print("screenshot-sort: tidy:", e, file=sys.stderr, flush=True)


def watch():
    """Follow niri's event stream; its screenshots land in the root and move from there."""
    try:
        ctypes.CDLL(None).prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG: dies with the shell
    except Exception:
        pass
    path = os.environ.get("NIRI_SOCKET")
    if not path:
        sys.exit("screenshot-sort: no NIRI_SOCKET")
    tidy_once()
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.connect(path)
        s.sendall(b'"EventStream"\n')
        f = s.makefile("r", encoding="utf-8")
        for line in f:
            try:
                ev = json.loads(line)
            except ValueError:
                continue
            shot = (ev.get("ScreenshotCaptured") or {}).get("path") if isinstance(ev, dict) else None
            if not shot:
                continue
            if os.path.dirname(os.path.abspath(shot)) != os.path.abspath(shots_root()):
                continue  # already sorted, or saved somewhere else on purpose
            for _ in range(50):  # niri writes the file on its own thread
                if os.path.exists(shot):
                    break
                time.sleep(0.1)
            time.sleep(0.2)  # niri may still be writing it
            try:
                print("→", place(shot), flush=True)
            except OSError as e:
                print("screenshot-sort:", shot, e, file=sys.stderr, flush=True)


def main(argv):
    if "--app" in argv:  # the per-app layout's option: ignored now
        i = argv.index("--app")
        del argv[i:i + 2]
    if not argv:
        print(__doc__)
        return 2
    cmd = argv[0]
    if cmd == "dir":
        print(target_dir())
    elif cmd == "place" and len(argv) > 1:
        print(place(argv[1]))
    elif cmd == "watch":
        watch()
    elif cmd in ("tidy", "old"):
        tidy(argv[1] if len(argv) > 1 else None)
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
