#!/usr/bin/env python3
"""fastfetch in angelOS's styles (Settings → System → fastfetch).

  fastfetch_style.py apply --style STYLE --emblem-rows JSON --emblem-palette JSON --colors JSON
      writes ~/.config/fastfetch/config.jsonc in that style, its picture in
      ~/.config/fastfetch/angelos-logo.txt. Only a config angelOS wrote (or the one the
      dotfiles shipped) is replaced; the first time, the one that was there is kept as
      config.before-angelos.jsonc. A config of the user's own is left alone.
  fastfetch_style.py restore
      puts config.before-angelos.jsonc back (the style "own")
  fastfetch_style.py preview --style STYLE [same options] [--hell JSON]
      runs fastfetch in that style (in a temporary folder) and prints what the terminal
      would show as JSON: {"cols", "lines": [[[text, fg, bg, bold], …], …]}
  fastfetch_style.py styles
      the styles as JSON

The styles (pictures are half blocks: one character is two square pixels). Each shows the
gear with its price (scripts/gear.py): that's what people giggle at, never leave it out.
  compact  the emblem of Settings → Bar → Logo at twice the size, short lines, the gear priced
  angel    the winged heart with the halo and the pill, every reading and the gear's total
  helper   the Y2K corner's angel herself: says hi, the readings, her word on the total
  receipt  an angelOS store receipt: the paper (with the emblem) is the logo, the readings are
           printed onto it (each paper line leaves the cursor at its margin), ИТОГО at the end
  stream   the emblem on a LIVE webcam, the readings as the chat, the gear as superchats
  window   the emblem and the readings in a Y2K window frame
  mini     no picture: eight lines

In hell (scripts/terminal-hell.py, --hell): the same style in the circle — its sigil instead
of the emblem, its number and name, its line, its words for the readings ("cpu · жар"),
its colours. Each of the nine circles has a sigil of its own; the angel gives way to the
demon, the receipt turns into a contract for the soul. The words follow "lang" (ru | en)
in --colors (or in --hell).
"""
import argparse
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
FF_DIR = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "fastfetch"
CONFIG = FF_DIR / "config.jsonc"
LOGO = FF_DIR / "angelos-logo.txt"
BEFORE = FF_DIR / "config.before-angelos.jsonc"
ANIM = FF_DIR / "angelos-anim.json"            # what moves (scripts/fastfetch_anim.py)
FISH = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "fish" / "conf.d" / "angelos-fastfetch.fish"
FISH_HOOK = r"""# angelOS: fastfetch's picture moves for a moment when it greets a new terminal
# (Settings → System → fastfetch → Animation: scripts/fastfetch_anim.py). Written by
# scripts/fastfetch_style.py; without angelos-anim.json fastfetch is plain.
status is-interactive; or return
function fastfetch --wraps fastfetch --description 'fastfetch (angelOS: its picture moves for a moment)'
    set -l conf
    set -l spec (set -q XDG_CONFIG_HOME; and echo $XDG_CONFIG_HOME; or echo $HOME/.config)/fastfetch/angelos-anim.json
    set -l term (set -q XDG_DATA_HOME; and echo $XDG_DATA_HOME; or echo $HOME/.local/share)/angelos/terminal
    # in hell: the circle's fastfetch (scripts/terminal-hell.py)
    if test -f $term/realm; and test (string trim < $term/realm) = hell; and test -f $term/fastfetch.jsonc
        set conf --config $term/fastfetch.jsonc
        set spec $term/fastfetch-anim.json
    end
    if test (count $argv) -eq 0; and test -f $spec; and test -f {anim}; and isatty stdin; and isatty stdout
        command fastfetch $conf --pipe false | python3 {anim} $spec
    else
        command fastfetch $conf $argv
    end
end
"""
MARK = "// angelOS fastfetch style:"
# the config the dotfiles shipped before the styles: ours to replace
SHIPPED = "NEEDY GIRL OVERDOSE: KAngel's winged heart"
STYLES = ("compact", "angel", "helper", "receipt", "stream", "window", "mini")
GEAR = "python3 " + str(HERE / "gear.py")

# ---- the circles' sigils: 19 × 12, in the emblem alphabet ('#' ink, 'o' the circle's
# accent, 'x' blood, 'y' flame, 'w' bone, 'f' ash) ----
SIGILS = {
    # Limbo: a ghost under a faint halo
    "limbo": ["......fffffff......", ".....f.......f.....", "......fffffff......", "...................",
              "......#######......", ".....#wwwwwww#.....", "....#ww#www#ww#....", "....#ww#www#ww#....",
              "....#wwwwwwwww#....", "....#wwwwwwwww#....", "....#w#ww#ww#w#....", "....#.#..#..#.#...."],
    # Lust: a heart caught in the black wind
    "lust": ["...ffffffffff......", "..f..........f.....", ".f...##...##..f....", "f...#oo#.#oo#..f...",
             "f..#ooooooooo#..f..", "f..#owooooooo#..f..", ".f..#ooooooo#..f...", "..f..#ooooo#..f....",
             "...f..#ooo#..f.....", "....ff.#o#.ff......", "......ff#ff........", ".......fffff......."],
    # Gluttony: a skull drooling
    "gluttony": ["....###########....", "...#wwwwwwwwwww#...", "..#wwwwwwwwwwwww#..", "..#ww###www###ww#..",
                 "..#ww#o#www#o#ww#..", "..#ww###w#w###ww#..", "..#wwwwww#wwwwww#..", "...#wwwwwwwwwww#...",
                 "....#w#w#w#w#w#....", "....###########....", ".....#o#...#o#.....", "......o.....o......"],
    # Greed: a heavy gold coin
    "greed": ["...................", "......#######......", "....##yyyyyyy##....", "...#yyyyy#yyyyy#...",
              "..#yyyy#####yyyy#..", "..#yyy#y#yyyyyyy#..", "..#yyyy####yyyyy#..", "..#yyyyyyy#y#yyy#..",
              "..#yyyy#####yyyy#..", "...#yyyyy#yyyyy#...", "....##yyyyyyy##....", "......#######......"],
    # Wrath: a hand rising out of the Styx
    "wrath": ["......#.#.#.#......", "......#w#w#w#......", "......#w#w#w#.#....", "......#wwwwwww#....",
              "......#wwwwwww#....", ".......#wwwww#.....", ".......#wwwww#.....", ".oo...oo#www#.oo...",
              "oo..oooo..oooo..ooo", "..oo....oo....oo...", "xxxxxxxxxxxxxxxxxxx", ".x.x.x.x.x.x.x.x.x."],
    # Heresy: a tomb on fire
    "heresy": [".........y.........", "........yoy........", ".......yoooy..y....", "......yoyoyo.yoy...",
               "...#############...", "...#fffffffffff#...", "...#fffff#fffff#...", "...#ffff###ffff#...",
               "...#fffff#fffff#...", "...#fffff#fffff#...", "...#############...", "..#ooooooooooooo#.."],
    # Violence: a dagger, and the blood off it
    "violence": [".........#.........", "........#w#........", "........#w#........", "........#w#........",
                 "........#w#........", "........#x#........", "....#yyyyyyyyy#....", "........#f#........",
                 "........#f#....x...", "........#y#...xxx..", ".........#.....x...", "..................."],
    # Fraud: a mask, laughing on one side and weeping on the other
    "fraud": ["...#############...", "..#wwwwww#ffffff#..", "..#w##www#fff##f#..", "..#w#o#ww#ff#o#f#..",
              "..#wwwwww#ffffff#..", "..#wwwwww#ffxfff#..", "...#wwwww#fffxf#...", "...#w#ww#w#f##f#...",
              "....#w##w#f#ff#....", ".....#wwww#ff#.....", "......#######......", "..................."],
    # Treachery: the ice of Cocytus
    "treachery": [".........o.........", "......o..w..o......", ".......o.w.o.......", "..o.....www.....o..",
                  "...oo..wwwww..oo...", ".wwwwwwwwowwwwwwww.", "...oo..wwwww..oo...", "..o.....www.....o..",
                  ".......o.w.o.......", "......o..w..o......", ".........o.........", "..................."],
}


def rgb(hex_colour):
    h = str(hex_colour).lstrip("#")
    if len(h) == 3:
        h = "".join(ch * 2 for ch in h)
    try:
        return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
    except ValueError:
        return (255, 255, 255)


def fg(hex_colour, bold=False):
    return "\x1b[%s38;2;%d;%d;%dm" % ("1;" if bold else "", *rgb(hex_colour))


def sgr(hex_colour, bold=False):
    """fastfetch's own colour spec ("38;2;r;g;b"), for display.color and {#…} in formats"""
    return ("1;" if bold else "") + "38;2;%d;%d;%d" % rgb(hex_colour)


def grid_of(rows, palette, bg=None):
    """pixel rows → a grid of colours ('.' and ' ' are nothing: None, or the background `bg`)"""
    width = max((len(r) for r in rows), default=0)
    return [[bg if ch in ". " else palette.get(ch, bg) for ch in r.ljust(width, ".")] for r in rows]


def blocks(grid, bg=None):
    """a grid of colours → terminal lines: one character, two pixels (▀ with the top one's
    colour on the bottom one's)"""
    width = len(grid[0]) if grid else 0
    if len(grid) % 2:
        grid = grid + [[bg] * width]
    lines = []
    for y in range(0, len(grid), 2):
        out = ""
        for x in range(width):
            top, bot = grid[y][x], grid[y + 1][x]
            if top and bot:
                out += "\x1b[38;2;%d;%d;%dm\x1b[48;2;%d;%d;%dm▀\x1b[0m" % (*rgb(top), *rgb(bot)) if top != bot else (
                    "\x1b[48;2;%d;%d;%dm \x1b[0m" % rgb(bg) if top == bg else fg(top) + "█\x1b[0m")
            elif top:
                out += fg(top) + "▀\x1b[0m"
            elif bot:
                out += fg(bot) + "▄\x1b[0m"
            else:
                out += " "
        lines.append(out)
    return lines, width


def half_blocks(rows, palette, bg=None):
    """pixel rows → terminal lines (see blocks)"""
    return blocks(grid_of(rows, palette, bg), bg)


def scaled(rows, k):
    return ["".join(ch * k for ch in r) for r in rows for _ in range(k)]


def logo_text(art, width, captions):
    """the picture, a blank line, the captions centred under it: (text, width, height, the
    picture's column)"""
    cap_w = max((w for _, w in captions), default=0)
    w = max(width, cap_w)
    out = [" " * ((w - width) // 2) + line for line in art]
    if captions:
        out.append("")
        out += [" " * max(0, (w - cw) // 2) + text for text, cw in captions]
    return "\n".join(out) + "\n", w, len(out), (w - width) // 2


def hearts(colours, glyph="♥"):
    return " ".join("{#%s}%s" % (sgr(c), glyph) for c in colours) + "{#}"


# ---- what moves (scripts/fastfetch_anim.py plays it): per picture, in its art pixels ----

# the Start emblems' wings (x0, x1, y0, y1): they flap
EMBLEM_WINGS = {"heart": [[0, 4, 4, 9], [14, 18, 4, 9]]}


def halo_of(rows, key):
    """the halo's rows at the top (only `key` pixels) when there's a blank row under it to bob into"""
    n = 0
    while n < len(rows) and key in rows[n] and set(rows[n]) <= {key, "."}:
        n += 1
    if n and n < len(rows) and set(rows[n]) <= {"."}:
        xs = [x for r in rows[:n] for x, ch in enumerate(r) if ch == key]
        return [min(xs), max(xs), 0, n - 1]
    return None


def motion(kind, rows, colors, hell, emblem=""):
    """the effects of a picture: emblem | heart (the winged heart) | sigil | girl"""
    if hell:
        pal = hell.get("palette") or {}
        fx = {"embers": 3, "ember": [pal.get("y", "#ffb347"), pal.get("x", "#a01818")],
              "flicker": ["y", "o"] if kind == "sigil" else ["r", "o"]}
        if kind == "sigil" and hell.get("circle") in ("greed", "treachery"):
            fx["glint"] = True              # the gold coin and the ice shine
        if kind == "girl":
            fx = {"embers": 3, "ember": fx["ember"]}
        return fx
    spark = [colors.get("accent2", "#c9b6ff"), "#ffffff"]
    if kind == "girl":
        return {"sparkles": 2, "spark": spark, "pulse": ["l"]}
    if kind == "heart":
        return {"glint": True, "sparkles": 2, "spark": spark, "flap": [[0, 10, 5, 15], [29, 39, 5, 15]],
                "halo": [12, 27, 0, 2], "twinkle": ["b"], "pulse": ["e"]}
    fx = {"glint": True, "sparkles": 2, "spark": spark}
    halo = halo_of(rows, "y")
    if halo:
        fx["halo"] = halo
    if emblem in EMBLEM_WINGS:
        fx["flap"] = EMBLEM_WINGS[emblem]
    fx.update({"heart": {"pulse": ["o"]}, "kitty": {"pulse": ["p"]}, "cd": {"cycle": ["x", "y", "o"]},
               "star": {"twinkle": ["x"]}}.get(emblem, {}))
    return fx


def layer(rows, pal, line, col, k=1, bg=None, fx=None, frames=None):
    return {"rows": rows, "pal": pal, "line": line, "col": col, "k": k, "bg": bg, "fx": fx or {}, "frames": frames or {}}


# ---- the styles ----

def tr(lang, ru, en):
    return en if lang == "en" else ru


def gear(fmt, nth=None, total=False, width=0, lang="ru", voice=None, zero=False, fill=None):
    """the command line of a gear.py reading (the prices are the point: never left out)"""
    cmd = ["python3", str(HERE / "gear.py"), "--fmt", fmt, "--lang", lang]
    if nth is not None:
        cmd += ["--nth", str(nth)]
    if total:
        cmd.append("--total")
    if zero:
        cmd.append("--zero")
    if width:
        cmd += ["--width", str(width)]
    if fill:
        cmd += ["--fill-char", fill]
    if voice:
        cmd += ["--voice", voice]
    return " ".join(shlex.quote(c) for c in cmd)


def sprite(who, frame="up"):
    """the Y2K corner's girl (modules/y2k/AngelSprite.js or DemonSprite.js): (rows, palette)"""
    src = (ROOT / "modules" / "y2k" / ("DemonSprite.js" if who == "demon" else "AngelSprite.js")).read_text()
    rows = re.findall(r'"([^"]*)"', re.search(r"const %s = \[(.*?)\];" % frame, src, re.S).group(1))
    pal = dict(re.findall(r'"(.)":\s*"(#[0-9a-fA-F]{6})"', re.search(r"const palette = \{(.*?)\};", src, re.S).group(1)))
    return rows, pal


def centred(text, width, seen=None):
    seen = len(text) if seen is None else seen
    left = max(0, (width - seen) // 2)
    return " " * left + text + " " * max(0, width - seen - left)


# the receipt: a strip of paper (parchment in hell) the readings are printed on
PAPER = 38                       # columns, a margin of one on each side
SLOTS = 4                        # gear lines it has room for


def paper_colours(hell):
    if hell:
        return "#e8d5ae", "#4a0e0e", hell.get("keys", "#a01818")
    return "#fbf6ee", "#3b2a35", None


def receipt_picture(emblem_rows, emblem_pal, colors, hell, lang, text_rows, emblem=""):
    """the logo of the receipt: the torn top, the shop's emblem and name, then blank paper the
    readings are printed on (each of those lines ends with the cursor back at its left margin,
    so fastfetch writes onto the paper), the torn bottom. (text, width, height, the first
    paper line for the text, what moves)"""
    paper, ink, accent = paper_colours(hell)
    accent = accent or colors.get("accent", "#ff6fb0")
    bg = "\x1b[48;2;%d;%d;%dm" % rgb(paper)
    sigil = SIGILS.get(hell.get("circle", "")) if hell else None
    rows = sigil or emblem_rows
    art, w = half_blocks(rows, emblem_pal, paper)
    lines = [fg(paper) + ("▄ " * PAPER)[:PAPER] + "\x1b[0m", bg + " " * PAPER + "\x1b[0m"]
    left = (PAPER - w) // 2
    moving = [layer(rows, emblem_pal, len(lines), left, 1, paper, motion("sigil" if sigil else "emblem", rows, colors, hell, emblem))]
    for a in art:
        lines.append(bg + " " * left + a + bg + " " * (PAPER - w - left) + "\x1b[0m")
    head = ("⛧ " + tr(lang, "ДОГОВОР", "CONTRACT") + " ⛧") if hell else ("♡ " + tr(lang, "МАГАЗИН ANGELOS", "ANGELOS STORE") + " ♡")
    lines.append(bg + " " * PAPER + "\x1b[0m")
    lines.append(bg + fg(accent, True) + bg + centred(head, PAPER) + "\x1b[0m")
    top = len(lines)
    for _ in range(text_rows):
        lines.append(bg + " " * PAPER + "\x1b[0m\x1b[%dD" % (PAPER - 1))
    lines.append(fg(paper) + ("▀ " * PAPER)[:PAPER] + "\x1b[0m")
    return "\n".join(lines) + "\n", PAPER, len(lines), top, {"layers": moving, "texts": []}


def picture(style, emblem_rows, emblem_pal, colors, hell, emblem=""):
    """the logo file's text, width and height for this style, and what moves in it ({"layers",
    "texts"}, positions in the logo) — None: no picture"""
    if style in ("mini", "receipt"):
        return None
    accent, title = colors.get("accent", "#ff6fb0"), colors.get("accent2", "#c9b6ff")
    lang = colors.get("lang") or (hell or {}).get("lang") or "ru"
    if style == "helper":
        who = "demon" if hell else "angel"
        rows, pal = sprite(who)
        art, w = half_blocks(rows, pal)
        frames = {f: sprite(who, f)[0] for f in ("down", "blink", "talk")}
        return logo_text(art, w, [])[:3] + ({"layers": [layer(rows, pal, 0, 0, fx=motion("girl", rows, colors, hell), frames=frames)], "texts": []},)
    if style == "stream":
        sigil = SIGILS.get(hell.get("circle", "")) if hell else None
        rows = sigil or emblem_rows
        pal = (hell or {}).get("palette") or emblem_pal
        art, w = half_blocks(scaled(rows, 2), pal)
        edge = fg((hell or {}).get("keys", accent))
        badge = "\x1b[1;38;2;255;255;255m\x1b[48;2;230;33;23m"
        live = badge + (" ⛧ LIVE " if hell else " ● LIVE ") + "\x1b[0m"
        inner = w + 4
        who = (hell.get("circleWord", "Circle") + " " + hell.get("roman", "")).strip() if hell and hell.get("roman") else tr(lang, "AngelOS-тян", "AngelOS-chan")
        tail = " " + who + " "
        out = [edge + "╭─" + "\x1b[0m" + live + edge + "─" * (inner - 9) + "╮\x1b[0m"]
        out += [edge + "│\x1b[0m" + " " * inner + edge + "│\x1b[0m"]
        out += [edge + "│\x1b[0m  " + a + "  " + edge + "│\x1b[0m" for a in art]
        out += [edge + "│\x1b[0m" + " " * inner + edge + "│\x1b[0m"]
        out += [edge + "╰" + "─" * (inner - len(tail) - 2) + "\x1b[0m" + fg((hell or {}).get("title", title), True) + tail + "\x1b[0m" + edge + "──╯\x1b[0m"]
        moving = {"layers": [layer(rows, pal, 2, 3, 2, fx=motion("sigil" if sigil else "emblem", rows, colors, hell, emblem))],
                  # the dot of LIVE blinks
                  "texts": [{"line": 0, "col": 2, "every": 0.5, "on": live, "off": badge + "   LIVE " + "\x1b[0m"}]}
        return "\n".join(out) + "\n", inner + 2, len(out), moving
    if hell:
        sigil = SIGILS.get(hell.get("circle", ""), None)
        rows = sigil or emblem_rows
        pal = hell.get("palette") or emblem_pal
        k = 2 if style in ("angel", "compact", "window") else 1
        art, w = half_blocks(scaled(rows, k), pal)
        head = "⛧ %s %s ⛧" % (hell.get("circleWord", "Circle").upper(), hell.get("roman", "")) if hell.get("roman") else "⛧ AngelOS ⛧"
        name = str(hell.get("name", "")).upper()
        caps = [(fg(hell.get("keys", accent), True) + head + "\x1b[0m", len(head))]
        if hell.get("roman") and name:
            caps.append((fg(hell.get("title", title)) + name + "\x1b[0m", len(name)))
        text, W, H, x = logo_text(art, w, caps)
        return text, W, H, {"layers": [layer(rows, pal, 0, x, k, fx=motion("sigil" if sigil else "emblem", rows, colors, hell, emblem))], "texts": []}
    if style == "angel":
        data = json.loads((ROOT / "data" / "fastfetch" / "angel.json").read_text())
        art, w = half_blocks(data["rows"], data["palette"])
        word = "✧ AngelOS ✧"
        text, W, H, x = logo_text(art, w, [(fg(accent, True) + word + "\x1b[0m", len(word))])
        return text, W, H, {"layers": [layer(data["rows"], data["palette"], 0, x, fx=motion("heart", data["rows"], colors, hell))], "texts": []}
    # compact, window: the Start emblem at twice the size (one pixel was too small to see)
    art, w = half_blocks(scaled(emblem_rows, 2), emblem_pal)
    word = "AngelOS"
    text, W, H, x = logo_text(art, w, [(fg(accent, True) + word + "\x1b[0m", len(word))])
    return text, W, H, {"layers": [layer(emblem_rows, emblem_pal, 0, x, 2, fx=motion("emblem", emblem_rows, colors, hell, emblem))], "texts": []}


def modules(style, colors, hell):
    accent, title = colors.get("accent", "#ff6fb0"), colors.get("accent2", "#c9b6ff")
    gold, dim = colors.get("accent3", "#ffe066"), colors.get("dim", "#9c8fa8")
    labels = (hell or {}).get("labels") or {}
    lang = colors.get("lang") or (hell or {}).get("lang") or "ru"
    voice = "demon" if hell else "angel"

    def key(word, kind=None):
        # in hell: "cpu · жар"
        lab = labels.get(kind or word)
        return "%s · %s" % (word, lab) if lab else word

    if hell:
        accent, title, dim = hell.get("keys", accent), hell.get("title", title), hell.get("dim", dim)
        gold = (hell.get("palette") or {}).get("y", gold)
        pal = hell.get("palette") or {}
        row = hearts([pal.get(k) or accent for k in ("o", "x", "y", "r", "w")], "⛧")
    else:
        row = hearts([accent, title, gold, colors.get("pink", accent), colors.get("lilac", title)])
    circle = []
    if hell:
        what = "%s %s · %s" % (hell.get("circleWord", "Circle"), hell.get("roman", ""), hell.get("name", "")) if hell.get("roman") else hell.get("name", "")
        circle.append({"type": "custom", "format": "{#%s}⛧ %s{#}" % (sgr(accent, True), what)})
        if hell.get("where"):
            circle.append({"type": "custom", "format": "{#%s}%s{#}" % (sgr(dim), hell["where"])})

    def gear_rows(keyw, side=""):
        """a line per device, "клава   NuPhy Air60 HE  $120", looking like the keyed rows"""
        # (fastfetch prints the blank key " " as a space when keys have a width)
        fmt = side + "{#%s}{word:%d}{#}{name}  {#%s}{price}" % (sgr(accent, True), keyw - 1, sgr(gold, True))
        return [{"type": "command", "key": " ", "text": gear(fmt, nth=i, lang=lang)} for i in range(SLOTS)]

    if style == "mini":
        head = "{#%s}%s AngelOS{#} {#%s}·{#} {user-name}@{host-name}" % (sgr(accent, True), "⛧" if hell else "♡", sgr(dim))
        return [{"type": "title", "format": head}] + circle + [
            {"type": "os", "key": "os", "format": "{pretty-name}"},
            {"type": "uptime", "key": "up"},
            {"type": "cpu", "key": key("cpu"), "format": "{name}"},
            {"type": "gpu", "key": key("gpu"), "format": "{name}"},
            {"type": "memory", "key": key("ram"), "format": "{used} / {total}"},
            {"type": "packages", "key": "pkgs"},
            {"type": "command", "key": "gear", "text": gear("{#%s}{total}{#} · {count} %s" % (sgr(gold, True), tr(lang, "шт.", "pcs")), total=True, lang=lang)},
            {"type": "custom", "format": row},
        ]

    if style == "window":
        bar = "─" * 26
        name = str(colors.get("windowTitle") or (hell or {}).get("windowTitle") or "AngelOS.exe")
        top = "{#%s}╭─{#} {#%s}%s %s{#} {#%s}%s ─ □ ✕{#}" % (sgr(accent), sgr(title, True), "⛧" if hell else "♡", name, sgr(accent), bar)
        side = "│ "
        mods = [{"type": "custom", "format": top},
                {"type": "title", "format": "{#%s}│{#} {#%s}{user-name}{#}@{host-name}" % (sgr(accent), sgr(title, True))}]
        for c in circle:
            c = dict(c)
            c["format"] = "{#%s}│{#} " % sgr(accent) + c["format"]
            mods.append(c)
        rows = [("os", "os", {"format": "{pretty-name}"}), ("kernel", "kernel", {"format": "{release}"}),
                ("uptime", "uptime", {}), ("packages", "pkgs", {}),
                ("cpu", key("cpu"), {"format": "{name}"}), ("gpu", key("gpu"), {"format": "{name}"}),
                ("memory", key("ram"), {"format": "{used} / {total}"}),
                ("disk", "disk", {"folders": "/", "format": "{size-used} / {size-total}"})]
        for kind, k, extra in rows:
            mods.append({"type": kind, "key": side + k, **extra})
        keyw = max(len(side + k) for _, k, _ in rows) + 2
        mods += gear_rows(keyw - len(side), "{#%s}%s{#}" % (sgr(accent), side))
        mods.append({"type": "custom", "format": "{#%s}╰%s{#}  %s" % (sgr(accent), "─" * 20, row)})
        return mods

    if style == "angel":
        mods = ["title", "separator"] + circle + [
            {"type": "os", "key": "os"},
            {"type": "kernel", "key": "kernel", "format": "{release}"},
            {"type": "uptime", "key": "uptime"},
            {"type": "packages", "key": "packages"},
            {"type": "wm", "key": "wm"},
            "break",
            {"type": "cpu", "key": key("cpu")},
            {"type": "gpu", "key": key("gpu"), "format": "{name}"},
            {"type": "memory", "key": key("ram"), "format": "{used} / {total}"},
            {"type": "disk", "key": "disk", "folders": "/", "format": "{size-used} / {size-total}"},
            "break",
            # the gear worth showing off (scripts/gear.py); nothing printed = no line
            {"type": "command", "key": "keyboard", "text": GEAR + " --kind keyboard"},
            {"type": "command", "key": "mouse", "text": GEAR + " --kind mouse"},
            {"type": "command", "key": "mic", "text": GEAR + " --kind mic"},
            {"type": "command", "key": tr(lang, "итого", "total"),
             "text": gear("{#%s}~{total}{#} %s" % (sgr(gold, True), tr(lang, "на столе", "on the desk")), total=True, lang=lang)},
            "break",
            {"type": "custom", "format": row},
        ]
        return mods

    if style == "helper":
        # she talks: hello, the readings, the gear with its prices and her word on the total
        hello = tr(lang, "привет, ", "hi, ") if not hell else tr(lang, "ну здравствуй, ", "well hello, ")
        rest = tr(lang, "вот что у нас тут:", "here's what we've got:") if not hell else tr(lang, "посмотрим, что у тебя:", "let's see what you've got:")
        mods = ["break",
                {"type": "title", "format": "{#%s}◀ %s{user-name}! %s{#} {#%s}%s{#}" % (sgr(accent, True), hello, "⛧" if hell else "♡", sgr(dim), rest)},
                {"type": "custom", "format": "{#%s}%s{#}" % (sgr(dim), "┄" * 34)}] + circle + [
            {"type": "os", "key": "os", "format": "{pretty-name}"},
            {"type": "kernel", "key": "kernel", "format": "{release}"},
            {"type": "uptime", "key": "uptime"},
            {"type": "packages", "key": "pkgs"},
            {"type": "wm", "key": "wm"},
            {"type": "cpu", "key": key("cpu"), "format": "{name}"},
            {"type": "gpu", "key": key("gpu"), "format": "{name}"},
            {"type": "memory", "key": key("ram"), "format": "{used} / {total}"},
            {"type": "custom", "format": "{#%s}%s{#}" % (sgr(dim), "┄" * 34)}]
        keyw = max(len(m["key"]) for m in mods if isinstance(m, dict) and m.get("key")) + 2
        mods += gear_rows(keyw)
        mods.append({"type": "command", "key": " ",
                     "text": gear("{#%s}%s {total}{#}  {#%s}— {say}" % (sgr(gold, True), tr(lang, "итого", "total"), sgr(title)),
                                  total=True, zero=True, lang=lang, voice=voice)})
        mods += ["break", {"type": "custom", "format": row}]
        return mods

    if style == "stream":
        # the readings as the chat, the gear as superchats
        nick = [("cpu", "cpu_enjoyer", "#4fc3f7", {"format": "{name}"}),
                ("gpu", "rtx_tyan" if not hell else "gpu_burner", "#ba68c8", {"format": "{name}"}),
                ("memory", "ram_eater", "#81c784", {"format": "{used} / {total}"}),
                ("os", "linux_enjoyer", "#ffb74d", {"format": "{pretty-name}"}),
                ("uptime", "no_sleep_andy", "#f06292", {}),
                ("packages", "pkg_hoarder", "#4db6ac", {}),
                ("wm", "tiling_fan", "#9575cd", {"format": "{pretty-name}"})]
        head = "{#%s}{user-name}{#} {#%s}%s{#}" % (sgr(title, True), sgr(dim), tr(lang, "стримит с {host-name}", "streaming from {host-name}"))
        mods = [{"type": "title", "format": head}] + circle + [
            {"type": "custom", "format": "{#%s}── %s %s{#}" % (sgr(dim), tr(lang, "чат", "chat"), "─" * 28)}]
        for kind, k, colour, extra in nick:
            mods.append({"type": kind, "key": k, "keyColor": sgr(colour, True), **extra})
        mods.append({"type": "custom", "format": "{#%s}── %s %s{#}" % (sgr(dim), tr(lang, "суперчаты", "superchats"), "─" * 22)})
        mods += [{"type": "command", "key": " ", "text": gear("{tier} {price} {#} {name}", nth=i, lang=lang)} for i in range(SLOTS)]
        mods.append({"type": "command", "key": " ",
                     "text": gear("{#%s}%s %s: {total}{#}" % (sgr(gold, True), "⛧" if hell else "♡", tr(lang, "донатов на сетап", "donated to the setup")),
                                  total=True, zero=True, lang=lang)})
        return mods

    if style == "receipt":
        paper, ink, _ = paper_colours(hell)
        on = "{#48;2;%d;%d;%d;38;2;%d;%d;%d}" % (*rgb(paper), *rgb(ink))
        bold = "{#1;48;2;%d;%d;%d;38;2;%d;%d;%d}" % (*rgb(paper), *rgb(ink))
        W = PAPER - 2
        line = lambda ch: {"type": "custom", "format": on + ch * W}
        who = tr(lang, "грешник", "sinner") if hell else tr(lang, "кассир", "cashier")
        mods = [{"type": "title", "key": " ", "format": on + who + " {user-name}@{host-name}"},
                {"type": "datetime", "key": " ", "format": on + "{year}-{month-pretty}-{day-pretty} {hour-pretty}:{minute-pretty}"}]
        if hell and hell.get("roman"):
            mods.append({"type": "custom", "format": on + "%s %s · %s" % (hell.get("circleWord", "Circle"), hell["roman"], str(hell.get("name", ""))[:W - 10])})
        mods += [line("-"),
                 {"type": "cpu", "key": " ", "format": on + "CPU  {name:%d}" % (W - 5)},
                 {"type": "gpu", "key": " ", "format": on + "GPU  {name:%d}" % (W - 5)},
                 {"type": "memory", "key": " ", "format": on + "RAM  {used} / {total}"},
                 {"type": "os", "key": " ", "format": on + "OS   {pretty-name:%d}" % (W - 5)},
                 {"type": "uptime", "key": " ", "format": on + "UP   {?days}{days}d {?}{hours}h {minutes}m"},
                 {"type": "packages", "key": " ", "format": on + "PKG  {all}"},
                 line("-")]
        mods += [{"type": "command", "key": " ", "text": gear(on + "{name} {fill} " + bold + "{price}", nth=i, width=W, lang=lang)} for i in range(SLOTS)]
        mods += [line("="),
                 {"type": "command", "key": " ", "text": gear(bold + tr(lang, "ИТОГО", "TOTAL") + " {fill} {total}", total=True, zero=True, width=W, lang=lang)}]
        if hell:
            mods.append({"type": "custom", "format": on + "+ " + tr(lang, "душа", "soul") + " " + "." * (W - 7 - len(tr(lang, "душа", "soul"))) + " ×1"})
        mods.append({"type": "custom", "format": on})
        if hell:
            mods.append({"type": "custom", "format": on + tr(lang, "подпись: ________ (кровью)", "signed: ________ (in blood)")})
        else:
            mods.append({"type": "custom", "format": on + centred("▌▍█▏▌▋▍▏█▌▎▍▋▌▏█▍▌▎▋▌█▍▏▋▌", W)})
            mods.append({"type": "custom", "format": on + centred(tr(lang, "СПАСИБО ЗА ПОКУПКУ ♡", "THANK YOU FOR SHOPPING ♡"), W)})
        return mods

    # compact
    mods = [{"type": "title", "format": "{#%s}{user-name}{#}@{#%s}{host-name}{#}" % (sgr(title, True), sgr(title, True))}] + circle + [
        {"type": "os", "key": "os", "format": "{pretty-name}"},
        {"type": "kernel", "key": "kernel", "format": "{release}"},
        {"type": "uptime", "key": "uptime"},
        {"type": "packages", "key": "pkgs"},
        {"type": "wm", "key": "wm"},
        {"type": "terminal", "key": "term"},
        {"type": "cpu", "key": key("cpu"), "format": "{name}"},
        {"type": "gpu", "key": key("gpu"), "format": "{name}"},
        {"type": "memory", "key": key("ram"), "format": "{used} / {total}"}]
    keyw = max(len(m["key"]) for m in mods if m.get("key")) + 2
    return mods + gear_rows(keyw) + [{"type": "custom", "format": row}]


def config(style, colors, logo, hell=None):
    """the config as a dict; `logo` = (path, width, height) or None"""
    accent, title = colors.get("accent", "#ff6fb0"), colors.get("accent2", "#c9b6ff")
    dim = colors.get("dim", "#9c8fa8")
    if hell:
        accent, title, dim = hell.get("keys", accent), hell.get("title", title), hell.get("dim", dim)
    mods = modules(style, colors, hell)
    # the readings in a column: the longest key and two spaces (fastfetch pads the key to
    # the width instead of printing the separator)
    keys = [len(m["key"]) for m in mods if isinstance(m, dict) and m.get("key", " ") != " "]
    keyw = max(keys) + 2 if keys and style not in ("angel", "stream") else 0
    cfg = {"$schema": "https://github.com/fastfetch-cli/fastfetch/raw/master/doc/json_schema.json"}
    if logo:
        path, w, h = logo
        pad = {"top": 1 if style not in ("window", "receipt", "stream") else 0, "left": 1, "right": 3}
        if style == "receipt":
            pad["right"] = 0        # the text goes onto the paper (the logo puts the cursor there)
        cfg["logo"] = {"type": "file-raw", "source": str(path), "width": w, "height": h, "padding": pad}
    else:
        cfg["logo"] = {"type": "none"}
    sep = {"angel": " ⛧ " if hell else " ♡ ", "stream": ": "}.get(style, "  ")
    disp = {"separator": sep, "color": {"keys": sgr(accent), "title": sgr(title), "separator": sgr(dim)}}
    if keyw:
        disp["key"] = {"width": keyw}
    cfg["display"] = disp
    cfg["modules"] = mods
    return cfg


def render_all(style, colors, emblem_rows, emblem_pal, logo_path, hell=None, emblem="", seconds=0):
    """(config text, logo text or None, the animation's spec or None) for this style. The spec
    (scripts/fastfetch_anim.py) places what moves in fastfetch's output: the logo's padding
    added to its place in the logo."""
    if style == "receipt":
        lang = colors.get("lang") or (hell or {}).get("lang") or "ru"
        text_rows = len(modules(style, colors, hell))
        text, w, h, top, moving = receipt_picture(emblem_rows, (hell or {}).get("palette") or emblem_pal, colors, hell, lang, text_rows, emblem)
        cfg = config(style, colors, (logo_path, w, h), hell)
        cfg["modules"] = ["break"] * top + cfg["modules"]
        pic = (text, w, h, moving)
    else:
        pic = picture(style, emblem_rows, emblem_pal, colors, hell, emblem)
        cfg = config(style, colors, (logo_path, pic[1], pic[2]) if pic else None, hell)
    head = "%s %s\n// Written by angelOS (Settings → System → fastfetch). Pick \"own\" there and this file\n// is yours again (the one you had first is config.before-angelos.jsonc).\n" % (MARK, style)
    spec = None
    if pic and seconds > 0:
        pad = cfg["logo"].get("padding", {})
        top, left = pad.get("top", 0), pad.get("left", 0)
        moving = pic[3]
        for item in moving["layers"] + moving["texts"]:
            item["line"] += top
            item["col"] += left
        # the receipt comes out of the till line by line
        spec = {"v": 1, "style": style, "seconds": seconds, "print": style == "receipt", **moving}
    return head + json.dumps(cfg, ensure_ascii=False, indent=2) + "\n", pic[0] if pic else None, spec


def render(style, colors, emblem_rows, emblem_pal, logo_path, hell=None):
    """(config text, logo text or None) for this style"""
    return render_all(style, colors, emblem_rows, emblem_pal, logo_path, hell)[:2]


def ours(path):
    try:
        text = path.read_text(errors="replace")
    except OSError:
        return True             # nothing there: ours to write
    return text.startswith(MARK) or SHIPPED in text


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_text(errors="replace") == text:
        return False
    tmp = path.with_name("." + path.name + ".tmp")
    tmp.write_text(text)
    tmp.replace(path)
    return True


# ---- the preview: a tiny terminal ----

PAL16 = ["#000000", "#cd3131", "#0dbc79", "#e5e510", "#2472c8", "#bc3fbc", "#11a8cd", "#e5e5e5",
         "#666666", "#f14c4c", "#23d18b", "#f5f543", "#3b8eea", "#d670d6", "#29b8db", "#ffffff"]
CSI = re.compile(r"\x1b\[([?0-9;]*)([A-Za-z])")


def terminal(data):
    """what a terminal shows for `data` (SGR colours, cursor moves): rows of runs [text, fg, bg, bold]"""
    cells, r, c, fgc, bgc, bold, i, saved = {}, 0, 0, None, None, False, 0, None
    while i < len(data):
        ch = data[i]
        if ch == "\x1b":
            m = CSI.match(data, i)
            if not m:
                # ESC 7 / ESC 8: save / restore the cursor (scripts/fastfetch_anim.py)
                if data[i + 1:i + 2] == "7":
                    saved = (r, c)
                elif data[i + 1:i + 2] == "8" and saved:
                    r, c = saved
                i += 2 if data[i + 1:i + 2] in ("7", "8") else 1
                continue
            i = m.end()
            args, cmd = m.group(1).lstrip("?"), m.group(2)
            nums = [int(x) if x.isdigit() else 0 for x in args.split(";")] if args else []
            k = nums[0] if nums and nums[0] else 1
            if cmd == "m":
                nums = nums or [0]
                j = 0
                while j < len(nums):
                    v = nums[j]
                    if v == 0:
                        fgc, bgc, bold = None, None, False
                    elif v == 1:
                        bold = True
                    elif v == 22:
                        bold = False
                    elif v == 39:
                        fgc = None
                    elif v == 49:
                        bgc = None
                    elif 30 <= v <= 37:
                        fgc = PAL16[v - 30 + (8 if bold else 0)]
                    elif 90 <= v <= 97:
                        fgc = PAL16[v - 82]
                    elif 40 <= v <= 47:
                        bgc = PAL16[v - 40]
                    elif 100 <= v <= 107:
                        bgc = PAL16[v - 92]
                    elif v in (38, 48) and j + 1 < len(nums):
                        col = None
                        if nums[j + 1] == 2 and j + 4 < len(nums):
                            col = "#%02x%02x%02x" % tuple(nums[j + 2:j + 5])
                            j += 4
                        elif nums[j + 1] == 5 and j + 2 < len(nums):
                            col = PAL16[nums[j + 2]] if nums[j + 2] < 16 else "#8a8a8a"
                            j += 2
                        if v == 38:
                            fgc = col
                        else:
                            bgc = col
                    j += 1
            elif cmd == "A":
                r = max(0, r - k)
            elif cmd == "B":
                r += k
            elif cmd == "C":
                c += k
            elif cmd == "D":
                c = max(0, c - k)
            elif cmd == "G":
                c = k - 1
            continue
        i += 1
        if ch == "\n":
            r, c = r + 1, 0
        elif ch == "\r":
            c = 0
        elif ord(ch) >= 32:
            cells[(r, c)] = (ch, fgc, bgc, bold)
            c += 1
    rows = max((k[0] for k in cells), default=-1) + 1
    cols = max((k[1] for k in cells), default=-1) + 1
    lines = []
    for y in range(rows):
        runs = []
        for x in range(cols):
            ch, f, b, bo = cells.get((y, x), (" ", None, None, False))
            if runs and runs[-1][1:] == [f, b, bo]:
                runs[-1][0] += ch
            else:
                runs.append([ch, f, b, bo])
        while runs and runs[-1][0].strip() == "" and runs[-1][2] is None:
            runs.pop()
        lines.append(runs)
    while lines and not lines[-1]:
        lines.pop()
    return {"cols": cols, "lines": lines}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["apply", "preview", "restore", "styles"])
    ap.add_argument("--style", choices=STYLES, default="compact")
    ap.add_argument("--emblem-rows", default="[]")
    ap.add_argument("--emblem-palette", default="{}")
    ap.add_argument("--colors", default="{}")
    ap.add_argument("--hell", default="")
    ap.add_argument("--emblem", default="", help="the Start emblem's name (its wings flap, the CD spins…)")
    ap.add_argument("--anim", type=float, default=0, help="seconds the picture moves in a new terminal (0: still)")
    a = ap.parse_args()
    if a.cmd == "styles":
        print(json.dumps(list(STYLES)))
        return 0
    if a.cmd == "restore":
        if CONFIG.exists() and not ours(CONFIG):
            print("config.jsonc is your own: left alone")
            return 0
        if ANIM.exists():
            ANIM.unlink()
        if BEFORE.exists():
            write(CONFIG, BEFORE.read_text(errors="replace"))
            print("restored")
        return 0
    rows, pal, colors = json.loads(a.emblem_rows), json.loads(a.emblem_palette), json.loads(a.colors)
    if not rows:
        rows = SIGILS["limbo"]
    hell = json.loads(a.hell) if a.hell else None
    if a.cmd == "preview":
        with tempfile.TemporaryDirectory() as tmp:
            logo = Path(tmp) / "logo.txt"
            # the preview moves too (Settings, the setup wizard): 3 s of frames
            conf_text, logo_text_, spec = render_all(a.style, colors, rows, pal, logo, hell, a.emblem, 3)
            if logo_text_:
                logo.write_text(logo_text_)
            conf = Path(tmp) / "config.jsonc"
            conf.write_text(conf_text)
            if not shutil.which("fastfetch"):
                print(json.dumps({"error": "fastfetch is not installed"}))
                return 1
            out = subprocess.run(["fastfetch", "--config", str(conf), "--pipe", "false"], capture_output=True, text=True,
                                 env={**os.environ, "COLUMNS": "120"}, timeout=20).stdout
            screen = terminal(out)
            if spec:
                import fastfetch_anim
                screen["frames"] = fastfetch_anim.patches(spec)
            print(json.dumps(screen, ensure_ascii=False))
        return 0
    # apply
    if not FF_DIR.is_dir():
        print("no ~/.config/fastfetch: fastfetch is not set up")
        return 0
    if CONFIG.exists() and not ours(CONFIG):
        print("config.jsonc is your own: left alone")
        return 0
    if CONFIG.exists() and not CONFIG.read_text(errors="replace").startswith(MARK) and not BEFORE.exists():
        shutil.copyfile(CONFIG, BEFORE)
    conf_text, logo_text_, spec = render_all(a.style, colors, rows, pal, LOGO, hell, a.emblem, a.anim)
    if logo_text_:
        write(LOGO, logo_text_)
    if spec:
        write(ANIM, json.dumps(spec, ensure_ascii=False) + "\n")
    elif ANIM.exists():
        ANIM.unlink()
    # fish greets with fastfetch (CachyOS's config): the hook moves the picture
    if spec and FISH.parent.parent.is_dir():
        write(FISH, FISH_HOOK.replace("{anim}", shlex.quote(str(HERE / "fastfetch_anim.py"))))
    print("written" if write(CONFIG, conf_text) else "unchanged")
    return 0


if __name__ == "__main__":
    sys.exit(main())
