#!/usr/bin/env python3
"""Render angelOS theme templates.

usage: render-templates.py PALETTE.json [DISABLED_IDS_COMMA_SEPARATED] [--palette JSON]

With --palette (services/ThemeExport) the palette is written to PALETTE.json first
(atomically), then rendered: the hooks that read the file see this render's palette.

Templates are listed in <shell>/templates/templates.json and in
~/.config/angelos/templates/*.json (user entries override by id).
Placeholders: {{key}} -> "#rrggbb", {{key.strip}} -> "rrggbb", plus
{{mode}} (light|dark), {{flavor}}, {{gtkSuffix}} ("-dark" or ""), {{shellDir}},
{{paletteFile}}, and the window-decoration keys ThemeExport adds ({{realm}},
{{decor*}}: heaven's or hell's colours for title bars and their buttons).
Entries with "terminal": true render with the palette's "term" overrides on top
(hell's colours while the demon rules, Y2K → Terminal in hell) and {{kittyExtra}};
entries with "apps": true with its "apps" overrides (GTK, Qt: Y2K → Apps in hell).
An entry with a "command" lists the files it writes in "writes" (~/ paths, {a,b}
alternatives): an update's snapshot takes them too, so «Вернуть как было» removes
or restores them (scripts/update-txn.py).
"variants" swaps an entry's template by the palette's "skin": {"goldengate": "gtk3-mac.css"}
renders the Golden Gate skin's version into the same target (services/ThemeExport.macPalette).
A target in niri's config (~/.config/niri/*.kdl: angelos.kdl — the borders, the Golden Gate
skin's window rules and Mac keys) is written as Settings → Windows writes niri's files
(window-config.py): the old one backed up to ~/.local/state/angelos/backups/niri-render-*,
`niri validate`, and put back if niri says no.
"""
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

SHELL = Path(__file__).resolve().parent.parent
USER = Path.home() / ".config/angelos/templates"
NIRI = Path.home() / ".config/niri"
BACKUPS = Path.home() / ".local/state/angelos/backups"


def write_niri(dst, out):
    """Write a niri config file: backup, validate, roll back. False when niri refused it."""
    BACKUPS.mkdir(parents=True, exist_ok=True)
    backup = Path(tempfile.mkdtemp(prefix="niri-render-%s-" % time.strftime("%Y%m%d-%H%M%S"), dir=BACKUPS))
    had = dst.exists()
    if had:
        shutil.copy2(dst, backup / dst.name)
    tmp = dst.with_suffix(dst.suffix + ".angelos-tmp")
    tmp.write_text(out)
    tmp.replace(dst)
    if shutil.which("niri") and (NIRI / "config.kdl").exists():
        p = subprocess.run(["niri", "validate", "-c", str(NIRI / "config.kdl")], capture_output=True, text=True)
        (backup / "validate.log").write_text(p.stdout + p.stderr)
        if p.returncode != 0:
            if had:
                shutil.copy2(backup / dst.name, dst)
            else:
                dst.unlink()
            print(f"niri validate failed for {dst}, rolled back (backup {backup}): " + p.stderr.strip()[-300:], file=sys.stderr)
            return False
    # only the newest twenty
    olds = sorted(BACKUPS.glob("niri-render-*"))
    for d in olds[:-20]:
        shutil.rmtree(d, ignore_errors=True)
    return True


def load_entries():
    entries = {}
    sources = [(SHELL / "templates/templates.json", SHELL / "templates")]
    if USER.is_dir():
        sources += [(p, USER) for p in sorted(USER.glob("*.json"))]
    for path, base in sources:
        try:
            data = json.loads(path.read_text())
        except (OSError, ValueError) as e:
            print(f"skip {path}: {e}", file=sys.stderr)
            continue
        for e in data if isinstance(data, list) else [data]:
            e["_base"] = str(base)
            entries[e["id"]] = e
    return list(entries.values())


def render(text, pal, quote=None):
    def sub(m):
        key, _, mod = m.group(1).partition(".")
        val = str(pal.get(key, m.group(0)))
        val = val.lstrip("#") if mod == "strip" else val
        # values that reach `sh -c` must stay single words (the flavor comes from settings.json)
        return quote(val) if quote and not re.fullmatch(r"[\w#.-]*", val) else val
    return re.sub(r"\{\{\s*([\w.]+)\s*\}\}", sub, text)


def main():
    args = sys.argv[1:]
    text = None
    if "--palette" in args:
        i = args.index("--palette")
        text = args[i + 1]
        del args[i:i + 2]
    path = Path(args[0])
    if text is not None:
        json.loads(text)                   # a broken palette never replaces a good one
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(path.suffix + ".angelos-tmp")
        tmp.write_text(text)
        tmp.replace(path)
    sys.argv[1:] = args
    pal = json.loads(path.read_text())
    pal["gtkSuffix"] = "-dark" if pal.get("mode") == "dark" else ""
    # for the entries that run angelOS's own scripts on the same palette
    pal["shellDir"] = str(SHELL)
    pal["paletteFile"] = str(Path(sys.argv[1]).resolve())
    disabled = set(filter(None, (sys.argv[2] if len(sys.argv) > 2 else "").split(",")))
    for e in load_entries():
        if e["id"] in disabled:
            continue
        try:
            p = pal
            for flag, key in (("terminal", "term"), ("apps", "apps")):
                if e.get(flag) and isinstance(pal.get(key), dict) and pal[key]:
                    p = dict(p, **pal[key])
                    p["gtkSuffix"] = "-dark" if p.get("mode") == "dark" else ""
            if e.get("template"):
                src = Path(e["_base"]) / (e.get("variants") or {}).get(p.get("skin") or "", e["template"])
                dst = Path(os.path.expanduser(e["target"]))
                dst.parent.mkdir(parents=True, exist_ok=True)
                out = render(src.read_text(), p)
                if not dst.exists() or dst.read_text() != out:
                    if dst.suffix == ".kdl" and NIRI in dst.resolve().parents:
                        if write_niri(dst, out):
                            print(f"wrote {dst}")
                    else:
                        tmp = dst.with_suffix(dst.suffix + ".angelos-tmp")
                        tmp.write_text(out)
                        tmp.replace(dst)
                        print(f"wrote {dst}")
            for key in ("command", "reload"):
                if e.get(key):
                    subprocess.run(["sh", "-c", render(e[key], p, shlex.quote)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
        except Exception as ex:  # keep going with the other templates
            print(f"{e['id']}: {ex}", file=sys.stderr)


if __name__ == "__main__":
    main()
