#!/usr/bin/env python3
"""The smart screenshot's auto-selection (modules/circle/CircleOverlay, like Circle to Search on a
Pixel): on a frozen frame, the places one click should pick — windows, pictures (photos, video
frames, stickers, avatars), blocks of text and UI pieces (panels, cards, bars, buttons).

  capture_regions.py <frame.ppm|png> [--windows '[{x,y,w,h,title,app_id,focused,col,row}]'] [--scale S]
      one JSON line: {"regions":[{"x","y","w","h","kind":"window|image|text|ui","score","label"}],
      "windows":[{"x","y","w","h","title","app_id","focused"}]} in frame pixels, regions best
      first, at most 60 (every window placed is among them); windows given are in logical pixels
      (times S = frame pixels), a tiled one with x/y null and its niri column/row is placed off the
      frame (place); a frame that cannot be read (or anything else going wrong):
      {"error":"…","regions":[]} and exit code 1

How: the frame is cut into 8 px cells; each cell counts its soft and its sharp steps of brightness,
how many of them go both up and down (texture, not a shadow or a gradient) and in how many pixel
rows / columns they lie (a border or a separator is one or two). Inside every window (the whole
frame when none is given):
  - grounds: quiet cells joined to neighbours of nearly the same colour; the biggest is the
    window's own, the others are panels, cards, bars and buttons ("ui"), grown to their edge;
  - pictures: textured cells joined over small gaps, not across a ground, with the flat patches
    inside them (the dark of a film); then cut along stripes of the colour around them (pictures
    side by side) and snapped to their edges; a thin ring round a flat block (a shadow) is none;
  - text: sharp cells that are neither pictures nor borders, joined into lines and paragraphs
    where the empty pixels between their strokes are few (14 px across, 13 down, times S); the
    box is cut to the pixel.
numpy only (Pillow just for a frame that is not a binary PPM), no network. ~40–60 ms of work on
1080×1920 or 1920×1080; Python and numpy starting cost ~60–70 ms more (an idle machine).
"""
import json
import sys

import numpy as np

C = 8                       # cell size, frame pixels
MAX = 60
SOFT, SHARP = 3, 40         # brightness step (0..255) above which a pixel is soft / sharp
MIXED = 3                   # steps both ways (of 128) that make a cell textured


def load(path):
    """The frame as an (h, w, 3) uint8 array: a binary PPM (grim -t ppm) read directly, anything
    else through Pillow."""
    with open(path, "rb") as f:
        raw = f.read()
    if raw[:2] == b"P6":
        vals, i = [], 2
        while len(vals) < 3:
            while raw[i:i + 1].isspace():
                i += 1
            if raw[i:i + 1] == b"#":
                i = raw.index(b"\n", i) + 1
                continue
            j = i
            while j < len(raw) and not raw[j:j + 1].isspace():
                j += 1
            vals.append(int(raw[i:j]))
            i = j
        w, h, top = vals
        if top != 255 or w < 1 or h < 1:
            raise ValueError("unsupported PPM")
        return np.frombuffer(raw, np.uint8, w * h * 3, i + 1).reshape(h, w, 3)
    import io
    from PIL import Image
    return np.asarray(Image.open(io.BytesIO(raw)).convert("RGB"))


def cells(px):
    """Per cell: soft and sharp step counts (0..64), steps both ways, line-likeness, the empty
    pixel rows / columns round its strokes, mean colour and chroma (from 16 samples); and the
    pixel step maps for snapping boxes to edges."""
    gh, gw = px.shape[0] // C, px.shape[1] // C
    a = px[:gh * C, :gw * C]
    g = ((a[..., 0].astype(np.uint16) + a[..., 1] + a[..., 1] + a[..., 2]) >> 2).astype(np.uint8)
    d = np.zeros_like(g)
    np.subtract(np.maximum(g[:, 1:], g[:, :-1]), np.minimum(g[:, 1:], g[:, :-1]), out=d[:, 1:])
    dy = np.maximum(g[1:], g[:-1])
    dy -= np.minimum(g[1:], g[:-1])
    np.maximum(d[1:], dy, out=d[1:])

    def rows(m):
        # per pixel row of each cell: 8 bools side by side are one uint64; times 0x0101… adds
        # its bytes into the top byte
        v = (m.view(np.uint64) * np.uint64(0x0101010101010101)) >> np.uint64(56)
        return v.astype(np.uint8).reshape(m.shape[0] // C, C, m.shape[1] // C)
    sh, st = d > SHARP, d > SOFT
    v = rows(sh)
    sharp = v.sum(axis=1, dtype=np.uint8)
    va = rows(st)
    steps = va.sum(axis=1, dtype=np.uint8)
    soft = steps - sharp
    # texture (grain, detail) steps up and down; a shadow or a gradient only one way
    s16 = g.astype(np.int16)
    mixed = np.zeros((gh, gw), np.uint8)
    for diff, cut in ((s16[:, 1:] - s16[:, :-1], (slice(None), slice(1, None))), (s16[1:] - s16[:-1], (slice(1, None), slice(None)))):
        up, dn = np.zeros_like(st), np.zeros_like(st)
        up[cut], dn[cut] = diff > SOFT, diff < -SOFT
        mixed += np.minimum(rows(up).sum(axis=1, dtype=np.uint8), rows(dn).sum(axis=1, dtype=np.uint8))
    # straight lines (borders, separators, soft shadows): all the steps of a cell in at most three
    # pixel rows (columns); glyphs and photos spread over many
    hline = ((va > 0).sum(axis=1) <= 3) & (steps >= 6)
    vline = ((rows(np.ascontiguousarray(st.T)) > 0).sum(axis=1).T <= 3) & (steps >= 6)
    u = rows(np.ascontiguousarray(sh.T)) > 0
    # empty pixel rows / columns before and after a cell's strokes (to measure gaps exactly)
    o = v > 0
    edges = {}
    for name, m, ax in (("top", o, 1), ("left", u, 1)):
        has = m.any(axis=ax)
        first = np.where(has, m.argmax(axis=ax), C).astype(np.int16)
        last = np.where(has, m[:, ::-1].argmax(axis=ax), C).astype(np.int16)
        if name == "left":
            first, last = first.T, last.T
        edges[name], edges["bottom" if name == "top" else "right"] = first, last
    s = a[1::2, 1::2]
    r, gg, b = (s[..., i].astype(np.int16) for i in range(3))
    chroma = np.maximum(np.maximum(r, gg), b) - np.minimum(np.minimum(r, gg), b)

    def mean(x):
        return x.reshape(gh, C // 2, gw, C // 2).sum(axis=3).sum(axis=1) * (4.0 / (C * C))
    return {**edges, "px": a, "step": st, "edge": sh, "soft": soft, "mixed": mixed, "sharp": sharp, "hline": hline, "vline": vline, "mean": np.stack([mean(r), mean(gg), mean(b)], axis=-1),
            "chroma": mean(chroma)}


def components(right, down):
    """Connected cells of a grid, given which cells join their right / lower neighbour: a label
    per cell. Runs along rows, then the runs that touch across rows joined by union-find."""
    h, w = right.shape[0], down.shape[1]
    brk = np.ones((h, w), bool)
    brk[:, 1:] = ~right
    run = np.cumsum(brk.ravel()).reshape(h, w) - 1
    n = int(run[-1, -1]) + 1
    pairs = np.unique(run[:-1][down].astype(np.int64) * n + run[1:][down])
    parent = list(range(n))
    for a, b in zip((pairs // n).tolist(), (pairs % n).tolist()):
        while parent[a] != a:
            parent[a] = a = parent[parent[a]]
        while parent[b] != b:
            parent[b] = b = parent[parent[b]]
        if a != b:
            parent[max(a, b)] = min(a, b)
    root = np.array(parent, np.int32)
    while True:
        nxt = root[root]
        if np.array_equal(nxt, root):
            return root[run]
        root = nxt


def label(mask):
    """4-connected components of a boolean grid: 0 = background, else a component label."""
    lab = components(mask[:, :-1] & mask[:, 1:], mask[:-1] & mask[1:])
    return np.where(mask, lab + 1, 0)


def boxes(lab):
    """Each component's cell box and cell count: [(y0, x0, y1, x1, n, label)] (y1/x1 exclusive)."""
    ys, xs = np.nonzero(lab)
    if not len(ys):
        return []
    ls = lab[ys, xs]
    order = np.argsort(ls, kind="stable")
    ls, ys, xs = ls[order], ys[order], xs[order]
    starts = np.flatnonzero(np.r_[True, ls[1:] != ls[:-1]])
    ends = np.r_[starts[1:], len(ls)]
    y0, y1 = np.minimum.reduceat(ys, starts), np.maximum.reduceat(ys, starts) + 1
    x0, x1 = np.minimum.reduceat(xs, starts), np.maximum.reduceat(xs, starts) + 1
    return list(zip(y0.tolist(), x0.tolist(), y1.tolist(), x1.tolist(), (ends - starts).tolist(), ls[starts].tolist()))


def grow(mask, ry, rx):
    """Dilate a boolean grid by ry cells up/down and rx cells left/right."""
    h, w = mask.shape
    out = mask.copy()
    for d in range(1, rx + 1):
        out[:, d:] |= mask[:, :-d]
        out[:, :-d] |= mask[:, d:]
    if ry:
        m = out.copy()
        for d in range(1, ry + 1):
            out[d:] |= m[:-d]
            out[:-d] |= m[d:]
    return out


def iou(a, b):
    x0, y0 = max(a["x"], b["x"]), max(a["y"], b["y"])
    x1, y1 = min(a["x"] + a["w"], b["x"] + b["w"]), min(a["y"] + a["h"], b["y"] + b["h"])
    inter = max(0, x1 - x0) * max(0, y1 - y0)
    return inter / float(a["w"] * a["h"] + b["w"] * b["h"] - inter or 1)


def cover(a, b):
    """How much of a's area lies in b (0..1)."""
    ix = max(0, min(a["x"] + a["w"], b["x"] + b["w"]) - max(a["x"], b["x"]))
    iy = max(0, min(a["y"] + a["h"], b["y"] + b["h"]) - max(a["y"], b["y"]))
    return ix * iy / max(1, a["w"] * a["h"])


def spread(seg, steps):
    """Give cells without a ground (-1) the ground of a neighbour, `steps` cells deep."""
    seg = seg.copy()
    for _ in range(steps):
        free = seg < 0
        if not free.any():
            break
        for src, dst in (((slice(None), slice(1, None)), (slice(None), slice(None, -1))),
                         ((slice(None), slice(None, -1)), (slice(None), slice(1, None))),
                         ((slice(1, None), slice(None)), (slice(None, -1), slice(None))),
                         ((slice(None, -1), slice(None)), (slice(1, None), slice(None)))):
            take = free[dst] & (seg[src] >= 0)
            seg[dst] = np.where(take, seg[src], seg[dst])
            free = seg < 0
    return seg


def runs(m, k):
    """Cells that belong to a horizontal run of at least k set cells."""
    out = np.zeros_like(m)
    w = m.shape[1]
    if w < k:
        return out
    start = m[:, :w - k + 1].copy()
    for i in range(1, k):
        start &= m[:, i:w - k + 1 + i]
    for i in range(k):
        out[:, i:w - k + 1 + i] |= start
    return out


def joins(ink, wall, lead, trail, gap):
    """Along axis 0: which ink cells join the next one — at most `gap` empty pixels between their
    strokes (trail of the first + lead of the second, + 8 for one empty cell between, which must
    not be a border); returns the joins (n-1, m) and the empty cells that now carry a join."""
    n = ink.shape[0]
    j = ink[:-1] & ink[1:] & (trail[:-1] + lead[1:] <= gap)
    via = np.zeros_like(ink)
    if n > 2:
        ok = ink[:-2] & ~ink[1:-1] & ~wall[1:-1] & ink[2:] & (trail[:-2] + C + lead[2:] <= gap)
        via[1:-1] = ok
        j[:-1] |= ok
        j[1:] |= ok
    return j, via


def snap(step, y0, x0, y1, x1):
    """A cell-aligned box (pixels) with each side moved to its edge — the first pixel row /
    column (from outside in) within 6 px either way where most of the side is a step of
    brightness."""
    H, W = step.shape
    m = C // 2 + 2

    def edge(prof, a, inward):
        idx = range(len(prof)) if inward else range(len(prof) - 1, -1, -1)
        return next((a + i for i in idx if prof[i] >= 0.5), None)
    ys = slice(y0 + C, max(y0 + C + 1, y1 - C))
    xs = slice(x0 + C, max(x0 + C + 1, x1 - C))
    a = max(0, y0 - m)
    ny0 = edge(step[a:y0 + m + 1, xs].mean(axis=1), a, True)
    a = max(0, y1 - m)
    ny1 = edge(step[a:min(H, y1 + m + 1), xs].mean(axis=1), a, False)
    a = max(0, x0 - m)
    nx0 = edge(step[ys, a:x0 + m + 1].mean(axis=0), a, True)
    a = max(0, x1 - m)
    nx1 = edge(step[ys, a:min(W, x1 + m + 1)].mean(axis=0), a, False)
    y0, x0 = ny0 if ny0 is not None else y0, nx0 if nx0 is not None else x0
    y1, x1 = ny1 if ny1 is not None and ny1 > y0 else y1, nx1 if nx1 is not None and nx1 > x0 else x1
    return y0, x0, y1, x1


def grow_to_edge(step, y0, x0, y1, x1, oy0, ox0, oy1, ox1):
    """A ground's quiet box (pixels) grown out to its own edge — the first pixel row / column
    outside it, within a cell and a bit, where most of the side is a step of brightness; the outer
    box (o…) where no edge is found."""
    H, W = step.shape
    reach = C + C // 2
    ys = slice(y0 + C // 2, max(y0 + C // 2 + 1, y1 - C // 2))
    xs = slice(x0 + C // 2, max(x0 + C // 2 + 1, x1 - C // 2))

    def first(prof, rows):
        return next((r for r, p in zip(rows, prof) if p >= 0.5), None)
    a = max(0, y0 - reach)
    top = first(step[a:y0, xs].mean(axis=1)[::-1], range(y0 - 1, a - 1, -1))
    a = min(H, y1 + reach)
    bottom = first(step[y1:a, xs].mean(axis=1), range(y1, a))
    a = max(0, x0 - reach)
    left = first(step[ys, a:x0].mean(axis=0)[::-1], range(x0 - 1, a - 1, -1))
    a = min(W, x1 + reach)
    right = first(step[ys, x1:a].mean(axis=0), range(x1, a))
    return (oy0 if top is None else top, ox0 if left is None else left,
            oy1 if bottom is None else bottom, ox1 if right is None else right)


def split(f, y0, x0, y1, x1, depth=0):
    """A picture box (pixels) trimmed and cut along flat stripes of the colour around it, at least
    3 px wide (pictures side by side, a button row): [(y0, x0, y1, x1)]."""
    px, step = f["px"], f["step"]
    H, W = step.shape
    ring = np.concatenate([px[max(0, y0 - 2), x0:x1], px[min(H - 1, y1 + 1), x0:x1],
                           px[y0:y1, max(0, x0 - 2)], px[y0:y1, min(W - 1, x1 + 1)]]).astype(np.int16)
    if not len(ring) or y1 - y0 < 8 or x1 - x0 < 8:
        return [(y0, x0, y1, x1)]
    around = np.median(ring, axis=0)
    for axis in (1, 0):
        st, col = step[y0:y1, x0:x1], px[y0:y1, x0:x1]
        flat = st.mean(axis=axis) < 0.02
        if not flat.any():
            continue
        idx = np.flatnonzero(flat)        # (the colour only of the flat rows: big boxes stay cheap)
        lines = col[idx, ::2] if axis == 1 else col[::2, idx].transpose(1, 0, 2)
        flat[idx] = np.abs(lines.mean(axis=1) - around).sum(axis=1) <= 18
        if not flat.any():
            continue
        keep = np.flatnonzero(~flat)
        if not len(keep):
            return []
        # pieces: runs of non-flat rows split by flat runs of 3 or more
        cuts, start = [], keep[0]
        for a, b in zip(keep[:-1], keep[1:]):
            if b - a > 3:
                cuts.append((start, a + 1))
                start = b
        cuts.append((start, keep[-1] + 1))
        if len(cuts) == 1 and cuts[0] == (0, len(flat)):
            continue
        out = []
        for a, b in cuts:
            box = (y0 + a, x0, y0 + b, x1) if axis == 1 else (y0, x0 + a, y1, x0 + b)
            out += split(f, *box, depth + 1) if depth < 4 else [box]
        return out
    return [(y0, x0, y1, x1)]


def analyse(f, y0, x0, y1, x1, scale=1.0):
    """The regions inside one container (cell box): pictures, text blocks, UI pieces."""
    soft, sharp, mean, chroma, hline, vline = (f[k][y0:y1, x0:x1] for k in ("soft", "sharp", "mean", "chroma", "hline", "vline"))
    h, w = soft.shape
    if h < 3 or w < 3:
        return []
    out = []
    soft, sharp = soft.astype(np.int16), sharp.astype(np.int16)
    quiet = (sharp <= 1) & (soft <= 16)
    # borders, separators and shadows: line cells in runs of three or more
    line = runs(hline, 3) | runs(vline.T, 3).T
    mixed = f["mixed"][y0:y1, x0:x1]
    photo = ((soft >= 16) & (soft >= sharp) & (mixed >= MIXED) | (chroma > 50) & (soft + sharp >= 16)) & ~line

    # grounds: quiet cells joined to quiet neighbours of nearly the same colour
    close_r = quiet[:, :-1] & quiet[:, 1:] & (np.abs(mean[:, :-1] - mean[:, 1:]).sum(axis=2) <= 18)
    close_d = quiet[:-1] & quiet[1:] & (np.abs(mean[:-1] - mean[1:]).sum(axis=2) <= 18)
    lab = components(close_r, close_d)
    size = np.bincount(lab[quiet], minlength=h * w)
    seg = np.where(quiet & (size[lab] >= 4), lab, -1)
    ground = int(size.argmax()) if size.max() >= 4 else -1
    owner = spread(seg, 2)
    sboxes = {k: b for *b, k in boxes(np.where(owner >= 0, owner + 1, 0))}
    qboxes = {k: b for *b, k in boxes(seg + 1)}

    # pictures: soft busy cells, closed over small gaps; dark flat patches inside are taken in
    taken = np.zeros((h, w), bool)
    # (never across a ground or panel: pictures in a row stay apart)
    plab = label(grow(photo, 1, 1) & ~(quiet & (size[lab] >= 30)))
    for by0, bx0, by1, bx1, n, k in boxes(plab):
        core = photo[by0:by1, bx0:bx1] & (plab[by0:by1, bx0:bx1] == k)
        if core.sum() < 8:
            continue
        ys, xs = np.nonzero(core)
        by0, bx0, by1, bx1 = by0 + int(ys.min()), bx0 + int(xs.min()), by0 + int(ys.max()) + 1, bx0 + int(xs.max()) + 1
        # flat patches inside it (the dark parts of a film) are its own
        for s in np.unique(owner[max(0, by0 - 1):by1 + 1, max(0, bx0 - 1):bx1 + 1]):
            if s < 0 or s == ground or (s + 1) not in sboxes:
                continue
            sy0, sx0, sy1, sx1, sn = sboxes[s + 1]
            if sy0 >= by0 - 2 and sy1 <= by1 + 2 and sx0 >= bx0 - 2 and sx1 <= bx1 + 2:
                by0, bx0, by1, bx1 = min(by0, sy0), min(bx0, sx0), max(by1, sy1), max(bx1, sx1)
        bh, bw = by1 - by0, bx1 - bx0
        share = photo[by0:by1, bx0:bx1].mean()
        # (a thin ring of busy cells round a flat block is a shadow or a border, not a picture)
        ring = min(bh, bw) >= 6 and core.sum() < 1.5 * (bh + bw)
        # a sparse one (a dark film) only where its closed cells fill its box, not a chain of
        # busy bits running across panels
        dense = share >= 0.3 or share >= 0.2 and (plab[by0:by1, bx0:bx1] == k).mean() >= 0.45
        if bh >= 4 and bw >= 4 and dense and not ring and bh * bw < 0.9 * h * w:
            taken[by0:by1, bx0:bx1] = True
            box = snap(f["step"], (y0 + by0) * C, (x0 + bx0) * C, (y0 + by1) * C, (x0 + bx1) * C)
            for py0, px0, py1, px1 in split(f, *box):
                if py1 - py0 < 24 or px1 - px0 < 24:
                    continue
                tones = (f["step"][py0:py1, px0:px1] & ~f["edge"][py0:py1, px0:px1]).mean()
                # soft tones make a picture; a few sharp icons on flat buttons are UI
                out.append(("image" if tones >= 0.1 else "ui", py0, px0, py1, px1,
                            (0.75 + 0.1 * min(1.0, share)) if tones >= 0.1 else 0.55))

    # text: sharp cells (not pictures) on one ground, joined along lines, lines into paragraphs
    free = ~photo & ~taken & ~line
    ink = (sharp >= 2) & free
    ink |= (sharp >= 1) & free & grow(ink, 1, 1)     # the faint edge of a glyph next to its body
    t, b, l, r = (f[k][y0:y1, x0:x1] for k in ("top", "bottom", "left", "right"))
    right, hvia = joins(ink.T, line.T, l.T, r.T, round(14 * scale))
    down, vvia = joins(ink, line, t, b, round(13 * scale))
    member = ink | hvia.T | vvia
    paras = np.where(member, components(right.T, down) + 1, 0)
    for by0, bx0, by1, bx1, n, k in boxes(paras):
        bh, bw = by1 - by0, bx1 - bx0
        dense = ink[by0:by1, bx0:bx1].mean()
        if 4 <= bh <= 8 and bw <= 1.5 * bh and (photo[by0:by1, bx0:bx1].mean() >= 0.2 or chroma[by0:by1, bx0:bx1].mean() > 40):
            # an avatar, an icon in colour: a small picture
            out.append(("image",) + snap(f["step"], (y0 + by0) * C, (x0 + bx0) * C, (y0 + by1) * C, (x0 + bx1) * C) + (0.7,))
        elif bw >= 4 and bh >= 2 and bw >= bh and dense >= 0.25:
            # to the pixel: the empty rows / columns of the outer cells are not the block's
            mine = ink[by0:by1, bx0:bx1] & (paras[by0:by1, bx0:bx1] == k)
            py0 = (y0 + by0) * C + int(t[by0:by1, bx0:bx1][0][mine[0]].min())
            py1 = (y0 + by1) * C - int(b[by0:by1, bx0:bx1][-1][mine[-1]].min())
            px0 = (x0 + bx0) * C + int(l[by0:by1, bx0:bx1][:, 0][mine[:, 0]].min())
            px1 = (x0 + bx1) * C - int(r[by0:by1, bx0:bx1][:, -1][mine[:, -1]].min())
            pad = round(3 * scale)
            out.append(("text", max(y0 * C, py0 - pad), max(x0 * C, px0 - pad), min(y1 * C, py1 + pad),
                        min(x1 * C, px1 + pad), 0.6 + min(0.1, dense / 5)))

    # UI pieces: every ground but the window's own — panels, cards, bars, buttons
    for k, (sy0, sx0, sy1, sx1, n) in sboxes.items():
        if k - 1 == ground:
            continue
        bh, bw = sy1 - sy0, sx1 - sx0
        if bh >= 2 and bw >= 3 and bh * bw >= 8 and n >= 0.6 * bh * bw and bh * bw < 0.9 * h * w \
                and not taken[sy0:sy1, sx0:sx1].mean() > 0.5:
            qy0, qx0, qy1, qx1, _ = qboxes[k]
            out.append(("ui",) + grow_to_edge(f["step"], (y0 + qy0) * C, (x0 + qx0) * C, (y0 + qy1) * C, (x0 + qx1) * C,
                                              (y0 + sy0) * C, (x0 + sx0) * C, (y0 + sy1) * C, (x0 + sx1) * C)
                       + (0.5 + 0.05 * n / (bh * bw),))
    return [{"kind": k, "x": int(a), "y": int(b), "w": int(d - a), "h": int(c - b), "score": round(float(s), 3), "label": ""}
            for k, b, a, c, d, s in out]


def place(px, windows, scale=1.0):
    """The windows with their place in frame pixels. niri (26.04) gives none for tiled windows
    (tile_pos_in_workspace_view is null), only their column, row and size: the columns stand
    side by side a gap apart, and where that row stands is read off the frame — the shift, gap
    and top whose window edges are the strongest steps in it. A frame where no such edges stand
    out leaves them unplaced (left out)."""
    placed = [dict(w, x=w["x"] * scale, y=w["y"] * scale, w=w["w"] * scale, h=w["h"] * scale)
              for w in windows if w.get("x") is not None and w.get("y") is not None]
    tiled = [w for w in windows if (w.get("x") is None or w.get("y") is None) and w.get("col")]
    if not tiled:
        return placed
    H, W = px.shape[:2]
    cols = {}
    for w in tiled:
        cols.setdefault(int(w["col"]), []).append(w)
    order = sorted(cols)
    for c in order:
        cols[c].sort(key=lambda w: int(w.get("row") or 1))
    width = np.array([max(w["w"] for w in cols[c]) * scale for c in order])
    # a window edge is a step all along the window: per pixel column, the mean step over the
    # middle rows, less what any column has (the median)
    # (every 4th row: an edge runs the window's whole height)
    band = px[H // 5:H - H // 5:4].astype(np.int16).sum(axis=2)
    ex = np.zeros(W + 1)
    ex[1:W] = np.minimum(np.abs(band[:, 1:] - band[:, :-1]), 120).mean(axis=0)
    ex -= np.median(ex)
    # the strip of columns at every shift and gap (the view may be scrolled anywhere: the focused
    # column need not be in it): the sum of the steps at the column edges that fall in the frame
    # (only the shifts that put some column edge on one of the strongest steps: a real edge is one)
    peak = np.nonzero((ex[1:W] > 0) & (ex[1:W] >= ex[:W - 1]) & (ex[1:W] >= ex[2:W + 1]))[0] + 1
    peak = peak[np.argsort(-ex[peak])[:24]]
    best = (0.0, 0, 0)
    for gap in range(0, round(64 * scale) + 1, 1):
        left = np.concatenate([[0.0], np.cumsum(width + gap)[:-1]])
        edges = np.round(np.concatenate([left, left + width])).astype(int)
        # (with next to no gap a right edge is the next left one: counted once)
        edges = np.unique(edges // 3 * 3 if gap < 3 else edges)
        shifts = np.unique((peak[:, None] - edges[None, :]).ravel())
        if not len(shifts):
            break
        at = shifts[:, None] + edges[None, :]
        inside = (at >= 1) & (at < W)
        sc = np.where(inside, ex[np.clip(at, 0, W)], 0).sum(axis=1)
        k = int(sc.argmax())
        if sc[k] > best[0]:
            best = (float(sc[k]), int(shifts[k]), gap)
    # two clear edges at least (a mean step of ~10 of 765 along the window, each)
    if best[0] < 16:
        return placed
    _, x0, gap = best
    xs = x0 + np.concatenate([[0.0], np.cumsum(width + gap)[:-1]])
    # the top: the same for every column, from the horizontal steps over the ones in view
    span = np.zeros(W, bool)
    for x, wd in zip(xs, width):
        span[max(0, int(x)):max(0, min(W, int(x + wd)))] = True
    if not span.any():
        return placed
    hs = [sum(w["h"] for w in cols[c]) * scale for c in order]
    ht = round(max(hs[i] for i in range(len(order)) if span[max(0, min(W - 1, int(xs[i]))):max(0, min(W, int(xs[i] + width[i])))].any()))
    ey = np.zeros(H + 1)
    g = px[:, np.nonzero(span)[0][::4]].astype(np.int16).sum(axis=2)
    ey[1:H] = np.minimum(np.abs(g[1:] - g[:-1]), 120).mean(axis=1)
    ey -= np.median(ey)
    tops = np.arange(0, max(0, H - ht) + 1)
    sc = ey[np.clip(tops, 0, H)] * (tops >= 1) + ey[np.clip(tops + ht, 0, H)] * (tops + ht < H)
    top = int(tops[int(sc.argmax())])
    for i, c in enumerate(order):
        y = float(top)
        for w in cols[c]:
            placed.append(dict(w, x=xs[i], y=y, w=w["w"] * scale, h=w["h"] * scale))
            y += w["h"] * scale + gap
    return placed


def regions(px, windows=(), scale=1.0, placed=None):
    """The regions, best first; `placed` (a list) gets the windows in frame pixels."""
    H, W = px.shape[:2]
    f = cells(px)
    gh, gw = f["soft"].shape
    out, wins = [], []
    for win in place(px, windows or (), scale):
        x, y = round(win["x"]), round(win["y"])
        x1, y1 = min(W, x + round(win["w"])), min(H, y + round(win["h"]))
        x, y = max(0, x), max(0, y)
        if x1 - x < 16 or y1 - y < 16:
            continue
        if placed is not None:
            placed.append({"x": x, "y": y, "w": x1 - x, "h": y1 - y, "title": win.get("title") or "",
                           "app_id": win.get("app_id") or "", "focused": bool(win.get("focused"))})
        wins.append({"kind": "window", "x": x, "y": y, "w": x1 - x, "h": y1 - y, "score": 0.5,
                     "label": win.get("title") or win.get("app_id") or ""})
        out += analyse(f, -(-y // C), -(-x // C), y1 // C, x1 // C, scale)
    if not wins:
        out += analyse(f, 0, 0, gh, gw, scale)
    # big pieces first: avatars must not push a whole picture out of the MAX
    for r in wins + out:
        r["score"] = round(r["score"] + 0.3 * min(1.0, (r["w"] * r["h"] / (0.06 * W * H)) ** 0.5)
                           - (0.15 if r["kind"] in ("image", "ui") and min(r["w"], r["h"]) < 48 else 0), 3)
    # tiny or whole-frame pieces are no use, nor a piece that is its window again;
    # duplicates (IoU > 0.6) keep the better one; windows always stay
    out = [r for r in out if r["w"] >= 24 and r["h"] >= 16 and r["w"] * r["h"] < 0.92 * W * H
           and all(iou(r, w) <= 0.85 for w in wins)]
    out.sort(key=lambda r: -r["score"])
    keep = []
    for r in out:
        if all(iou(r, k) <= 0.6 for k in keep):
            keep.append(r)
    # a panel or a picture lying in a block of text is the space between its letters (a quiet run
    # of cells, a coloured glyph), a picture in a bigger picture a piece of it: the eye sees
    # the block, the picture
    keep = [r for r in keep if not any(
        k is not r and k["w"] * k["h"] > 1.5 * r["w"] * r["h"] and cover(r, k) >= 0.7 and
        (k["kind"] == "text" and r["kind"] in ("ui", "image") or k["kind"] == r["kind"] == "image")
        for k in keep)]
    keep = sorted(wins + keep[:max(0, MAX - len(wins))], key=lambda r: -r["score"])
    return keep[:MAX]


def main(argv):
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 2
    args = {"--windows": "[]", "--scale": "1"}
    it = iter(argv[1:])
    for a in it:
        if a in args:
            args[a] = next(it, args[a])
    try:
        wins = json.loads(args["--windows"]) or []
        px = load(argv[0])
        placed = []
        found = regions(px, wins, float(args["--scale"]), placed)
        print(json.dumps({"regions": found, "windows": placed}))
    except Exception as e:  # noqa: BLE001 — the overlay wants one JSON line whatever happens
        print(json.dumps({"error": str(e), "regions": []}))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
