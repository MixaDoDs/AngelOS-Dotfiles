#!/usr/bin/env python3
"""Key binding profiles: every theme has its own niri keys.

  keyprofile.py status            -> {"profile", "want", "file", "files": {...}}
  keyprofile.py apply pixel|macos -> the theme's profile in front (validated, atomic)
  keyprofile.py sync              -> the profile settings.json asks for (skin + mac.keys)
  keyprofile.py init              -> the profile files, if missing (templates/keybinds)
  keyprofile.py path              -> the file of the profile in front (what Settings edits)
  keyprofile.py merge BASE OURS NEW -> an update's profile: the repository's changes (BASE → NEW)
                                     brought into the user's file OURS, printed (install.sh)

~/.config/niri/cfg/keybinds.kdl is a selector angelOS writes — two includes:

  keybinds-common.kdl   both themes: media keys, emergency keys, screenshots, panels
  keybinds-pixel.kdl    the pixel theme: angelOS's own keys (the repository's)
  keybinds-macos.kdl    Golden Gate: tiling on Super+Alt, the Mac keys (⌘Q ⌘H ⌘M ⌘Tab …)

The profile is read after the common file, so a key there replaces the common one for
that theme only. A switch writes only the selector: a copy of the niri config with
the new selector must pass `niri validate` first, then one rename puts it in place
(niri reloads once and never sees half of one profile and half of the other), the
real config is validated again and the old selector comes back if it fails. Backups:
~/.local/state/angelos/backups/keyprofile-*. Only the profile's include line changes:
whatever else someone wrote into keybinds.kdl (a binds block of their own) stays, for
both themes, and is read after the profile.

`init` on a config from before profiles (keybinds.kdl with a binds block and no include of a
profile): that file is backed up and becomes the pixel profile minus the binds the common
file holds the same way — also when a pixel profile is there already (an update installs the
repository's next to the user's old keybinds.kdl; that one is what the user's keys are, the
other is backed up); the Golden Gate profile comes from the template.

`merge`: an update's three-way merge, key by key — a bind the user left as it came follows
the repository (changed, moved, removed), a key the repository adds comes in unless the
user's file binds it or the user removed it, every change of the user's stays. Workspace keys
routed through angelOS or not (workspace-anim.py) count the same and keep the user's way.
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
BINDS = re.compile(r'(?m)^\s*binds\s*\{')
INCLUDE = re.compile(r'(?m)^\s*include\s+"(?:\./)?keybinds-(pixel|macos)\.kdl"')
HEADER = """// angelOS: the key profile of the theme in front — written by angelOS (scripts/keyprofile.py),
// switched with the theme. Edit the profiles, not this file (Settings → Keyboard does):
//   keybinds-common.kdl — both themes, keybinds-pixel.kdl — the pixel theme,
//   keybinds-macos.kdl — Golden Gate (macOS). The profile is read last: its key wins.
"""


def selector_text(profile, old=""):
    """the selector for `profile`; an existing one keeps everything but its profile include"""
    if INCLUDE.search(old):
        return INCLUDE.sub(lambda m: m.group(0).replace(f"keybinds-{m.group(1)}.kdl", FILES[profile]), old, count=1)
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


def _script(name, module):
    import importlib.util
    spec = importlib.util.spec_from_file_location(module, SHELL / "scripts" / name)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _keybinds():
    return _script("keybinds.py", "angelos_keybinds")


def init():
    """the profile files from the templates where missing; a pre-profile keybinds.kdl becomes
    the pixel profile (without what the common file holds the same way)"""
    made = []
    CFG.mkdir(parents=True, exist_ok=True)
    legacy = SELECTOR.exists() and not current() and BINDS.search(SELECTOR.read_text()) is not None
    folder = backup(SELECTOR, CFG / FILES["pixel"]) if legacy else None
    if not (CFG / FILES["common"]).exists():
        atomic_write(CFG / FILES["common"], template(FILES["common"]))
        made.append(FILES["common"])
    if legacy or not (CFG / FILES["pixel"]).exists():
        if legacy:
            kb = _keybinds()
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
        old = SELECTOR.read_text() if SELECTOR.exists() else ""
        made = init()
        new = selector_text(profile, old if current() else "")
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


def _sig(wa, b):
    """what a bind does, spacing and workspace routing aside"""
    action = wa.route("{ " + re.sub(r"\s+", " ", b["action"]) + "; }", False)
    return (action, b["title"], json.dumps(b["props"], sort_keys=True))


def merge(base, ours, new):
    """the repository's change base → new brought into ours (see the module doc); None when
    a file can't be merged bind by bind (a multi-line bind, a key twice, no binds block)"""
    kb, wa = _keybinds(), _script("workspace-anim.py", "angelos_workspace_anim")
    try:
        parsed = [kb.parse(t) for t in (base, ours, new)]
    except ValueError:
        return None
    keyed = []
    for _, _, binds, _ in parsed:
        d = {}
        for b in binds:
            k = kb.norm_key(b["key"])
            if not b["editable"] or k in d:
                return None
            d[k] = b
        keyed.append(d)
    B, O, N = keyed
    lines, (start, _), _, _ = parsed[1]
    nlines = parsed[2][0]
    sig = lambda b: _sig(wa, b)  # noqa: E731
    replace, drop, after = {}, set(), {}
    for k, b in O.items():
        if k in B and sig(b) == sig(B[k]):          # as it came: follows the repository
            if k not in N:
                drop.add(b["line"])
            elif sig(N[k]) != sig(b):
                replace[b["line"]] = nlines[N[k]["line"]]
    have = {l.strip() for l in lines}
    anchor, pending = None, []                      # each new key after the one it follows
    for k, b in N.items():
        if k in O:
            anchor = O[k]["line"]
            if pending:                             # new keys ahead of every old one: before it
                at = anchor - 1 if anchor - 1 > start and kb.SECTION.match(lines[anchor - 1]) else anchor
                after.setdefault(at - 1, []).extend(pending + [""])
                pending = []
            continue
        if k in B:                                  # the user took it out
            continue
        add = []
        head = nlines[b["line"] - 1] if b["line"] > 0 else ""
        if kb.SECTION.match(head) and head.strip() not in have:
            add += ["", head] if anchor is not None else [head]
            have.add(head.strip())
        (pending if anchor is None else after.setdefault(anchor, [])).extend(add + [nlines[b["line"]]])
    after.setdefault(start, []).extend(pending)     # an O with no key of N at all
    out = []
    for i, l in enumerate(lines):
        if i not in drop:
            out.append(replace.get(i, l))
        out.extend(after.get(i, []))
    return wa.route("\n".join(out), wa.routed(ours))


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
        elif len(args) == 4 and args[0] == "merge":
            text = merge(*(Path(a).read_text() for a in args[1:]))
            if text is None:
                return 3
            sys.stdout.write(text)
            return 0
        else:
            raise ValueError("usage: keyprofile.py status | apply pixel|macos | sync | init | path | merge BASE OURS NEW")
    except (OSError, ValueError) as e:
        print(json.dumps({"error": str(e)}, ensure_ascii=False))
        return 1
    print(json.dumps(out, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
