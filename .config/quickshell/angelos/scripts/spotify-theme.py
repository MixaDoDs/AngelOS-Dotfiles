#!/usr/bin/env python3
"""Spotify in angelOS's colours, heaven and hell, over whatever Spicetify theme is set (entry
"spotify" of templates/templates.json).

  spotify-theme.py build PALETTE.json   write the extension for the palette and register it

Spicetify only: without it nothing is installed. The colours go in as a Spicetify extension,
~/.config/spicetify/Extensions/angelos-colors.js, a stylesheet of --spice-* variables with
!important — over the theme's color.ini and over the inline colours a theme like Vantagraph
Custom sets from its own editor. Spotify is never restarted (the music would stop): `spicetify
… -n`, the colours show from Spotify's next start (or Ctrl+Shift+R). The colours are
scripts/discord-theme.py's scheme, so Spotify matches Discord.
"""
import importlib.util
import json
import shutil
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
SHELL = Path(__file__).resolve().parent.parent
SPICE_DIR = HOME / ".config/spicetify"
EXT_NAME = "angelos-colors.js"
EXT = SPICE_DIR / "Extensions" / EXT_NAME
MARK = "written by angelOS"

_spec = importlib.util.spec_from_file_location("discord_theme", SHELL / "scripts/discord-theme.py")
discord = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(discord)


def spicetify():
    return shutil.which("spicetify") or next((str(p) for p in [HOME / ".spicetify/spicetify"] if p.exists()), None)


def colors(pal):
    """--spice-<name> → (r, g, b) 0..1: Spicetify's own names and Vantagraph's"""
    s = discord.scheme(pal)
    mix = discord.mix
    out = {
        # Spicetify's base names (every theme)
        "main": s["desk"], "sidebar": s["face"], "player": s["face"], "card": s["faceAlt"],
        "shadow": s["shadow"], "text": s["text"], "subtext": s["textDim"],
        "button": s["accent"], "button-active": s["accentHover"], "button-disabled": s["muted"],
        "highlight": s["hover"], "highlight-elevated": s["active"], "selected-row": s["text"],
        "tab-active": s["active"], "notification": s["accent"], "notification-error": s["danger"],
        "misc": s["textDim"], "playbar": s["face"],
        # Vantagraph Custom's
        "window": s["deep"], "panel": s["desk"], "panel-hover": s["hover"], "menu": s["faceAlt"],
        "stroke": s["edge"], "accent": s["accent"], "btn-active": s["accent2"],
        "play-btn": s["accent"], "play-btn-hover": s["accentHover"], "heart": s["accent"],
        "bar-fill": s["accent"], "bar-bg": mix(s["face"], s["text"], 0.35),
    }
    return out, s


def extension(pal):
    cols, s = colors(pal)
    to255 = lambda c: [round(max(0.0, min(1.0, v)) * 255) for v in c]
    lines = []
    for name, c in cols.items():
        r, g, b = to255(c)
        lines.append("--spice-%s:#%02x%02x%02x!important;--spice-rgb-%s:%d,%d,%d!important;" % (name, r, g, b, name, r, g, b))
    css = ":root{" + "".join(lines) + "}"
    realm = "hell" if s["hell"] else "heaven, " + ("dark" if s["dark"] else "light")
    return ("// angelos-colors.js — %s (%s). Rewritten on every palette change.\n"
            "(function angelosColors() {\n"
            "  if (!document.head) { setTimeout(angelosColors, 100); return; }\n"
            "  let el = document.getElementById(\"angelos-colors\");\n"
            "  if (!el) { el = document.createElement(\"style\"); el.id = \"angelos-colors\"; document.head.appendChild(el); }\n"
            "  el.textContent = %s;\n"
            "})();\n") % (MARK, realm, json.dumps(css))


def registered():
    cfg = SPICE_DIR / "config-xpui.ini"
    try:
        for line in cfg.read_text().splitlines():
            if line.strip().startswith("extensions"):
                return EXT_NAME in line.split("=", 1)[1].split("|")
    except OSError:
        pass
    return False


def build(palette_file):
    tool = spicetify()
    if not tool or not (SPICE_DIR / "config-xpui.ini").exists():
        return {"ok": True, "skipped": "no Spicetify"}
    if EXT.exists() and MARK not in EXT.read_text(errors="replace")[:200]:
        return {"ok": True, "skipped": "%s is not angelOS's" % EXT}
    pal = json.loads(Path(palette_file).read_text())
    text = extension(pal)
    changed = not EXT.exists() or EXT.read_text() != text
    if changed:
        EXT.parent.mkdir(parents=True, exist_ok=True)
        EXT.write_text(text)
    # -n: never restart Spotify
    if not registered():
        cmd = [[tool, "config", "extensions", EXT_NAME], [tool, "apply", "-n"]]
    elif changed:
        cmd = [[tool, "refresh", "-e", "-n"]]
    else:
        cmd = []
    for c in cmd:
        r = subprocess.run(c, capture_output=True, text=True, timeout=120)
        if r.returncode != 0:
            return {"ok": False, "error": (r.stderr or r.stdout).strip()[-400:]}
    return {"ok": True, "changed": changed, "extension": str(EXT)}


def main():
    if len(sys.argv) == 3 and sys.argv[1] == "build":
        print(json.dumps(build(sys.argv[2])))
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
