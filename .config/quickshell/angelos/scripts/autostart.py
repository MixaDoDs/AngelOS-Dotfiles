#!/usr/bin/env python3
"""Apps started at login (Settings → Apps → Autostart, `angelos autostart`).

The freedesktop way: ~/.config/autostart/*.desktop (the user's) over /etc/xdg/autostart (the
system's); systemd's xdg-autostart generator starts them with the session (niri.service wants
xdg-desktop-autostart.target), so they come up without angelOS too and other tools see them.

  autostart.py list                 JSON {"entries": [{id, name, icon, exec, on, source, system,
                                    fits}], "works": bool}
                                    source: user | system | override (the user's file over a
                                    system one); system: comes with the system (a service more
                                    than an app: no window of its own, or from /etc only);
                                    fits: this desktop starts it (OnlyShowIn/NotShowIn, TryExec);
                                    works: the session starts autostart entries at all
  autostart.py add APP              APP: a desktop id (firefox, org.gnome.Nautilus.desktop) of an
                                    installed app, or a path to a .desktop file — copied into
                                    ~/.config/autostart
  autostart.py add-command NAME COMMAND…
                                    a command of one's own
  autostart.py on|off ID            switch an entry (a system one: an override of the user's
                                    with Hidden=true, the system file is never touched)
  autostart.py remove ID            take the user's entry away (a system one can only be off)
Exit 0, or 1 with a line saying why.
"""
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config")
USER_DIR = CONFIG / "autostart"
SYSTEM_DIRS = [Path(d) / "autostart" for d in (os.environ.get("XDG_CONFIG_DIRS") or "/etc/xdg").split(":") if d]
DATA_DIRS = [Path(os.environ.get("XDG_DATA_HOME") or HOME / ".local/share")] + \
            [Path(d) for d in (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":") if d]
LANG = (os.environ.get("ANGELOS_LANG") or os.environ.get("LANG") or "en")[:2].lower()
MARK = "X-angelOS-Autostart"


def parse(path):
    """the [Desktop Entry] group as {key: value}; None when it can't be read"""
    try:
        lines = Path(path).read_text(errors="replace").splitlines()
    except OSError:
        return None
    out, here = {}, False
    for line in lines:
        line = line.strip()
        if line.startswith("["):
            here = line == "[Desktop Entry]"
            continue
        if here and "=" in line and not line.startswith("#"):
            k, v = line.split("=", 1)
            out[k.strip()] = v.strip()
    return out


def name_of(e, fallback):
    return e.get(f"Name[{LANG}]") or e.get("Name") or fallback


def truthy(v):
    return str(v).strip().lower() == "true"


def desktops():
    return [d for d in (os.environ.get("XDG_CURRENT_DESKTOP") or "").split(":") if d]


def fits(e):
    """would the session start it here? (what systemd's generator checks)"""
    here = desktops()
    only = [d for d in e.get("OnlyShowIn", "").split(";") if d]
    never = [d for d in e.get("NotShowIn", "").split(";") if d]
    if only and not set(only) & set(here):
        return False
    if set(never) & set(here):
        return False
    tryexec = e.get("TryExec")
    if tryexec and not (shutil.which(tryexec) or os.access(tryexec, os.X_OK)):
        return False
    return True


def entries():
    found = {}
    for d in reversed(SYSTEM_DIRS):
        for f in sorted(d.glob("*.desktop")) if d.is_dir() else []:
            found[f.name] = {"system": f}
    if USER_DIR.is_dir():
        for f in sorted(USER_DIR.glob("*.desktop")):
            found.setdefault(f.name, {})["user"] = f
    out = []
    for fid, src in found.items():
        mine, theirs = parse(src["user"]) if "user" in src else None, parse(src["system"]) if "system" in src else None
        e = mine if mine is not None else theirs
        if e is None or (e.get("Type") or "Application") != "Application":
            continue
        # an override that only hides: the name and the command are the system file's
        shown = theirs if mine is not None and theirs is not None and not mine.get("Exec") else e
        on = not truthy(e.get("Hidden", "")) and e.get("X-GNOME-Autostart-enabled", "true").lower() != "false"
        out.append({
            "id": fid,
            "name": name_of(shown, fid[:-len(".desktop")]),
            "icon": shown.get("Icon", ""),
            "exec": shown.get("Exec", ""),
            "on": on,
            "source": "override" if mine is not None and theirs is not None else "user" if mine is not None else "system",
            "system": "system" in src and (truthy(shown.get("NoDisplay", "")) or not (mine or {}).get("Exec")),
            "fits": fits(shown),
        })
    out.sort(key=lambda x: (x["system"], x["name"].lower()))
    return out


def works():
    """the session starts autostart entries: systemd's target is there (niri-session)"""
    if os.environ.get("AUTOSTART_WORKS") in ("0", "1"):   # the tests
        return os.environ["AUTOSTART_WORKS"] == "1"
    try:
        r = subprocess.run(["systemctl", "--user", "is-active", "xdg-desktop-autostart.target"],
                           capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        return False
    return r.stdout.strip() == "active"


def valid_id(fid):
    return bool(re.fullmatch(r"[^/\0]+\.desktop", fid)) and fid not in (".desktop",)


def find_app(app):
    p = Path(app).expanduser()
    if p.suffix == ".desktop" and p.is_file():
        return p
    fid = app if app.endswith(".desktop") else app + ".desktop"
    if "/" in fid:
        return None
    for d in DATA_DIRS:
        f = d / "applications" / fid
        if f.is_file():
            return f
    return None


def write(fid, lines):
    USER_DIR.mkdir(parents=True, exist_ok=True)
    tmp = USER_DIR / (fid + ".tmp")
    tmp.write_text("\n".join(lines) + "\n")
    os.replace(tmp, USER_DIR / fid)


def add(app):
    src = find_app(app)
    if not src:
        sys.exit(f"no such app: {app}")
    e = parse(src)
    if not e or not e.get("Exec"):
        sys.exit(f"{src.name} has no command to start")
    # a login starts it with no file or address to open
    cmd = re.sub(r"\s*%[fFuUdDnNickvm]", "", e["Exec"]).strip()
    lines = ["[Desktop Entry]", "Type=Application"]
    for k, v in e.items():
        if k == "Name" or k.startswith("Name[") or k in ("Icon", "TryExec", "Path", "Terminal", "StartupWMClass"):
            lines.append(f"{k}={v}")
    lines += [f"Exec={cmd}", f"{MARK}=true"]
    write(src.name, lines)
    return src.name


def add_command(name, argv):
    name = name.strip()
    if not name or not argv:
        sys.exit("autostart.py add-command NAME COMMAND…")
    cmd = argv[0] if len(argv) == 1 else shlex.join(argv)
    try:
        first = shlex.split(cmd)[0]
    except (ValueError, IndexError):
        sys.exit(f"the command can't be read: {cmd}")
    slug = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-") or re.sub(r"[^A-Za-z0-9]+", "-", os.path.basename(first)).strip("-") or "command"
    fid = f"angelos-{slug}.desktop"
    write(fid, ["[Desktop Entry]", "Type=Application", f"Name={name}", f"Exec={cmd}", f"{MARK}=true"])
    return fid


def switch(fid, on):
    if not valid_id(fid):
        sys.exit(f"not an autostart entry: {fid}")
    mine = USER_DIR / fid
    theirs = next((d / fid for d in SYSTEM_DIRS if (d / fid).is_file()), None)
    if not mine.is_file() and not theirs:
        sys.exit(f"no such entry: {fid}")
    if mine.is_file():
        text = mine.read_text(errors="replace")
        only_hides = theirs is not None and not (parse(mine) or {}).get("Exec")
        if on and only_hides:
            mine.unlink()     # the system's own entry again
            return
        lines = [l for l in text.splitlines() if not re.match(r"\s*(Hidden|X-GNOME-Autostart-enabled)\s*=", l)]
        if not on:
            lines.append("Hidden=true")
        write(fid, lines)
    elif not on:
        write(fid, ["[Desktop Entry]", "Type=Application", "Hidden=true"])


def remove(fid):
    if not valid_id(fid):
        sys.exit(f"not an autostart entry: {fid}")
    mine = USER_DIR / fid
    if any((d / fid).is_file() for d in SYSTEM_DIRS):
        # the system's file stays where it is: off is all a user can do to it
        switch(fid, False)
        return
    if not mine.is_file():
        sys.exit(f"no such entry: {fid}")
    mine.unlink()


if __name__ == "__main__":
    a = sys.argv[1:]
    cmd = a[0] if a else "list"
    if cmd == "list":
        print(json.dumps({"entries": entries(), "works": works()}, ensure_ascii=False))
    elif cmd == "add" and len(a) == 2:
        print(add(a[1]))
    elif cmd == "add-command" and len(a) >= 3:
        print(add_command(a[1], a[2:]))
    elif cmd in ("on", "off") and len(a) == 2:
        switch(a[1], cmd == "on")
    elif cmd == "remove" and len(a) == 2:
        remove(a[1])
    else:
        print(__doc__)
        sys.exit(2)
