#!/usr/bin/env python3
"""Circle to Search / Live Text (services/CircleSearch, modules/circle/CircleOverlay).

The overlay freezes a screen with grim (P6 .ppm) and the user draws a loop over it.
This helper does the rest, each subcommand prints one JSON object:

  circle.py ocr <frame.ppm> [x y w h] [--poly x,y;x,y;...] [--zoom 2]
      words in the frame (or in the box), boxes in frame pixels, in reading order:
      {"words":[{"x","y","w","h","t","line","conf","block","para"}], "text": "..."};
      doubtful words and scraps of pictures are left out; with --poly only the words
      whose middle is inside the loop are kept
  circle.py translate <text> [--to auto|ru|en|...]
      {"text": "...", "to": "ru"} through translate-shell (`trans -b`)
  circle.py crop <frame.ppm> x y w h <out.png>
      the piece as a PNG (copy as a picture, search by picture)
  circle.py lens <frame.ppm> x y w h
      a page that sends the piece to Google Lens; prints {"page": "/run/.../lens.html"}
  circle.py fixlink <url>
      a YouTube link read off the screen, its id checked: I/l/1, O/0/o and -/_ look alike
      in UI fonts, so a missing video's look-alikes are tried (YouTube oEmbed) and the
      nearest one that exists wins; {"url": "...", "fixed": true|false}

PPM in, PNG out by hand (zlib), tesseract and trans as programs; the OCR page is cleaned
with numpy + Pillow when they are there (page_for_ocr), plain grey without them.
"""
import base64
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import urllib.parse
import zlib

HOME = os.path.expanduser("~")
RUNTIME = os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/tmp", "angelos")


def out(obj):
    sys.stdout.write(json.dumps(obj, ensure_ascii=False))
    sys.stdout.write("\n")
    sys.stdout.flush()


# ---------------------------------------------------------------- pictures

def read_ppm(path):
    with open(path, "rb") as f:
        data = f.read()
    # header: P6 <ws> width <ws> height <ws> maxval <one ws> pixels; comments start with #
    fields = []
    i = 0
    while len(fields) < 4:
        while data[i:i + 1].isspace():
            i += 1
        if data[i:i + 1] == b"#":
            while data[i:i + 1] not in (b"\n", b""):
                i += 1
            continue
        j = i
        while not data[j:j + 1].isspace():
            j += 1
        fields.append(data[i:j])
        i = j
    if fields[0] != b"P6" or int(fields[3]) > 255:
        raise ValueError("not an 8-bit P6 picture")
    w, h = int(fields[1]), int(fields[2])
    i += 1
    return w, h, data[i:i + w * h * 3]


def crop(img, x, y, w, h):
    iw, ih, px = img
    x = max(0, min(iw - 1, int(x)))
    y = max(0, min(ih - 1, int(y)))
    w = max(1, min(iw - x, int(w)))
    h = max(1, min(ih - y, int(h)))
    stride = iw * 3
    rows = [px[(y + r) * stride + x * 3:(y + r) * stride + (x + w) * 3] for r in range(h)]
    return w, h, b"".join(rows), (x, y)


def upscale(w, h, px, k):
    """k× nearest neighbour: small UI text reads much better for tesseract."""
    if k <= 1:
        return w, h, px
    rows = []
    for r in range(h):
        row = px[r * w * 3:(r + 1) * w * 3]
        wide = b"".join(row[i:i + 3] * k for i in range(0, len(row), 3))
        rows.extend([wide] * k)
    return w * k, h * k, b"".join(rows)


def gray_for_ocr(w, h, px):
    """Grey, and light-on-dark turned over: tesseract reads dark text on a light page."""
    g = bytes((px[i] * 77 + px[i + 1] * 150 + px[i + 2] * 29) >> 8 for i in range(0, len(px), 3))
    if sum(g[::97]) / max(1, len(g[::97])) < 110:
        g = bytes(255 - v for v in g)
    return g


def square(a, k, f):
    """k×k max (f=np.maximum) or min (np.minimum), as two sliding passes: 2k array ops."""
    import numpy as np
    r = k // 2
    h, w = a.shape
    p = np.pad(a, r, mode="edge")
    m = p[:, :w]
    for i in range(1, k):
        m = f(m, p[:, i:i + w])
    o = m[:h]
    for i in range(1, k):
        o = f(o, m[i:i + h])
    return o


def ink_page(w, h, px):
    """Every bit of text dark on white, whatever it stands on: strokes thinner than a
    small square are what differs from their closing (dark text) or opening (light text),
    so light on dark, dark on light, buttons and gradients come out the same way and the
    edges of plates go (they are wide, not strokes). A (h, w) uint8 array, 255 = paper."""
    import numpy as np
    from PIL import Image, ImageFilter
    g = (np.frombuffer(px, np.uint8).reshape(h, w, 3) @ np.array([77, 150, 29], np.uint16) >> 8).astype(np.uint8)
    k = 9
    c = square(square(g, k, np.maximum), k, np.minimum).astype(np.int16)
    o = square(square(g, k, np.minimum), k, np.maximum).astype(np.int16)
    # which way the text goes here: the background (a median of a smaller copy) is on the
    # light side of the two → dark text, else light text
    q = 4
    bg = Image.fromarray(g).resize((max(1, w // q), max(1, h // q)), Image.BOX).filter(ImageFilter.MedianFilter(9)).resize((w, h), Image.BILINEAR)
    gi = g.astype(np.int16)
    d = np.where(np.asarray(bg, np.int16) * 2 > c + o, c - gi, gi - o)
    return (255 - np.clip((d - 12) * 3.2, 0, 255)).astype(np.uint8)


def page_for_ocr(w, h, px, zoom):
    """ink_page upscaled smoothly: (w, h, bytes) for one tesseract page."""
    from PIL import Image
    img = Image.fromarray(ink_page(w, h, px))
    if zoom > 1:
        img = img.resize((w * zoom, h * zoom), Image.LANCZOS)
    return img.width, img.height, img.tobytes()


def write_pgm(path, w, h, g):
    with open(path, "wb") as f:
        f.write(b"P5\n%d %d\n255\n" % (w, h))
        f.write(g)


def write_ppm(path, w, h, px):
    with open(path, "wb") as f:
        f.write(b"P6\n%d %d\n255\n" % (w, h))
        f.write(px)


def png_bytes(w, h, px):
    raw = b"".join(b"\x00" + px[r * w * 3:(r + 1) * w * 3] for r in range(h))

    def chunk(kind, body):
        c = struct.pack(">I", len(body)) + kind + body
        return c + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))



# ---- layout: where the lines are, which go together, in which order
#
# The page is cut into narrow vertical strips; in each strip a run of inked rows between clean
# rows is a piece of a line (a glyph row seen through a slit). Pieces of neighbouring strips at
# the same height chain into segments of lines, segments into lines, lines into blocks
# (paragraphs, columns, table rows), blocks into reading order (cuts through the gaps between
# them, columns before rows). Each segment is then read on its own, scaled so that its letters
# are the size tesseract reads best: small UI text is blown up, big titles are not.

STRIP = 16


def _runs(b):
    """True runs along axis 1 of a 2D bool array: (row, start, end) arrays."""
    import numpy as np
    z = np.zeros((b.shape[0], 1), np.int8)
    d = np.diff(np.concatenate([z, b.astype(np.int8), z], 1), axis=1)
    r, s = np.nonzero(d == 1)
    _, e = np.nonzero(d == -1)
    return r, s, e


def _window_any(a, k):
    """Along axis 1: is any of a[x-k+1 .. x] true (a 1×k max filter, left anchored)."""
    import numpy as np
    cs = np.concatenate([np.zeros((a.shape[0], 1), np.int32), np.cumsum(a, 1, dtype=np.int32)], 1)
    i = np.arange(a.shape[1])
    return (cs[:, i + 1] - cs[:, np.maximum(0, i - k + 1)]) > 0


def _window_all(a, k):
    """Along axis 1: are a[x .. x+k-1] all true (1×k min filter, left anchored)."""
    import numpy as np
    n = a.shape[1]
    out = np.zeros(a.shape, bool)
    if n >= k:
        cs = np.concatenate([np.zeros((a.shape[0], 1), np.int32), np.cumsum(a, 1, dtype=np.int32)], 1)
        out[:, :n - k + 1] = (cs[:, k:] - cs[:, :n - k + 1]) == k
    return out


def unrule(m, length=40, thin=3):
    """The ink without long thin straight lines (window borders, table rules, underlines,
    progress bars): they would tie lines and columns together."""
    out = m.copy()
    for a, back in ((m, lambda x: x), (m.T, lambda x: x.T)):
        rule = _window_any(_window_all(a, length), length) & a
        if not rule.any():
            continue
        # across the line it is at most `thin` px thick (a bold glyph or a plate is not)
        t = rule.T
        thick = _window_any(_window_all(t, thin + 1), thin + 1).T
        out &= ~back(rule & ~thick)
    return out


class Seg:
    __slots__ = ("x0", "y0", "x1", "y1", "h", "multi", "words", "line", "block")

    def __init__(self, x0, y0, x1, y1, h, multi=False):
        self.x0, self.y0, self.x1, self.y1, self.h, self.multi = x0, y0, x1, y1, h, multi
        self.words = []


def segments(ink, gray=None, page=None):
    """Pieces of text lines: [Seg] in page pixels, h = the height of its letters."""
    import numpy as np
    H, W = ink.shape
    ns = (W + STRIP - 1) // STRIP
    pad = np.zeros((H, ns * STRIP), bool)
    pad[:, :W] = ink
    rows = pad.reshape(H, ns, STRIP).sum(2).T            # strips × rows: inked px per row
    st, y0, y1 = _runs(rows > 0)
    cs = np.concatenate([np.zeros((ns, 1), np.int64), np.cumsum(rows, 1)], 1)
    inked = cs[st, y1] - cs[st, y0]
    hh = y1 - y0
    ok = (hh >= 3) & (hh <= 120) & (inked >= 4)
    frags = [[int(a), int(b), int(c)] for a, b, c in zip(st[ok], y0[ok], y1[ok])]
    if gray is not None:
        # letters stand on a flat ground; a piece of a photo or an avatar does not: the paper
        # around its strokes changes from pixel to pixel
        keep = []
        for f in frags:
            sx = f[0] * STRIP
            ya, yb = max(0, f[1] - 2), min(H, f[2] + 2)
            g = gray[ya:yb, sx:sx + STRIP]
            v = g[page[ya:yb, sx:sx + STRIP] > 220]
            if len(v) >= 8 and np.median(np.abs(v - np.median(v))) >= 4:
                continue
            keep.append(f)
        frags = keep
    by_strip = {}
    for f in sorted(frags, key=lambda f: (f[0], f[1])):
        by_strip.setdefault(f[0], []).append(f)
    # a piece two lines tall (tight lines touching in this strip) is cut where its neighbours
    # in the next strips leave a gap, so it does not tie the two lines together
    for s in list(by_strip):
        out = []
        for f in by_strip[s]:
            cuts = []
            for nb in (by_strip.get(s - 1, ()), by_strip.get(s + 1, ())):
                inner = [g for g in nb if g[1] >= f[1] - 2 and g[2] <= f[2] + 2 and (g[2] - g[1]) <= 0.7 * (f[2] - f[1])]
                inner.sort(key=lambda g: g[1])
                for g1, g2 in zip(inner, inner[1:]):
                    if g2[1] >= g1[2]:
                        cuts.append((g1[2] + g2[1]) // 2)
                if cuts:
                    break
            if cuts:
                edges = [f[1]] + sorted(set(cuts)) + [f[2]]
                out.extend([s, a, b] for a, b in zip(edges, edges[1:]) if b - a >= 4)
            else:
                out.append(f)
        by_strip[s] = out
    frags = [f for s in sorted(by_strip) for f in by_strip[s]]
    n = len(frags)
    if not n:
        return []
    for i, f in enumerate(frags):
        f.append(i)
    st = np.array([f[0] for f in frags])
    y0 = np.array([f[1] for f in frags])
    y1 = np.array([f[2] for f in frags])
    hh = y1 - y0
    # chain pieces of neighbouring strips that sit at the same height and are about as tall
    parent = list(range(n))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for s, here in by_strip.items():
        nxt = by_strip.get(s + 1)
        if not nxt:
            continue
        for f in here:
            i = f[3]
            for g in nxt:
                if g[1] >= f[2]:
                    break
                k = g[3]
                ov = min(f[2], g[2]) - max(f[1], g[1])
                lo, hi = min(hh[i], hh[k]), max(hh[i], hh[k])
                # (a word of small letters only is half as tall as one with capitals)
                if ov >= 0.5 * lo and hi <= 2.6 * lo:
                    ri, rk = find(i), find(k)
                    if ri != rk:
                        parent[rk] = ri
    groups = {}
    for i in range(n):
        groups.setdefault(find(i), []).append(i)
    segs = []
    for g in groups.values():
        g = np.array(g)
        sy0, sy1 = int(y0[g].min()), int(y1[g].max())
        x0, x1 = int(st[g].min()) * STRIP, min(W, int(st[g].max() + 1) * STRIP)
        # the letters' height: the tallest piece (ascender to descender) that is not two lines
        fh = hh[g]
        h = float(fh[fh <= 2.6 * np.median(fh)].max())
        if len(g) == 1 and h < 3:
            continue
        # the real ends, and wide gaps inside (a table's columns can share a strip run)
        col = ink[sy0:sy1, x0:x1].any(0)
        xs = np.nonzero(col)[0]
        if not len(xs):
            continue
        gap = max(8, 1.6 * h)
        start = xs[0]
        for a, b in zip(xs[:-1], xs[1:]):
            if b - a > gap:
                segs.append(_seg(ink, x0 + start, x0 + a + 1, sy0, sy1, h))
                start = b
        segs.append(_seg(ink, x0 + start, x0 + xs[-1] + 1, sy0, sy1, h))
    return [s for s in segs if s]


def _trim_blobs(ink, x0, x1, y0, y1, h):
    """The ends of a piece without a filled blob set apart from the rest (a status dot, a badge,
    a bit of an avatar beside a name): letters are strokes, never a filled patch. (x0, x1)."""
    import numpy as np
    while True:
        cols = ink[y0:y1, x0:x1].any(0)
        xs = np.nonzero(cols)[0]
        if not len(xs):
            return x0, x1
        runs, start = [], xs[0]
        for a, b in zip(xs[:-1], xs[1:]):
            if b - a > max(3, 0.3 * h):  # a space apart, not a letter's gap
                runs.append((start, a + 1))
                start = b
        runs.append((start, xs[-1] + 1))
        if len(runs) < 2:
            return x0, x1
        changed = False
        for end in (0, -1):
            a, b = runs[end]
            blob = ink[y0:y1, x0 + a:x0 + b]
            ys = np.nonzero(blob.any(1))[0]
            # (a filled patch outlives shrinking by 2 px all round; a stroke of a letter does not)
            core = square(blob.astype(np.uint8), 5, np.minimum) if len(ys) and min(blob.shape) >= 5 else blob[:0]
            if b - a <= 1.5 * h and len(ys) and (ys[-1] - ys[0] + 1) >= 0.4 * h and core.sum() >= 0.3 * blob.sum():
                if end == 0:
                    x0 += runs[1][0]
                else:
                    x1 = x0 + runs[-2][1]
                changed = True
                break
        if not changed:
            return x0, x1


def _seg(ink, x0, x1, y0, y1, h):
    x0, x1 = _trim_blobs(ink, x0, x1, y0, y1, h)
    rows = ink[y0:y1, x0:x1].any(1)
    ys = rows.nonzero()[0]
    if not len(ys):
        return None
    y0, y1 = y0 + int(ys[0]), y0 + int(ys[-1]) + 1
    w = x1 - x0
    if w < 3 or (w < 0.5 * h and w < 6):
        return None
    density = ink[y0:y1, x0:x1].mean()
    if density > 0.8:  # a filled shape: a dot, a bar, an avatar's face, not letters
        return None
    return Seg(x0, y0, x1, y1, h, multi=(y1 - y0) > 1.6 * h)


def alike(s, t):
    """Two pieces of one line: about as tall, or the taller one is a run of text (a word of
    small letters only, "очень", is half as tall as "Пока") and not a square picture next to
    a name (an avatar)."""
    big, small = (s, t) if s.h >= t.h else (t, s)
    if big.h <= 1.5 * small.h:
        return True
    return big.h <= 2.3 * small.h and big.x1 - big.x0 >= 2.5 * (big.y1 - big.y0)


def merge_segments(segs):
    """Pieces at the same height with a word-sized gap between them are one segment."""
    segs.sort(key=lambda s: (s.x0, s.y0))
    out = []
    for s in segs:
        best = None
        for t in out:
            gap = s.x0 - t.x1
            if gap < -2 or gap > max(10, 1.3 * max(s.h, t.h)):
                continue
            ov = min(s.y1, t.y1) - max(s.y0, t.y0)
            lo = min(s.y1 - s.y0, t.y1 - t.y0)
            # (a word of small letters only, "очень", is half as tall as "Пока")
            big, small = (s, t) if s.y1 - s.y0 >= t.y1 - t.y0 else (t, s)
            mark = small.x1 - small.x0 <= 1.5 * big.h and small.y0 >= big.y0 - 1 and small.y1 <= big.y1 + 1
            if ov >= 0.55 * lo and (alike(s, t) or mark) and \
                    max(s.y1, t.y1) - min(s.y0, t.y0) <= 1.25 * max(s.y1 - s.y0, t.y1 - t.y0):
                best = t
                break
        if best:
            best.x1 = max(best.x1, s.x1)
            best.y0, best.y1 = min(best.y0, s.y0), max(best.y1, s.y1)
            best.h = max(best.h, s.h)
            best.multi = (best.y1 - best.y0) > 1.6 * best.h
        else:
            out.append(s)
    return out


class Line:
    __slots__ = ("segs", "x0", "y0", "x1", "y1", "h")

    def __init__(self, segs):
        self.segs = sorted(segs, key=lambda s: s.x0)
        self.x0 = min(s.x0 for s in segs)
        self.x1 = max(s.x1 for s in segs)
        self.y0 = min(s.y0 for s in segs)
        self.y1 = max(s.y1 for s in segs)
        self.h = max(s.h for s in segs)


def make_lines(segs, join=3.0):
    """Segments on one height close enough (a row of a small table, a label and its value)
    are one line; multi-line segments stay alone."""
    segs = sorted(segs, key=lambda s: (s.y0, s.x0))
    lines = []
    for s in segs:
        hit = None
        if not s.multi:
            for ln in lines:
                if ln.y1 < s.y0 - 2 * s.h:
                    continue
                ov = min(s.y1, ln.y1) - max(s.y0, ln.y0)
                lo = min(s.y1 - s.y0, ln.y1 - ln.y0)
                gap = max(s.x0 - ln.x1, ln.x0 - s.x1)
                if ov >= 0.6 * lo and gap <= join * max(s.h, ln.h) and all(alike(s, t) for t in ln.segs) \
                        and not any(t.multi for t in ln.segs):
                    hit = ln
                    break
        if hit:
            lines[lines.index(hit)] = Line(hit.segs + [s])
        else:
            lines.append(Line([s]))
    return lines


class Block:
    __slots__ = ("lines", "x0", "y0", "x1", "y1")

    def __init__(self, lines):
        self.lines = lines
        self.fit()

    def fit(self):
        self.x0 = min(l.x0 for l in self.lines)
        self.x1 = max(l.x1 for l in self.lines)
        self.y0 = min(l.y0 for l in self.lines)
        self.y1 = max(l.y1 for l in self.lines)


def make_blocks(lines):
    """Lines stacked one under another (overlapping across, about one line apart, alike in
    size) are a block: a paragraph, a list, a column."""
    blocks = []
    for ln in sorted(lines, key=lambda l: (l.y0, l.x0)):
        best, bgap = None, None
        for b in blocks:
            last = b.lines[-1]
            gap = ln.y0 - last.y1
            h = max(ln.h, last.h)
            if gap < -0.3 * h or gap > 2.2 * h:
                continue
            if max(ln.h, last.h) > 2.2 * min(ln.h, last.h):
                continue
            # under the block: overlapping it, or starting where it starts
            ov = min(ln.x1, b.x1) - max(ln.x0, b.x0)
            if ov < 0.3 * min(ln.x1 - ln.x0, b.x1 - b.x0) and abs(ln.x0 - b.x0) > 2 * h:
                continue
            # nothing else in between (another block's line under this block's last)
            if bgap is None or gap < bgap:
                best, bgap = b, gap
        if best:
            best.lines.append(ln)
            best.fit()
        else:
            blocks.append(Block([ln]))
    return merge_overlaps(merge_tables(blocks))


def merge_overlaps(blocks):
    """Blocks that overlap are one (a list whose items have icons in some rows only): the
    reading order cuts between blocks, and overlapping ones cannot be cut apart."""
    changed = True
    while changed:
        changed = False
        for i, a in enumerate(blocks):
            for b in blocks[i + 1:]:
                if min(a.x1, b.x1) > max(a.x0, b.x0) and min(a.y1, b.y1) > max(a.y0, b.y0):
                    a.lines = sorted(a.lines + b.lines, key=lambda l: (l.y0 + l.y1) / 2)
                    a.fit()
                    blocks.remove(b)
                    changed = True
                    break
            if changed:
                break
    return blocks


def merge_tables(blocks):
    """Side by side blocks whose lines pair up row by row are one table: read row by row.
    Two columns of long text (two terminals, a page in columns) are not: their gap is narrow
    next to their lines."""
    changed = True
    while changed:
        changed = False
        blocks.sort(key=lambda b: (b.x0, b.y0))
        for i, a in enumerate(blocks):
            for b in blocks:
                if b is a or b.x0 < a.x1 or len(a.lines) < 2 or len(b.lines) < 2:
                    continue
                gap = b.x0 - a.x1
                h = max(max(l.h for l in a.lines), max(l.h for l in b.lines))
                wa = sorted(l.x1 - l.x0 for l in a.lines)[len(a.lines) // 2]
                if gap > 14 * h or (gap < 0.25 * wa and wa > 12 * h):
                    continue
                if min(a.y1, b.y1) - max(a.y0, b.y0) < 0.5 * min(a.y1 - a.y0, b.y1 - b.y0):
                    continue
                # a block between them breaks the pair
                if any(c is not a and c is not b and c.x0 >= a.x1 and c.x1 <= b.x0 and
                       min(c.y1, a.y1) - max(c.y0, a.y0) > 0 for c in blocks):
                    continue
                pairs = {}
                for lb in b.lines:
                    cb = (lb.y0 + lb.y1) / 2
                    for la in a.lines:
                        if abs((la.y0 + la.y1) / 2 - cb) <= 0.45 * max(la.h, lb.h):
                            pairs[id(lb)] = la
                            break
                if len(pairs) < 0.6 * len(b.lines) or len(set(map(id, pairs.values()))) < 0.6 * min(len(a.lines), len(b.lines)):
                    continue
                rows = {id(la): [la] for la in a.lines}
                for lb in b.lines:
                    la = pairs.get(id(lb))
                    if la is not None:
                        rows[id(la)].append(lb)
                    else:
                        rows[id(lb)] = [lb]
                lines = [Line([s for l in r for s in l.segs]) for r in rows.values()]
                lines.sort(key=lambda l: (l.y0 + l.y1) / 2)
                blocks.remove(b)
                a.lines = lines
                a.fit()
                changed = True
                break
            if changed:
                break
    return blocks


def reading_order(blocks, depth=0):
    """Cuts through gaps that no block crosses: columns first (left to right), then rows
    (top to bottom); what cannot be cut goes by its top."""
    if len(blocks) <= 1 or depth > 40:
        return list(blocks)
    hs = sorted(l.h for b in blocks for l in b.lines)
    unit = hs[len(hs) // 2]
    for axis in ("x", "y"):
        lo = (lambda b: b.x0) if axis == "x" else (lambda b: b.y0)
        hi = (lambda b: b.x1) if axis == "x" else (lambda b: b.y1)
        need = max(6, 0.8 * unit) if axis == "x" else 0
        bs = sorted(blocks, key=lo)
        groups, cur, reach = [], [bs[0]], hi(bs[0])
        for b in bs[1:]:
            if lo(b) - reach > need:
                groups.append(cur)
                cur = []
            cur.append(b)
            reach = max(reach, hi(b))
        groups.append(cur)
        if len(groups) > 1:
            return [b for g in groups for b in reading_order(g, depth + 1)]
    return sorted(blocks, key=lambda b: (b.y0, b.x0))


def split_multi(segs, ink):
    """A segment two or more lines tall (lines touching all along) cut at its thinnest rows."""
    out = []
    todo = list(segs)
    while todo:
        s = todo.pop()
        if not s.multi:
            out.append(s)
            continue
        prof = ink[s.y0:s.y1, s.x0:s.x1].sum(1)
        lo, hi = int(0.7 * s.h), len(prof) - int(0.7 * s.h)
        if hi <= lo:
            out.append(s)
            continue
        c = lo + int(prof[lo:hi].argmin())
        if prof[c] > 0.25 * float(prof.max()):
            out.append(s)
            continue
        for a, b in ((s.y0, s.y0 + c), (s.y0 + c + 1, s.y1)):
            t = _seg(ink, s.x0, s.x1, a, b, s.h)
            if t:
                t.h = min(s.h, t.y1 - t.y0) if t.y1 - t.y0 < s.h else s.h
                todo.append(t)
    return out


def layout(ink, gray=None, page=None):
    """[Block] in reading order, lines top to bottom, segments left to right."""
    segs = merge_segments(segments(unrule(ink), gray, page))
    return reading_order(make_blocks(make_lines(split_multi(segs, ink))))


# ---- reading the segments

def tess_env():
    env = dict(os.environ)
    local = os.environ.get("ANGELOS_TESSDATA") or os.path.join(HOME, ".local/share/tessdata")
    if os.path.isdir(local) and any(n.endswith(".traineddata") for n in os.listdir(local)):
        env["TESSDATA_PREFIX"] = local
    return env


def languages(env):
    try:
        r = subprocess.run(["tesseract", "--list-langs"], capture_output=True, text=True, env=env, timeout=10)
        have = [l.strip() for l in r.stdout.splitlines()[1:] if l.strip() and l.strip() != "osd"]
    except (OSError, subprocess.SubprocessError):
        return ""
    # the scripts people here write in first; the rest of what is installed after
    order = ["rus", "eng", "ukr"]
    picked = [l for l in order if l in have] + [l for l in have if l not in order]
    return "+".join(picked[:4])


# the letters' height (px) tesseract reads them at: a piece the user drew round is read a bit
# bigger (better), the whole screen a bit smaller (faster; just as good on screen text)
TARGET = float(os.environ.get("ANGELOS_OCR_TARGET") or 38)
TARGET_WHOLE = float(os.environ.get("ANGELOS_OCR_TARGET_WHOLE") or 36)
RESAMPLE = os.environ.get("ANGELOS_OCR_RESAMPLE") or "LANCZOS"


def read_segments(page, segs, langs, env, zoom=0, tmp=None, target=TARGET):
    """Every segment cut out (with a margin, without its neighbours), scaled so its letters
    are TARGET px and read. Fills seg.words with (x, y, w, h, text, conf, line_no) in page
    pixels."""
    import bisect
    from PIL import Image
    H, W = page.shape
    jobs = []
    by_top = sorted(segs, key=lambda s: s.y0)
    tops = [s.y0 for s in by_top]
    tallest = max((s.y1 - s.y0 for s in segs), default=0)
    for i, s in enumerate(segs):
        z = zoom or max(1.0, min(4.0, target / max(4.0, s.h)))
        m = int(max(3, 0.45 * s.h))
        x0, y0 = max(0, s.x0 - m), max(0, s.y0 - m)
        x1, y1 = min(W, s.x1 + m), min(H, s.y1 + m)
        a = page[y0:y1, x0:x1].copy()
        # the lines above and below that the margin catches are not this line's: white
        for t in by_top[bisect.bisect_left(tops, y0 - tallest):bisect.bisect_right(tops, y1)]:
            if t is s or t.x1 <= x0 or t.x0 >= x1 or t.y1 <= y0:
                continue
            # a short piece right under or over the line, within it: a descender or an accent the
            # strips cut off (white it and "angelOS" reads "anaelOS")
            if 2 * (t.y1 - t.y0) <= s.h and s.x0 <= t.x0 and t.x1 <= s.x1 and (-1 <= t.y0 - s.y1 <= 2 or -1 <= s.y0 - t.y1 <= 2):
                continue
            tx0, tx1 = max(t.x0, x0) - x0, min(t.x1, x1) - x0
            if t.y0 < s.y0:
                a[max(t.y0, y0) - y0:min(t.y1, s.y0) - y0, tx0:tx1] = 255
            if t.y1 > s.y1:
                a[max(t.y0, s.y1) - y0:min(t.y1, y1) - y0, tx0:tx1] = 255
        piece = Image.fromarray(a)
        if z != 1:
            piece = piece.resize((max(1, round((x1 - x0) * z)), max(1, round((y1 - y0) * z))), getattr(Image, RESAMPLE))
        jobs.append((piece, x0, y0, z))
    if not jobs:
        return
    # the pieces stacked into a few pages (one tesseract each, side by side): one page reads
    # the same whatever came before it, unlike a list of pages, and starts tesseract once
    # in the background one reader per core it was given (8 readers bought little over 4: 1456
    # words in 4.8 s against 5.2 s — 20.10)
    cpus = len(os.sched_getaffinity(0)) or 2
    area = sum(p.width * p.height for p, *_ in jobs)
    k = max(1, min(cpus if BACKGROUND else max(1, cpus // 2), 8, int(area // 150_000) + 1, len(jobs)))
    if os.environ.get("ANGELOS_OCR_DEBUG"):
        sys.stderr.write("area %d k %d\n" % (area, k))
    # about the same amount of picture in each (the biggest pieces first, each to the
    # lightest page)
    parts, load = [[] for _ in range(k)], [0] * k
    for i in sorted(range(len(jobs)), key=lambda i: -jobs[i][0].width * jobs[i][0].height):
        b = load.index(min(load))
        parts[b].append(i)
        load[b] += jobs[i][0].width * jobs[i][0].height
    if k > 1:  # several readers side by side: one thread each is faster than all of them fighting
        env = dict(env, OMP_THREAD_LIMIT="1")
    procs = []
    for part in parts:
        if not part:
            continue
        part.sort()
        width = max(jobs[i][0].width for i in part) + 2 * PAD
        height = sum(jobs[i][0].height + PAD for i in part) + PAD
        sheet = Image.new("L", (width, height), 255)
        slots, y = [], PAD
        for i in part:
            sheet.paste(jobs[i][0], (PAD, y))
            slots.append((y, y + jobs[i][0].height, i))
            y += jobs[i][0].height + PAD
        path = os.path.join(tmp, "page%d.pgm" % len(procs))
        sheet.save(path)
        p = subprocess.Popen(["tesseract", path, "stdout", "-l", langs, "--psm", "4", "-c", "tessedit_create_tsv=1"],
                             stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, env=env)
        procs.append((p, slots))
    for p, slots in procs:
        try:
            outp, _ = p.communicate(timeout=90)
        except subprocess.TimeoutExpired:
            for q, _ in procs:
                q.kill()
            raise
        tops = [sl[0] for sl in slots]
        for row in outp.splitlines()[1:]:
            f = row.split("\t")
            if len(f) < 12 or f[0] != "5" or not f[11].strip():
                continue
            left, top, ww, hh = int(f[6]), int(f[7]), int(f[8]), int(f[9])
            k = bisect.bisect_right(tops, top + hh / 2) - 1
            if k < 0 or top + hh / 2 > slots[k][1] + PAD / 2:
                continue
            y0s, _, i = slots[k]
            _, x0, y0, z = jobs[i]
            try:
                conf = float(f[10])
            except ValueError:
                conf = -1
            segs[i].words.append((x0 + (left - PAD) / z, y0 + (top - y0s) / z, ww / z, hh / z,
                                  f[11].strip(), conf, (int(f[2]), int(f[3]), int(f[4]))))


PAD = 16


def reread(page, segs, langs, env, tmp, target, floor):
    """A word of small text tesseract doubted, in the other alphabet than the rest of its
    segment ("used:" read as "изе" in an English line): read once more in that segment's
    language alone, all of them on one page per language; kept if it is sure this time."""
    from PIL import Image
    have = langs.split("+")
    if "rus" not in have or "eng" not in have:
        return
    todo = {"rus": [], "eng": []}
    # shortcut: small letters only (where the alphabets mix up); bigger text is left as read
    for s in (s for s in segs if s.h < 13):
        cyr = sum(1 for w in s.words if w[5] >= floor and CYR.search(w[4]))
        lat = sum(1 for w in s.words if w[5] >= floor and LAT.search(w[4]))
        if max(cyr, lat) < 2 or max(cyr, lat) < 2 * min(cyr, lat):  # no clear language to read it in
            continue
        lang, other = ("rus", LAT) if cyr > lat else ("eng", CYR)
        todo[lang] += [(s, k) for k, w in enumerate(s.words) if w[5] < floor and len(w[4]) >= 2 and other.search(w[4])]
    H, W = page.shape
    procs = []
    for lang, items in todo.items():
        if not items:
            continue
        pieces = []
        for s, k in items:
            x, y, w, h = s.words[k][:4]
            z = max(1.0, min(4.0, target / max(4.0, s.h)))
            m = max(2, int(0.3 * s.h))
            x0, y0, x1, y1 = max(0, int(x) - m), max(0, int(y) - m), min(W, int(x + w) + 1 + m), min(H, int(y + h) + 1 + m)
            im = Image.fromarray(page[y0:y1, x0:x1])
            pieces.append(im.resize((max(1, round(im.width * z)), max(1, round(im.height * z))), Image.LANCZOS))
        sheet = Image.new("L", (max(p.width for p in pieces) + 2 * PAD, sum(p.height + PAD for p in pieces) + PAD), 255)
        slots, y = [], PAD
        for (s, k), im in zip(items, pieces):
            sheet.paste(im, (PAD, y))
            slots.append((y, y + im.height, s, k))
            y += im.height + PAD
        path = os.path.join(tmp, "again-%s.pgm" % lang)  # one block of lines (psm 4 sees no column in a few words)
        sheet.save(path)
        procs.append((subprocess.Popen(["tesseract", path, "stdout", "-l", lang, "--psm", "6", "-c", "tessedit_create_tsv=1"],
                                       stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, env=env), slots))
    for p, slots in procs:
        outp, _ = p.communicate(timeout=60)
        got = {}
        for row in outp.splitlines()[1:]:
            f = row.split("\t")
            if len(f) < 12 or f[0] != "5" or not f[11].strip():
                continue
            mid = int(f[7]) + int(f[9]) / 2
            for i, (a, b, _, _) in enumerate(slots):
                if a - PAD / 2 <= mid < b + PAD / 2:
                    try:
                        got.setdefault(i, []).append((f[11].strip(), float(f[10])))
                    except ValueError:
                        pass
                    break
        for i, ws in got.items():
            _, _, s, k = slots[i]
            conf = min(c for _, c in ws)
            if conf >= floor:
                w = s.words[k]
                s.words[k] = w[:4] + ("".join(t for t, _ in ws), conf) + w[6:]


# ---- cleaning what was read

LINKISH = re.compile(r"^(https?:|www\.)|\w\.[a-z]{2,}(/|$)", re.I)
ONE_LETTER = set("вискуояаВИСКУОЯАaAI&+-=*/|<>{}()[]$#%@!?:;.,\"'—–→←~^")
# Latin and Cyrillic letters that look the same: a word read in the wrong alphabet
LAT2CYR = dict(zip("ABCEHKMOPTXYaceopxyb", "АВСЕНКМОРТХУасеорхуь"))
CYR2LAT = {v: k for k, v in LAT2CYR.items() if k != "b"}
CYR = re.compile(r"[а-яёА-ЯЁ]")
LAT = re.compile(r"[a-zA-Z]")


def script_fix(words):
    """A word whose letters all exist in both alphabets is written in the alphabet of the
    rest of its line ("HO" in a Russian line is "НО"); a word mixing the two alphabets is
    put in the one most of its letters are in."""
    cyr = sum(1 for w in words if CYR.search(w["t"]) and not LAT.search(w["t"]) and not set(w["t"]) <= set(CYR2LAT) | set("0123456789.,:;!?-«»()\"'"))
    lat = sum(1 for w in words if LAT.search(w["t"]) and not CYR.search(w["t"]) and not set(w["t"]) <= set(LAT2CYR) | set("0123456789.,:;!?-«»()\"'"))
    for w in words:
        t = w["t"]
        c, l = len(CYR.findall(t)), len(LAT.findall(t))
        # a code or a model ("P52", "0xC0000005", "B650") is Latin whatever its line is written in
        if (c or l) and any(ch.isdigit() for ch in t) and all(ch in CYR2LAT or ch in LAT2CYR for ch in CYR.findall(t) + LAT.findall(t)):
            w["t"] = "".join(CYR2LAT.get(ch, ch) for ch in t)
            continue
        if c and l:
            if c >= l and all(ch in LAT2CYR for ch in LAT.findall(t)):
                w["t"] = "".join(LAT2CYR.get(ch, ch) for ch in t)
            elif l > c and all(ch in CYR2LAT for ch in CYR.findall(t)):
                w["t"] = "".join(CYR2LAT.get(ch, ch) for ch in t)
        elif l and not c and cyr > lat and all(ch in LAT2CYR for ch in LAT.findall(t)) and not LINKISH.search(t):
            w["t"] = "".join(LAT2CYR.get(ch, ch) for ch in t)
        elif c and not l and lat > cyr and all(ch in CYR2LAT for ch in CYR.findall(t)):
            w["t"] = "".join(CYR2LAT.get(ch, ch) for ch in t)


def keep_word(t, conf, floor, sure=False):
    """Is this word text? `sure`: its line has words tesseract is sure of, so a long word it
    doubts (code, an id, a path: nothing a dictionary knows) is text too."""
    if not t:
        return False
    alnum = sum(ch.isalnum() for ch in t)
    if LINKISH.search(t):
        return conf >= 10
    if conf < floor and not (sure and len(t) >= 4 and alnum >= 0.5 * len(t)):
        return False
    if len(t) == 1 and t not in ONE_LETTER and not t.isdigit():
        return conf >= 90
    if not alnum:
        # punctuation alone: code and prose have it (=, {, ->), icons read as it too
        return conf >= 60 and len(t) <= 3
    return True


def sure_of(words):
    return any(w[5] >= 85 and sum(ch.isalnum() for ch in w[4]) >= 2 for w in words)


def clean_segment(seg, floor, sure=None):
    """The words of one segment that are text: tesseract's doubts dropped, and the scraps an
    icon at the start or the end turns into (a short word set apart from the rest)."""
    if sure is None:
        sure = sure_of(seg.words)
    ws = [w for w in seg.words if keep_word(w[4], w[5], floor, sure)]
    h = seg.h
    while len(ws) > 1:
        changed = False
        for end in (0, -1):
            w = ws[end]
            nb = ws[1] if end == 0 else ws[-2]
            gap = (nb[0] - (w[0] + w[2])) if end == 0 else (w[0] - (nb[0] + nb[2]))
            t, c = w[4], w[5]
            alnum = sum(ch.isalnum() for ch in t)
            iconish = len(t) <= 2 and gap > 0.55 * h and (c < 70 or (alnum == 0 and c < 85) or (len(t) == 1 and t not in ONE_LETTER))
            # a letter alone before the text, set further apart than a space: an icon
            iconish = iconish or (end == 0 and len(t) == 1 and not t.isdigit() and (gap > 0.75 * h or (t not in ONE_LETTER and c < 95)))
            if iconish or (alnum == 0 and c < 60 and gap > 0.4 * h):
                ws.pop(end)
                changed = True
                break
        if not changed:
            break
    if not ws:
        return []
    # a segment of one scrap: an icon, a bit of a picture
    if len(ws) == 1:
        t, c = ws[0][4], ws[0][5]
        alnum = sum(ch.isalnum() for ch in t)
        if (alnum == 0 and (c < 90 or len(t) < 2)) or (alnum == 1 and not t.isdigit()) or (len(t) <= 2 and c < 80):
            return []
    # all doubtful and short: a picture read as letters (a stroke read as "|" or one sure
    # character beside them does not vouch for them)
    lett = [w for w in ws if any(ch.isalnum() for ch in w[4])]
    if lett and not any(w[5] >= 70 and len(w[4]) >= 2 for w in lett) and \
            sum(len(w[4]) for w in lett) <= 4 * len(lett):
        return []
    # nothing but marks one character each ("~ -"): grain, a twig
    if not lett and all(len(w[4]) < 2 for w in ws):
        return []
    return ws


# the read behind the overlay (`--background`: the whole frame, the piece round the pointer)
BACKGROUND = False


def background():
    """Keep the read off the pointer's way: the last half of the physical cores, one thread each,
    at the idle priority. Eight tesseracts side by side made the pointer heavy for the first
    seconds (20.10): nice alone left them on the SMT siblings of the cores niri draws on, and the
    sched_ext scheduler weighs nice lightly."""
    try:
        groups = {}
        for c in os.sched_getaffinity(0):
            with open("/sys/devices/system/cpu/cpu%d/topology/thread_siblings_list" % c) as f:
                key = f.read().strip()
            groups[key] = min(groups.get(key, c), c)
        firsts = sorted(groups.values())
        os.sched_setaffinity(0, firsts[len(firsts) // 2:] or firsts)
    except (OSError, ValueError):
        pass
    try:
        os.sched_setscheduler(0, os.SCHED_IDLE, os.sched_param(0))
    except (OSError, AttributeError):
        pass


def ocr(args):
    global BACKGROUND
    if "--background" in args:
        args = [a for a in args if a != "--background"]
        BACKGROUND = True
        background()
    path = args[0]
    poly = []
    zoom = 0
    box = []
    rest = args[1:]
    i = 0
    while i < len(rest):
        if rest[i] == "--poly":
            poly = [tuple(float(v) for v in p.split(",")) for p in rest[i + 1].split(";") if p]
            i += 2
        elif rest[i] == "--zoom":
            zoom = int(rest[i + 1])
            i += 2
        else:
            box.append(float(rest[i]))
            i += 1
    if not shutil.which("tesseract"):
        return out({"error": "tesseract"})
    img = read_ppm(path)
    piece = len(box) == 4
    if piece:
        w, h, px, (ox, oy) = crop(img, *box)
    else:
        w, h, px = img
        ox = oy = 0
    env = tess_env()
    langs = languages(env) or "eng"
    try:
        import numpy as np
        from PIL import Image  # noqa: F401
    except ImportError:
        return ocr_plain(w, h, px, ox, oy, piece, zoom, poly, langs, env)
    page = ink_page(w, h, px)
    gray = (np.frombuffer(px, np.uint8).reshape(h, w, 3) @ np.array([77, 150, 29], np.uint16) >> 8).astype(np.int16)
    blocks = layout(page < 128, gray, page)
    segs = [s for b in blocks for l in b.lines for s in l.segs]
    with tempfile.TemporaryDirectory(prefix="angelos-circle-") as tmp:
        try:
            read_segments(page, segs, langs, env, zoom, tmp, TARGET if piece else TARGET_WHOLE)
            floor = 35 if piece else 50
            reread(page, segs, langs, env, tmp, TARGET if piece else TARGET_WHOLE, floor)
        except subprocess.TimeoutExpired:
            return out({"error": "timeout"})
    words = []
    for bi, b in enumerate(blocks):
        para, last = 0, None
        for li, ln in enumerate(b.lines):
            if last is not None and (ln.y0 - last.y1 > 0.8 * max(ln.h, last.h) or max(ln.h, last.h) > 2.2 * min(ln.h, last.h)):
                para += 1
            got = []
            sure = sure_of([w for s in ln.segs for w in s.words])
            for s in ln.segs:
                ws = clean_segment(s, floor, sure)
                # a segment of several lines: tesseract's own line numbers split it
                for x, y, ww, hh, t, c, tl in ws:
                    got.append((tl if s.multi else (0, 0, 0), x, y, ww, hh, t, c, id(s)))
            if not got:
                continue
            last = ln
            # one line, or the lines of a multi-line segment one after another
            sub = sorted({g[0] for g in got})
            for k, key in enumerate(sub):
                row = sorted([g for g in got if g[0] == key], key=lambda g: g[1]) if key == (0, 0, 0) else [g for g in got if g[0] == key]
                lid = "%d.%d.%d" % (bi + 1, para + 1, li * 10 + k + 1)
                ws = []
                for _, x, y, ww, hh, t, c, _ in row:
                    ws.append({"x": round(ox + x, 1), "y": round(oy + y, 1), "w": round(ww, 1), "h": round(hh, 1), "t": t,
                               "line": lid, "conf": round(c), "block": bi + 1, "para": para + 1})
                script_fix(ws)
                words.extend(ws)
    words = tidy(words)
    if poly:
        words = [w for w in words if inside(w["x"] + w["w"] / 2, w["y"] + w["h"] / 2, poly)]
    out({"words": words, "text": join_words(words), "langs": langs})


def tidy(words):
    """The words as the overlay lights and picks them: a place read twice (overlapping pieces
    of a line) once, the surer reading; a line over two rows split; every word of a row as tall
    as the row (the marks stand in a line) and none over its neighbour."""
    def over(a, b):
        """The same place read twice: overlapping, and one reading a piece of the other (or
        no letter at all) — not a neighbour whose box tesseract drew too long."""
        ix = min(a["x"] + a["w"], b["x"] + b["w"]) - max(a["x"], b["x"])
        iy = min(a["y"] + a["h"], b["y"] + b["h"]) - max(a["y"], b["y"])
        if ix <= 0.5 * min(a["w"], b["w"]) or iy <= 0.5 * min(a["h"], b["h"]):
            return False
        p, q = ("".join(ch for ch in w["t"].lower() if ch.isalnum()) for w in (a, b))
        return not p or not q or p in q or q in p or p[-3:] == q[-3:] or p[:3] == q[:3]
    rank = lambda w: (w.get("conf", 0) >= 60, len(w["t"]), w.get("conf", 0))
    keep = []
    for w in sorted(words, key=rank, reverse=True):
        if not any(over(w, k) for k in keep):
            keep.append(w)
    kept = {id(w) for w in keep}
    words = [w for w in words if id(w) in kept]
    lines, order = {}, []
    for w in words:
        if w["line"] not in lines:
            lines[w["line"]] = []
            order.append(w["line"])
        lines[w["line"]].append(w)
    rows = []
    for lid in order:
        # a "line" over two rows (tesseract's own line of a piece two lines tall): one per row
        ws = sorted(lines[lid], key=lambda w: w["y"] + w["h"] / 2)
        groups = [[ws[0]]]
        for w in ws[1:]:
            g = groups[-1]
            mid = sum(q["y"] + q["h"] / 2 for q in g) / len(g)
            if w["y"] + w["h"] / 2 - mid > 0.5 * max(w["h"], max(q["h"] for q in g)):
                groups.append([w])
            else:
                g.append(w)
        rows += [(lid if len(groups) == 1 else "%s.%d" % (lid, i), g) for i, g in enumerate(groups)]
    # each row's band: the middle of its words' tops and bottoms (a box tesseract drew into the
    # next row does not stretch it), rows that still overlap cut halfway
    med = lambda v: sorted(v)[len(v) // 2]
    band = [[med([w["y"] for w in g]), med([w["y"] + w["h"] for w in g]), min(w["x"] for w in g), max(w["x"] + w["w"] for w in g)]
            for _, g in rows]
    for a in band:
        for b in band:
            if a is not b and a[0] < b[0] < a[1] and min(a[3], b[3]) > max(a[2], b[2]):
                a[1] = b[0] = (a[1] + b[0]) / 2
    out = []
    for (lid, row), (y0, y1, _, _) in zip(rows, band):
        row = sorted(row, key=lambda w: w["x"])
        glued = [dict(w) for w in row]
        for a, b in zip(glued, glued[1:]):
            if a["x"] + a["w"] > b["x"]:
                # a box drawn on over the next word ends where that word starts
                cut = round(b["x"] if b["x"] > a["x"] + 0.5 * a["w"] else (a["x"] + a["w"] + b["x"]) / 2, 1)
                a["w"] = round(max(1, cut - a["x"]), 1)
                b["w"] = round(max(1, b["x"] + b["w"] - cut), 1)
                b["x"] = cut
        for w in glued:
            w["y"], w["h"], w["line"] = round(y0, 1), round(y1 - y0, 1), lid
        out += glued
    return out


def ocr_plain(w, h, px, ox, oy, piece, zoom, poly, langs, env):
    """No numpy/Pillow: the old way, one grey page through tesseract's own layout."""
    if not zoom:
        zoom = 3 if h < 80 else 2 if w * h < 900_000 else 1
    w2, h2, px2 = upscale(w, h, px, zoom)
    g2 = gray_for_ocr(w2, h2, px2)
    with tempfile.TemporaryDirectory(prefix="angelos-circle-") as tmp:
        src = os.path.join(tmp, "in.pgm")
        write_pgm(src, w2, h2, g2)
        try:
            r = subprocess.run(["tesseract", src, "stdout", "-l", langs, "--psm", "3" if piece else "11", "-c", "tessedit_create_tsv=1"],
                               capture_output=True, text=True, env=env, timeout=60)
        except subprocess.TimeoutExpired:
            return out({"error": "timeout"})
    words = []
    for row in r.stdout.splitlines()[1:]:
        f = row.split("\t")
        if len(f) < 12 or f[0] != "5":
            continue
        t = f[11].strip()
        try:
            conf = float(f[10])
        except ValueError:
            conf = -1
        if not keep_word(t, conf, 30 if piece else 60):
            continue
        x, y, ww, hh = ox + int(f[6]) / zoom, oy + int(f[7]) / zoom, int(f[8]) / zoom, int(f[9]) / zoom
        if poly and not inside(x + ww / 2, y + hh / 2, poly):
            continue
        words.append({"x": round(x, 1), "y": round(y, 1), "w": round(ww, 1), "h": round(hh, 1), "t": t,
                      "line": "%s.%s.%s" % (f[2], f[3], f[4]), "conf": round(conf)})
    out({"words": words, "text": join_words(words), "langs": langs})


def inside(px, py, poly):
    hit = False
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        if (y1 > py) != (y2 > py) and px < (x2 - x1) * (py - y1) / ((y2 - y1) or 1e-9) + x1:
            hit = not hit
    return hit


def join_words(words):
    """The text to copy: words of a line by spaces, lines by line breaks; wrapped prose by
    spaces (a word broken by a hyphen glued back), and a blank line after a paragraph of it."""
    lines = []
    for w in words:
        if not lines or w["line"] != lines[-1][0]:
            lines.append((w["line"], w.get("block"), w.get("para"), []))
        lines[-1][3].append(w)
    out = []
    wrapped = False
    for i, (lid, b, p, ws) in enumerate(lines):
        t = " ".join(w["t"] for w in ws)
        if i:
            pb, pp = lines[i - 1][1], lines[i - 1][2]
            if b is None or (b, p) != (pb, pp):
                out.append("\n\n" if wrapped else "\n")
                wrapped = False
            elif prose(lines, i - 1) and re.match(r"[a-zа-яё(«\"]", t):
                wrapped = True
                if re.search(r"[^\W\d_]-$", out[-1]):
                    out[-1] = out[-1][:-1]
                else:
                    out.append(" ")
            else:
                out.append("\n")
        out.append(t)
    return "".join(out)


def prose(lines, i):
    """A line of running text that wraps on to the next: words mostly letters, about as wide
    as the paragraph's widest line."""
    ws = lines[i][3]
    letters = sum(sum(ch.isalpha() for ch in w["t"]) for w in ws)
    chars = sum(len(w["t"]) for w in ws)
    if len(ws) < 4 or letters < 0.75 * chars:
        return False
    para = [l for l in lines if l[1] == lines[i][1] and l[2] == lines[i][2]]
    width = lambda l: max(w["x"] + w["w"] for w in l[3]) - min(w["x"] for w in l[3])
    return width(lines[i]) >= 0.75 * max(width(l) for l in para)


# ---------------------------------------------------------------- translate

def translate(args):
    text = args[0] if args else sys.stdin.read()
    to = "auto"
    if "--to" in args:
        to = args[args.index("--to") + 1]
    if to == "auto":
        # mostly Cyrillic → English, anything else → Russian
        letters = re.findall(r"[^\W\d_]", text)
        cyr = sum(1 for c in letters if "Ѐ" <= c <= "ӿ")
        to = "en" if letters and cyr / len(letters) > 0.5 else "ru"
    trans = shutil.which("trans")
    if not trans:
        return out({"error": "trans", "to": to})
    try:
        r = subprocess.run([trans, "-b", "-no-ansi", "-no-autocorrect", ":" + to, text],
                           capture_output=True, text=True, timeout=30)
    except subprocess.TimeoutExpired:
        return out({"error": "timeout", "to": to})
    res = r.stdout.strip()
    if r.returncode != 0 or not res:
        return out({"error": (r.stderr.strip() or "trans")[:200], "to": to})
    out({"text": res, "to": to})


# ---------------------------------------------------------------- pictures out

def crop_png(args):
    img = read_ppm(args[0])
    w, h, px, _ = crop(img, *map(float, args[1:5]))
    with open(args[5], "wb") as f:
        f.write(png_bytes(w, h, px))
    out({"png": args[5], "w": w, "h": h})


LENS_PAGE = """<!doctype html><meta charset="utf-8"><title>Google Lens…</title>
<body style="background:#111;color:#ccc;font:16px sans-serif;display:grid;place-items:center;height:100vh;margin:0">
<form id="f" method="post" enctype="multipart/form-data" action="https://lens.google.com/v3/upload?ep=ccm&amp;st=%(ts)d">
<input type="file" name="encoded_image" id="i" hidden></form><p>Google Lens…</p>
<script>
const b = atob("%(b64)s"), a = new Uint8Array(b.length);
for (let k = 0; k < b.length; k++) a[k] = b.charCodeAt(k);
const dt = new DataTransfer();
dt.items.add(new File([a], "circle.png", {type: "image/png"}));
document.getElementById("i").files = dt.files;
document.getElementById("f").submit();
</script>"""


def lens(args):
    import time
    img = read_ppm(args[0])
    w, h, px, _ = crop(img, *map(float, args[1:5]))
    os.makedirs(RUNTIME, exist_ok=True)
    page = os.path.join(RUNTIME, "circle-lens.html")
    with open(page, "w") as f:
        f.write(LENS_PAGE % {"b64": base64.b64encode(png_bytes(w, h, px)).decode(), "ts": int(time.time() * 1000)})
    out({"page": page})


YT = re.compile(r"^(https?://)?(www\.|m\.)?(youtube\.com/(watch\?(.*&)?v=|shorts/|live/|embed/)|youtu\.be/)([\w-]{11})")
LOOKALIKE = ["Il1i", "O0oQD", "-_", "S5s", "B8", "Z2z", "g9q", "Uu", "Vv", "Ww", "Xx", "Cc", "Kk", "Pp"]


def variants(vid, most=2):
    """The id's look-alikes by how many letters change: [[one change…], [two changes…]]."""
    import itertools
    alt = {}
    for i, ch in enumerate(vid):
        g = next((g for g in LOOKALIKE if ch in g), "")
        if g:
            alt[i] = [c for c in g if c != ch]
    rounds = []
    for k in range(1, most + 1):
        r = []
        for pos in itertools.combinations(sorted(alt), k):
            for repl in itertools.product(*(alt[i] for i in pos)):
                v = list(vid)
                for i, c in zip(pos, repl):
                    v[i] = c
                r.append("".join(v))
        rounds.append(r)
    return rounds


def yt_exists(vid, timeout=4):
    import urllib.error
    import urllib.request
    url = "https://www.youtube.com/oembed?format=json&url=" + urllib.parse.quote("https://www.youtube.com/watch?v=" + vid)
    try:
        with urllib.request.urlopen(url, timeout=timeout) as r:
            return r.status == 200
    except urllib.error.HTTPError as e:
        if e.code in (400, 404):
            return False
        return True if e.code in (401, 403) else None  # 401/403: there, just not embeddable; 429/5xx: can't tell
    except OSError:
        return None  # no network: can't tell


def fix_youtube(url, exists=yt_exists):
    m = YT.match(url)
    if not m:
        return url, False
    vid = m.group(6)
    if exists(vid) is not False:
        return url, False
    from concurrent.futures import ThreadPoolExecutor
    # shortcut: one and two changes only (≈ a few hundred asks at most), a third is a guess
    with ThreadPoolExecutor(12) as pool:
        for cands in variants(vid):
            cands = cands[:400]
            answers = list(pool.map(exists, cands))
            # a busy answer (429, a timeout) asked once more, one by one
            answers = [exists(c) if a is None else a for c, a in zip(cands, answers)]
            for c, ok in zip(cands, answers):
                if ok:
                    return url[:m.start(6)] + c + url[m.end(6):], True
    return url, False


def fixlink(args):
    url, fixed = fix_youtube(args[0])
    out({"url": url, "fixed": fixed})


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    cmd, args = sys.argv[1], sys.argv[2:]
    try:
        {"ocr": ocr, "translate": translate, "crop": crop_png, "lens": lens, "fixlink": fixlink}[cmd](args)
    except KeyError:
        print(__doc__)
        return 2
    except (OSError, ValueError, IndexError) as e:
        out({"error": str(e)})
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
