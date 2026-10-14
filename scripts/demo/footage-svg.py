#!/usr/bin/env python3
"""The README's found footage: tapes from a smoke-damaged tower, a camcorder whose clock was
never set (every timecode is December 2002). CSS-animated SVGs for GitHub's <img>: no JS,
nothing external, the fonts embedded as subset WOFF2, every effect a hard-edged pixel one
(no blur, no glow), `prefers-reduced-motion` stops it all on a still frame.

  docs/readme/footage/header[.ru].svg          the VHS playback screen, 1280×560
  docs/readme/footage/tape-NN[.ru].svg         a title card per section (01–12), 1280×200
  docs/readme/footage/tape-keys[.ru].svg       the appendix card, 1280×200
  docs/readme/footage/divider.svg              a strip of tracking noise, 1280×28
  docs/readme/footage/end[.ru].svg             NO SIGNAL, end of tape, 1280×360
  docs/readme/footage/stamp-evidence[.ru].svg  a red rubber stamp, 360×120
  docs/readme/footage/cobweb-tl.svg, -tr.svg   corner webs for the text, transparent, 220×220
  docs/readme/footage/spider.svg               a pixel spider on its thread, transparent, 90×300
  docs/readme/footage/cobweb-divider.svg       a sagging strand with a dead fly, transparent, 1280×40

The cards gather dust: each tape's corner web is denser than the one before.

Fonts: Cozette Vector Bold (MIT) for the OSD, Pixeloid Sans Bold (OFL) for the title and the
stamp, Caveat (OFL, pinned at wght 700) for the marker on the cassette labels.

  scripts/demo/footage-svg.py [--out docs/readme/footage]
"""
import argparse
import base64
import functools
import io
import math
import random
import re
from html import escape, unescape
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = Path(__file__).resolve().parents[2]
FONTS = {
    "osd": ROOT / ".local/share/fonts/pixel/CozetteVectorBold.ttf",              # 13 px grid
    "title": ROOT / ".local/share/fonts/pixel/PixeloidSans-Bold.ttf",            # 9 px grid
    "hand": ROOT / ".config/quickshell/angelos/data/fonts/Caveat-Variable.ttf",  # wght 700
}
FALLBACK = {"osd": "monospace", "title": "monospace", "hand": "cursive,monospace"}
BG, PINK, CYAN, PURPLE, LPINK, GREEN = "#241432", "#ff5cad", "#4fe3ff", "#b36bff", "#ffb3d9", "#57e3a2"
WHITE, BLACK, BLUE, BLUE_SH, RED = "#f6f2ff", "#000", "#0033cc", "#00175c", "#ff2638"
PAPER, INK, MARKER = "#efe7d2", "#22163a", "#d8327e"
WEB, WEB_DARK, DUST = "#a39abb", "#5b5566", "#b9aecb"   # cobweb on the CRT; WEB_DARK outlines
GREY = "#8a8494"   # the transparent pieces: reads on white and on #0d1117
W = 1280

TAPES = [  # n, date, time, en, ru
    ("01", "20.12.2002", "23:41", "the note", "записка"),
    ("02", "21.12.2002", "14:05", "two faces", "два лица"),
    ("03", "22.12.2002", "02:17", "the wallpaper breathes", "обои дышат"),
    ("04", "22.12.2002", "19:30", "i right-clicked", "я нажала правой"),
    ("05", "23.12.2002", "11:52", "everything can be changed", "всё можно поменять"),
    ("06", "24.12.2002", "21:08", "windows on a strip", "окна на ленте"),
    ("07", "25.12.2002", "16:44", "goldengate.app", "goldengate.app"),
    ("08", "26.12.2002", "03:33", "someone in the corner", "кто-то в углу"),
    ("09", "27.12.2002", "20:20", "other people's things", "чужие вещи"),
    ("10", "28.12.2002", "09:15", "it looks after itself", "оно следит за собой"),
    ("11", "30.12.2002", "22:47", "what it runs on", "на чём оно живёт"),
    ("12", "31.12.2002", "23:58", "save yourself", "сохрани себя"),
    ("keys", "--.--.----", "--:--", "taped under the keyboard", "приклеено под клавиатурой"),
]


# ---- fonts -------------------------------------------------------------------------------

@functools.cache
def font_bytes(name):
    f = TTFont(FONTS[name], recalcTimestamp=False)
    if "fvar" in f:
        f = instancer.instantiateVariableFont(f, {"wght": 700})
        f.recalcTimestamp = False
    buf = io.BytesIO()
    f.save(buf)
    return buf.getvalue()


@functools.cache
def metrics(name):
    f = TTFont(io.BytesIO(font_bytes(name)))
    return f.getBestCmap(), f["hmtx"], f["head"].unitsPerEm


def width(name, text, size):
    cmap, hmtx, upm = metrics(name)
    return sum(hmtx[cmap.get(ord(c), ".notdef")][0] for c in text) * size / upm


@functools.cache
def woff2(name, chars):
    f = TTFont(io.BytesIO(font_bytes(name)), recalcTimestamp=False)
    o = subset.Options()
    o.flavor, o.hinting, o.desubroutinize, o.notdef_outline = "woff2", False, True, False
    o.layout_features, o.name_IDs = ["kern"], [0, 1, 2, 13, 14]   # keeps the copyright + license
    o.drop_tables += ["FFTM"]
    s = subset.Subsetter(o)
    s.populate(text=chars)
    s.subset(f)
    buf = io.BytesIO()
    subset.save_font(f, buf, o)
    return base64.b64encode(buf.getvalue()).decode()


# ---- svg pieces --------------------------------------------------------------------------

def n(v):
    return f"{v:.2f}".rstrip("0").rstrip(".")


def T(cls, x, y, s, size, fill, extra=""):
    return f'<text class="{cls}" x="{n(x)}" y="{n(y)}" font-size="{n(size)}" fill="{fill}"{extra}>{escape(s)}</text>'


def cw(size):
    return width("osd", "0", size)


def osd(x, y, s, size=39, fill=WHITE, sh=BLACK, split=0):
    """VHS on-screen text: a hard black drop shadow one font pixel down-right; `split` adds
    pink and cyan copies that many px to either side (a hard RGB split)"""
    k = size / 13
    out = [T("osd", x + k, y + k, s, size, sh)]
    if split:
        out += [f'<g class="spl">{T("osd", x - split, y, s, size, PINK)}</g>',
                f'<g class="spr">{T("osd", x + split, y, s, size, CYAN)}</g>']
    return "".join(out) + T("osd", x, y, s, size, fill)


class Svg:
    def __init__(self, w, h, title, desc=None):
        self.w, self.h, self.title, self.desc = w, h, title, desc or title
        self.css, self.defs, self.body, self.ids = [], [], [], 0

    def uid(self, p):
        self.ids += 1
        return f"{p}{self.ids}"

    def anim(self, prop, stops, period, cls=None):
        """a hard-cut animation: each (pct, value) holds until the next stop; loops on stop 0"""
        cls = cls or self.uid("a")
        frames = "".join(f"{n(p)}%{{{prop}:{v}}}" for p, v in stops) + f"100%{{{prop}:{stops[0][1]}}}"
        self.css.append(f".{cls}{{animation:{cls} {n(period)}s steps(1,end) infinite}}@keyframes {cls}{{{frames}}}")
        return cls

    def ticker(self, x, y, size, segs, t0=0, still=None, fill=WHITE, split=0):
        """monospace OSD text whose (values, step) segments are digit strips rolled by a
        steps() animation: index at time t = (t0 + t) // step; `still` is the frame shown
        without animation"""
        k, c, still = size / 13, cw(size), t0 if still is None else still
        out, cx = [], x
        for seg in segs:
            if isinstance(seg, str):
                out.append(osd(cx, y, seg, size, fill, split=split))
                cx += c * len(seg)
                continue
            values, step = seg
            cnt, period, cid = len(values), len(values) * step, self.uid("s")
            self.defs.append(f'<clipPath id="{cid}c"><rect x="{n(cx - k - split)}" y="{n(y - 9 * k)}" '
                             f'width="{n(c * len(values[0]) + 3 * k + 2 * split)}" height="{n(11 * k)}"/></clipPath>')

            def strip(dx, dy, color):
                spans = "".join(f'<tspan x="{n(cx + dx)}" y="{n(y + dy + i * size)}">{v}</tspan>'
                                for i, v in enumerate(values))
                return f'<text class="osd" font-size="{n(size)}" fill="{color}">{spans}</text>'
            layers = strip(k, k, BLACK)
            if split:
                layers += f'<g class="spl">{strip(-split, 0, PINK)}</g><g class="spr">{strip(split, 0, CYAN)}</g>'
            out.append(f'<g clip-path="url(#{cid}c)"><g class="{cid}" transform="translate(0,'
                       f'{n(-(still // step % cnt) * size)})">{layers}{strip(0, 0, fill)}</g></g>')
            self.css.append(f".{cid}{{animation:{cid} {period}s steps({cnt}) infinite;animation-delay:-{t0 % period}s}}"
                            f"@keyframes {cid}{{from{{transform:translate(0,0)}}to{{transform:translate(0,-{n(cnt * size)}px)}}}}")
            cx += c * len(values[0])
        return "".join(out)

    def render(self):
        body = "".join(self.body)
        faces = []
        for name in FONTS:
            chars = "".join(unescape(re.sub(r"<[^>]+>", "", m)) for m in
                            re.findall(rf'<text class="{name}"[^>]*>(.*?)</text>', body))
            if chars:
                faces.append(f'@font-face{{font-family:"fx-{name}";src:url(data:font/woff2;base64,'
                             f'{woff2(name, "".join(sorted(set(chars))))}) format("woff2")}}'
                             f'.{name}{{font-family:"fx-{name}",{FALLBACK[name]}}}')
        css = ("".join(faces) + "".join(self.css) +
               "@media (prefers-reduced-motion:reduce){*{animation:none!important}}")
        t = escape(self.title)
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" '
                f'viewBox="0 0 {self.w} {self.h}" role="img" aria-label="{escape(self.desc)}" xml:space="preserve">'
                f"<title>{t}</title><defs><style>{css}</style>{''.join(self.defs)}</defs>{body}</svg>\n")


def dashes(rnd, x0, y0, w, h, count, maxw=90, rows=(1, 1, 2, 2, 3)):
    """random short horizontal dashes as one path: tracking noise"""
    d = []
    for _ in range(count):
        x, y, dw = x0 + rnd.randrange(w), y0 + rnd.randrange(h), rnd.randint(3, maxw)
        d.append(f"M{x} {y}h{dw}v{rnd.choice(rows)}h-{dw}z")
    return "".join(d)


def specks(rnd, x0, y0, w, h, count, sizes=(2, 2, 3, 4)):
    d = []
    for _ in range(count):
        s = rnd.choice(sizes)
        d.append(f"M{x0 + rnd.randrange(w)} {y0 + rnd.randrange(h)}h{s}v{s}h-{s}z")
    return "".join(d)


def scanlines(svg, w, h, alpha=".3"):
    svg.defs.append(f'<pattern id="sl" width="8" height="4" patternUnits="userSpaceOnUse">'
                    f'<rect y="2" width="8" height="2" fill="#000" opacity="{alpha}"/></pattern>')
    return f'<rect width="{w}" height="{h}" fill="url(#sl)"/>'


def edges(w, h, insets=(6, 16, 34), alpha=".22"):
    """a CRT's darker rim in hard steps"""
    return "".join(f'<path d="M0 0H{w}V{h}H0ZM{i} {i}V{h - i}H{w - i}V{i}Z" fill="#000" fill-rule="evenodd" '
                   f'opacity="{alpha}"/>' for i in insets)


def head_switch(rnd, w, h):
    """the head-switching smear along the bottom lines of a VHS frame"""
    return (f'<rect y="{h - 7}" width="{w}" height="7" fill="#000" opacity=".55"/>'
            f'<path d="{dashes(rnd, -20, h - 7, w, 6, 70, 140, (1, 2))}" fill="#fff" opacity=".45"/>')


def band(svg, rnd, w, h, still_y, period, travel, active=1.0, strong=False):
    """a tracking-noise band crawling down in 4 px steps; `active` = share of the loop it is on screen"""
    bh = 44 if strong else 30
    jit = svg.anim("transform", [(0, "translate(0,0)"), (25, "translate(-37px,1px)"),
                                 (50, "translate(23px,0)"), (75, "translate(-11px,-1px)")], 0.32)
    start, end = -bh - 4, travel
    stepn = (end - start) // 4
    cls = svg.uid("b")
    svg.css.append(f".{cls}{{animation:{cls} {n(period)}s linear infinite}}@keyframes {cls}{{"
                   f"0%{{transform:translate(0,{start}px);animation-timing-function:steps({stepn},end)}}"
                   f"{n(active * 100)}%{{transform:translate(0,{end}px)}}100%{{transform:translate(0,{end}px)}}}}")
    return (f'<g class="{cls}" transform="translate(0,{still_y})"><g class="{jit}">'
            f'<rect x="-60" width="{w + 120}" height="{bh}" fill="#fff" opacity=".05"/>'
            f'<path d="{dashes(rnd, -60, 0, w + 120, bh, 140 if strong else 80, 120)}" fill="#fff" opacity=".6"/>'
            f'<path d="{dashes(rnd, -60, 0, w + 120, bh, 50, 160)}" fill="#000" opacity=".5"/>'
            f'<rect x="-60" y="{bh - 2}" width="{w + 120}" height="2" fill="#fff" opacity=".22"/></g></g>')


def flicker(svg, w, h, period, stops):
    cls = svg.anim("opacity", stops, period)
    return f'<rect class="{cls}" width="{w}" height="{h}" fill="#fff" opacity="0"/>'


# ---- cobwebs ----------------------------------------------------------------------------

def strands(rnd, anchor, fan, r, d):
    """one web: spokes fanning from `anchor` (degrees, 0 = +x, 90 = +y; y points down) and
    cross-threads sagging toward it; density d 0..1 → more spokes, more rings, fewer gaps"""
    ax, ay = anchor
    nsp = 3 + round(d * 5)
    spokes = [(math.radians(fan[0] + (fan[1] - fan[0]) * (i + rnd.uniform(.25, .75)) / nsp),
               r * rnd.uniform(.72, 1.0)) for i in range(nsp)]
    at = lambda a, ln, f: (ax + f * ln * math.cos(a), ay + f * ln * math.sin(a))
    lines = [[(ax, ay), at(a, ln, 1)] for a, ln in spokes]
    rings = 1 + round(d * 6)
    for k in range(rings):
        f = (k + 1) / (rings + 1) * rnd.uniform(.9, 1.08)
        for (a, la), (b, lb) in zip(spokes, spokes[1:]):
            if rnd.random() < .45 * (1 - d) + .08:      # a broken thread
                continue
            p, q = at(a, la, f), at(b, lb, f)
            lines.append([p, (ax + ((p[0] + q[0]) / 2 - ax) * .92, ay + ((p[1] + q[1]) / 2 - ay) * .92), q])
    return lines


def cobweb(svg, rnd, parts, cell=2, color=WEB, outline=None, mirror=None, dust=0, glint=True):
    """webs (anchor, fan, r, d) as hard `cell`-px strokes snapped to the cell grid (crispEdges);
    `mirror` = canvas width to flip it into the right corner; a glint pixel runs out along the
    longest spoke every 8 s"""
    snap = lambda v: math.floor(v / cell) * cell + cell / 2
    lines = [ln for part in parts for ln in strands(rnd, *part)]
    d = "".join("M" + "L".join(f"{n(snap(x))} {n(snap(y))}" for x, y in ln) for ln in lines)
    stroke = (f'fill="none" stroke-linejoin="bevel" stroke-linecap="square" shape-rendering="crispEdges"')
    out = []
    if outline:
        out.append(f'<path d="{d}" stroke="{outline}" stroke-width="{cell * 2}" {stroke}/>')
    out.append(f'<path d="{d}" stroke="{color}" stroke-width="{cell}" {stroke}/>')
    knots = [ln[1] for ln in lines if len(ln) == 3]
    if dust and knots:
        specks_d = "".join(f"M{n(snap(x) - cell / 2)} {n(snap(y) - cell / 2)}h{s}v{s}h-{s}z"
                           for x, y in rnd.sample(knots, min(dust, len(knots)))
                           for s in [cell * rnd.choice((1, 2, 2))])
        out.append(f'<path d="{specks_d}" fill="{outline or DUST}" shape-rendering="crispEdges"/>')
    if glint:
        (x0, y0), (x1, y1) = max(lines[:3 + round(parts[0][3] * 5)],
                                 key=lambda ln: math.dist(*ln))
        x0, y0, x1, y1 = (snap(v) - cell / 2 for v in (x0, y0, x1, y1))
        steps = max(1, round(max(abs(x1 - x0), abs(y1 - y0)) / cell))
        on, run = svg.anim("opacity", [(0, "1"), (18, "0")], 8), svg.uid("g")
        svg.css.append(f".{run}{{animation:{run} 8s linear infinite}}@keyframes {run}{{"
                       f"0%{{transform:translate({n(x0)}px,{n(y0)}px);animation-timing-function:steps({steps},end)}}"
                       f"18%{{transform:translate({n(x1)}px,{n(y1)}px)}}100%{{transform:translate({n(x1)}px,{n(y1)}px)}}}}")
        out.append(f'<g class="{on}" opacity="0"><rect class="{run}" width="{cell}" height="{cell}" fill="#f4efff" '
                   f'shape-rendering="crispEdges"/></g>')
    flip = f' transform="translate({mirror},0) scale(-1,1)"' if mirror else ""
    return f'<g{flip}>{"".join(out)}</g>'


def pixel_art(rows, colors, x, y, k):
    """rows of chars → one crisp path per colour, each art pixel k×k"""
    out = []
    for ch, color in colors.items():
        d = "".join(f"M{x + i * k} {y + j * k}h{k}v{k}h-{k}z" for j, row in enumerate(rows)
                    for i, c in enumerate(row) if c == ch)
        if d:
            out.append(f'<path d="{d}" fill="{color}"/>')
    return f'<g shape-rendering="crispEdges">{"".join(out)}</g>'


def outlined(rows, body="b"):
    """add an 'o' outline pixel around the `body` cells (4-neighbours that are empty)"""
    g = [list("." + r + ".") for r in ["." * len(rows[0])] + rows + ["." * len(rows[0])]]
    for j in range(len(g)):
        for i in range(len(g[0])):
            if g[j][i] == "." and any(0 <= j + dj < len(g) and 0 <= i + di < len(g[0]) and g[j + dj][i + di] in body
                                      for dj, di in ((0, 1), (1, 0), (0, -1), (-1, 0))):
                g[j][i] = "o"
    return ["".join(r) for r in g]


# ---- the pieces --------------------------------------------------------------------------

def header(lang):
    rnd = random.Random(f"header-{lang}")
    h = 560
    sub = {"en": "RECOVERED MEDIA · 12 TAPES · CASE #0031-12",
           "ru": "НАЙДЕННЫЕ ЗАПИСИ · 12 КАССЕТ · ДЕЛО №0031-12"}[lang]
    desc = {"en": "angelOS. Recovered media, 12 tapes, case #0031-12. A VHS playback screen, 31.12.2002.",
            "ru": "angelOS. Найденные записи, 12 кассет, дело №0031-12. Воспроизведение с VHS, 31.12.2002."}[lang]
    s = Svg(W, h, "angelOS — recovered media" if lang == "en" else "angelOS — найденные записи", desc)
    b = s.body
    b.append(f'<rect width="{W}" height="{h}" fill="{BG}"/>')
    jit = s.anim("transform", [(0, "translate(0,0)"), (40, "translate(0,4px)"), (40.8, "translate(-3px,-2px)"),
                               (41.6, "translate(0,0)"), (83, "translate(6px,0)"), (83.6, "translate(0,0)")], 7)
    b.append(f'<g class="{jit}">{edges(W, h)}')
    # the camcorder's burnt-in REC, date and time (they ride the picture, so they jitter with it)
    rec = s.anim("opacity", [(0, "1"), (50, "0")], 1.2)
    b.append(f'<g class="{rec}">{osd(1224 - 5 * cw(39), 84, "●", 39, RED)}</g>')
    b.append(osd(1224 - 3 * cw(39), 84, "REC", 39))
    b.append(osd(1224 - 10 * cw(39), 452, "31.12.2002", 39))
    # 23:56:47 at load; the minute rolls 50–59, the seconds 00–59
    b.append(s.ticker(1224 - 8 * cw(39), 500, 39,
                      ["23:5", ([str(i) for i in range(10)], 60), ":", ([f"{i:02}" for i in range(60)], 1)],
                      t0=6 * 60 + 47))
    # the title: a hard RGB split that jumps; two slices tear sideways during the jump
    tx, ty, ts = 640, 300, 144
    tp = s.anim("transform", [(0, "translate(0,0)"), (60, "translate(-22px,4px)"), (61.6, "translate(14px,-2px)"),
                              (63.2, "translate(0,0)"), (88, "translate(-10px,0)"), (89, "translate(0,0)")], 5)
    tc = s.anim("transform", [(0, "translate(0,0)"), (60, "translate(18px,-3px)"), (61.6, "translate(-16px,2px)"),
                              (63.2, "translate(0,0)"), (88, "translate(8px,0)"), (89, "translate(0,0)")], 5)
    tm = s.anim("transform", [(0, "translate(0,0)"), (60, "translate(6px,0)"), (61.6, "translate(-4px,0)"),
                              (63.2, "translate(0,0)")], 5)
    mid = ' text-anchor="middle"'
    b.append(f'<g class="{tp}">{T("title", tx - 6, ty, "angelOS", ts, PINK, mid)}</g>'
             f'<g class="{tc}">{T("title", tx + 6, ty, "angelOS", ts, CYAN, mid)}</g>'
             f'<g class="{tm}">{T("title", tx, ty, "angelOS", ts, WHITE, mid)}</g>')
    for y0, hh, dx, stops in ((214, 26, 44, [(0, "0"), (60, "1"), (61.6, "0"), (88, "1"), (89, "0")]),
                              (262, 18, -34, [(0, "0"), (61.6, "1"), (63.2, "0")])):
        cid, cls = s.uid("c"), s.anim("opacity", stops, 5)
        s.defs.append(f'<clipPath id="{cid}"><rect x="0" y="{y0}" width="{W}" height="{hh}"/></clipPath>')
        b.append(f'<g clip-path="url(#{cid})"><g class="{cls}" opacity="0"><rect y="{y0}" width="{W}" height="{hh}" '
                 f'fill="{BG}"/>{T("title", tx + dx - 12, ty, "angelOS", ts, PINK, mid)}'
                 f'{T("title", tx + dx, ty, "angelOS", ts, WHITE, mid)}</g></g>')
    sw = cw(26) * len(sub)
    b.append(osd(640 - sw / 2, 372, sub, 26, LPINK))
    b.append(f'{head_switch(rnd, W, h)}</g>')
    # the deck's own OSD stays put
    b.append(osd(56, 84, "▶ PLAY", 39))
    b.append(osd(56, 500, "SP  ·  CH 03  ·  TRACKING ◂ ▸", 26, WHITE))
    b.append(cobweb(s, rnd, [((0, 0), (4, 86), 72, .35)], dust=3))   # on the glass, not on the tape
    b.append(band(s, rnd, W, h, 128, 6, h + 40))
    b.append(scanlines(s, W, h))
    b.append(flicker(s, W, h, 3.3, [(0, "0"), (12, ".035"), (13.5, "0"), (47, ".02"), (48, "0"), (77, ".05"), (78.2, "0")]))
    return s.render()


def sticker(s, rnd, num, label, lang, damaged=False):
    x, y, w, h = 48, 30, 600, 140
    out = [f'<g transform="rotate(-2 {x + w // 2} {y + h // 2})">',
           f'<rect x="{x + 7}" y="{y + 7}" width="{w}" height="{h}" fill="#000" opacity=".5"/>',
           f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{PAPER}"/>',
           f'<rect x="{x}" y="{y}" width="{w}" height="22" fill="{PINK}"/>',
           T("osd", x + 96, y + 16, "VHS · E-180", 13, "#3a0f2a"),
           T("osd", x + w - 12 - cw(13) * 2, y + 16, "SP", 13, "#3a0f2a"),
           f'<rect x="{x + 18}" y="{y + h - 26}" width="{w - 36}" height="2" fill="#c3cfe2"/>']
    lx, size = x + 22, 58.0
    if num != "keys":
        out.append(T("hand", lx, y + h - 32, num, 60, MARKER))
        lx += width("hand", num, 60) + 20
    room = x + w - 22 - lx
    size = min(size, room / width("hand", label, 1))
    # textLength: a fallback font (fonts blocked, rsvg) is squeezed to fit the label too
    out.append(T("hand", lx, y + h - 32, label, size, INK,
                 f' textLength="{n(width("hand", label, size))}" lengthAdjust="spacingAndGlyphs"'))
    out.append(f'<path d="{specks(rnd, x, y, w, h, 60 if damaged else 26)}" fill="#2b1d16" opacity=".32"/>')
    if damaged:   # scorched corner, in hard steps
        cx, cy = x + w, y + h
        out.append(f'<path d="M{cx} {cy - 64}v64h-150v-8h40v-10h36v-14h30v-16h24v-16z" fill="#3a271c" opacity=".55"/>'
                   f'<path d="M{cx} {cy - 30}v30h-70v-8h28v-10h24v-12z" fill="#1c120c" opacity=".7"/>')
    out.append(f'<rect x="{x - 26}" y="{y - 4}" width="92" height="22" fill="#ff8fc8" opacity=".72" '
               f'transform="rotate(-22 {x + 20} {y + 7})"/></g>')
    return "".join(out)


def tape(num, date, time, en, ru, lang):
    rnd = random.Random(f"tape-{num}-{lang}")
    h, last, keys = 200, num == "12", num == "keys"
    label = en if lang == "en" else ru
    if keys:
        title = {"en": "Appendix — taped under the keyboard", "ru": "Приложение — приклеено под клавиатурой"}[lang]
        desc = title
    else:
        title = (f"Tape {num}/12 — {label}" if lang == "en" else f"Кассета {num}/12 — {label}")
        desc = (f"Tape {num} of 12, {date} {time}: {label}" if lang == "en"
                else f"Кассета {num} из 12, {date} {time}: {label}")
    s = Svg(W, h, title, desc)
    b = s.body
    b.append(f'<rect width="{W}" height="{h}" fill="{BG}"/>')
    i = 13 if keys else int(num)
    if last:   # one 15 s loop: the clock runs to 23:59:59, the picture tears, then NO SIGNAL
        hits = [10, 10.6, 33, 33.5, 55, 55.4, 70, 70.8, 72, 72.6, 74, 74.5, 75.5, 76.4, 77.5, 78.4, 79.2]
        shifts = ["translate(-6px,2px)", "translate(0,0)", "translate(9px,0)", "translate(0,0)",
                  "translate(0,-3px)", "translate(0,0)", "translate(-12px,3px)", "translate(4px,-2px)",
                  "translate(0,0)", "translate(14px,0)", "translate(-5px,4px)", "translate(0,0)",
                  "translate(-16px,-2px)", "translate(10px,5px)", "translate(-4px,0)", "translate(18px,-3px)",
                  "translate(0,0)"]
        jit = s.anim("transform", [(0, "translate(0,0)")] + list(zip(hits, shifts)), 15)
    else:
        p = 5 + rnd.randrange(5)
        at = rnd.randrange(20, 80)
        jit = s.anim("transform", [(0, "translate(0,0)"), (at, f"translate({rnd.choice((-3, 3))}px,2px)"),
                                   (at + 1.2, "translate(0,0)")], p)
    b.append(f'<g class="{jit}">{edges(W, h, (5, 12))}{sticker(s, rnd, num, label, lang, last)}')
    if last:   # two slices of the label tear sideways
        for y0, hh, dx, stops in ((70, 22, 38, [(0, "0"), (33, "1"), (33.5, "0"), (72, "1"), (72.6, "0")]),
                                  (112, 30, -46, [(0, "0"), (55, "1"), (55.4, "0"), (75.5, "1"), (77.5, "0")])):
            cid, cls = s.uid("c"), s.anim("opacity", stops, 15)
            s.defs.append(f'<clipPath id="{cid}"><rect x="0" y="{y0}" width="700" height="{hh}"/></clipPath>')
            b.append(f'<g clip-path="url(#{cid})"><g class="{cls}" opacity="0"><rect y="{y0}" width="700" '
                     f'height="{hh}" fill="{BG}"/><g transform="translate({dx},0)">'
                     f'{sticker(s, random.Random(f"tape-{num}-{lang}"), num, label, lang, True)}</g></g></g>')
    b.append(f"{head_switch(rnd, W, h)}</g>")
    # the OSD block
    x0, xr, sz = 712, 1232, 39
    split = 3 if last else 0
    if last:
        s.anim("transform", [(0, "translate(0,0)"), (33, "translate(-8px,0)"), (33.5, "translate(0,0)"),
                             (70, "translate(-14px,1px)"), (72.6, "translate(-5px,0)"), (75.5, "translate(-20px,0)"),
                             (78.4, "translate(0,0)")], 15, "spl")
        s.anim("transform", [(0, "translate(0,0)"), (33, "translate(8px,0)"), (33.5, "translate(0,0)"),
                             (70, "translate(12px,-1px)"), (72.6, "translate(6px,0)"), (75.5, "translate(17px,0)"),
                             (78.4, "translate(0,0)")], 15, "spr")
    b.append(osd(x0, 70, "▶ PLAY", sz, split=split))
    tag = ("APPENDIX" if lang == "en" else "ПРИЛОЖЕНИЕ") if keys else \
          (f"TAPE {num}/12" if lang == "en" else f"КАССЕТА {num}/12")
    b.append(osd(xr - cw(sz) * len(tag), 70, tag, sz, split=split))
    if last:
        secs = ([f"{v}" for v in range(48, 60)] + ["59"] * 3, 1)
        b.append(s.ticker(x0, 124, sz, [f"{date}  23:59:", secs], t0=0, still=11, split=split))
        b.append(osd(x0, 170, "SP", sz, split=split))
        b.append(s.ticker(xr - cw(sz) * 7, 170, sz, ["1:17:", secs], t0=0, still=11, split=split))
    else:
        b.append(osd(x0, 124, f"{date}  {time}", sz))
        b.append(osd(x0, 170, "SP", sz))
        start = (i * 7 * 60 + i * 13) % 3600   # where the tape counter is when the card loads
        b.append(s.ticker(xr - cw(sz) * 7, 170, sz,
                          ["0:", ([str(v) for v in range(6)], 600), ([str(v) for v in range(10)], 60), ":",
                           ([f"{v:02}" for v in range(60)], 1)], t0=start))
    if last:
        b.append(band(s, rnd, W, h, 240, 5, h + 4, active=0.6, strong=True))
        ns = s.anim("opacity", [(0, "0"), (80, "1")], 15)
        word = "NO SIGNAL" if lang == "en" else "НЕТ СИГНАЛА"
        b.append(f'<g class="{ns}" opacity="0"><rect width="{W}" height="{h}" fill="{BLUE}"/>'
                 f'{osd(640 - cw(52) * len(word) / 2, 118, word, 52, WHITE, BLUE_SH)}'
                 f'{osd(56, 52, "CH 03", 26, WHITE, BLUE_SH)}</g>')
    else:
        b.append(band(s, rnd, W, h, 240, 6 + rnd.randrange(4), h + 4, active=0.4))
    # the web grows tape by tape; it keeps right of x 1236 / above y 44, clear of the OSD
    d = .5 if keys else (i - 1) / 11
    parts = [((0, 0), (4, 86), 46 if keys else 26 + (i - 1) * 36 / 11, d)]
    if last:   # spreading down the right edge
        parts += [((0, 62), (-60, 80), 38, .8), ((0, 108), (-70, 70), 40, .9), ((0, 160), (-75, 60), 38, .85),
                  ((0, 40), (88, 92), 156, 0)]
    b.append(cobweb(s, rnd, parts, mirror=W, dust=i // 2 + (6 if last else 0)))
    b.append(scanlines(s, W, h))
    b.append(flicker(s, W, h, 2.6 + (i % 4) * 0.4,
                     [(0, "0"), (20, ".04"), (22, "0"), (61, ".025"), (62.5, "0")]))
    return s.render()


def divider():
    rnd = random.Random("divider")
    h = 28
    s = Svg(W, h, "tracking noise", "a strip of VHS tracking noise")
    s.defs.append(f'<pattern id="n1" width="320" height="{h}" patternUnits="userSpaceOnUse">'
                  f'<path d="{dashes(rnd, 0, 0, 300, h, 34, 70)}" fill="#fff" opacity=".7"/>'
                  f'<path d="{dashes(rnd, 0, 0, 300, h, 20, 50)}" fill="#8a7fa0" opacity=".8"/></pattern>'
                  f'<pattern id="n2" width="208" height="{h}" patternUnits="userSpaceOnUse">'
                  f'<path d="{dashes(rnd, 0, 0, 190, h, 5, 40, (1, 2))}" fill="{PINK}"/>'
                  f'<path d="{dashes(rnd, 0, 0, 190, h, 5, 40, (1, 2))}" fill="{CYAN}"/>'
                  f'<path d="{dashes(rnd, 0, 0, 190, h, 12, 60)}" fill="#000"/></pattern>')
    a = s.anim("transform", [(i * 12.5, f"translate({-rnd.randrange(320)}px,{rnd.choice((-2, -1, 0, 1, 2))}px)")
                             for i in range(8)], 0.64)
    c = s.anim("transform", [(i * 100 / 6, f"translate({-rnd.randrange(208)}px,{rnd.choice((-1, 0, 1))}px)")
                             for i in range(6)], 0.54)
    streak = s.anim("opacity", [(0, "0"), (30, ".5"), (33, "0"), (71, ".35"), (72.5, "0")], 2.2)
    s.body += [f'<rect width="{W}" height="{h}" fill="#140a1c"/>',
               f'<g class="{a}"><rect x="-320" y="-4" width="{W + 640}" height="{h + 8}" fill="url(#n1)"/></g>',
               f'<g class="{c}"><rect x="-208" y="-4" width="{W + 416}" height="{h + 8}" fill="url(#n2)"/></g>',
               f'<rect class="{streak}" y="9" width="{W}" height="6" fill="#fff" opacity="0"/>',
               f'<rect width="{W}" height="2" fill="#000" opacity=".6"/><rect y="{h - 2}" width="{W}" height="2" '
               f'fill="#000" opacity=".6"/>', scanlines(s, W, h, ".35")]
    return s.render()


def end(lang):
    rnd = random.Random(f"end-{lang}")
    h = 360
    word, hi, stop = {"en": ("NO SIGNAL", "she says hi", "■ STOP  ·  END OF TAPE"),
                      "ru": ("НЕТ СИГНАЛА", "она передаёт привет", "■ СТОП  ·  КОНЕЦ ЗАПИСИ")}[lang]
    s = Svg(W, h, f"{word} — {stop[2:].replace('  ', ' ')}", f"{word}. {stop[2:]}".replace("  ", " "))
    b = s.body
    b.append(f'<rect width="{W}" height="{h}" fill="{BLUE}"/>')
    b.append(osd(640 - cw(26) * len(hi) / 2, 236, hi, 26, "#fff", "#0033cc").replace("<text", '<text opacity=".07"'))
    b.append(osd(640 - cw(65) * len(word) / 2, 170, word, 65, WHITE, BLUE_SH))
    b.append(osd(56, 66, "CH 03", 39, WHITE, BLUE_SH))
    # ~10 s: blue … a burst of snow, a frame of the tape, snow, blue again
    fr = s.anim("opacity", [(0, "0"), (66, "1"), (88, "0")], 10)
    nz = s.anim("opacity", [(0, "0"), (30, "1"), (30.6, "0"), (64, "1"), (66, "0"), (88, "1"), (90, "0")], 10)
    blink = s.anim("opacity", [(0, "1"), (55, "0")], 0.55)
    tw = cw(65) * len(hi)
    b.append(f'<g class="{fr}" opacity="0"><rect width="{W}" height="{h}" fill="{BG}"/>{edges(W, h)}'
             f'<path d="{dashes(rnd, 0, 0, W, h, 60, 70, (1, 2))}" fill="#fff" opacity=".12"/>'
             f'<g class="{blink}">{osd(640 - tw / 2, 196, hi, 65, LPINK, BLACK, split=5)}</g>'
             f'{osd(1224 - cw(26) * 19, 268, "31.12.2002 23:59:59", 26)}{head_switch(rnd, W, h)}</g>')
    s.defs.append(f'<pattern id="snow" width="160" height="90" patternUnits="userSpaceOnUse">'
                  f'<rect width="160" height="90" fill="#2a2a30"/>'
                  f'<path d="{dashes(rnd, 0, 0, 150, 90, 70, 30, (1, 2, 3))}" fill="#fff"/>'
                  f'<path d="{dashes(rnd, 0, 0, 150, 90, 50, 30, (1, 2))}" fill="#000"/></pattern>')
    b.append(f'<rect class="{nz}" width="{W}" height="{h}" fill="url(#snow)" opacity="0"/>')
    b.append(osd(640 - cw(39) * len(stop) / 2, 318, stop, 39, WHITE, BLUE_SH))
    b.append(cobweb(s, rnd, [((0, 0), (3, 87), 220, .9)], mirror=W, dust=10))
    b.append(scanlines(s, W, h, ".22"))
    return s.render()


def stamp(lang):
    rnd = random.Random(f"stamp-{lang}")
    w, h = 360, 120
    big, small = {"en": ("EVIDENCE", "DO NOT ERASE"), "ru": ("ВЕЩДОК", "НЕ СТИРАТЬ")}[lang]
    s = Svg(w, h, f"{big} · {small}", f"A red rubber stamp: {big}, {small}" if lang == "en"
            else f"Красный штамп: {big}, {small}")
    ink = "#d81f3a"
    s.defs.append(f'<pattern id="holes" width="46" height="34" patternUnits="userSpaceOnUse">'
                  f'<path d="{specks(rnd, 0, 0, 44, 32, 16, (1, 2, 2, 3, 4))}" fill="#000"/></pattern>'
                  f'<mask id="ink" maskUnits="userSpaceOnUse" x="0" y="0" width="{w}" height="{h}">'
                  f'<rect width="{w}" height="{h}" fill="#fff"/><rect width="{w}" height="{h}" fill="url(#holes)"/>'
                  f'<path d="{dashes(rnd, 20, 14, 320, 92, 14, 36, (1, 2))}" fill="#000"/></mask>')
    bs = 9 * max(k for k in range(1, 5) if width("title", big, 9 * k) <= 270)      # whole font pixels
    ss = 9 * max(k for k in range(1, 3) if width("title", small, 9 * k) <= 250)
    b = [f'<g mask="url(#ink)" shape-rendering="crispEdges"><g transform="rotate(-4 180 60)" fill="{ink}">',
         '<path d="M24 16h312v88H24ZM30 22v76h300V22Z" fill-rule="evenodd"/>',
         '<path d="M34 26h292v68H34ZM36 28v64h288V28Z" fill-rule="evenodd"/>',
         T("title", 180, 65, big, bs, ink, ' text-anchor="middle"'),
         T("title", 180, 87, small, ss, ink, ' text-anchor="middle"'),
         '</g></g>']
    s.body += b
    return s.render()


def cobweb_corner(side):
    rnd = random.Random("cobweb")    # one web, mirrored: tl and tr are twins
    s = Svg(220, 220, "cobweb", "a cobweb in the corner")
    s.body.append(cobweb(s, rnd, [((0, 0), (3, 87), 212, .85)], color=GREY, outline=WEB_DARK, dust=8,
                         mirror=220 if side == "tr" else None))
    return s.render()


SPIDER = ["x..x.x..x",
          ".x.ebe.x.",
          "..xbbbx..",
          "xxxbdbxxx",
          "..xbdbx..",
          ".x.bbb.x.",
          "x..x.x..x"]


def spider():
    w, h, k = 90, 300, 3
    s = Svg(w, h, "spider", "a small pixel spider going up and down its thread")
    x, art = 33, outlined(SPIDER, "bde")       # art is 11×9 with the outline; the body starts at +k
    # one 14 s loop in 3 px steps: halfway → bottom, wait, → top, wait, → halfway
    mid, low, top = 141, 267, 18
    seg = [(0, mid, low), (22.8, low, low), (27.8, low, top), (72.8, top, top), (77.8, top, mid)]
    frames = "".join(f"{n(p)}%{{transform:translate(0,{a}px);animation-timing-function:steps({max(1, abs(b - a) // k)},end)}}"
                     for p, a, b in seg) + f"100%{{transform:translate(0,{mid}px)}}"
    s.css.append(f".sp{{animation:sp 14s linear infinite}}@keyframes sp{{{frames}}}")
    s.body.append(f'<g class="sp" transform="translate(0,{mid})">'
                  f'<rect x="{x + 4 * k + 1}" y="-{h}" width="1" height="{h + k}" fill="{GREY}" shape-rendering="crispEdges"/>'
                  f'{pixel_art(art, {"o": WEB_DARK, "x": GREY, "b": GREY, "d": WEB_DARK, "e": PINK}, x - k, -k, k)}</g>')
    return s.render()


FLY = [".w...w.",
       "wwbbbww",
       ".bbbbb.",
       "..bbb..",
       ".x.x.x."]


def cobweb_divider():
    rnd = random.Random("cobweb-divider")
    w, h, cell = W, 40, 2
    s = Svg(w, h, "a cobweb strand", "a sagging cobweb strand with a dead fly caught in it")
    sag = lambda x: 6 + 22 * (1 - (2 * x / w - 1) ** 2)
    snap = lambda v: math.floor(v / cell) * cell + cell / 2
    d = "M" + "L".join(f"{n(snap(x))} {n(snap(sag(x)))}" for x in list(range(0, w, 32)) + [w - 1])
    stroke = 'fill="none" stroke-linejoin="bevel" shape-rendering="crispEdges"'
    out = [f'<path d="{d}" stroke="{WEB_DARK}" stroke-width="{cell * 2}" {stroke}/>',
           f'<path d="{d}" stroke="{GREY}" stroke-width="{cell}" {stroke}/>']
    for kx in (296, 742, 1018):           # knots
        out.append(pixel_art(outlined(["bb", "bb"]), {"o": WEB_DARK, "b": GREY},
                             snap(kx) - cell / 2 - 2 * cell, snap(sag(kx)) - cell / 2 - 2 * cell, cell))
    fx = 866                              # the fly, on a short thread under the strand
    fy = math.floor(sag(fx) / cell) * cell + cell
    out.append(f'<rect x="{fx}" y="{fy}" width="{cell}" height="{2 * cell}" fill="{GREY}" shape-rendering="crispEdges"/>')
    out.append(pixel_art(outlined(FLY, "bw"), {"o": WEB_DARK, "w": "#cfc9d9", "b": "#3e3846", "x": WEB_DARK},
                         fx - 4 * cell, fy + cell, cell))
    s.body += out
    return s.render()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(ROOT / "docs/readme/footage"))
    out = Path(ap.parse_args().out)
    out.mkdir(parents=True, exist_ok=True)
    files = {"divider.svg": divider(), "cobweb-tl.svg": cobweb_corner("tl"), "cobweb-tr.svg": cobweb_corner("tr"),
             "spider.svg": spider(), "cobweb-divider.svg": cobweb_divider()}
    for lang, sfx in (("en", ""), ("ru", ".ru")):
        files[f"header{sfx}.svg"] = header(lang)
        files[f"end{sfx}.svg"] = end(lang)
        files[f"stamp-evidence{sfx}.svg"] = stamp(lang)
        for t in TAPES:
            files[f"tape-{t[0]}{sfx}.svg"] = tape(*t, lang)
    for name, text in sorted(files.items()):
        (out / name).write_text(text, encoding="utf-8")
        print(f"{out / name}  {len(text.encode()) / 1024:.1f} KB")


if __name__ == "__main__":
    main()
