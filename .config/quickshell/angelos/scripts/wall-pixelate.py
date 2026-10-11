#!/usr/bin/env python3
"""Pixel wallpapers: any picture redrawn in big pixels for one screen (services/Wallpapers).

    wall-pixelate.py <picture> [--screen WxH] [--size N] [--colors N] [--dither 0..100]
                     [--cache DIR] [--out FILE] [--force]

Prints one line of JSON, {source, out, art: [w, h], block, colors} or {source, out, skip}, and
leaves the copy in the cache (path + size + mtime + the screen + the numbers + VERSION), so the
same question is answered at once the next time. The original is never touched.

The copy is made for the screen it is shown on: the picture is cut to the screen's shape the
way the wallpaper is (centred), drawn `size` screen pixels to one art pixel (counted on a
1080-pixel screen, so a 1440p screen gets the same look in bigger blocks) and saved at exactly
the screen's pixels: every art pixel is a whole square there, none is smeared.

How it is drawn (numpy and Pillow, as live-wall.py):
  - down to the art's size with a sharp filter, a little more contrast and colour, a light
    unsharp: an art pixel is a decision, not an average
  - a palette of `colors` colours of the picture's own, k-means in Oklab from a median cut
  - ordered dither (Bayer 4×4) between the two palette colours a pixel lies between, only where
    the picture is smooth (a sky, a wall) and the two colours are close: gradients become
    dither, edges stay clean, nothing turns into noise
  - lone pixels that differ a little from everything around are taken back (a star stays)

What is left as it is (skip):
  - "art": the picture is pixel art already (its colours change on a grid), redrawing it on
    another grid would only spoil it
  - "animated": a GIF that moves
A picture smaller than the art's size is not redrawn either: it is only enlarged without
smoothing ("small").
"""
import argparse
import hashlib
import json
import os
import sys
from pathlib import Path

VERSION = 1
BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
SIZES = (2, 3, 4, 5, 6, 8, 10, 12)       # screen pixels to one art pixel on a 1080-pixel screen


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def plan(screen, size):
    """the art's size and the block for a screen: (aw, ah, block)"""
    w, h = screen
    block = max(1, round(size * min(w, h) / 1080))
    return -(-w // block), -(-h // block), block


def cache_key(p, st, screen, size, colors, dither):
    s = f"{p}|{st.st_size}|{st.st_mtime_ns}|{screen[0]}x{screen[1]}|{size}|{colors}|{dither}|{VERSION}"
    return hashlib.md5(str(p).encode()).hexdigest()[:16] + f"-{screen[0]}x{screen[1]}-" + hashlib.md5(s.encode()).hexdigest()[:12]


# ---- colour: sRGB 0…1 <-> Oklab ----
def to_lab(rgb):
    import numpy as np
    c = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    l = 0.4122214708 * c[..., 0] + 0.5363325363 * c[..., 1] + 0.0514459929 * c[..., 2]
    m = 0.2119034982 * c[..., 0] + 0.6806995451 * c[..., 1] + 0.1073969566 * c[..., 2]
    s = 0.0883024619 * c[..., 0] + 0.2817188376 * c[..., 1] + 0.6299787005 * c[..., 2]
    l, m, s = np.cbrt(l), np.cbrt(m), np.cbrt(s)
    return np.stack([0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                     1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                     0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s], -1).astype(np.float32)


def to_rgb(lab):
    import numpy as np
    l = lab[..., 0] + 0.3963377774 * lab[..., 1] + 0.2158037573 * lab[..., 2]
    m = lab[..., 0] - 0.1055613458 * lab[..., 1] - 0.0638541728 * lab[..., 2]
    s = lab[..., 0] - 0.0894841775 * lab[..., 1] - 1.2914855480 * lab[..., 2]
    l, m, s = l ** 3, m ** 3, s ** 3
    c = np.stack([4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
                  -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
                  -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s], -1)
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def pixel_grid(a):
    """(k, ox, oy): art pixels k×k starting at ox, oy; k = 1 for a photo (as live-wall.py)"""
    import numpy as np
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


def blur3(a):
    """a 3×3 box, edges repeated"""
    import numpy as np
    p = np.pad(a, ((1, 1), (1, 1), (0, 0)), mode="edge")
    return (p[:-2, :-2] + p[:-2, 1:-1] + p[:-2, 2:] + p[1:-1, :-2] + p[1:-1, 1:-1] + p[1:-1, 2:] + p[2:, :-2] + p[2:, 1:-1] + p[2:, 2:]) / 9


def nearest(lab, pal):
    """index of the nearest palette colour for every row of lab (n, 3), in chunks"""
    import numpy as np
    out = np.empty(len(lab), np.int32)
    p2 = (pal ** 2).sum(1)
    for i in range(0, len(lab), 65536):
        x = lab[i:i + 65536]
        out[i:i + 65536] = (p2[None, :] - 2 * x @ pal.T).argmin(1)
    return out


def palette_of(im, lab, colors):
    """`colors` colours of the picture: a median cut, then k-means in Oklab"""
    import numpy as np
    from PIL import Image
    q = im.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    raw = np.array(q.getpalette()[:colors * 3], np.float32).reshape(-1, 3) / 255
    used = np.unique(np.asarray(q))
    pal = to_lab(raw[used[used < len(raw)]])
    x = lab.reshape(-1, 3)
    if len(x) > 60000:
        x = x[np.random.default_rng(7).choice(len(x), 60000, replace=False)]
    for _ in range(12):
        idx = nearest(x, pal)
        n = np.bincount(idx, minlength=len(pal)).astype(np.float32)
        s = np.stack([np.bincount(idx, weights=x[:, c], minlength=len(pal)) for c in range(3)], 1).astype(np.float32)
        keep = n > 0
        new = pal.copy()
        new[keep] = s[keep] / n[keep, None]
        moved = float(np.abs(new - pal).max())
        pal = new[keep]
        if moved < 0.0015:
            break
    # darkest first: the palette reads like a ramp in an editor
    return pal[np.argsort(pal[:, 0])]


def draw(lab, pal, dither):
    """(palette indices, how much dither was allowed), both (h, w): the nearest colour,
    ordered dither on the smooth parts"""
    import numpy as np
    h, w, _ = lab.shape
    x = lab.reshape(-1, 3)
    i1 = nearest(x, pal)
    if dither <= 0 or len(pal) < 2:
        return i1.reshape(h, w), np.zeros((h, w), np.float32)
    c1 = pal[i1]
    # the colour on the other side of the pixel: the nearest to its mirror image in c1
    p2 = (pal ** 2).sum(1)
    i2 = np.empty(len(x), np.int32)
    for i in range(0, len(x), 65536):
        m = 2 * x[i:i + 65536] - c1[i:i + 65536]
        d = p2[None, :] - 2 * m @ pal.T
        d[np.arange(len(m)), i1[i:i + 65536]] = np.inf
        i2[i:i + 65536] = d.argmin(1)
    c2 = pal[i2]
    v = c2 - c1
    vv = (v ** 2).sum(1)
    t = np.clip(((x - c1) * v).sum(1) / np.maximum(vv, 1e-9), 0, 0.5)
    # only where the picture is smooth and the two colours are near each other
    g = lab.astype(np.float32)
    gx = np.abs(np.diff(g, axis=1, append=g[:, -1:])).sum(2) + np.abs(np.diff(g, axis=1, prepend=g[:, :1])).sum(2)
    gy = np.abs(np.diff(g, axis=0, append=g[-1:])).sum(2) + np.abs(np.diff(g, axis=0, prepend=g[:1])).sum(2)
    edge = blur3(np.maximum(gx, gy)[..., None])[..., 0].reshape(-1)
    flat = 1 - np.clip((edge - 0.035) / 0.07, 0, 1)
    # … a step of hue counts double: two tones of one colour mix, a brown and a blue do not
    apart = np.sqrt(v[:, 0] ** 2 + 4 * (v[:, 1] ** 2 + v[:, 2] ** 2))
    near = 1 - np.clip((apart - 0.10) / 0.10, 0, 1)
    s = (dither / 100) * flat * near
    yy, xx = np.mgrid[0:h, 0:w]
    thr = ((np.array(BAYER4, np.float32)[yy % 4, xx % 4] + 0.5) / 16).reshape(-1)
    take2 = t > 0.5 - (0.5 - np.minimum(thr, 0.5)) * s
    take2 &= thr < 0.5
    out = np.where(take2, i2, i1).reshape(h, w)
    return out, s.reshape(h, w)


def tidy(idx, pal, soft):
    """a lone pixel a little off everything around it goes back (a star is far off: it stays)"""
    import numpy as np
    p = np.pad(idx, 1, mode="edge")
    n = [p[:-2, 1:-1], p[2:, 1:-1], p[1:-1, :-2], p[1:-1, 2:]]
    lone = np.ones(idx.shape, bool)
    for q in n:
        lone &= q != idx
    same = (n[0] == n[1]) & (n[2] == n[3]) & (n[0] == n[2])
    d = np.sqrt(((pal[idx] - pal[n[0]]) ** 2).sum(2))
    fix = lone & same & (d < 0.15) & (soft < 0.08)
    out = idx.copy()
    out[fix] = n[0][fix]
    return out


def load(path, want):
    """(RGB image, animated): cut to the screen's shape `want` = w / h, centred"""
    from PIL import Image
    Image.MAX_IMAGE_PIXELS = None
    im = Image.open(path)
    if getattr(im, "is_animated", False) and getattr(im, "n_frames", 1) > 1:
        return None, True
    if im.format == "JPEG" and im.width > 6000:
        im.draft("RGB", (im.width // 2, im.height // 2))
    if im.mode in ("RGBA", "LA", "P", "PA"):
        im = im.convert("RGBA")
        im = Image.alpha_composite(Image.new("RGBA", im.size, (0, 0, 0, 255)), im)
    im = im.convert("RGB")
    w, h = im.size
    if w / h > want:
        cw = max(1, round(h * want))
        im = im.crop(((w - cw) // 2, 0, (w - cw) // 2 + cw, h))
    else:
        ch = max(1, round(w / want))
        im = im.crop((0, (h - ch) // 2, w, (h - ch) // 2 + ch))
    return im, False


def pixelate(path, screen, size, colors, dither):
    """(image for the screen | None, info)"""
    import numpy as np
    from PIL import Image, ImageEnhance
    W, H = screen
    aw, ah, block = plan(screen, size)
    im, animated = load(path, W / H)
    if animated:
        return None, {"skip": "animated"}
    # pixel art already? looked at in the middle of the picture, at its own pixels
    cw, chh = min(im.width, 1024), min(im.height, 1024)
    mid = np.asarray(im.crop(((im.width - cw) // 2, (im.height - chh) // 2, (im.width - cw) // 2 + cw, (im.height - chh) // 2 + chh)))
    k, _, _ = pixel_grid(mid)
    if k > 1:
        return None, {"skip": "art", "grid": k}
    if im.width <= aw or im.height <= ah:
        # no more pixels than the art would have: enlarged as it is, without smoothing
        f = max(1, -(-W // im.width), -(-H // im.height))
        big = im.resize((im.width * f, im.height * f), Image.Resampling.NEAREST)
        x, y = (big.width - W) // 2, (big.height - H) // 2
        return big.crop((x, y, x + W, y + H)), {"art": [im.width, im.height], "block": f, "small": True}
    small = im.resize((aw, ah), Image.Resampling.LANCZOS, reducing_gap=3.0)
    small = ImageEnhance.Color(ImageEnhance.Contrast(small).enhance(1.06)).enhance(1.12)
    a = np.asarray(small).astype(np.float32) / 255
    a = np.clip(a + 0.45 * (a - blur3(a)), 0, 1)
    lab = to_lab(a)
    pal = palette_of(Image.fromarray((a * 255 + 0.5).astype(np.uint8)), lab, colors)
    idx, soft = draw(lab, pal, dither)
    idx = tidy(idx, pal, soft)
    out = Image.fromarray(idx.astype(np.uint8), "P")
    flat = (to_rgb(pal) * 255 + 0.5).astype(np.uint8).reshape(-1).tolist()
    out.putpalette(flat + [0] * (768 - len(flat)))
    big = out.resize((aw * block, ah * block), Image.Resampling.NEAREST)
    x, y = (big.width - W) // 2, (big.height - H) // 2
    return big.crop((x, y, x + W, y + H)), {"art": [aw, ah], "block": block, "colors": int(len(pal))}


def prune(cache, key, keep=3):
    """the copies of one picture for one screen pile up while a slider is moved: the newest stay"""
    stem = key.rsplit("-", 1)[0] + "-"
    old = sorted((f for f in cache.glob(stem + "*.json")), key=lambda f: f.stat().st_mtime, reverse=True)[keep:]
    for f in old:
        for g in (f, f.with_suffix(".png")):
            try:
                g.unlink()
            except OSError:
                pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("picture")
    ap.add_argument("--screen", default="1920x1080")
    ap.add_argument("--size", type=int, default=4)
    ap.add_argument("--colors", type=int, default=32)
    ap.add_argument("--dither", type=int, default=60)
    ap.add_argument("--cache", default=os.path.expanduser("~/.cache/angelos/wall-pixel"))
    ap.add_argument("--out", help="write the copy here (no cache)")
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args()
    p = Path(a.picture).expanduser()
    try:
        W, H = (int(v) for v in a.screen.lower().split("x"))
        if not (16 <= W <= 16384 and 16 <= H <= 16384):
            raise ValueError
    except ValueError:
        print(json.dumps({"error": "screen: WxH", "source": str(p)}))
        return 2
    size, colors, dither = clamp(a.size, 1, 32), clamp(a.colors, 2, 256), clamp(a.dither, 0, 100)
    try:
        p = p.resolve()
        st = p.stat()
    except OSError as e:
        print(json.dumps({"error": str(e), "source": str(p)}))
        return 1
    cache = Path(a.cache)
    key = cache_key(p, st, (W, H), size, colors, dither)
    jf = cache / (key + ".json")
    if not a.out and not a.force:
        try:
            j = json.loads(jf.read_text())
            if j.get("out") and os.path.exists(j["out"]):
                os.utime(jf)
                print(json.dumps(j))
                return 0
        except (OSError, ValueError):
            pass
    try:
        img, info = pixelate(p, (W, H), size, colors, dither)
    except Exception as e:  # a picture Pillow cannot read: shown as it is
        print(json.dumps({"error": f"{type(e).__name__}: {e}", "source": str(p), "out": str(p)}))
        return 1
    info["source"] = str(p)
    if img is None:
        info["out"] = str(p)
    else:
        target = Path(a.out).expanduser() if a.out else cache / (key + ".png")
        target.parent.mkdir(parents=True, exist_ok=True)
        tmp = target.with_name(target.stem + ".tmp.png")
        img.save(tmp, compress_level=6)
        os.replace(tmp, target)
        info["out"] = str(target)
    if not a.out:
        cache.mkdir(parents=True, exist_ok=True)
        jf.write_text(json.dumps(info))
        prune(cache, key)
    print(json.dumps(info))
    return 0


if __name__ == "__main__":
    sys.exit(main())
