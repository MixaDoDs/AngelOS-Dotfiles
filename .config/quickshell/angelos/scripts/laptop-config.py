#!/usr/bin/env python3
"""A laptop's keys and switches in niri: cfg/angelos-laptop.kdl (services/Laptop writes it).

  laptop-config.py                 -> JSON {keys, file, skipped}: what the file holds now
  laptop-config.py '<json>'        -> write it, keys:
      keys: true | false     the brightness keys, the keyboard's light, the touchpad's key,
                             airplane mode, the display key and Mod+P (the projection menu),
                             the calculator key — each through `qs ipc call angelos …`
      switches: true | false the lid and tablet-mode switches (niri switch-events) → angelOS

A key you bound yourself in another niri file stays yours: it is left out here and named in
"skipped". The file is included at the end of config.kdl (after the key profiles), written
with a backup, checked with `niri validate` and rolled back when niri refuses it.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

home = Path.home()
niri = Path(os.environ.get("XDG_CONFIG_HOME") or home / ".config") / "niri"
path = niri / "cfg/angelos-laptop.kdl"
config = niri / "config.kdl"
INCLUDE = 'include "./cfg/angelos-laptop.kdl"'
IPC = "qs -c angelos ipc call angelos"

# key, extra flags, IPC call — the order they are written in
KEYS = [
    ("XF86MonBrightnessUp", "allow-when-locked=true allow-inhibiting=false", "brightness up"),
    ("XF86MonBrightnessDown", "allow-when-locked=true allow-inhibiting=false", "brightness down"),
    ("XF86KbdBrightnessUp", "allow-when-locked=true allow-inhibiting=false", "kbdLight up"),
    ("XF86KbdBrightnessDown", "allow-when-locked=true allow-inhibiting=false", "kbdLight down"),
    ("XF86KbdLightOnOff", "allow-when-locked=true allow-inhibiting=false", "kbdLight cycle"),
    ("XF86TouchpadToggle", "allow-inhibiting=false", "laptop 'touchpad toggle'"),
    ("XF86TouchpadOn", "allow-inhibiting=false", "laptop 'touchpad on'"),
    ("XF86TouchpadOff", "allow-inhibiting=false", "laptop 'touchpad off'"),
    ("XF86RFKill", "allow-when-locked=true allow-inhibiting=false", "laptop airplane"),
    ("XF86Display", "", "laptop project"),
    ("Mod+P", 'hotkey-overlay-title="angelOS: экраны (проектор)"', "laptop project"),
    ("XF86Calculator", "", "launcherWith ="),
]
SWITCHES = [
    ("lid-close", "laptop 'lid close'"),
    ("lid-open", "laptop 'lid open'"),
    ("tablet-mode-on", "laptop 'tablet on'"),
    ("tablet-mode-off", "laptop 'tablet off'"),
]
HEADER = "// angelOS: a laptop's keys and switches — written by angelOS (Settings → Keyboard → Laptop\n// keys, scripts/laptop-config.py); a key bound in your own files is left out of here\n"


def included_files(cfg, seen=None):
    """config.kdl and every file it includes, recursively (ours left out)"""
    seen = seen or set()
    if cfg in seen or not cfg.exists() or cfg == path:
        return []
    seen.add(cfg)
    out = [cfg]
    for m in re.finditer(r'^\s*include\s+"([^"]+)"', cfg.read_text(errors="ignore"), re.M):
        out += included_files((cfg.parent / m.group(1)).resolve(), seen)
    return out


def strip_comments(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def bound_elsewhere():
    """key names bound in the other niri files (case-insensitive, modifiers normalised)"""
    keys = set()
    for f in included_files(config.resolve()):
        text = strip_comments(f.read_text(errors="ignore"))
        for m in re.finditer(r"^\s*([A-Za-z0-9_+]+)\s*(?:[a-z-]+=\S+\s*)*\{", text, re.M):
            keys.add(norm(m.group(1)))
    return keys


def norm(key):
    parts = key.split("+")
    mods = sorted(p.lower() for p in parts[:-1])
    mods = ["mod" if m in ("mod", "super", "win") else m for m in mods]
    return "+".join(mods + [parts[-1].lower()])


def render(keys, switches):
    out = [HEADER]
    skipped = []
    if keys:
        taken = bound_elsewhere()
        lines = []
        for key, flags, call in KEYS:
            if norm(key) in taken:
                skipped.append(key)
                continue
            cmd = f'{IPC} {call}'.replace('"', '\\"')
            lines.append(f'    {key:<26}{(" " + flags) if flags else ""} {{ spawn-sh "{cmd}"; }}')
        if lines:
            out.append("binds {\n" + "\n".join(lines) + "\n}\n")
    if switches:
        lines = [f'    {ev} {{ spawn "sh" "-c" "{IPC} {call}"; }}' for ev, call in SWITCHES]
        out.append("switch-events {\n" + "\n".join(lines) + "\n}\n")
    return "\n".join(out), skipped


def current():
    text = path.read_text() if path.exists() else ""
    taken = bound_elsewhere() if path.exists() else set()
    return {"keys": "binds {" in text, "switches": "switch-events {" in text, "file": str(path),
            "skipped": [k for k, _, _ in KEYS if norm(k) in taken]}


def atomic_write(p, text):
    p.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=p.parent, prefix="." + p.name)
    with os.fdopen(fd, "w") as f:
        f.write(text)
    os.replace(tmp, p)


def apply(changes):
    cur = current()
    keys = bool(changes.get("keys", cur["keys"]))
    switches = bool(changes.get("switches", cur["switches"]))
    new, skipped = render(keys, switches)
    old = path.read_text() if path.exists() else None
    cfg = config.read_text() if config.exists() else ""
    new_cfg = cfg if INCLUDE in cfg else cfg.rstrip("\n") + "\n\n// angelOS: a laptop's keys and switches (last: they come after the key profiles)\n" + INCLUDE + "\n"
    if old == new and new_cfg == cfg:
        print(json.dumps({"saved": False, "skipped": skipped}))
        return
    backup_root = home / ".local/state/angelos/backups"
    backup_root.mkdir(parents=True, exist_ok=True)
    backup = Path(tempfile.mkdtemp(prefix="laptop-keys-", dir=backup_root))
    if old is not None:
        shutil.copy2(path, backup / path.name)
    if cfg:
        shutil.copy2(config, backup / config.name)
    # the included file first: niri never sees a dangling include
    atomic_write(path, new)
    if new_cfg != cfg:
        atomic_write(config, new_cfg)
    p = subprocess.run(["niri", "validate", "-c", str(config)], capture_output=True, text=True)
    (backup / "validate.log").write_text(p.stdout + p.stderr)
    if p.returncode:
        if new_cfg != cfg:
            atomic_write(config, cfg)
        if old is None:
            path.unlink(missing_ok=True)
        else:
            atomic_write(path, old)
        raise SystemExit("niri validate failed, rolled back: " + (p.stderr.strip().splitlines() or ["?"])[-1][:300])
    print(json.dumps({"saved": True, "skipped": skipped, "backup": str(backup)}))


if __name__ == "__main__":
    if len(sys.argv) == 1:
        print(json.dumps(current()))
    else:
        apply(json.loads(sys.argv[1]))
