#!/usr/bin/env python3
"""Half-alive wallpapers: finds what in a picture may move a little (widgets/LiveWall).

    live-wall.py <picture> [--cache DIR] [--force] [--debug OUT.png]

Prints one line of JSON and leaves in the cache a mask the shader reads (shaders/live_wall.frag),
made once per picture (path + size + mtime, and its hints' mtime): the picture as a scene, one
layer per art pixel

    R  the layer, ×32: 1 sky (stars come out, a star falls), 2 a cloud, 3 a thing in the sky (a
       ring, a moon: a glint runs over it), 4 still water (a lake, a sea), 5 falling water,
       6 land under an open horizon (rocks, a shore: clouds' shadows pass over it); 0 nothing
    G  within the layer: the water's depth from its line 0…1, a fall's way down from its top,
       the place round a ring 0…1
    B  small bright points already in the picture: in the sky lights (stars, lit windows)
       that twinkle, on the water glints that shimmer

Hints the author ships next to a picture (<name>.scene.json) say what a look cannot be sure of
(the scene editor writes them: owner/scene-editor, `angelos scene edit`; every key optional):
    {"rings": [[cx, cy, rx, ry, t], …]}   a ring in the sky, roughly: centre and radii in the
                                          picture's 0…1, t its half-thickness over the radius.
                                          Its stone is found in that band (fine texture, not a
                                          cloud's warm colour, above the horizon) and the ellipse
                                          fitted to it, tilt and all
    "paint": {"size": [w, h], "png": B64} the layers painted by hand, over what was found: an RGBA
                                          PNG (any size, scaled to the mask without smoothing), a
                                          pixel's colour the nearest of PAINT; alpha 0 = as found
    "lights": [[x, y], …]                 more points that twinkle (on water: glints), 0…1
    "rims" | "eyes" | "ponds": [[x, y]…]  where a pebble breaks off, an eye opens, rings spread —
                                          instead of the places found
    "effects": {"stars": false, …}        what this picture never does: stars, meteors, lights,
                                          water, glint, pebble, gust, eye, rings (widgets/LiveWall)
    "night": 0…1, "axis": 0…1, "mirror"   how dark the sky is (stars from 0.5), the waterline,
                                          whether the water shows the scene upside down

The JSON: {mask, size: [w, h] of the picture, grid: [cell w, cell h, offset x, offset y] of one
art pixel in the picture's pixels (cell 1 = a photo), pixelArt, sky: {found, night, area},
water: {found, axis, mirror, area, falls}, lights, glints, scene: {outdoor, rims, objects}}.
rims are where a pebble may break off (land over a fall or the dark), eyes where an eye may
open deep in a cloud; picture 0…1. axis is the waterline (0 top … 1 bottom);
mirror = the water shows the scene upside down, so the sky's stars are drawn there too.

Only numpy and Pillow, no model. What it looks for:
  - pixel art: where colours change (every k-th column and row); then one value per art pixel,
    so a dithered sky is the artist's dither, not noise
  - points: bright compact blobs on a darker ground (a star, a lit window, a dash on the water)
  - sky: grown from the top edge. In pixel art the solid shapes stop it: big areas of one
    colour whose colour is not dithered into what is around them (mountains, a city, a big
    feather; a band of the sky's gradient is dithered into the next one); a bright outline
    stops it too. In a photo, a gentle colour step is sky and a textured edge is not.
  - water: the waterline is the row the picture is most mirror-like about, with waves (dashes)
    under it and none above (an emblem or a glow is symmetric too, without a lake); without a
    mirror, a band of dashes reaching the bottom that is no lighter than the sky; or a sea: a
    straight horizon across the whole width with water under it (water is of the sky's cool
    hues, green and blue over red), grown down to where the land or a fall starts
  - falls: water under the sea whose texture runs down (streaks: steps across, none along),
    fed by it from above; what is under a fall in the same column and wet falls too
"""
import argparse
import hashlib
import json
import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image

Image.MAX_IMAGE_PIXELS = None
VERSION = 13
MAX_W = 960          # the mask is never wider than this


def load(path):
    im = Image.open(path)
    size = im.size
    fmt = im.format
    # a huge JPEG is read at a fraction (draft) before anything else
    if fmt == "JPEG" and im.width > 6000:
        im.draft("RGB", (im.width // 2, im.height // 2))
    if im.mode in ("RGBA", "LA", "P", "PA"):
        im = im.convert("RGBA")
        im = Image.alpha_composite(Image.new("RGBA", im.size, (0, 0, 0, 255)), im)
    return im.convert("RGB"), size, fmt


def pixel_grid(a):
    """(k, ox, oy): art pixels k×k starting at ox, oy; k = 1 for a photo."""
    L = a.astype(np.float32).sum(2)
    dx = np.abs(np.diff(L, axis=1)).sum(0)
    dy = np.abs(np.diff(L, axis=0)).sum(1)
    tx, ty = dx.sum(), dy.sum()
    if tx < 1 or ty < 1:
        return 1, 0, 0
    ix = np.arange(len(dx)) + 1
    iy = np.arange(len(dy)) + 1
    for k in range(24, 1, -1):
        bx = np.bincount(ix % k, weights=dx, minlength=k)
        by = np.bincount(iy % k, weights=dy, minlength=k)
        if bx.max() / tx > 0.8 and by.max() / ty > 0.8:
            return k, int(bx.argmax()), int(by.argmax())
    return 1, 0, 0


def box(x, r):
    """Mean over a (2r+1)² window, edges clamped; x is (h, w) or (h, w, c)."""
    if r <= 0:
        return x
    pad = ((r, r), (r, r)) + ((0, 0),) * (x.ndim - 2)
    c = np.pad(x.astype(np.float64), pad, mode="edge").cumsum(0).cumsum(1)
    c = np.pad(c, ((1, 0), (1, 0)) + ((0, 0),) * (x.ndim - 2))
    n = 2 * r + 1
    return ((c[n:, n:] - c[:-n, n:] - c[n:, :-n] + c[:-n, :-n]) / (n * n)).astype(np.float32)


def lum(a):
    return a[..., 0] * 0.299 + a[..., 1] * 0.587 + a[..., 2] * 0.114


def shift(m, dy, dx):
    """m moved by (dy, dx), the new edge False."""
    o = np.zeros_like(m)
    h, w = m.shape
    o[max(dy, 0):h + min(dy, 0), max(dx, 0):w + min(dx, 0)] = m[max(-dy, 0):h + min(-dy, 0), max(-dx, 0):w + min(-dx, 0)]
    return o


def dilate(m, r=1):
    for _ in range(r):
        m = m | shift(m, 1, 0) | shift(m, -1, 0) | shift(m, 0, 1) | shift(m, 0, -1)
    return m


def erode(m, r=1):
    return ~dilate(~m, r)


def label(eqx, eqy, shape):
    """Components joined where eqx (x↔x+1) / eqy (y↔y+1) say so: labels (h, w)."""
    h, w = shape
    lab = np.arange(h * w).reshape(h, w)
    while True:
        n = lab.copy()
        m = np.minimum(n[:, 1:], n[:, :-1])
        n[:, 1:] = np.where(eqx, m, n[:, 1:])
        n[:, :-1] = np.where(eqx, np.minimum(n[:, :-1], m), n[:, :-1])
        m = np.minimum(n[1:], n[:-1])
        n[1:] = np.where(eqy, m, n[1:])
        n[:-1] = np.where(eqy, np.minimum(n[:-1], m), n[:-1])
        f = n.ravel()
        f = f[f]
        f = f[f]
        n = f.reshape(h, w)
        if np.array_equal(n, lab):
            return lab
        lab = n


def components(mask):
    """The 8-connected parts of mask: list of (ys, xs)."""
    h, w = mask.shape
    eqx = mask[:, 1:] & mask[:, :-1]
    eqy = mask[1:] & mask[:-1]
    lab = label(eqx, eqy, (h, w))
    # diagonals: a second pass joining the labels of diagonal neighbours
    for dy, dx in ((1, 1), (1, -1)):
        a = mask[:-1, max(0, -dx):w - max(0, dx)] & mask[1:, max(0, dx):w - max(0, -dx)]
        if a.any():
            la = lab[:-1, max(0, -dx):w - max(0, dx)][a]
            lb = lab[1:, max(0, dx):w - max(0, -dx)][a]
            parent = {}

            def find(x):
                while parent.get(x, x) != x:
                    x = parent[x]
                return x
            for p, q in zip(la.tolist(), lb.tolist()):
                rp, rq = find(p), find(q)
                if rp != rq:
                    parent[max(rp, rq)] = min(rp, rq)
            if parent:
                flat = lab.ravel()
                keys = np.array(list(parent.keys()))
                roots = np.array([find(k) for k in keys])
                lut = dict(zip(keys.tolist(), roots.tolist()))
                sel = np.isin(flat, keys)
                flat[sel] = [lut[v] for v in flat[sel].tolist()]
                lab = flat.reshape(h, w)
    ys, xs = np.nonzero(mask)
    if not len(ys):
        return []
    ids = lab[ys, xs]
    order = np.argsort(ids, kind="stable")
    ids, ys, xs = ids[order], ys[order], xs[order]
    cuts = np.nonzero(np.diff(ids))[0] + 1
    return list(zip(np.split(ys, cuts), np.split(xs, cuts)))


def find_points(L, unit):
    """Small bright blobs on a darker ground: (mask, [(ys, xs, w, h, ground)])."""
    h, w = L.shape
    ground = box(L, max(3, int(round(4 * unit))))
    cand = (L - ground > 0.10) & (L > 0.22)
    if cand.sum() > 0.25 * h * w:          # a busy picture: everything is a "point"
        return np.zeros_like(cand), []
    amax = max(14, int(14 * unit * unit))
    smax = max(5, int(round(6 * unit)))
    blobs = []
    mask = np.zeros_like(cand)
    for ys, xs in components(cand):
        if len(ys) > amax:
            continue
        bw, bh = int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)
        if bh > smax or bw > smax * 2:
            continue
        # the ground a step away is darker all round (not the lit edge of a shape)
        y0, y1 = max(0, ys.min() - 3), min(h, ys.max() + 4)
        x0, x1 = max(0, xs.min() - 3), min(w, xs.max() + 4)
        near = np.zeros((y1 - y0, x1 - x0), dtype=bool)
        near[ys - y0, xs - x0] = True
        near = dilate(near, 1)
        ring = L[y0:y1, x0:x1][~near]
        if ring.size and (ring > L[ys, xs].max() - 0.08).mean() > 0.12:
            continue
        blobs.append((ys, xs, bw, bh, float(ground[ys, xs].mean())))
    # a dot among dots is a pattern (a dithered ray, a texture), not a star; dashes on water
    # may crowd
    centres = np.zeros((h, w), dtype=np.float32)
    for ys, xs, *_ in blobs:
        centres[int(ys.mean()), int(xs.mean())] += 1
    r = max(3, int(round(4 * unit)))
    crowd = box(centres, r) * (2 * r + 1) ** 2
    kept = []
    for b in blobs:
        ys, xs, bw, bh = b[:4]
        if crowd[int(ys.mean()), int(xs.mean())] > 2.5 and not (bw >= 2 * bh and bw >= 2):
            continue
        mask[ys, xs] = True
        kept.append(b)
    return mask, kept


def solid_shapes(art, tol):
    """Pixel art: big areas of one colour that are not dithered into their surroundings."""
    h, w, _ = art.shape
    a = art.astype(np.int16)
    eqx = np.abs(a[:, 1:] - a[:, :-1]).max(2) <= tol
    eqy = np.abs(a[1:] - a[:-1]).max(2) <= tol
    lab = label(eqx, eqy, (h, w))
    ids, inv, cnt = np.unique(lab, return_inverse=True, return_counts=True)
    inv = inv.reshape(h, w)
    solid = np.zeros((h, w), dtype=bool)
    for b in np.nonzero(cnt >= 0.004 * h * w)[0]:
        m = inv == b
        if m[0].any():                      # touches the top edge: the sky's own
            continue
        ring = dilate(m, 2) & ~m
        col = a[m][0]
        same = (np.abs(a[ring] - col).max(1) <= tol).mean() if ring.any() else 0
        if same < 0.06:
            solid |= m
    return solid


def flood_top(passx, passy):
    """Everything reachable from the top row through the passable steps."""
    h = passy.shape[0] + 1
    w = passx.shape[1] + 1
    m = np.zeros((h, w), dtype=bool)
    m[0] = True
    while True:
        n = m.copy()
        n[1:] |= m[:-1] & passy
        n[:-1] |= m[1:] & passy
        n[:, 1:] |= m[:, :-1] & passx
        n[:, :-1] |= m[:, 1:] & passx
        if np.array_equal(n, m):
            return m
        m = n


def flood(seed, passx, passy):
    """Everything reachable from seed through the passable steps."""
    m = seed.copy()
    while True:
        n = m.copy()
        n[1:] |= m[:-1] & passy
        n[:-1] |= m[1:] & passy
        n[:, 1:] |= m[:, :-1] & passx
        n[:, :-1] |= m[:, 1:] & passx
        if np.array_equal(n, m):
            return m
        m = n


def horizon(S):
    """A sea's horizon: the row the colour steps at across (nearly) the whole width,
    (row, share of the columns)."""
    h = S.shape[0]
    best, best_y = 0.0, None
    for y in range(max(2, int(h * 0.15)), min(h - 2, int(h * 0.8))):
        share = float((np.abs(S[y + 1] - S[y - 2]).max(1) > 0.06).mean())
        if share > best:
            best, best_y = share, y
    return best_y, best


def sea_and_falls(A, S, L, unit):
    """A sea under a straight horizon and the falls it feeds: (horizon row, sea, falls) or None."""
    h, w = L.shape
    hy, share = horizon(S)
    if hy is None or share < 0.6:
        return None
    r, g, b = S[..., 0], S[..., 1], S[..., 2]
    wet = (g - r > 0.045) & (b - r > 0.03)
    wet[:hy + 1] = False
    # the water starts at the horizon or a little under it (under a glow, a far shore)
    n = max(3, int(h * 0.04))
    for y in range(hy + 1, min(h - n, hy + 2 + max(4, int(h * 0.05)))):
        if wet[y:y + n].mean() >= 0.5:
            break
    else:
        return None
    band = slice(y, y + n)
    # a sea mirrors the sky: no lighter than it (moonlit ground is), and it has waves —
    # steps down more than across (smooth dark hills have none)
    near_sky = L[max(0, hy - max(3, int(h * 0.15))):hy]
    if np.median(L[band]) > max(np.median(L[:hy]), np.median(near_sky)) + 0.12:
        return None
    # texture running down (a fall's streaks) or across (waves)
    ex = np.zeros_like(L)
    ey = np.zeros_like(L)
    ex[:, :-1] = np.abs(np.diff(L, axis=1))
    ey[:-1] = np.abs(np.diff(L, axis=0))
    wb = wet[band]
    if not wb.any() or ey[band][wb].mean() < 0.003 or ey[band][wb].mean() < 1.2 * ex[band][wb].mean():
        return None
    down = box(ey - ex, max(2, int(round(3 * unit)))) < -0.005
    # a fall goes on in its column for as long as it is wet (a smooth sheet, a lit streak)
    fall = wet & down
    fall[: hy + max(2, int(h * 0.02))] = False
    for y in range(hy + 1, h):
        fall[y] |= fall[y - 1] & wet[y]
    still = wet & ~fall
    seed = np.zeros((h, w), dtype=bool)
    seed[band] = still[band]
    sea = flood(seed, still[:, 1:] & still[:, :-1], still[1:] & still[:-1])
    # no threads of it down a crack in the rocks
    sea &= dilate(erode(sea, 1), 1)
    sea = flood(seed & sea, sea[:, 1:] & sea[:, :-1], sea[1:] & sea[:-1])
    # what the sea surrounds is sea (a glint's path, a boat, a reflection)
    for ys, xs in components(~sea):
        if ys.min() > hy and ys.max() < h - 1 and xs.min() > 0 and xs.max() < w - 1 and len(ys) < 0.03 * h * w:
            sea[ys, xs] = True
    if sea.mean() < 0.04:
        return None
    # a fall starts under the sea's edge: the edge row of every column, taken over its
    # neighbours (a mirrored mountain or a ring's leg is a thin streak down the water: it
    # left a narrow gap in the sea, not a lower edge); what streams above it is sea
    rows = np.arange(h)[:, None]
    last = np.where(sea.any(0), h - 1 - np.argmax(sea[::-1], 0), hy)
    k = max(6, int(w * 0.045))
    pad = np.pad(last, k, mode="edge")
    edge = np.array([np.median(pad[i:i + 2 * k + 1]) for i in range(w)])
    over = fall & (rows <= edge[None, :])
    sea |= over
    fall &= ~over
    # a fall is fed by the sea: it starts at the sea's edge or not far under it (behind a
    # rock), and it is tall
    falls = np.zeros((h, w), dtype=bool)
    near = dilate(sea, max(2, int(round(3 * unit))))
    for ys, xs in components(fall & ~sea):
        if len(ys) < 0.002 * h * w or ys.max() - ys.min() < 0.08 * h:
            continue
        if not (near[ys, xs].any() or ys.min() <= hy + 0.25 * h):
            continue
        # it falls out of the sea, not into it (a blue doorway in a house in the water)
        under = np.zeros((h, w), dtype=bool)
        under[ys, xs] = True
        under = np.cumsum(under, 0) > 0
        if (sea & under).sum() > 0.3 * len(ys):
            continue
        if True:
            falls[ys, xs] = True
    return hy, sea, falls


def mirror_axis(L, unit):
    """The row the picture is most mirror-like about: (row, score)."""
    h, w = L.shape
    Lb = box(L, max(1, int(round(2 * unit))))
    best, best_a = -1.0, None
    for a in range(int(h * 0.4), int(h * 0.9)):
        K = int(min(a, h - a, h * 0.3))
        if K < h * 0.06:
            continue
        u = Lb[a - K:a][::-1]
        d = Lb[a:a + K]
        u = u - u.mean()
        d = d - d.mean()
        den = np.sqrt((u * u).sum() * (d * d).sum())
        if den < 1e-6:
            continue
        s = float((u * d).sum() / den)
        if s > best:
            best, best_a = s, a
    return best_a, best


L_SKY, L_CLOUD, L_THING, L_WATER, L_FALL, L_LAND = 1, 2, 3, 4, 5, 6
# the painted layers' colours (hints "paint"; the scene editor draws with these): layer → RGB
PAINT = {0: (40, 40, 48), L_SKY: (74, 108, 255), L_CLOUD: (255, 143, 200), L_THING: (255, 210, 74),
         L_WATER: (40, 220, 190), L_FALL: (220, 80, 220), L_LAND: (150, 110, 60)}


def paint_of(hints, w, h):
    """The hand-painted layers on the mask's grid: (h, w) int8, -1 where it is as found."""
    out = np.full((h, w), -1, dtype=np.int8)
    p = hints.get("paint")
    if not isinstance(p, dict) or not p.get("png"):
        return out
    try:
        import base64
        import io
        im = Image.open(io.BytesIO(base64.b64decode(p["png"]))).convert("RGBA")
    except Exception:
        return out
    if im.size != (w, h):
        im = im.resize((w, h), Image.NEAREST)
    a = np.asarray(im).astype(np.int32)
    ids = np.array(list(PAINT))
    cols = np.array([PAINT[i] for i in ids])
    d = ((a[..., None, :3] - cols[None, None]) ** 2).sum(-1)
    lay = ids[d.argmin(-1)]
    on = a[..., 3] > 127
    out[on] = lay[on]
    return out


def points_of(hints, key):
    """A list of [x, y] in 0…1 from the hints, or None (not given)."""
    v = hints.get(key)
    if not isinstance(v, list):
        return None
    out = []
    for q in v:
        try:
            out.append([round(min(1, max(0, float(q[0]))), 4), round(min(1, max(0, float(q[1]))), 4)])
        except (TypeError, ValueError, IndexError):
            pass
    return out


def hints_of(path):
    """The author's hints next to the picture: <name>.scene.json (and its mtime) or ({}, 0)."""
    f = Path(path).with_name(Path(path).stem + ".scene.json")
    try:
        return json.loads(f.read_text()), int(f.stat().st_mtime)
    except (OSError, ValueError):
        return {}, 0


def ring_field(xs, ys, cx, cy, M):
    """For pixel coords: d (1 on the ellipse (p-c)ᵀM(p-c) = 1) and the place round it 0…1."""
    dx, dy = xs - cx, ys - cy
    d = np.sqrt(np.maximum(M[0, 0] * dx * dx + 2 * M[0, 1] * dx * dy + M[1, 1] * dy * dy, 0))
    ev, V = np.linalg.eigh(M)
    p = np.stack([dx, dy], -1) @ V * np.sqrt(np.maximum(ev, 1e-12))
    return d, (np.arctan2(p[..., 1], p[..., 0]) / (2 * np.pi)) % 1.0


def fit_ellipse(x, y):
    """The ellipse through points (centred near 0): (cx, cy, M) or None."""
    D = np.stack([x * x, x * y, y * y, x, y], 1)
    try:
        a, b, c, d, e = np.linalg.lstsq(D, np.ones(len(x)), rcond=None)[0]
    except np.linalg.LinAlgError:
        return None
    Q = np.array([[a, b / 2], [b / 2, c]])
    if a <= 0 or np.linalg.det(Q) <= 0:
        return None
    ctr = np.linalg.solve(2 * Q, -np.array([d, e]))
    k = 1 + ctr @ Q @ ctr
    return (ctr[0], ctr[1], Q / k) if k > 0 else None


def rings(hints, A, below):
    """The hinted rings' stone on the mask: (mask, place round them 0…1). below: the first
    row under the horizon (a ring stands in the sea: what is lower is not its stone)."""
    h, w = A.shape[:2]
    on = np.zeros((h, w), dtype=bool)
    where = np.zeros((h, w), dtype=np.float32)
    if not hints.get("rings"):
        return on, where
    m1 = box(A, 1)
    sd = np.sqrt(np.maximum(box(A * A, 1) - m1 * m1, 0)).mean(2)
    stone = (box((sd > 0.05).astype(np.float32), 1) > 0.5) & (m1[..., 0] - m1[..., 1] < 0.09)
    stone[below:] = False
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64) + 0.5
    for r in hints["rings"]:
        try:
            cx, cy, rx, ry, t = (float(x) for x in r[:5])
        except (TypeError, ValueError):
            continue
        X, Y = cx * w, cy * h
        M = np.diag([1 / max(rx * w, 1) ** 2, 1 / max(ry * h, 1) ** 2])
        r0 = (rx * w + ry * h) / 2
        band = t * 1.6
        for it in range(4):
            d, ang = ring_field(xs, ys, X, Y, M)
            sel = stone & (np.abs(d - 1) <= band)
            # the ring's pieces (clouds cut it), not a mountain the ellipse happens to cross
            keep = np.zeros((h, w), dtype=bool)
            parts = components(sel)
            big = max((len(c[0]) for c in parts), default=0)
            for cy_, cx_ in parts:
                if len(cy_) >= 0.25 * big:
                    keep[cy_, cx_] = True
            if it == 3 or keep.sum() < 30:
                break
            f = fit_ellipse(xs[keep] - X, ys[keep] - Y)
            # a short arc fits any ellipse: the fit may not wander far from the hint
            if f is None or np.hypot(f[0], f[1]) > 0.25 * r0:
                break
            ev = np.linalg.eigvalsh(f[2])
            if not (0.6 * r0 < 1 / np.sqrt(ev.max()) and 1 / np.sqrt(ev.min()) < 1.6 * r0):
                break
            X, Y, M = X + f[0], Y + f[1], f[2]
            band = t
        on |= keep
        where[keep] = ang[keep]
    return on, where


def analyze(path, debug=None, hints=None):
    if hints is None:
        hints, _ = hints_of(path)
    im, size, fmt = load(path)
    a = np.asarray(im)
    k, ox, oy = pixel_grid(a)
    exact = fmt in ("PNG", "GIF", "BMP") or (fmt == "WEBP" and getattr(im, "info", {}).get("lossless"))
    if k > 1:
        art = a[oy + k // 2::k, ox + k // 2::k]
        sx, sy = size[0] / im.width, size[1] / im.height
        grid = [k * sx, k * sy, ox * sx, oy * sy]
    else:
        tw = min(640, im.width)
        art = np.asarray(im.resize((tw, max(1, round(im.height * tw / im.width))), Image.BOX))
        c = max(1, round(size[0] / 1280))
        grid = [c, c, 0, 0]
    if art.shape[1] > MAX_W:
        art = np.asarray(Image.fromarray(art).resize((MAX_W, max(1, round(art.shape[0] * MAX_W / art.shape[1]))), Image.BOX))
        exact = False
    A = art.astype(np.float32) / 255.0
    h, w = A.shape[:2]
    unit = 1.0 if k > 1 else max(1.0, w / 480)     # one art pixel of the mask, roughly

    L = lum(A)
    pts, blobs = find_points(L, unit)

    # the colour with the points taken out, the dither averaged away
    filled = A
    if pts.any():
        g = box(np.where(pts[..., None], 0, A), 3)
        n = box((~pts).astype(np.float32), 3)[..., None]
        filled = np.where(pts[..., None], g / np.maximum(n, 1e-3), A)
    C = box(filled, max(1, int(round(1.5 * unit))))
    Lc = lum(C)

    # ---- water ----
    dashes = [b for b in blobs if b[2] >= 2 * b[3] and b[2] >= 2]
    axis, score = mirror_axis(Lc, unit)
    water = np.zeros((h, w), dtype=bool)
    mirror = False
    sky_l_top = float(Lc[: max(2, h // 5)].mean())
    if axis is not None and score >= 0.8:
        below = sum(1 for b in dashes if b[0].min() >= axis)
        above = len(dashes) - below
        K = int(min(axis, h - axis, h * 0.3))
        ratio = Lc[axis:axis + K].std() / max(1e-4, Lc[axis - K:axis].std())
        if (below >= 5 and below >= 3 * above + 2) or (k == 1 and score >= 0.9 and ratio < 0.95):
            water[axis:] = True
            mirror = True
    falls = np.zeros((h, w), dtype=bool)
    horizon_row = None
    if not water.any():
        found = sea_and_falls(A, box(filled, 1), lum(filled), unit)
        if found:
            horizon_row, water, falls = found
            axis = horizon_row + 1
    if not water.any() and len(dashes) >= 10:
        tops = np.array(sorted(int(b[0].min()) for b in dashes))
        top = int(tops[len(tops) // 10])
        xs = np.concatenate([b[1] for b in dashes if b[0].min() >= top])
        # a sea is no lighter than the sky and of its hue (it mirrors it); a lit forest is not
        chroma = lambda c: c / max(1e-3, float(c.sum()))
        hue_gap = np.abs(chroma(np.median(C[top:].reshape(-1, 3), 0)) - chroma(np.median(C[: max(2, h // 5)].reshape(-1, 3), 0))).max()
        if top > h * 0.4 and tops.max() > h * 0.85 and np.ptp(xs) > w * 0.5 and Lc[top:].mean() <= sky_l_top + 0.05 and hue_gap < 0.06:
            axis = max(0, top - int(round(2 * unit)))
            water[axis:] = True
    water_area = float(water.mean())
    if water_area < 0.04:
        water[:] = False
        water_area, mirror = 0.0, False
        falls[:] = False

    # ---- sky ----
    # steps over a finer average in pixel art: a bright outline stays a step
    S = box(filled, 1) if k > 1 else C
    step_y = np.abs(np.diff(S, axis=0)).max(2)
    step_x = np.abs(np.diff(S, axis=1)).max(2)
    if k > 1:
        solid = solid_shapes(art, 0 if exact else 10)
        thr = 0.09
    else:
        # a photo's sky is smooth: fine texture (leaves, text, fabric) is not sky
        tex = np.sqrt(np.maximum(box(L * L, 2) - box(L, 2) ** 2, 0))
        solid = tex > 0.012 + 0.05 * box(L, 2)
        top = int(max(3, h * 0.08))
        base = np.concatenate([step_y[:top].ravel(), step_x[:top].ravel()])
        thr = float(np.clip(np.percentile(base, 90) * 2.5, 0.006, 0.025))
    passy = (step_y < thr) & ~solid[1:] & ~solid[:-1]
    passx = (step_x < thr) & ~solid[:, 1:] & ~solid[:, :-1]
    sky = flood_top(passx, passy)
    if water.any():
        sky[axis:] = False
    if horizon_row is not None:
        sky[horizon_row:] = False
    # holes the size of a star are sky; bigger ones are things in the sky (a halo, a moon)
    for ys, xs in components(~sky):
        if len(ys) <= 30 * unit * unit and ys.min() > 0 and ys.max() < h - 1 and xs.min() > 0 and xs.max() < w - 1:
            sky[ys, xs] = True
    stars = [b for b in blobs if sky[b[0][0], b[1][0]] and b[4] <= 0.4]
    # a photo's sky with stars in it ends a little below the lowest of them (the rest of what
    # grew may be a smooth wall); a gap with no stars takes the line of its neighbours
    if k == 1 and len(stars) >= 8:
        low = np.full(w, -1.0)
        reach = int(w * 0.06)
        for ys, xs, *_ in stars:
            lo, hi = max(0, xs.min() - reach), min(w, xs.max() + reach + 1)
            low[lo:hi] = np.maximum(low[lo:hi], ys.max())
        known = low >= 0
        idx = np.arange(w)
        low = np.convolve(np.interp(idx, idx[known], low[known]), np.ones(reach) / reach, mode="same")
        sky &= np.arange(h)[:, None] <= (low + 4 * unit)[None, :]
    sky_area = float(sky.mean())
    # a sky is the same across a row (a gradient from top to bottom, a glow): a region that
    # grew over a whole room or a city is not
    # things in the sky that let it through (a detailed emblem) are taken out first
    coherent = True
    if sky.any():
        grown = int(sky.sum())
        dev = []
        for y in np.nonzero(sky.any(1))[0]:
            xs_ = np.nonzero(sky[y])[0]
            d = np.abs(C[y, xs_] - np.median(C[y, xs_], 0)).max(1)
            sky[y, xs_[d > 0.18]] = False
            dev.append(d[d <= 0.18].mean() if (d <= 0.18).any() else 0)
        # under a horizon the sky cannot have grown over a room: clouds may vary it more
        coherent = float(np.mean(dev)) < (0.06 if horizon_row is None else 0.09) and sky.sum() > 0.6 * grown
        # thin leaks (between houses, along a ceiling) go; what is left must reach the top
        r = max(2, int(round(2 * unit)))
        opened = dilate(erode(sky, r), r) & sky
        sky[:] = False
        for ys, xs in components(opened):
            if ys.min() == 0 and len(ys) >= 0.01 * h * w:
                sky[ys, xs] = True
        sky_area = float(sky.mean())
    sky_l = float(Lc[sky].mean()) if sky.any() else 1.0
    sky_rgb = C[sky].mean(0) if sky.any() else np.ones(3)
    night = float(np.clip((0.42 - sky_l) / 0.3, 0, 1))
    if len(stars) >= 8 and sky_l < 0.3:
        night = max(night, 0.6)
    if sky_rgb[2] < sky_rgb[0] * 0.9 and len(stars) < 8:       # a warm dark: dusk, a room
        night *= 0.5
    # a plain backdrop (a logo on black) is no night sky: no stars of its own, no gradient
    rows_ = np.nonzero(sky.any(1))[0]
    if len(rows_) > 4:
        band = max(1, len(rows_) // 10)
        top_c = C[rows_[:band]][sky[rows_[:band]]].mean(0)
        bot_c = C[rows_[-band:]][sky[rows_[-band:]]].mean(0)
        if np.abs(top_c - bot_c).max() < 0.03 and len(stars) < 8:
            night = 0.0
    # in a night sky new stars come out on its dark only: what is clearly lighter than that
    # (a cloud, a glow, a moon's halo) hides them, and a falling star passes behind it
    if sky.any() and night >= 0.5:
        dark = Lc <= float(np.percentile(Lc[sky], 35)) + 0.06
        sky &= erode(dark, 1) | ~dilate(~dark, 1)
        sky_area = float(sky.mean())
    sky_found = sky_area > 0.1 and coherent
    if not sky_found:
        sky[:] = False
        night = 0.0

    # ---- painted by hand (hints "paint"): over what was found ----
    paint = paint_of(hints, w, h)
    painted = paint >= 0
    if painted.any():
        had_water = water.any()
        p_fall = paint == L_FALL
        sky = (sky & ~painted) | (paint == L_SKY)
        water = (water & ~painted) | (paint == L_WATER) | p_fall
        falls = (falls & ~painted) | p_fall
        if water.any() and not had_water:
            axis = int(np.nonzero((water & ~falls).any(1))[0].min()) if (water & ~falls).any() else int(np.nonzero(water.any(1))[0].min())
            mirror = False
        water_area = float(water.mean())
        if (paint == L_SKY).any():
            sky_area = float(sky.mean())
            if not sky_found:
                sky_l = float(Lc[sky].mean())
                night = float(np.clip((0.42 - sky_l) / 0.3, 0, 1))
            sky_found = True
        elif not sky.any():
            sky_found, night = False, 0.0
    if isinstance(hints.get("night"), (int, float)):
        night = float(np.clip(hints["night"], 0, 1))
    if isinstance(hints.get("axis"), (int, float)) and water.any():
        axis = int(np.clip(hints["axis"], 0, 1) * h)
    if isinstance(hints.get("mirror"), bool):
        mirror = hints["mirror"] and water.any()

    # ---- the mask ----
    lights = np.zeros((h, w), dtype=np.float32)
    glints = np.zeros((h, w), dtype=np.float32)
    n_l = n_g = 0
    near_sky = erode(sky, 1)
    for ys, xs, bw, bh, gr in blobs:
        v = np.clip((L[ys, xs] - 0.2) / 0.6, 0.35, 1.0)
        if falls[ys[0], xs[0]]:
            continue
        if water[ys[0], xs[0]]:
            glints[ys, xs] = v
            n_g += 1
        elif horizon_row is not None and not near_sky[ys[0], xs[0]]:
            continue                        # by a sea: a speck on the rocks is no light
        elif gr <= 0.4:                     # a point on a light ground is no star
            lights[ys, xs] = v
            n_l += 1
    # the picture's own lights twinkle under a night sky only (stars, a city's windows); and an
    # eye's highlight or two is not a starry sky
    if n_l < 6 or not sky_found or night < 0.5:
        lights[:] = 0
        n_l = 0
    if n_g < 4:
        glints[:] = 0
        n_g = 0
    # ---- the scene ----
    # under an open horizon everything else is land (clouds' shadows pass over it); above it,
    # what is not sky is a cloud (or a hinted ring). Elsewhere (a city, a room, a photo) the
    # rest stays nothing: no shadows over it
    outdoor = horizon_row is not None
    layer = np.zeros((h, w), dtype=np.uint8)
    param = np.zeros((h, w), dtype=np.float32)
    if outdoor:
        layer[:] = L_LAND
        layer[:horizon_row] = L_CLOUD
    layer[sky] = L_SKY
    layer[water] = L_WATER
    rows = np.arange(h)[:, None]
    if water.any():
        span = max(1, int(np.nonzero(water.any(1))[0].max()) - axis + 1)
        param = np.where(water, np.clip((rows - axis) / span, 0, 1), param)
    layer[falls] = L_FALL
    if falls.any():
        top = np.where(falls.any(0), np.argmax(falls, 0), h)
        param = np.where(falls, np.clip((rows - top[None, :]) / (0.3 * h), 0, 1), param)
    ring, round_ = rings(hints, A, horizon_row if horizon_row is not None else h)
    # a ring is the stone of it: not the sky through it, nor a bright cloud in front
    ring &= ~sky & ~water & ~falls
    # a cloud (it drifts) is a cloud's colour: warm, peach by day, pink at night; what else
    # stands over the horizon (mountains, a ring's edge, a tower) is nothing and stays put
    if outdoor:
        S_ = box(filled, 1)
        warm = (S_[..., 0] - S_[..., 1]) > 0.07
        # the ring's whole band (its lit side is warm too) and a margin round it
        hull = erode(dilate(ring, 5), 5) | dilate(ring, 2)
        still = (layer == L_CLOUD) & (~warm | hull)
        layer[still] = 0
    layer[ring] = L_THING
    param = np.where(ring, round_, param)
    lights[ring] = 0
    if painted.any():
        layer[painted] = paint[painted]
        # within the painted layers: the water's depth, a fall's way down, a thing's place
        # across it (where a glint runs)
        wat = layer == L_WATER
        if (painted & wat).any():
            span = max(1, int(np.nonzero(wat.any(1))[0].max()) - axis + 1)
            param = np.where(painted & wat, np.clip((rows - axis) / span, 0, 1), param)
        fl = layer == L_FALL
        if (painted & fl).any():
            top = np.where(fl.any(0), np.argmax(fl, 0), h)
            param = np.where(painted & fl, np.clip((rows - top[None, :]) / (0.3 * h), 0, 1), param)
        th = painted & (layer == L_THING)
        if th.any():
            xs_ = np.nonzero(th.any(0))[0]
            cols_ = np.arange(w)[None, :]
            param = np.where(th, np.clip((cols_ - xs_.min()) / max(1, np.ptp(xs_)), 0, 1), param)
        still_ = painted & (paint == 0)
        lights[still_] = 0
        glints[still_] = 0
        # a scene painted outdoors (clouds, land, water) gets its events too
        if not outdoor and (np.isin(paint, (L_CLOUD, L_LAND)).any() or (painted & wat).any()):
            outdoor = True
            horizon_row = max(0, axis - 1) if water.any() else int(np.nonzero(np.isin(paint, (L_LAND,)).any(1))[0].min()) if (paint == L_LAND).any() else 0
    # points that twinkle, added by hand (on water: glints)
    for x_, y_ in points_of(hints, "lights") or []:
        yy, xx = min(h - 1, int(y_ * h)), min(w - 1, int(x_ * w))
        if layer[yy, xx] in (L_WATER, L_FALL):
            glints[yy, xx] = 1.0
            n_g += 1
        else:
            lights[yy, xx] = 1.0
            n_l += 1
    # where a pebble may break off: land with a fall or the dark under it
    rims = []
    if outdoor:
        land = layer == L_LAND
        dark = L < 0.08
        under = np.zeros((h, w), dtype=bool)
        under[:-2] = (falls[1:-1] | dark[1:-1]) & (falls[2:] | dark[2:])
        rim = land & under & ~dark
        rim[: horizon_row + 2] = False
        ys_, xs_ = np.nonzero(rim)
        if len(xs_):
            order = np.argsort(xs_)
            for i in np.linspace(0, len(order) - 1, min(24, len(order))).astype(int):
                rims.append([round((xs_[order[i]] + 0.5) / w, 4), round((ys_[order[i]] + 0.5) / h, 4)])
    # where an eye may open (Uriel: the Ophanim are near, out of the frame): deep inside a
    # cloud, its whole almond (13×7 art pixels and a margin) cloud
    eyes = []
    if outdoor:
        inside = layer == L_CLOUD
        for _ in range(4):
            inside = erode(inside, 1)
        inside &= box(inside.astype(np.float32), 3) > 0.99
        inside[:, :10] = inside[:, -10:] = False
        inside[:5] = False
        ys_, xs_ = np.nonzero(inside)
        if len(xs_):
            order = np.argsort(xs_)
            for i in np.linspace(0, len(order) - 1, min(12, len(order))).astype(int):
                eyes.append([round((xs_[order[i]] + 0.5) / w, 4), round((ys_[order[i]] + 0.5) / h, 4)])
    # where rings may spread on the water: a place with open water all round, as far as the
    # rings ever reach (16 art pixels across, 5 up and down: flat circles seen from the shore)
    ponds = []
    if outdoor and water.any():
        sea = water & ~falls
        ok = sea.copy()
        for dx in range(-17, 18):
            ok &= np.roll(sea, dx, 1) if abs(dx) < w else ok
        for dy in range(-5, 6):
            ok &= np.roll(sea, dy, 0)
        ok[:, :17] = ok[:, -17:] = False
        ok[: horizon_row + 6] = False
        ys_, xs_ = np.nonzero(ok)
        if len(xs_):
            pick = np.random.default_rng(7).choice(len(xs_), min(16, len(xs_)), replace=False)
            ponds = [[round((xs_[i] + 0.5) / w, 4), round((ys_[i] + 0.5) / h, 4)] for i in pick]
    # the places put by hand win over the found ones
    rims = points_of(hints, "rims") if points_of(hints, "rims") is not None else rims
    eyes = points_of(hints, "eyes") if points_of(hints, "eyes") is not None else eyes
    ponds = points_of(hints, "ponds") if points_of(hints, "ponds") is not None else ponds
    effects = {k: bool(v) for k, v in (hints.get("effects") or {}).items() if isinstance(v, bool)}
    # no alpha: Qt premultiplies it, and a zero would wipe the other three
    rgb = np.stack([layer.astype(np.float32) * 32 / 255, param, np.maximum(lights, glints)], -1)
    mask = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "RGB")
    info = {
        "version": VERSION,
        "size": list(size),
        "maskSize": [w, h],
        "grid": [round(v, 4) for v in grid],
        "pixelArt": k > 1,
        "sky": {"found": bool(sky_found), "night": round(night, 3), "area": round(sky_area, 3)},
        "water": {"found": bool(water.any()), "axis": round(axis / h, 4) if water.any() else None,
                  "mirror": bool(mirror), "area": round(water_area, 3), "falls": round(float(falls.mean()), 3)},
        "lights": n_l,
        "glints": n_g,
        "scene": {"outdoor": outdoor, "rims": rims, "eyes": eyes, "ponds": ponds,
                  "objects": int(len(hints.get("rings", [])) + bool((layer == L_THING).any() and painted.any()))},
        "effects": effects,
        "painted": bool(painted.any()),
    }
    if debug:
        dim = A * 0.35 * 255

        def tint(m, col):
            o = dim.copy()
            o[m] = o[m] * 0.4 + np.array(col) * 0.6
            return o
        pl = dim.copy()
        pl[lights > 0] = [255, 255, 120]
        pl[glints > 0] = [120, 255, 255]
        wt = tint(water, [40, 220, 190])
        wt[falls] = dim[falls] * 0.4 + np.array([220, 80, 220]) * 0.6
        if water.any():
            wt[axis] = [255, 60, 60]
        st = tint(sky, [90, 110, 255])
        st[solid] = st[solid] * 0.5 + np.array([200, 60, 60]) * 0.5
        st[ring] = st[ring] * 0.3 + np.array([255, 220, 80]) * 0.7
        for u_, v_ in rims:
            st[min(h - 1, int(v_ * h)), min(w - 1, int(u_ * w))] = [255, 255, 255]
        grid_ = np.concatenate([np.concatenate([A * 255, st], 1), np.concatenate([wt, pl], 1)], 0)
        Image.fromarray(np.clip(grid_, 0, 255).astype(np.uint8)).save(debug)
    return mask, info


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("picture")
    ap.add_argument("--cache", default=os.path.expanduser("~/.cache/angelos/live-wall"))
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--debug")
    args = ap.parse_args()
    p = Path(args.picture).expanduser()
    try:
        st = p.stat()
    except OSError as e:
        print(json.dumps({"error": str(e), "source": str(p)}))
        return 1
    _, hinted = hints_of(p)
    key = hashlib.md5(f"{p.resolve()}|{st.st_size}|{int(st.st_mtime)}|{hinted}|{VERSION}".encode()).hexdigest()
    cache = Path(args.cache)
    cache.mkdir(parents=True, exist_ok=True)
    jf, mf = cache / (key + ".json"), cache / (key + ".png")
    if not args.force and not args.debug and jf.exists() and mf.exists():
        try:
            print(jf.read_text().strip())
            return 0
        except OSError:
            pass
    try:
        mask, info = analyze(p, args.debug)
    except Exception as e:  # a picture Pillow cannot read: nothing alive in it
        print(json.dumps({"error": f"{type(e).__name__}: {e}", "source": str(p)}))
        return 1
    tmp = mf.with_name(key + ".tmp.png")
    mask.save(tmp)
    os.replace(tmp, mf)
    info["mask"] = str(mf)
    info["source"] = str(p)
    jf.write_text(json.dumps(info))
    print(json.dumps(info))
    return 0


if __name__ == "__main__":
    sys.exit(main())
