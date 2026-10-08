#!/usr/bin/env python3
"""Half-alive wallpapers: finds what in a picture may move a little (widgets/LiveWall).

    live-wall.py <picture> [--cache DIR] [--force] [--debug OUT.png]

Prints one line of JSON and leaves in the cache a mask the shader reads (shaders/live_wall.frag),
made once per picture (path + size + mtime):

    R  sky        where new stars may twinkle and a star may fall
    G  water      what ripples, and mirrors the sky above the waterline
    B  points     small bright points already in the picture: off the water lights (stars, lit
                  windows) that twinkle, on it glints that shimmer

The JSON: {mask, size: [w, h] of the picture, grid: [cell w, cell h, offset x, offset y] of one
art pixel in the picture's pixels (cell 1 = a photo), pixelArt, sky: {found, night, area},
water: {found, axis, mirror, area}, lights, glints}. axis is the waterline (0 top … 1 bottom);
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
    mirror, a band of dashes reaching the bottom that is no lighter than the sky
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
VERSION = 5
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


def analyze(path, debug=None):
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
        coherent = float(np.mean(dev)) < 0.06 and sky.sum() > 0.6 * grown
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
    sky_found = sky_area > 0.1 and coherent
    if not sky_found:
        sky[:] = False
        night = 0.0

    # ---- the mask ----
    lights = np.zeros((h, w), dtype=np.float32)
    glints = np.zeros((h, w), dtype=np.float32)
    n_l = n_g = 0
    for ys, xs, bw, bh, gr in blobs:
        v = np.clip((L[ys, xs] - 0.2) / 0.6, 0.35, 1.0)
        if water[ys[0], xs[0]]:
            glints[ys, xs] = v
            n_g += 1
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
    # no alpha: Qt premultiplies it, and a zero would wipe the other three
    rgb = np.stack([sky.astype(np.float32), water.astype(np.float32), np.maximum(lights, glints)], -1)
    mask = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "RGB")
    info = {
        "version": VERSION,
        "size": list(size),
        "maskSize": [w, h],
        "grid": [round(v, 4) for v in grid],
        "pixelArt": k > 1,
        "sky": {"found": bool(sky_found), "night": round(night, 3), "area": round(sky_area, 3)},
        "water": {"found": bool(water.any()), "axis": round(axis / h, 4) if water.any() else None,
                  "mirror": bool(mirror), "area": round(water_area, 3)},
        "lights": n_l,
        "glints": n_g,
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
        if water.any():
            wt[axis] = [255, 60, 60]
        st = tint(sky, [90, 110, 255])
        st[solid] = st[solid] * 0.5 + np.array([200, 60, 60]) * 0.5
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
    key = hashlib.md5(f"{p.resolve()}|{st.st_size}|{int(st.st_mtime)}|{VERSION}".encode()).hexdigest()
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
