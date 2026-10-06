#!/usr/bin/env python3
"""Read or set niri's workspace-switch animation (cfg/animation.kdl) and whether
the workspace keys go through angelOS (both themes' key profiles, cfg/keybinds-*.kdl).

  workspace-anim.py                          -> {"preset": "soft|dash|instant|custom", "routed": bool,
                                                 "slowdown": float, "speed": float, "ms": int}
  workspace-anim.py <preset> [--route|--native] [--speed X]
      write it: a staged copy is validated with `niri validate`, the old files are
      backed up under ~/.local/state/angelos/backups/anim-*, and restored if the
      final validation fails.

--speed X divides the preset's duration by X (2 = twice as fast; 0.25–4).
--route turns `focus-workspace N / -up / -down / -previous` binds into
`spawn-sh "exec …/bin/angelos ws N"` (the shell captures the screen for its
transition, then asks niri to switch; niri is called directly if the shell is
not running). --native turns them back.
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

PRESETS = {
    # ease-out-quint: starts right away, settles softly
    "soft": (380, 'curve "cubic-bezier" 0.22 1 0.36 1'),
    # slow start, a dash, a tidy stop
    "dash": (460, 'curve "cubic-bezier" 0.8 0 0.12 1'),
    "instant": None,
}
CONFIG = Path.home() / ".config/niri/config.kdl"
ANIMATIONS = CONFIG.parent / "cfg/animation.kdl"
sys.path.insert(0, str(Path(__file__).resolve().parent))
import keyprofile  # noqa: E402
# the workspace keys of the theme in front (its key profile, scripts/keyprofile.py)
KEYBINDS = keyprofile.path()
# routing is one setting for both themes: every theme's profile is written, or the keys of
# the theme not in front stay as they were and its switch has no animation after a theme change
ROUTE_FILES = [p for p in (keyprofile.CFG / keyprofile.FILES[n] for n in keyprofile.PROFILES) if p.exists()] \
    if keyprofile.current() else [KEYBINDS]
BACKUPS = Path.home() / ".local/state/angelos/backups"
BLOCK = re.compile(r"(?m)^([ \t]*)workspace-switch\s*\{([^{}]*)\}")
ANGELOS = "exec ~/.config/quickshell/angelos/bin/angelos ws "
NATIVE_ACTIONS = {"up": "focus-workspace-up", "down": "focus-workspace-down", "prev": "focus-workspace-previous"}
NATIVE_RE = re.compile(r"\{\s*(focus-workspace(?:-up|-down|-previous)?)(?:\s+(\d{1,2}))?\s*;\s*\}")
ROUTED_RE = re.compile(r'\{\s*spawn-sh\s+"' + re.escape(ANGELOS) + r'(\d{1,2}|up|down|prev)"\s*;\s*\}')


def normalize(body):
    return re.sub(r"\s+", " ", body).strip()


def clamp_speed(speed):
    return max(0.25, min(4.0, float(speed)))


def body_of(preset, speed=1.0):
    if PRESETS[preset] is None:
        return "off"
    ms, curve = PRESETS[preset]
    return f"duration-ms {max(40, round(ms / clamp_speed(speed)))}\n{curve}"


def current(text):
    """(preset, speed, duration ms) of the workspace-switch block"""
    match = BLOCK.search(text)
    if not match:
        return "soft", 1.0, PRESETS["soft"][0]
    body = normalize(match.group(2))
    if body == "off":
        return "instant", 1.0, 0
    for name, value in PRESETS.items():
        if value is None:
            continue
        m = re.fullmatch(r"duration-ms (\d+) " + re.escape(normalize(value[1])), body)
        if m and int(m.group(1)) > 0:
            return name, round(value[0] / int(m.group(1)), 3), int(m.group(1))
    m = re.search(r"duration-ms (\d+)", body)
    return "custom", 1.0, int(m.group(1)) if m else 0


def update(text, preset, speed=1.0):
    body = body_of(preset, speed)
    match = BLOCK.search(text)
    indent = match.group(1) if match else None
    if indent is None:
        opening = re.search(r"(?m)^([ \t]*)animations\s*\{", text)
        if not opening:
            raise ValueError("animations block not found in cfg/animation.kdl")
        indent = opening.group(1) + "    "
    lines = "\n".join(f"{indent}    {line}" for line in body.splitlines())
    block = f"{indent}workspace-switch {{\n{lines}\n{indent}}}"
    if match:
        return text[:match.start()] + block + text[match.end():]
    return text[:opening.end()] + "\n" + block + text[opening.end():]


def slowdown(text):
    """animations { slowdown N }: niri stretches every animation by it"""
    match = re.search(r"(?m)^[ \t]*slowdown\s+([0-9]*\.?[0-9]+)", text)
    return float(match.group(1)) if match else 1.0


def routed(text):
    return bool(ROUTED_RE.search(text))


def route(text, on):
    def to_angelos(m):
        action, num = m.group(1), m.group(2)
        target = num if action == "focus-workspace" and num else {v: k for k, v in NATIVE_ACTIONS.items()}.get(action)
        if not target:
            return m.group(0)
        return '{ spawn-sh "' + ANGELOS + target + '"; }'

    def to_niri(m):
        target = m.group(1)
        return "{ " + (f"focus-workspace {target}" if target.isdigit() else NATIVE_ACTIONS[target]) + "; }"

    out = []
    for line in text.splitlines(keepends=True):
        # only plain Mod+<key> workspace binds; move-column/move-window binds stay as they are
        if on and NATIVE_RE.search(line) and not line.lstrip().startswith("//"):
            line = NATIVE_RE.sub(to_angelos, line)
        elif not on and ROUTED_RE.search(line):
            line = ROUTED_RE.sub(to_niri, line)
        out.append(line)
    return "".join(out)


def validate(config):
    result = subprocess.run(["niri", "validate", "-c", str(config)], capture_output=True, text=True)
    if result.returncode:
        raise ValueError((result.stderr or result.stdout).strip()[-400:])


def atomic_write(path, content):
    fd, name = tempfile.mkstemp(prefix=".anim-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(content)
        os.chmod(name, path.stat().st_mode & 0o777)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def save(preset, route_mode, speed=1.0):
    if preset not in PRESETS:
        raise ValueError("unknown preset: " + preset)
    BACKUPS.mkdir(parents=True, exist_ok=True)
    with (BACKUPS / ".anim.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        old = {ANIMATIONS: ANIMATIONS.read_text(), **{p: p.read_text() for p in ROUTE_FILES}}
        new = {ANIMATIONS: update(old[ANIMATIONS], preset, speed)}
        for p in ROUTE_FILES:
            new[p] = old[p] if route_mode is None else route(old[p], route_mode)
        changed = [p for p in new if new[p] != old[p]]
        if not changed:
            return "Unchanged"
        with tempfile.TemporaryDirectory(prefix="angelos-anim-") as tmp:
            staged = Path(tmp) / "niri"
            shutil.copytree(CONFIG.parent, staged)
            for path in changed:
                (staged / path.relative_to(CONFIG.parent)).write_text(new[path])
            validate(staged / CONFIG.name)
        backup = Path(tempfile.mkdtemp(prefix="anim-", dir=BACKUPS))
        for path in changed:
            shutil.copy2(path, backup / path.name)
            if path.read_text() != old[path]:
                raise RuntimeError(path.name + " changed during validation; try again")
        for path in changed:
            atomic_write(path, new[path])
        try:
            validate(CONFIG)
        except Exception:
            for path in changed:
                if path.read_text() == new[path]:
                    atomic_write(path, old[path])
            raise
        return "Saved · " + str(backup)


def main():
    try:
        if len(sys.argv) == 1:
            text = ANIMATIONS.read_text()
            preset, speed, ms = current(text)
            print(json.dumps({"preset": preset, "speed": speed, "ms": ms, "routed": routed(KEYBINDS.read_text()), "slowdown": slowdown(text)}))
        else:
            mode = True if "--route" in sys.argv else False if "--native" in sys.argv else None
            speed = 1.0
            if "--speed" in sys.argv:
                speed = clamp_speed(sys.argv[sys.argv.index("--speed") + 1])
            print(json.dumps({"ok": save(sys.argv[1], mode, speed)}))
    except (OSError, ValueError, RuntimeError) as error:
        print(json.dumps({"error": str(error)}))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
