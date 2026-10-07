#!/usr/bin/env python3
"""The terminal in hell (Settings → Y2K → Terminal in hell), run by render-templates.py.

usage: terminal-hell.py PALETTE.json

The terminals' colours come from their templates (kitty.conf, foot.ini, alacritty.toml
with "terminal": true — the palette's "term" overrides them with hell's while the demon
rules). This writes what the templates can't:
  ~/.local/share/angelos/terminal/realm          heaven | hell
  ~/.local/share/angelos/terminal/hell-lines.txt  her lines for a new terminal, one a line
  ~/.local/share/angelos/terminal/hell.png        kitty's scorched background (painted once)
  ~/.local/share/angelos/terminal/fastfetch.jsonc in hell: fastfetch in the circle. With one
                                                  of angelOS's styles (scripts/fastfetch_style.py)
                                                  that style in the circle: the circle's own sigil
                                                  (each of the nine has one), its number, name and
                                                  line, its words for the readings ("cpu · жар"),
                                                  its colours. With a config of the user's own:
                                                  that config in the circle, the same way
  ~/.local/share/angelos/terminal/fastfetch-logo.txt  its picture
  ~/.config/fish/conf.d/angelos-realm.fish        in hell: command colours from the circle's
                                                  palette for the session, fastfetch with the
                                                  circle's config, and one of her lines before
                                                  the first prompt (only if fish is set up)
"""
import importlib.util
import json
import random
import re
import sys
from pathlib import Path

HOME = Path.home()
OUT = HOME / ".local/share/angelos/terminal"
FASTFETCH = HOME / ".config/fastfetch/config.jsonc"
FISH = HOME / ".config/fish/conf.d/angelos-realm.fish"
PAINT_VERSION = "2"

FISH_SNIPPET = r"""# angelOS: the terminal in hell (Settings → Y2K → Terminal in hell).
# Written by angelOS (scripts/terminal-hell.py) — edits here are overwritten.
status is-interactive; or return
set -l __angelos_dir (set -q XDG_DATA_HOME; and echo $XDG_DATA_HOME; or echo $HOME/.local/share)/angelos/terminal
test -f $__angelos_dir/realm; or return
test (string trim < $__angelos_dir/realm) = hell; or return
# the circle's colours for the command line — this session only, the universal colours stay yours
set -g fish_color_command {accent}
set -g fish_color_keyword {accent2}
set -g fish_color_param {fg}
set -g fish_color_quote {color3}
set -g fish_color_redirection {color1}
set -g fish_color_end {textDim}
set -g fish_color_operator {accent2}
set -g fish_color_escape {color5}
set -g fish_color_error {color9} --bold
set -g fish_color_autosuggestion {textDim}
set -g fish_color_comment {textDim}
set -g fish_color_selection --background={lo}
set -g fish_color_search_match --background={bgAlt}
# fastfetch in the circle (the greeting runs it: CachyOS's fish config does)
# (angelos-fastfetch.fish, when it's there, already does this, its picture moving)
if test -f $__angelos_dir/fastfetch.jsonc; and not functions -q fastfetch
    function fastfetch --wraps fastfetch
        command fastfetch --config (set -q XDG_DATA_HOME; and echo $XDG_DATA_HOME; or echo $HOME/.local/share)/angelos/terminal/fastfetch.jsonc $argv
    end
end
# one of her lines before the first prompt (after fastfetch)
function __angelos_hell_line --on-event fish_prompt
    functions -e __angelos_hell_line
    set -l file (set -q XDG_DATA_HOME; and echo $XDG_DATA_HOME; or echo $HOME/.local/share)/angelos/terminal/hell-lines.txt
    test -s $file; or return
    set -l lines (string match -v -r '^\s*$' < $file)
    test (count $lines) -gt 0; or return
    set_color {accent}; printf '⛧ '
    set_color {fg}; printf '%s' $lines[(random 1 (count $lines))]
    set_color normal; echo
end
"""


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_text() == text:
        return False
    tmp = path.with_suffix(path.suffix + ".angelos-tmp")
    tmp.write_text(text)
    tmp.replace(path)
    return True


# the snippet's colours when the palette has none (heaven: the snippet stays silent anyway)
FISH_DEFAULTS = {"accent": "e2703f", "accent2": "c99a5e", "fg": "d9cbbd", "textDim": "9c8f85",
                 "lo": "1f1716", "bgAlt": "16100f", "color1": "a8473a", "color3": "b08f52",
                 "color5": "8a4a6a", "color8": "3b2a26", "color9": "c4604c"}


def fish_snippet(term):
    cols = dict(FISH_DEFAULTS)
    for k in cols:
        v = str(term.get(k, "")).lstrip("#")
        if len(v) == 6:
            cols[k] = v
    # the snippet has fish's own braces: fill only our names
    out = FISH_SNIPPET
    for k, v in cols.items():
        out = out.replace("{" + k + "}", v)
    return out


def jsonc(text):
    """JSON with comments (fastfetch's config.jsonc): // and /* */ outside strings, trailing commas"""
    out, i, n, quote = [], 0, len(text), False
    while i < n:
        c = text[i]
        if quote:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if c == '"':
                quote = False
            i += 1
        elif c == '"':
            quote = True
            out.append(c)
            i += 1
        elif text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j < 0 else j
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            i = n if j < 0 else j + 2
        else:
            out.append(c)
            i += 1
    return json.loads(re.sub(r",(\s*[}\]])", r"\1", "".join(out)))


def ansi(hex_colour, bold=False):
    h = hex_colour.lstrip("#")
    return "\x1b[%s38;2;%d;%d;%dm" % ("1;" if bold else "", int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def ff_colour(hex_colour):
    h = hex_colour.lstrip("#")
    return "38;2;%d;%d;%d" % (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def fastfetch_logo(ff, width=40, height=16):
    """the emblem with horns in the circle's colours (two blocks an art pixel, like
    fastfetch-logo.py), and under it the circle's number and its name"""
    logo = ff.get("logo") or {}
    rows, pal = logo.get("rows") or [], logo.get("palette") or {}
    art = []
    for row in rows:
        line, cur = "", None
        for ch in row:
            col = pal.get(ch) if ch not in ". " else None
            if col is None:
                line += ("\x1b[0m" if cur else "") + "  "
                cur = None
            else:
                if col != cur:
                    line += ansi(col)
                    cur = col
                line += "██"
        art.append(line + ("\x1b[0m" if cur else ""))
    w = max((len(r) for r in rows), default=0) * 2
    art = [" " * max(0, (width - w) // 2) + a for a in art]
    head = "⛧ %s %s ⛧" % (ff.get("circleWord", "Circle").upper(), ff.get("roman", "")) if ff.get("roman") else "⛧"
    name = str(ff.get("name", "")).upper()
    text = [" " * max(0, (width - len(head)) // 2) + ansi(ff.get("keys", "#e2703f"), True) + head + "\x1b[0m",
            " " * max(0, (width - len(name)) // 2) + ansi(ff.get("title", "#d9cbbd")) + name + "\x1b[0m"]
    body = art + [""] + text
    body = [""] * max(0, (height - len(body)) // 2) + body
    return "\n".join(body + [""] * max(0, height - len(body))) + "\n"


def fastfetch_config(ff, user, logo_path):
    """the user's own config in the circle: the same modules, its words and colours"""
    cfg = json.loads(json.dumps(user)) if isinstance(user, dict) else {"modules": ["title", "separator", "os", "kernel", "uptime", "cpu", "gpu", "memory", "break", "colors"]}
    if ff.get("logo"):
        logo = cfg.get("logo") if isinstance(cfg.get("logo"), dict) else {}
        logo.update({"type": "file-raw", "source": str(logo_path), "width": 40, "height": 16})
        logo.setdefault("padding", {"top": 1, "right": 3})
        cfg["logo"] = logo
    disp = cfg.setdefault("display", {})
    disp["separator"] = " ⛧ "
    disp["color"] = {"keys": ff_colour(ff.get("keys", "#e2703f")), "title": ff_colour(ff.get("title", "#d9cbbd")),
                     "output": ff_colour(ff.get("title", "#d9cbbd")), "separator": ff_colour(ff.get("dim", "#9c8f85"))}
    labels = ff.get("labels") or {}
    words = {"cpu": ("cpu", "CPU"), "gpu": ("gpu", "GPU"), "memory": ("ram", "RAM")}
    mods = []
    for m in cfg.get("modules", []):
        kind = m if isinstance(m, str) else m.get("type") if isinstance(m, dict) else None
        if kind in words and labels.get(words[kind][0]):
            m = dict(m) if isinstance(m, dict) else {"type": kind}
            m["key"] = "%s · %s" % (m.get("key") or words[kind][1], labels[words[kind][0]])
        mods.append(m)
        # the circle under the title's line: its number and name, its one line
        if kind == "separator" and not any(isinstance(x, dict) and x.get("angelosCircle") for x in mods):
            circle = "%s %s · %s" % (ff.get("circleWord", "Circle"), ff.get("roman", ""), ff.get("name", "")) if ff.get("roman") else ff.get("name", "")
            mods.append({"type": "custom", "format": "⛧ " + circle, "outputColor": ff_colour(ff.get("keys", "#e2703f")), "angelosCircle": True})
            if ff.get("where"):
                mods.append({"type": "custom", "format": ff["where"], "outputColor": ff_colour(ff.get("dim", "#9c8f85")), "angelosCircle": True})
    for m in mods:
        if isinstance(m, dict):
            m.pop("angelosCircle", None)
    cfg["modules"] = mods
    return "// angelOS: fastfetch in the circle — written from ~/.config/fastfetch/config.jsonc by\n// scripts/terminal-hell.py; edits here are overwritten (edit your own config instead)\n" + json.dumps(cfg, ensure_ascii=False, indent=2) + "\n"


def styled_fastfetch(ff, logo_path):
    """(config text, logo text, what moves) of angelOS's fastfetch style in the circle, or None
    when the user's config isn't one of the styles"""
    style = ff.get("style")
    try:
        spec = importlib.util.spec_from_file_location("fastfetch_style", Path(__file__).with_name("fastfetch_style.py"))
        fs = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(fs)
    except (OSError, ImportError, SyntaxError):
        return None
    if style not in fs.STYLES or not FASTFETCH.exists() or not FASTFETCH.read_text(errors="replace").startswith(fs.MARK):
        return None
    logo = ff.get("logo") or {}
    pal = logo.get("palette") or {"#": "#040303", "o": ff.get("keys", "#e2703f"), "x": "#6b2420", "y": "#c99a5e",
                                  "w": ff.get("title", "#d9cbbd"), "f": ff.get("dim", "#9c8f85"), "r": ff.get("keys", "#e2703f")}
    hell = {**ff, "palette": pal}
    return fs.render_all(style, {"lang": ff.get("lang", "ru")}, logo.get("rows") or fs.SIGILS["limbo"], pal, logo_path, hell,
                         ff.get("emblem", ""), float(ff.get("anim") or 0))


def paint(path):
    """a scorched pixel background: near-black, a little lighter low down, a few charred
    cracks and a pentagram barely there. Nothing glows. Drawn at 1/4 size, scaled up crisp."""
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        return False
    import math
    w, h = 400, 250
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        t = y / (h - 1)
        r = int(9 + 9 * t)
        g = int(6 + 5 * t)
        b = int(7 + 5 * t)
        for x in range(w):
            px[x, y] = (r, g, b)
    rnd = random.Random(666)
    d = ImageDraw.Draw(img)
    # charred cracks: short dark random walks
    for _ in range(26):
        x, y = rnd.randrange(w), rnd.randrange(h // 3, h)
        for _ in range(rnd.randrange(6, 18)):
            px[x % w, min(h - 1, y)] = (4, 3, 3)
            x += rnd.choice((-1, 0, 1, 1))
            y += rnd.choice((-1, 0, 0, 1))
    # the pentagram, barely there
    cx, cy, rad = w - 62, h - 64, 44
    col = (30, 22, 21)
    pts = [(cx + rad * math.cos(-math.pi / 2 + i * 2 * math.pi / 5), cy + rad * math.sin(-math.pi / 2 + i * 2 * math.pi / 5)) for i in range(5)]
    for i in range(5):
        d.line([pts[i], pts[(i + 2) % 5]], fill=col, width=1)
    d.ellipse([cx - rad - 5, cy - rad - 5, cx + rad + 5, cy + rad + 5], outline=col, width=1)
    d.ellipse([cx - rad - 9, cy - rad - 9, cx + rad + 9, cy + rad + 9], outline=(24, 17, 16), width=1)
    path.parent.mkdir(parents=True, exist_ok=True)
    img.resize((w * 4, h * 4), Image.NEAREST).save(path)
    (path.parent / ".paint-version").write_text(PAINT_VERSION)
    return True


def main():
    pal = json.loads(Path(sys.argv[1]).read_text())
    realm = pal.get("termRealm", "heaven")
    write(OUT / "realm", realm + "\n")
    lines = [str(l).replace("\n", " ") for l in pal.get("hellLines") or []]
    if lines:
        write(OUT / "hell-lines.txt", "\n".join(lines) + "\n")
    bg = OUT / "hell.png"
    ver = OUT / ".paint-version"
    if realm == "hell" and (not bg.exists() or not ver.exists() or ver.read_text().strip() != PAINT_VERSION):
        paint(bg)
    # fastfetch in the circle: only in hell, and only next to a fastfetch config of the user's
    ff = pal.get("fastfetch") if realm == "hell" else None
    conf, logo = OUT / "fastfetch.jsonc", OUT / "fastfetch-logo.txt"
    anim = OUT / "fastfetch-anim.json"
    styled = styled_fastfetch(ff, logo) if ff and FASTFETCH.exists() else None
    if styled:
        conf_text, logo_text, spec = styled
        if logo_text:
            write(logo, logo_text)
        write(conf, conf_text)
        # its picture moves for a moment too (scripts/fastfetch_anim.py, angelos-fastfetch.fish)
        if spec:
            write(anim, json.dumps(spec, ensure_ascii=False) + "\n")
        elif anim.exists():
            anim.unlink()
    elif ff and FASTFETCH.exists():
        try:
            user = jsonc(FASTFETCH.read_text())
        except (OSError, ValueError):
            user = None
        if ff.get("logo"):
            write(logo, fastfetch_logo(ff))
        write(conf, fastfetch_config(ff, user, logo))
        if anim.exists():
            anim.unlink()
    else:
        for f in (conf, logo, anim):
            if f.exists():
                f.unlink()
    # fish: only where fish is the user's shell (its config dir exists)
    if FISH.parent.parent.is_dir():
        write(FISH, fish_snippet(pal.get("term") or {}))


if __name__ == "__main__":
    main()
