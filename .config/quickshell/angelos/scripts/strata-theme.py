#!/usr/bin/env python3
"""Strata (the file manager) in angelOS's colours, heaven and hell (entry "strata" of
templates/templates.json; Settings → Default apps → Files · Strata picks it).

  strata-theme.py build PALETTE.json   write ~/.config/strata/themes/angelos.toml for the palette
  strata-theme.py path                 where the theme lives

Strata leaves GTK's CSS alone (~/.config/gtk-4.0/gtk.css can't reach it, on purpose): its look is
nine colour tokens in a TOML file. It watches ~/.config/strata/themes while it runs and re-applies
a changed file to every open window, so a new palette, the dark or light mode and the demon's
hell reach it on the fly — once «angelOS» is the theme it uses (scripts/strata-setup.py apply).

The tokens, darkest to lightest in a dark theme as Strata's own themes have them: background
(the desk), surface (the sidebar: the face), muted (hover: faceAlt), highlight (the selection:
faceAlt tinted with the accent, kept readable under the text), border; text, dim_text, accent,
danger; the code preview's syntax colours from the terminal colours.
"""
import json
import os
import re
import sys
from pathlib import Path

CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
THEME = CONFIG / "strata/themes/angelos.toml"

# hell's colours, the same as scripts/telegram-theme.py and Theme.hell*
HELL = {
    "body": "#160609", "face": "#2a0b10", "faceAlt": "#3d1016", "sunken": "#0c0305",
    "edge": "#050102", "hi": "#6e1a21", "blood": "#b3142b", "ember": "#ff6a1a",
    "flame": "#ffb02e", "gold": "#d9a441", "text": "#f3d9c0", "textDim": "#a8857a",
}


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def hexa(c):
    return "#" + "".join("%02x" % max(0, min(255, round(v * 255))) for v in c)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def luminance(c):
    lin = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c]
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


def contrast(a, b):
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def readable(fill, text, toward, ratio=4.5):
    """fill moved toward `toward` (the background) until text reads on it"""
    for _ in range(20):
        if contrast(fill, text) >= ratio:
            break
        fill = mix(fill, toward, 0.15)
    return fill


def tokens(pal):
    if pal.get("realm") == "hell":
        h = {k: rgb(v) for k, v in HELL.items()}
        bg, text = h["sunken"], h["text"]
        return {
            "background": bg, "surface": h["body"], "muted": h["face"],
            "highlight": readable(h["hi"], text, bg), "border": h["faceAlt"],
            "text": text, "dim_text": h["textDim"], "accent": h["ember"], "danger": h["blood"],
            "syntax_keyword": h["ember"], "syntax_string": h["gold"], "syntax_constant": h["flame"],
            "syntax_type": h["textDim"], "syntax_preprocessor": h["blood"],
        }
    p = {k: rgb(v) for k, v in pal.items() if isinstance(v, str) and re.fullmatch(r"#[0-9a-fA-F]{6}", v)}
    dark = pal.get("mode") == "dark"
    text = p.get("text", rgb("#fafafa" if dark else "#2a1a22"))
    bg = p.get("desk", rgb("#171822" if dark else "#f4eef2"))
    face, alt = p.get("face", bg), p.get("faceAlt", bg)
    accent = p.get("accent", rgb("#ff8fb8"))
    term = lambda n, fb: p.get(f"color{n}", fb)  # noqa: E731
    return {
        "background": bg, "surface": face, "muted": alt,
        "highlight": readable(mix(alt, accent, 0.35), text, bg),
        "border": mix(alt, p.get("textDim", text), 0.25),
        "text": text, "dim_text": p.get("textDim", mix(text, bg, 0.4)),
        # the accent marks icons, the focus and links: the lighter one reads better on a dark desk
        "accent": accent if not dark or contrast(accent, bg) >= 3 else p.get("accent2", accent),
        "danger": p.get("danger", rgb("#ff4f6d")),
        "syntax_keyword": term(5, accent), "syntax_string": term(2, accent), "syntax_constant": term(9, accent),
        "syntax_type": term(3, accent), "syntax_preprocessor": term(6, accent),
    }


def render(pal):
    realm = "hell" if pal.get("realm") == "hell" else "heaven"
    lines = [f"# angelOS · {realm} · {pal.get('mode', 'dark')} — written by angelOS (scripts/strata-theme.py)",
             'name = "angelOS"']
    lines += [f'{k} = "{hexa(v)}"' for k, v in tokens(pal).items()]
    return "\n".join(lines) + "\n"


def build(palette_file):
    pal = json.loads(Path(palette_file).read_text())
    text = render(pal)
    if THEME.exists() and THEME.read_text() == text:
        return False
    THEME.parent.mkdir(parents=True, exist_ok=True)
    tmp = THEME.with_name(".angelos.toml.tmp")  # not *.toml: Strata would read it half-written
    tmp.write_text(text)
    tmp.replace(THEME)  # one change for Strata's watcher, never a half-written file
    return True


def main():
    if len(sys.argv) == 3 and sys.argv[1] == "build":
        print(json.dumps({"ok": True, "changed": build(sys.argv[2]), "path": str(THEME)}))
    elif sys.argv[1:] == ["path"]:
        print(THEME)
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
