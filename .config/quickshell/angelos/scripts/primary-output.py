#!/usr/bin/env python3
"""The main screen for niri too: `focus-at-startup` on that output only.

  primary-output.py status          -> JSON {"focused": [outputs with focus-at-startup]}
  primary-output.py set <output>    -> JSON {"ok": true, "changed": [files]} | {"error": …}

angelOS keeps its own main screen in Settings → Monitor (Config.system.primaryScreen);
this makes niri focus the same monitor when the session starts, so the first
windows, the launcher and the Start menu open there. The line is removed from
every other output block (in every niri config file) and added to a block for
the chosen output — the one that had it before if it is there, else the block
niri uses for it, else a new block in monitor.kdl (included first by config.kdl:
a mode-less block that came before monitor.kdl's would cost the saved refresh
rate). A block names the output by its connector or "Make Model Serial".
The change is checked with `niri validate` on a staged copy; the old files go
into ~/.local/state/angelos/backups/<stamp>-primary-output first.
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
import niri_outputs  # noqa: E402

NIRI = niri_outputs.NIRI
BACKUPS = Path.home() / ".local/state/angelos/backups"
NAME_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.:-]{0,63}\Z")
BLOCK = re.compile(r'(?ms)^([ \t]*)output\s+"([^"]+)"\s*\{(.*?)^\1\}')
FOCUS = re.compile(r"(?m)^[ \t]*focus-at-startup\b[^\n]*\n?")


class Fail(Exception):
    pass


def config_files():
    files = [NIRI / "config.kdl", NIRI / "monitor.kdl", NIRI / "angelos.kdl"] + sorted((NIRI / "cfg").glob("*.kdl"))
    seen, out = set(), []
    for f in files:
        if f.is_file() and not f.is_symlink() and f.resolve() not in seen:
            seen.add(f.resolve())
            out.append(f)
    return out


def status():
    # niri focuses the first block with focus-at-startup that names a connected monitor
    outs = niri_outputs.outputs()
    if outs:
        hit = niri_outputs.focused(niri_outputs.blocks(niri_outputs.config_path()), outs)
        return [hit] if hit else []
    focused = []
    for f in config_files():
        for m in BLOCK.finditer(f.read_text()):
            if FOCUS.search(m.group(3)) and m.group(2) not in focused:
                focused.append(m.group(2))
    return focused


def rewrite(target):
    """{file: new text} for the files that change."""
    out = niri_outputs.outputs().get(target) or {"name": target}
    def is_target(name):
        return niri_outputs.matches(name, out)
    texts = {f: f.read_text() for f in config_files()}
    had = None                                  # the file that set it before
    new = {}
    for f, text in texts.items():
        def strip(m):
            nonlocal had
            if not FOCUS.search(m.group(3)):
                return m.group(0)
            had = had or f
            if is_target(m.group(2)):
                return m.group(0)
            return m.group(0)[:m.start(3) - m.start(0)] + FOCUS.sub("", m.group(3)) + m.group(0)[m.end(3) - m.start(0):]
        out_text = BLOCK.sub(strip, text)
        if out_text != text:
            new[f] = out_text
    current = {f: new.get(f, t) for f, t in texts.items()}
    if any(is_target(m.group(2)) and FOCUS.search(m.group(3)) for t in current.values() for m in BLOCK.finditer(t)):
        return new
    # add it to a block of the target: where it was before, else the one niri uses, else any
    config = NIRI / "config.kdl"
    read = []
    found = niri_outputs.blocks(config, texts=current, files=read)
    win, _ = niri_outputs.winner(found, out)
    order = [f for f in [had, win and win[0]] if f in current]
    order += [f for f in current if f not in order]
    for f in order:
        m = next((m for m in BLOCK.finditer(current[f]) if is_target(m.group(2))), None)
        if m:
            body = m.group(3)
            lines = [l for l in body.splitlines() if l.strip()]
            indent = re.match(r"[ \t]*", lines[0]).group(0) if lines else m.group(1) + "    "
            body = body if body.endswith("\n") else body + "\n"
            text = current[f]
            new[f] = text[:m.start(3)] + body + indent + "focus-at-startup\n" + text[m.end(3):]
            return new
    # no block for it yet: a new one in monitor.kdl, which config.kdl must include (first)
    dest = NIRI / "monitor.kdl"
    if dest.is_symlink():
        raise Fail("monitor.kdl is a symlink: add the block there by hand")
    new[dest] = current.get(dest, "").rstrip("\n") + f'\n\noutput "{niri_outputs.ident(target, niri_outputs.outputs())}" {{\n    focus-at-startup\n}}\n'
    if Path(os.path.normpath(dest)) not in read:
        if config not in current:
            raise Fail("config.kdl does not include monitor.kdl and is not a plain file")
        new[config] = niri_outputs.include_first(current[config], Path(os.path.normpath(dest)), NIRI)
    return new


def apply(target):
    if not NAME_RE.fullmatch(target):
        raise Fail("bad output name")
    new = rewrite(target)
    if not new:
        return []
    with tempfile.TemporaryDirectory(prefix="angelos-primary-") as tmp:
        staged = Path(tmp) / "niri"
        shutil.copytree(NIRI, staged, symlinks=True)
        for f, text in new.items():
            (staged / f.relative_to(NIRI)).write_text(text)
        r = subprocess.run(["niri", "validate", "-c", str(staged / "config.kdl")], capture_output=True, text=True)
        if r.returncode:
            raise Fail("niri validate: " + (r.stderr or r.stdout).strip()[-300:])
    backup = BACKUPS / (time.strftime("%Y%m%d-%H%M%S") + "-primary-output")
    while backup.exists():
        backup = backup.with_name(backup.name + "-1")
    backup.mkdir(parents=True)
    for f in new:
        if f.exists():
            shutil.copy2(f, backup / f.relative_to(NIRI).as_posix().replace("/", "__"))
    for f, text in new.items():
        fd, name = tempfile.mkstemp(prefix=".primary-", dir=f.parent)
        with os.fdopen(fd, "w") as out:
            out.write(text)
        os.chmod(name, f.stat().st_mode & 0o777 if f.exists() else 0o644)
        os.replace(name, f)
    return [str(f.relative_to(NIRI)) for f in new]


def main():
    args = sys.argv[1:]
    try:
        if not args or args[0] == "status":
            print(json.dumps({"focused": status()}))
        elif args[0] == "set" and len(args) == 2:
            print(json.dumps({"ok": True, "changed": apply(args[1])}))
        else:
            raise Fail("usage: primary-output.py status | set <output>")
    except (Fail, OSError) as error:
        print(json.dumps({"error": str(error)}))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
