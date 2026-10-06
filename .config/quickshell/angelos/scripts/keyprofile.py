#!/usr/bin/env python3
"""Key binding profiles: every theme has its own niri keys.

  keyprofile.py status            -> {"profile", "want", "file", "files": {...}}
  keyprofile.py apply pixel|macos -> the theme's profile in front (validated, atomic)
  keyprofile.py sync              -> the profile settings.json asks for (skin + mac.keys)
  keyprofile.py init              -> the profile files, if missing (templates/keybinds)
  keyprofile.py path              -> the file of the profile in front (what Settings edits)

~/.config/niri/cfg/keybinds.kdl is a selector angelOS writes — two includes:

  keybinds-common.kdl   both themes: media keys, emergency keys, screenshots, panels
  keybinds-pixel.kdl    the pixel theme: angelOS's own keys (the repository's)
  keybinds-macos.kdl    Golden Gate: tiling on Super+Alt, the Mac keys (⌘Q ⌘H ⌘M ⌘Tab …)

The profile is read after the common file, so a key there replaces the common one for
that theme only. A switch writes only the selector: a copy of the niri config with
the new selector must pass `niri validate` first, then one rename puts it in place
(niri reloads once and never sees half of one profile and half of the other), the
real config is validated again and the old selector comes back if it fails. Backups:
~/.local/state/angelos/backups/keyprofile-*.

`init` on a config from before profiles (keybinds.kdl with a binds block of its own):
that file is backed up and becomes the pixel profile minus the binds the common file
holds the same way; the Golden Gate profile comes from the template.
"""
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

HOME = Path.home()
NIRI = HOME / ".config/niri"
CONFIG = NIRI / "config.kdl"
CFG = NIRI / "cfg"
SELECTOR = CFG / "keybinds.kdl"
SHELL = Path(__file__).resolve().parents[1]
TEMPLATES = SHELL / "templates/keybinds"
BACKUPS = HOME / ".local/state/angelos/backups"
SETTINGS = HOME / ".config/angelos/settings.json"
PROFILES = ("pixel", "macos")
FILES = {"common": "keybinds-common.kdl", "pixel": "keybinds-pixel.kdl", "macos": "keybinds-macos.kdl"}
INCLUDE = re.compile(r'(?m)^\s*include\s+"(?:\./)?keybinds-(pixel|macos)\.kdl"')
HEADER = """// angelOS: the key profile of the theme in front — written by angelOS (scripts/keyprofile.py),
// switched with the theme. Edit the profiles, not this file (Settings → Keyboard does):
//   keybinds-common.kdl — both themes, keybinds-pixel.kdl — the pixel theme,
//   keybinds-macos.kdl — Golden Gate (macOS). The profile is read last: its key wins.
"""


def selector_text(profile):
    return HEADER + f'include "{FILES["common"]}"\ninclude "{FILES[profile]}"\n'


def current():
    """the profile the selector includes; "" for a config from before profiles"""
    try:
        m = INCLUDE.search(SELECTOR.read_text())
    except OSError:
        return ""
    return m.group(1) if m else ""


def path():
    """the file Settings edits: the profile in front (keybinds.kdl itself before profiles)"""
    p = current()
    return CFG / FILES[p] if p else SELECTOR


def wanted():
    try:
        s = json.loads(SETTINGS.read_text())
    except (OSError, ValueError):
        s = {}
    skin = (s.get("settingsUi") or {}).get("skin", "classic")
    keys = (s.get("mac") or {}).get("keys", False)   # SettingsSchema: offered, never imposed
    return "macos" if skin == "goldengate" and keys is True else "pixel"


def validate(config):
    r = subprocess.run(["niri", "validate", "-c", str(config)], capture_output=True, text=True)
    if r.returncode:
        raise ValueError((r.stderr or r.stdout).strip()[-600:])


def atomic_write(target, text):
    fd, name = tempfile.mkstemp(prefix=".keyprofile-", dir=target.parent)
    try:
        with os.fdopen(fd, "w") as f:
            f.write(text)
        if target.exists():
            os.chmod(name, target.stat().st_mode & 0o777)
        os.replace(name, target)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def backup(*paths):
    BACKUPS.mkdir(parents=True, exist_ok=True)
    folder = Path(tempfile.mkdtemp(prefix="keyprofile-" + time.strftime("%Y%m%d-%H%M%S-"), dir=BACKUPS))
    for p in paths:
        if p.exists():
            shutil.copy2(p, folder / p.name)
    return folder


def template(name):
    return (TEMPLATES / name).read_text().replace("@HOME@", str(HOME))


def _norm(b):
    return (b["key"].lower(), b["action"].replace("@HOME@", str(HOME)), json.dumps(b["props"], sort_keys=True))


def init():
    """the profile files from the templates where missing; a pre-profile keybinds.kdl becomes
    the pixel profile (without what the common file holds the same way)"""
    made = []
    CFG.mkdir(parents=True, exist_ok=True)
    legacy = SELECTOR.exists() and not current() and "binds" in SELECTOR.read_text()
    folder = backup(SELECTOR) if legacy else None
    if not (CFG / FILES["common"]).exists():
        atomic_write(CFG / FILES["common"], template(FILES["common"]))
        made.append(FILES["common"])
    if not (CFG / FILES["pixel"]).exists():
        if legacy:
            sys.path.insert(0, str(SHELL / "scripts"))
            import importlib.util
            spec = importlib.util.spec_from_file_location("angelos_keybinds", SHELL / "scripts/keybinds.py")
            kb = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(kb)
            common = {_norm(dict(b, key=kb.norm_key(b["key"]))) for b in kb.parse((CFG / FILES["common"]).read_text())[2]}
            text = SELECTOR.read_text()
            lines, _, binds, _ = kb.parse(text)
            drop = {b["line"] for b in binds if _norm(dict(b, key=kb.norm_key(b["key"]))) in common}
            text = "\n".join(l for i, l in enumerate(lines) if i not in drop)
        else:
            text = template(FILES["pixel"])
        atomic_write(CFG / FILES["pixel"], text)
        made.append(FILES["pixel"])
    if not (CFG / FILES["macos"]).exists():
        atomic_write(CFG / FILES["macos"], template(FILES["macos"]))
        made.append(FILES["macos"])
    return {"made": made, "legacyBackup": str(folder) if folder else ""}


def apply(profile):
    if profile not in PROFILES:
        raise ValueError("profile must be one of: " + ", ".join(PROFILES))
    BACKUPS.mkdir(parents=True, exist_ok=True)
    # keybinds.py and workspace-anim.py edit the profiles under the same lock
    with (BACKUPS / ".anim.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        made = init()
        new = selector_text(profile)
        old = SELECTOR.read_text() if SELECTOR.exists() else ""
        if old == new:
            return {"profile": profile, "changed": False, **made}
        with tempfile.TemporaryDirectory(prefix="angelos-keyprofile-") as tmp:
            staged = Path(tmp) / "niri"
            shutil.copytree(NIRI, staged, symlinks=True)
            (staged / "cfg/keybinds.kdl").write_text(new)
            validate(staged / "config.kdl")
        folder = backup(SELECTOR)
        atomic_write(SELECTOR, new)
        try:
            validate(CONFIG)
        except Exception:
            if old:
                atomic_write(SELECTOR, old)
            raise
        return {"profile": profile, "changed": True, "backup": str(folder), **made}


def status():
    return {"profile": current(), "want": wanted(), "file": str(path()),
            "files": {k: (CFG / v).exists() for k, v in FILES.items()}}


def main():
    args = sys.argv[1:]
    try:
        if not args or args == ["status"]:
            out = status()
        elif args == ["path"]:
            print(path())
            return 0
        elif args == ["init"]:
            out = init()
        elif args == ["sync"]:
            out = apply(wanted())
        elif len(args) == 2 and args[0] == "apply":
            out = apply(args[1])
        else:
            raise ValueError("usage: keyprofile.py status | apply pixel|macos | sync | init | path")
    except (OSError, ValueError) as e:
        print(json.dumps({"error": str(e)}, ensure_ascii=False))
        return 1
    print(json.dumps(out, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
