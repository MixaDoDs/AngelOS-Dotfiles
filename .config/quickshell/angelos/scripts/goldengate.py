#!/usr/bin/env python3
"""The Golden Gate skin's settings outside angelOS, on and off (run by render-templates.py with
every render: templates.json entry "golden-gate"; on while the palette says skin goldengate).

  goldengate.py PALETTE.json     on: the system font Inter (and JetBrains Mono for code) for GTK,
                                 the Adwaita icons (blue folders), appmenu-gtk-module in GTK 3's
                                 gtk-modules (its menus go to the menu bar: docs/GLOBAL-MENU.md);
                                 off: everything back as it was before the skin
  goldengate.py wallpapers       draw the skin's two wallpapers (light, dark) if they are missing
                                 and print where they are, as JSON
  goldengate.py status           JSON: on or off, what was there before

What was set before is kept once in ~/.local/state/angelos/goldengate-before.json and put back
when the skin goes (or the demon takes over: hell has its own look). A font or icon theme that
is not installed is not set; neither is a GTK module that is not there.
"""
import configparser
import json
import os
import subprocess
import sys
from io import StringIO
from pathlib import Path

HOME = Path.home()
SHELL = Path(__file__).resolve().parent.parent
STATE = HOME / ".local/state/angelos/goldengate-before.json"
INI = [HOME / ".config/gtk-3.0/settings.ini", HOME / ".config/gtk-4.0/settings.ini"]
WALLS = HOME / ".local/share/angelos/wallpapers"
MODULE = "appmenu-gtk-module"
MODULE_FILES = [Path(p) for p in os.environ.get("ANGELOS_APPMENU_MODULE", "").split(":") if p] or \
    [Path("/usr/lib/gtk-3.0/modules/libappmenu-gtk-module.so"), Path("/usr/lib64/gtk-3.0/modules/libappmenu-gtk-module.so")]
GS = "org.gnome.desktop.interface"


def gsettings(key, value=None):
    try:
        if value is None:
            r = subprocess.run(["gsettings", "get", GS, key], capture_output=True, text=True, timeout=5)
            return r.stdout.strip().strip("'") if r.returncode == 0 else None
        subprocess.run(["gsettings", "set", GS, key, value], capture_output=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return value


def ini_read(path):
    cp = configparser.RawConfigParser()
    cp.optionxform = str
    if path.exists():
        try:
            cp.read(path)
        except configparser.Error:
            pass
    if not cp.has_section("Settings"):
        cp.add_section("Settings")
    return cp


def ini_write(path, cp):
    buf = StringIO()
    cp.write(buf, space_around_delimiters=False)
    text = buf.getvalue().rstrip("\n") + "\n"
    if path.exists() and path.read_text() == text:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".angelos-tmp")
    tmp.write_text(text)
    tmp.replace(path)


def families():
    try:
        out = subprocess.run(["fc-list", "--format", "%{family}\n"], capture_output=True, text=True, timeout=15).stdout
    except (OSError, subprocess.TimeoutExpired):
        return set()
    return {n.strip() for line in out.splitlines() for n in line.split(",")}


def icon_theme_here(name):
    return any((d / name / "index.theme").exists() for d in (HOME / ".local/share/icons", HOME / ".icons", Path("/usr/share/icons")))


def wanted():
    fams = families()
    want = {}
    if "Inter" in fams:
        want["font-name"] = "Inter 10"
    if "JetBrains Mono" in fams:
        want["monospace-font-name"] = "JetBrains Mono 10"
    if icon_theme_here("Adwaita"):
        want["icon-theme"] = "Adwaita"
    return want


def on():
    want = wanted()
    module = any(p.exists() for p in MODULE_FILES)
    if not STATE.exists():
        before = {"gsettings": {k: gsettings(k) for k in ("font-name", "monospace-font-name", "icon-theme")}, "ini": {}}
        for path in INI:
            cp = ini_read(path)
            before["ini"][str(path)] = {k: cp.get("Settings", k, fallback=None) for k in ("gtk-font-name", "gtk-icon-theme-name", "gtk-modules")}
        STATE.parent.mkdir(parents=True, exist_ok=True)
        STATE.write_text(json.dumps(before, indent=1))
    for k, v in want.items():
        if gsettings(k) != v:
            gsettings(k, v)
    for path in INI:
        cp = ini_read(path)
        if "font-name" in want:
            cp.set("Settings", "gtk-font-name", want["font-name"])
        if "icon-theme" in want:
            cp.set("Settings", "gtk-icon-theme-name", want["icon-theme"])
        if module and path.parent.name == "gtk-3.0":
            mods = [m for m in (cp.get("Settings", "gtk-modules", fallback="") or "").split(":") if m]
            if MODULE not in mods:
                cp.set("Settings", "gtk-modules", ":".join(mods + [MODULE]))
        ini_write(path, cp)
    print(json.dumps({"goldengate": "on", "set": want, "appmenu-gtk-module": module}))


def off():
    if not STATE.exists():
        print(json.dumps({"goldengate": "off"}))
        return
    before = json.loads(STATE.read_text())
    for k, v in (before.get("gsettings") or {}).items():
        if v:
            gsettings(k, v)
    for path_s, keys in (before.get("ini") or {}).items():
        path = Path(path_s)
        if not path.exists():
            continue
        cp = ini_read(path)
        for k, v in keys.items():
            if k == "gtk-modules" and v is None:
                # ours only: other modules added since stay
                mods = [m for m in (cp.get("Settings", k, fallback="") or "").split(":") if m and m != MODULE]
                if mods:
                    cp.set("Settings", k, ":".join(mods))
                else:
                    cp.remove_option("Settings", k)
            elif v is None:
                cp.remove_option("Settings", k)
            else:
                cp.set("Settings", k, v)
        ini_write(path, cp)
    STATE.unlink()
    print(json.dumps({"goldengate": "off", "restored": True}))


def wallpapers():
    WALLS.mkdir(parents=True, exist_ok=True)
    out = {}
    for kind in ("light", "dark"):
        dst = WALLS / ("goldengate-%s.jpg" % kind)
        if not dst.exists():
            args = [sys.executable, str(SHELL / "scripts/goldengate-wallpaper.py"), str(dst), "--size", os.environ.get("ANGELOS_WALL_SIZE", "3840x2160")]
            if kind == "dark":
                args.append("--dark")
            subprocess.run(args, capture_output=True, timeout=120)
        if dst.exists():
            out[kind] = str(dst)
    print(json.dumps(out))


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__.strip().split("\n\n")[0])
        return 2
    if args[0] == "wallpapers":
        wallpapers()
        return 0
    if args[0] == "status":
        print(json.dumps({"on": STATE.exists(), "before": json.loads(STATE.read_text()) if STATE.exists() else None}))
        return 0
    pal = json.loads(Path(args[0]).read_text())
    if pal.get("skin") == "goldengate":
        on()
    else:
        off()
    return 0


if __name__ == "__main__":
    sys.exit(main())
