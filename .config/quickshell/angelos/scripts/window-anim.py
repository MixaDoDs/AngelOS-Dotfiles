#!/usr/bin/env python3
"""Read or set niri's window open and close animations (cfg/animation.kdl).

  window-anim.py                          -> {"open": {"preset", "speed", "ms"},
                                              "close": {…}, "presets": {"open": […], "close": […]}}
  window-anim.py <open|close> <preset> [speed]
      write it: a staged copy is validated with `niri validate`, the old file is
      backed up under ~/.local/state/angelos/backups/window-anim-*, and restored
      if the final validation fails.
  window-anim.py recolor [palette.json]
      the theme changed (templates.json hook): the shader presets in use are written
      again in its colours; nothing else is touched.

Presets: default (niri's own), off, and angelOS shaders from shaders/open/*.glsl
and shaders/close/*.glsl. The speed (0.25–4, 2 = twice as fast) divides the
preset's duration; the block remembers it in its marker comment
(`// angelOS close: pixel ×1.5`). niri compiles the shader when it loads the
config; a broken one only logs a warning and falls back to the default.
A shader's ANGELOS_ACCENT / ANGELOS_ACCENT2 become the theme's accents as vec3
(~/.cache/angelos/palette.json; angelOS pink and cyan without one) — #43.
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

HERE = Path(__file__).resolve().parent
SHADERS = HERE.parent / "shaders"
CONFIG = Path.home() / ".config/niri/config.kdl"
ANIMATIONS = CONFIG.parent / "cfg/animation.kdl"
BACKUPS = Path.home() / ".local/state/angelos/backups"
PALETTE = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "angelos/palette.json"
# shader placeholder -> palette key, and the colour without a palette
COLOURS = {"ANGELOS_ACCENT2": ("accent2", "#73e6ff"), "ANGELOS_ACCENT": ("accent", "#ff73bf")}
KINDS = ("open", "close")
BLOCKS = {"open": "window-open", "close": "window-close"}
# length and curve per preset at speed 1; shader presets ease inside the shader
TIMING = {
    "open": {
        "default": (280, 'curve "ease-out-cubic"'),
        "pop": (420, 'curve "linear"'),
        "pixel": (460, 'curve "linear"'),
        "heart": (440, 'curve "linear"'),
        "star": (440, 'curve "linear"'),
        "cd": (520, 'curve "linear"'),
        "crt": (460, 'curve "linear"'),
        "glitch": (360, 'curve "linear"'),
        "drop": (560, 'curve "linear"'),
        "rise": (380, 'curve "linear"'),
    },
    "close": {
        "default": (220, 'curve "ease-out-quad"'),
        "pixel": (460, 'curve "linear"'),
        "heart": (420, 'curve "linear"'),
        "fall": (520, 'curve "linear"'),
        "glitch": (380, 'curve "linear"'),
        "crt": (440, 'curve "linear"'),
        "minimize": (340, 'curve "linear"'),
    },
}
FALLBACK = {"open": (150, 'curve "ease-out-expo"'), "close": (150, 'curve "ease-out-quad"')}


def palette(path=None):
    try:
        data = json.loads(Path(path or PALETTE).read_text())
    except (OSError, ValueError):
        data = {}
    return data if isinstance(data, dict) else {}


def vec3(colour, fallback):
    m = re.fullmatch(r"#?([0-9a-fA-F]{6})(?:[0-9a-fA-F]{2})?", str(colour or "").strip())
    h = m.group(1) if m else fallback.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return f"vec3({r:.3f}, {g:.3f}, {b:.3f})"


def colourize(code, pal):
    # ACCENT2 first: ACCENT is its prefix
    for name, (key, fallback) in COLOURS.items():
        code = code.replace(name, vec3(pal.get(key), fallback))
    return code


def mark(kind):
    return f"// angelOS {kind}: "


def clamp_speed(speed):
    return max(0.25, min(4.0, float(speed)))


def presets(kind):
    return ["default", "off"] + sorted(p.stem for p in (SHADERS / kind).glob("*.glsl"))


def find_block(text, name):
    """(start of line, end after '}', indent) of `name { … }` — skips KDL strings,
    so the braces of a GLSL shader inside r#"…"# don't count"""
    m = re.search(r"(?m)^([ \t]*)" + re.escape(name) + r"\s*\{", text)
    if not m:
        return None
    i, depth = m.end() - 1, 0
    while i < len(text):
        if text.startswith('r#"', i):
            j = text.find('"#', i + 3)
            i = len(text) if j < 0 else j + 2
            continue
        if text.startswith('r"', i):
            j = text.find('"', i + 2)
            i = len(text) if j < 0 else j + 1
            continue
        c = text[i]
        if c == '"':
            i += 1
            while i < len(text) and text[i] != '"':
                i += 2 if text[i] == "\\" else 1
        elif c == "/" and text.startswith("//", i):
            j = text.find("\n", i)
            i = len(text) if j < 0 else j
            continue
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return m.start(), i + 1, m.group(1)
        i += 1
    return None


def current(text, kind):
    """{"preset", "speed", "ms"} of the block"""
    b = find_block(text, BLOCKS[kind])
    if not b:
        return {"preset": "default", "speed": 1.0, "ms": 0}
    body = text[b[0]:b[1]]
    ms = re.search(r"duration-ms\s+(\d+)", body)
    ms = int(ms.group(1)) if ms else 0
    m = re.search(re.escape(mark(kind)) + r"(\w+)(?:\s+[×x]([0-9.]+))?", body)
    if m:
        speed = float(m.group(2)) if m.group(2) else 1.0
        return {"preset": m.group(1), "speed": speed, "ms": ms}
    if re.search(r"\{\s*off\s*;?\s*\}", body) or re.search(r"(?m)^\s*off\s*$", body):
        return {"preset": "off", "speed": 1.0, "ms": 0}
    if "custom-shader" in body:
        return {"preset": "custom", "speed": 1.0, "ms": ms}
    return {"preset": "default", "speed": 1.0, "ms": ms}


def render(kind, preset, speed, indent, pal=None):
    inner = indent + "    "
    name = BLOCKS[kind]
    if preset == "off":
        return f"{indent}{name} {{\n{inner}{mark(kind)}off\n{inner}off\n{indent}}}"
    speed = clamp_speed(speed)
    ms, curve = TIMING[kind].get(preset, FALLBACK[kind])
    label = preset if abs(speed - 1.0) < 0.005 else f"{preset} ×{speed:g}"
    lines = [f"{indent}{name} {{", f"{inner}{mark(kind)}{label}",
             f"{inner}duration-ms {max(40, round(ms / speed))}", inner + curve]
    if preset != "default":
        code = colourize((SHADERS / kind / f"{preset}.glsl").read_text(), palette() if pal is None else pal)
        if '"#' in code:
            raise ValueError("shader must not contain \"#")
        lines.append(inner + 'custom-shader r#"')
        lines += [(inner + "    " + l) if l.strip() else "" for l in code.strip("\n").splitlines()]
        lines.append(inner + '"#')
    lines.append(indent + "}")
    return "\n".join(lines)


def update(text, kind, preset, speed=1.0, pal=None):
    b = find_block(text, BLOCKS[kind])
    if b:
        return text[:b[0]] + render(kind, preset, speed, b[2], pal) + text[b[1]:]
    opening = re.search(r"(?m)^([ \t]*)animations\s*\{", text)
    if not opening:
        raise ValueError("animations block not found in cfg/animation.kdl")
    return text[:opening.end()] + "\n" + render(kind, preset, speed, opening.group(1) + "    ", pal) + text[opening.end():]


def recoloured(text, pal):
    """the text with the shader presets in use rendered again in `pal`'s colours"""
    for kind in KINDS:
        cur = current(text, kind)
        if cur["preset"] in presets(kind) and cur["preset"] not in ("default", "off"):
            text = update(text, kind, cur["preset"], cur["speed"], pal)
    return text


def validate(config):
    result = subprocess.run(["niri", "validate", "-c", str(config)], capture_output=True, text=True)
    if result.returncode:
        raise ValueError((result.stderr or result.stdout).strip()[-400:])


def atomic_write(path, content):
    fd, name = tempfile.mkstemp(prefix=".window-anim-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(content)
        os.chmod(name, path.stat().st_mode & 0o777)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def save(kind, preset, speed):
    if kind not in KINDS:
        raise ValueError("open or close, not " + kind)
    if preset not in presets(kind):
        raise ValueError("unknown preset: " + preset)
    return write(lambda old: update(old, kind, preset, speed))


def write(change):
    BACKUPS.mkdir(parents=True, exist_ok=True)
    # the same lock as workspace-anim.py: both edit cfg/animation.kdl
    with (BACKUPS / ".anim.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        old = ANIMATIONS.read_text()
        new = change(old)
        if new == old:
            return "Unchanged"
        with tempfile.TemporaryDirectory(prefix="angelos-window-anim-") as tmp:
            staged = Path(tmp) / "niri"
            shutil.copytree(CONFIG.parent, staged)
            (staged / ANIMATIONS.relative_to(CONFIG.parent)).write_text(new)
            validate(staged / CONFIG.name)
        backup = Path(tempfile.mkdtemp(prefix="window-anim-", dir=BACKUPS))
        shutil.copy2(ANIMATIONS, backup / ANIMATIONS.name)
        if ANIMATIONS.read_text() != old:
            raise RuntimeError("animation.kdl changed during validation; try again")
        atomic_write(ANIMATIONS, new)
        try:
            validate(CONFIG)
        except Exception:
            if ANIMATIONS.read_text() == new:
                atomic_write(ANIMATIONS, old)
            raise
        return "Saved · " + str(backup)


def main():
    try:
        if len(sys.argv) == 1:
            text = ANIMATIONS.read_text()
            print(json.dumps({"open": current(text, "open"), "close": current(text, "close"),
                              "presets": {k: presets(k) for k in KINDS}}))
        elif sys.argv[1] == "recolor":
            if not ANIMATIONS.exists():
                print(json.dumps({"ok": "No animation.kdl"}))
                return 0
            pal = palette(sys.argv[2] if len(sys.argv) > 2 else None)
            print(json.dumps({"ok": write(lambda old: recoloured(old, pal))}))
        elif len(sys.argv) >= 3:
            speed = clamp_speed(sys.argv[3]) if len(sys.argv) > 3 else 1.0
            print(json.dumps({"ok": save(sys.argv[1], sys.argv[2], speed)}))
        else:
            raise ValueError("usage: window-anim.py [open|close <preset> [speed] | recolor [palette.json]]")
    except (OSError, ValueError, RuntimeError) as error:
        print(json.dumps({"error": str(error)}))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
