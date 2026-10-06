#!/usr/bin/env python3
"""The sprite-rig tool: cuts an artist's sheet into the helper's parts (modules/y2k/SpriteRig).

  sprite-rig.py build RECIPE OUT        cut the sheet a recipe names into OUT/ (body.png, eyes.png,
                                        mouth.png, wing_left.png, wing_right.png, tail.png, rig.json)
                                        and OUT/rig-check.png (three poses, for a look)
  sprite-rig.py guess SHEET [--like RECIPE]
                                        a first recipe for a new sheet, printed as JSON: the parts
                                        found by the sheet's layout, the art-pixel size from the
                                        body, the blink and talk patches fitted onto the face, the
                                        pivots taken over from the like recipe (the neon demon's)
  sprite-rig.py skins [--sprites DIR]   every circle's demon in one go: for each circle of
                                        story/circles.json with a sheet in DIR/<circle>/
                                        (~/Pictures/angelos-sprites), its recipe.json there — made
                                        by `guess` the first time, then the one to tweak by hand —
                                        and the parts into modules/y2k/sprites/demon-<circle>/
  sprite-rig.py verify                  rebuild the neon demon from its recipe and compare it with
                                        modules/y2k/sprites/demon-glitch/ pixel by pixel

How a sheet is cut (the same steps the sprites in the shell were made with):
  1. each part is cropped from the sheet (with `mask`: only its own blob — parts sit close
     together), shrunk by `block` sheet pixels per art pixel (a premultiplied box filter,
     hard alpha) and reduced to 48 colours;
  2. the closed eyes and the open mouth are patches of the face: scaled, laid on the body at
     x, y, and only the pixels that differ from the body under them are kept (clipped to
     `clip`) — the blink and talk overlays, the body's size; where they overlap (a figure
     whose eye is its face) rig.json says blinkCoversTalk and the blink wins; where tears
     would run from — the low edge of each closed eye — goes into rig.json as `tears`;
  3. the wings and the tail are rotated around their pivot on the full-size sheet for every
     angle, only then shrunk (clean outlines), cropped to what all frames cover and put into
     the unrotated part's colours: a strip of frames; `at` is where the pivot sits on the body.
A recipe (JSON): {"sheet", "block", "mask", "cell"?, "boxes": {part: [x0, y0, x1, y1]},
"overlays": {"eyes"|"mouth": {"scale", "x", "y", "clip"?, "oval"?: [cx, cy, rx, ry], "thr"?} |
{"file": a finished overlay, the body's size}},
"parts": {part: {"pivot", "at", "angles", "every", "under"?}}}.
"colors": optional palette size (48 by default). A part may use "sequence": [box, ...]
and optional "scale" instead of a pivot and angles: authored frames, placed at "at"; "key": N
makes a flat dark background around them transparent (from each frame's edge inwards, the
pixels whose R+G+B is at most N — a frame drawn on an opaque black card).
"cell": the grid (sheet pixels) the blobs are found on — 8 unless said; a sheet whose parts
nearly touch (a tail a few pixels under the boots, a wing against the hair) needs a finer one,
4 or 2, or the parts merge into one blob. `guess` goes down by itself while the tail isn't found.
Needs Pillow and numpy.
"""
import json
import os
import shutil
import sys
import tempfile
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

SHELL = Path(__file__).resolve().parent.parent
SPRITES = SHELL / "modules/y2k/sprites"
CELL = 8
PAD = 28 * 20          # room to swing: 100 art pixels around the part at the old block size


def expand(path):
    return Path(os.path.expanduser(str(path)))


def tilde(path):
    """a path under the home as ~/… (recipes go into the shell's tree, which is published)"""
    p, home = str(Path(path).expanduser().resolve()), str(Path.home().resolve())
    return "~" + p[len(home):] if p == home or p.startswith(home + os.sep) else p


# ---------- step 1: parts at art pixels ----------
def shrink(a, f):
    """premultiplied box downscale by f, hard alpha, colours unpremultiplied"""
    h, w, _ = a.shape
    W2, H2 = max(1, round(w * f)), max(1, round(h * f))
    rgb = a[..., :3].astype(float)
    al = (a[..., 3] >= 200).astype(float)
    pm = np.dstack([rgb * al[..., None], al])
    chans = [Image.fromarray(pm[..., i].astype(np.float32), mode="F").resize((W2, H2), Image.BOX) for i in range(4)]
    out = np.dstack([np.asarray(c) for c in chans])
    A = out[..., 3]
    keep = A >= 0.5
    col = np.zeros((H2, W2, 3))
    col[keep] = out[..., :3][keep] / A[keep][:, None]
    res = np.zeros((H2, W2, 4), np.uint8)
    res[..., :3] = np.clip(col, 0, 255)
    res[..., 3] = keep * 255
    return res


def palette(res, n=48):
    im = Image.fromarray(res, "RGBA")
    a = res[..., 3]
    q = im.convert("RGB").quantize(colors=n, method=Image.Quantize.MEDIANCUT).convert("RGB")
    return np.dstack([np.asarray(q), a])


def blobs(a, cell=CELL):
    """the sheet's opaque blobs on a grid of `cell` pixels: label array (cells), count"""
    m = a[..., 3] >= 200
    H, W = m.shape
    g = m[:H - H % cell, :W - W % cell].reshape(H // cell, cell, W // cell, cell).any(axis=(1, 3))
    lab = np.zeros(g.shape, int)
    n = 0
    for y in range(g.shape[0]):
        for x in range(g.shape[1]):
            if g[y, x] and not lab[y, x]:
                n += 1
                q = deque([(y, x)])
                lab[y, x] = n
                while q:
                    cy, cx = q.popleft()
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < g.shape[0] and 0 <= nx < g.shape[1] and g[ny, nx] and not lab[ny, nx]:
                                lab[ny, nx] = n
                                q.append((ny, nx))
    return lab, n


def masked_crop(a, box, lab, cell=CELL):
    """the box, keeping only its biggest blob (grown by 2 cells, for loose glitch bits)
    and nothing that belongs to another blob"""
    x0, y0, x1, y1 = box
    sub = lab[y0 // cell:(y1 + cell - 1) // cell, x0 // cell:(x1 + cell - 1) // cell]
    ids, counts = np.unique(sub[sub > 0], return_counts=True)
    own = ids[np.argmax(counts)]
    mine = lab == own
    grown = mine.copy()
    for _ in range(2):
        p = np.pad(grown, 1)
        grown = p[1:-1, 1:-1] | p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]
    keep = grown & ((lab == 0) | mine)
    full = np.kron(keep, np.ones((cell, cell), bool))
    full = np.pad(full, ((0, a.shape[0] - full.shape[0]), (0, a.shape[1] - full.shape[1])))
    out = a[y0:y1, x0:x1].copy()
    out[..., 3] = np.where(full[y0:y1, x0:x1], out[..., 3], 0)
    return out


def key_out(a):
    """a sheet without alpha (a flat background): the border's colour, and all that touches
    the border in it, becomes transparent"""
    if (a[..., 3] < 200).any():
        return a
    rgb = a[..., :3].astype(int)
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    bg = np.median(border, axis=0)
    near = np.abs(rgb - bg).sum(2) < 60
    H, W = near.shape
    seen = np.zeros_like(near)
    q = deque((y, x) for y in range(H) for x in (0, W - 1) if near[y, x])
    q.extend((y, x) for x in range(W) for y in (0, H - 1) if near[y, x])
    for y, x in q:
        seen[y, x] = True
    while q:
        y, x = q.popleft()
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < H and 0 <= nx < W and near[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                q.append((ny, nx))
    out = a.copy()
    out[..., 3] = np.where(seen, 0, 255)
    return out


class Sheet:
    def __init__(self, recipe):
        self.r = recipe
        self.a = key_out(np.asarray(Image.open(expand(recipe["sheet"])).convert("RGBA")))
        self.cell = recipe.get("cell", CELL)
        self.lab = blobs(self.a, self.cell)[0] if recipe.get("mask") else None

    def part(self, name):
        box = self.r["boxes"][name]
        if self.lab is not None:
            return masked_crop(self.a, box, self.lab, self.cell)
        x0, y0, x1, y1 = box
        return self.a[y0:y1, x0:x1]

    def small(self, name):
        return palette(shrink(self.part(name), 1 / self.r["block"]), self.r.get("colors", 48))


# ---------- step 2: blink and talk ----------
def patch_art(p_hi, s, block):
    """the patch at art resolution: scaled by s, then the sheet's 1/block"""
    h, w, _ = p_hi.shape
    big = Image.fromarray(p_hi, "RGBA").resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)
    return shrink(np.asarray(big), 1 / block)


def diff_overlay(body, patch, x, y, thr=38):
    """only the pixels of the patch that differ from the body under it"""
    H, W = body.shape[:2]
    out = np.zeros_like(body)
    ph, pw = patch.shape[:2]
    for j in range(ph):
        for i in range(pw):
            X, Y = x + i, y + j
            if 0 <= X < W and 0 <= Y < H and patch[j, i, 3] and body[Y, X, 3]:
                d = np.abs(patch[j, i, :3].astype(int) - body[Y, X, :3].astype(int)).sum()
                if d > thr:
                    out[Y, X] = patch[j, i]
    return out


def overlay(sheet, body, name):
    f = sheet.r["overlays"][name]
    if "file" in f:
        # finished by hand (a mouth too odd for a patch: fangs of the closed one to paint out)
        return np.asarray(Image.open(expand(f["file"])).convert("RGBA")).copy()
    p = patch_art(sheet.part(name), f["scale"], sheet.r["block"])
    ov = diff_overlay(body, p, int(round(f["x"])), int(round(f["y"])), thr=f.get("thr", 38))
    if "clip" in f:
        x0, y0, x1, y1 = f["clip"]
        keep = np.zeros(ov.shape[:2], bool)
        keep[y0:y1, x0:x1] = True
        ov[~keep] = 0
    if "oval" in f:
        # an oval instead of a box: no square edge around a mouth, and the closed one's
        # fangs inside it covered by the face of the patch (with a low thr)
        cx, cy, rx, ry = f["oval"]
        yy, xx = np.mgrid[0:ov.shape[0], 0:ov.shape[1]]
        ov[((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2 > 1] = 0
    return ov


# ---------- step 3: swinging parts ----------
def quantize_to(frames, base):
    """all frames in the colours of the unrotated part"""
    pal = Image.fromarray(base[..., :3]).quantize(colors=64, method=Image.Quantize.MEDIANCUT)
    out = []
    for f in frames:
        q = np.asarray(Image.fromarray(f[..., :3]).quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB"))
        out.append(np.dstack([q, f[..., 3]]))
    return out


def swing_frames(sheet, name, cfg, small0):
    hi = Image.fromarray(sheet.part(name), "RGBA")
    W, H = hi.width + 2 * PAD, hi.height + 2 * PAD
    canvas = Image.new("RGBA", (W, H))
    canvas.alpha_composite(hi, (PAD, PAD))
    kx, ky = hi.width / small0.shape[1], hi.height / small0.shape[0]
    px, py = cfg["pivot"]
    cx, cy = PAD + (px + 0.5) * kx, PAD + (py + 0.5) * ky
    frames = [shrink(np.asarray(canvas.rotate(a, Image.BICUBIC, center=(cx, cy))), 1 / sheet.r["block"]) for a in cfg["angles"]]
    fh, fw = frames[0].shape[:2]
    sx, sy = fw / W, fh / H
    pivot = (cx * sx - 0.5, cy * sy - 0.5)
    alpha = np.any([f[..., 3] > 0 for f in frames], axis=0)
    ys, xs = np.nonzero(alpha)
    x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    frames = quantize_to([f[y0:y1, x0:x1] for f in frames], small0)
    return frames, (pivot[0] - x0, pivot[1] - y0)


def key_dark(a, limit):
    """the frame's dark card gone: from the edge inwards, every transparent pixel and every
    pixel no brighter than `limit` (R+G+B) that touches one becomes transparent"""
    dark = (a[..., 3] < 200) | (a[..., :3].astype(int).sum(2) <= limit)
    H, W = dark.shape
    seen = np.zeros_like(dark)
    q = deque((y, x) for y in range(H) for x in (0, W - 1) if dark[y, x])
    q.extend((y, x) for x in range(W) for y in (0, H - 1) if dark[y, x])
    for y, x in q:
        seen[y, x] = True
    while q:
        y, x = q.popleft()
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < H and 0 <= nx < W and dark[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                q.append((ny, nx))
    out = a.copy()
    out[..., 3] = np.where(seen, 0, out[..., 3])
    return out


def sequence_frames(sheet, cfg):
    """An artist's separate poses, aligned at their common top-left origin."""
    frames = []
    for x0, y0, x1, y1 in cfg["sequence"]:
        crop = sheet.a[y0:y1, x0:x1]
        if cfg.get("key"):
            crop = key_dark(crop, cfg["key"])
        frames.append(patch_art(crop, cfg.get("scale", 1), sheet.r["block"]))
    height = max(f.shape[0] for f in frames)
    width = max(f.shape[1] for f in frames)
    frames = [np.pad(f, ((0, height - f.shape[0]), (0, width - f.shape[1]), (0, 0)))
              for f in frames]
    return quantize_to(frames, np.concatenate(frames, axis=1))


def build(recipe, out):
    out = Path(out)
    sheet = Sheet(recipe)
    body = sheet.small("body")
    bh, bw = body.shape[:2]
    parts = {}
    for name, pc in recipe["parts"].items():
        if "sequence" in pc:
            frames, (pvx, pvy) = sequence_frames(sheet, pc), (0, 0)
        else:
            frames, (pvx, pvy) = swing_frames(sheet, name, pc, sheet.small(name))
        fh, fw = frames[0].shape[:2]
        ax, ay = pc["at"]
        parts[name] = dict(frames=frames, w=fw, h=fh, x=round(ax - pvx), y=round(ay - pvy),
                           pivot=[round(float(pvx), 1), round(float(pvy), 1)], angles=pc.get("angles", []),
                           under=pc.get("under", True), every=pc.get("every", 1))
    x0 = min([0] + [p["x"] for p in parts.values()])
    y0 = min([0] + [p["y"] for p in parts.values()])
    x1 = max([bw] + [p["x"] + p["w"] for p in parts.values()])
    y1 = max([bh] + [p["y"] + p["h"] for p in parts.values()])
    rig = {"size": [x1 - x0, y1 - y0], "body": {"x": -x0, "y": -y0, "w": bw, "h": bh}, "parts": {}}
    out.mkdir(parents=True, exist_ok=True)
    for name, p in parts.items():
        Image.fromarray(np.concatenate(p["frames"], axis=1), "RGBA").save(out / (name + ".png"), optimize=True)
        rig["parts"][name] = {"x": p["x"] - x0, "y": p["y"] - y0, "w": p["w"], "h": p["h"],
                              "frames": len(p["frames"]), "every": p["every"], "angles": p["angles"],
                              "pivot": p["pivot"], "under": p["under"]}
    Image.fromarray(body, "RGBA").save(out / "body.png")
    ovs = []
    for name in ("eyes", "mouth"):
        ovs.append(overlay(sheet, body, name))
        Image.fromarray(ovs[-1], "RGBA").save(out / (name + ".png"))
    # a figure whose eye is its face (the closed eye and the talking one are the same spot):
    # a blink hides the talking for its moment, the two never show at once
    if ((ovs[0][..., 3] > 0) & (ovs[1][..., 3] > 0)).any():
        rig["blinkCoversTalk"] = True
    rig["tears"] = tear_points(ovs[0], bw)
    json.dump(rig, open(out / "rig.json", "w"), indent=1)
    check(rig, parts, body, out, ovs)
    return rig


def tear_points(eyes, body_w):
    """where tears run from: the lowest pixel of each closed eye (a blob of the blink overlay),
    a third and two thirds across a wide one (a single great eye), in the middle of a small one"""
    m = eyes[..., 3] > 0
    H, W = m.shape
    lab = np.zeros(m.shape, int)
    n, points = 0, []
    for y in range(H):
        for x in range(W):
            if m[y, x] and not lab[y, x]:
                n += 1
                q, cells = deque([(y, x)]), []
                lab[y, x] = n
                while q:
                    cy, cx = q.popleft()
                    cells.append((cy, cx))
                    for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                        if 0 <= ny < H and 0 <= nx < W and m[ny, nx] and not lab[ny, nx]:
                            lab[ny, nx] = n
                            q.append((ny, nx))
                if len(cells) < 6:
                    continue
                ys, xs = np.array([c[0] for c in cells]), np.array([c[1] for c in cells])
                x0, x1 = xs.min(), xs.max()
                cols = [x0 + (x1 - x0) / 3, x0 + 2 * (x1 - x0) / 3] if x1 - x0 > body_w * 0.3 else [(x0 + x1) / 2]
                for cx in cols:
                    cx = int(round(cx))
                    near = ys[np.abs(xs - cx) <= 1]
                    points.append([cx, int((near.max() if len(near) else ys.max()) + 1)])
    return sorted(points)


def check(rig, parts, body, out, overlays=()):
    """three poses side by side (wings in, middle, out), then the face as it is, blinking
    and talking — ×3, on a dark violet: what to look at before tuning a recipe"""
    tiles = []
    n = max([len(p["frames"]) for p in parts.values()] or [1])
    for k in (0, n // 2, n - 1):
        W, H = rig["size"]
        im = Image.new("RGBA", (W, H))
        bx, by = rig["body"]["x"], rig["body"]["y"]
        for layer in (True, False):
            if not layer:
                im.alpha_composite(Image.fromarray(body, "RGBA"), (bx, by))
            for name, p in parts.items():
                if p["under"] == layer:
                    r = rig["parts"][name]
                    im.alpha_composite(Image.fromarray(p["frames"][min(k, len(p["frames"]) - 1)], "RGBA"), (r["x"], r["y"]))
        bg = Image.new("RGBA", im.size, (60, 40, 70, 255))
        bg.alpha_composite(im)
        tiles.append(bg.resize((W * 3, H * 3), Image.NEAREST))
    bh, bw = body.shape[:2]
    # the face: the body's upper half, or down past the lowest overlay pixel (a girl's face is
    # up there, a figure's eye may sit lower)
    low = max([int(np.nonzero(ov[..., 3].any(axis=1))[0].max()) + 4 for ov in overlays if ov[..., 3].any()] or [0])
    fh = min(bh, max(int(bh * 0.55), low))
    for ov in (None,) + tuple(overlays):
        im = Image.fromarray(body, "RGBA")
        if ov is not None:
            im.alpha_composite(Image.fromarray(ov, "RGBA"))
        bg = Image.new("RGBA", im.size, (60, 40, 70, 255))
        bg.alpha_composite(im)
        face = bg.crop((0, 0, bw, fh))
        tiles.append(face.resize((face.width * 3, face.height * 3), Image.NEAREST))
    s = Image.new("RGBA", (sum(t.width + 12 for t in tiles), max(t.height for t in tiles)), (20, 20, 20, 255))
    x = 0
    for t in tiles:
        s.alpha_composite(t, (x, 0))
        x += t.width + 12
    s.save(out / "rig-check.png")


# ---------- guess: a first recipe for a new sheet ----------
def find_parts(a, cell=CELL):
    """the parts by where the sheets put them (the prompt asks for this layout): the body is
    the tallest blob, on the left; the two big blobs right of it in the upper half are the
    wings (left one first); low on the sheet the tail — the widest blob lying under the body,
    wider than tall — and, right of it, the closed eyes and the open mouth: the two topmost there, left to
    right (more pictures further down, a belly's mouth say, are left alone). → {part: box}"""
    lab, n = blobs(a, cell)
    H, W = a.shape[:2]
    found = []
    for i in range(1, n + 1):
        ys, xs = np.nonzero(lab == i)
        if len(ys) * cell * cell < 12 * CELL * CELL:
            continue
        box = [int(xs.min() * cell), int(ys.min() * cell), int(min(W, (xs.max() + 1) * cell)), int(min(H, (ys.max() + 1) * cell))]
        found.append({"box": box, "area": len(ys), "w": box[2] - box[0], "h": box[3] - box[1],
                      "cx": (box[0] + box[2]) / 2, "cy": (box[1] + box[3]) / 2})
    if not found:
        raise SystemExit("no parts found on the sheet")
    body = max(found, key=lambda b: (b["h"], b["area"]))
    big = [b for b in found if b is not body and b["area"] >= body["area"] * 0.04]
    upper = sorted([b for b in big if b["cy"] < H * 0.55 and b["cx"] > body["box"][2]], key=lambda b: -b["area"])[:2]
    # low on the sheet: the tail under the body, then the two faces right of it, topmost
    lower = [b for b in big if b not in upper and b["cy"] > H * 0.55]
    under = [b for b in lower if b["box"][0] < body["box"][2] and b["w"] > b["h"]]
    tail = max(under, key=lambda b: b["w"]) if under and len(lower) >= 3 else None
    faces = sorted([b for b in lower if b is not tail], key=lambda b: b["cy"])[:2]
    parts = {"body": body["box"]}
    if len(upper) == 2:
        left, right = sorted(upper, key=lambda b: b["cx"])
        parts["wing_left"], parts["wing_right"] = left["box"], right["box"]
    if tail:
        parts["tail"] = tail["box"]
    if len(faces) == 2:
        eyes, mouth = sorted(faces, key=lambda b: b["cx"])
        parts["eyes"], parts["mouth"] = eyes["box"], mouth["box"]
    missing = [p for p in ("wing_left", "wing_right", "eyes", "mouth") if p not in parts]
    if missing:
        raise SystemExit("could not tell these parts on the sheet: " + ", ".join(missing))
    return parts


def fit_patch(body, hi, block, scales, region):
    """where the patch (closed eyes, open mouth) sits on the body and how big: the least mean
    colour difference over it, each pixel's difference clipped (the eyes themselves don't decide)"""
    H, W = body.shape[:2]
    best = (1e9, None)
    x0, y0, x1, y1 = region
    for s in scales:
        p = patch_art(hi, s, block)
        ph, pw = p.shape[:2]
        for y in range(y0, y1):
            for x in range(x0, x1):
                if x < 0 or y < 0 or x + pw > W or y + ph > H:
                    continue
                b = body[y:y + ph, x:x + pw]
                both = (p[..., 3] > 0) & (b[..., 3] > 0)
                if both.sum() / max(1, (p[..., 3] > 0).sum()) < 0.9:
                    continue
                d = np.minimum(np.abs(p[..., :3].astype(int) - b[..., :3].astype(int)).sum(2), 140)
                e = float(d[both].mean())
                if e < best[0]:
                    best = (e, (round(float(s), 3), x, y, pw, ph))
    return best[1]


def guess(sheet_path, like):
    a = key_out(np.asarray(Image.open(expand(sheet_path)).convert("RGBA")))
    ref = json.load(open(like))
    ref_sheet = Sheet(ref)
    ref_body = ref_sheet.small("body")
    # parts that nearly touch merge on the usual grid (the tail into the body): finer ones
    for cell in (CELL, CELL // 2, CELL // 4):
        try:
            boxes = find_parts(a, cell)
        except SystemExit:
            if cell == CELL // 4:
                raise
            continue
        if "tail" not in ref["parts"] or "tail" in boxes:
            break
    # the same figure height as the reference: the art pixel from the body's height
    block = round((boxes["body"][3] - boxes["body"][1]) / ref_body.shape[0], 3)
    recipe = {"sheet": tilde(sheet_path), "block": block, "mask": True, "boxes": boxes, "overlays": {}, "parts": {}}
    if cell != CELL:
        recipe["cell"] = cell
    sheet = Sheet(recipe)
    body = sheet.small("body")
    bh, bw = body.shape[:2]
    # the mouth first (its patch fits most surely), then the eyes, which sit above it
    mouth_y = int(bh * 0.5)
    for name, lo, hi_ in (("mouth", 0.4, 1.3), ("eyes", 0.6, 1.3)):
        found = fit_patch(body, sheet.part(name), block, np.arange(lo, hi_, 0.025), (0, int(bh * 0.15), bw, mouth_y if name == "eyes" else int(bh * 0.5)))
        if not found:
            raise SystemExit("could not lay the %s on the face" % name)
        s, x, y, pw, ph = found
        if name == "mouth":
            mouth_y = y
        # only the eyes / the mouth change, not the hair of the patch: its middle
        if name == "eyes":
            clip = [x + int(pw * 0.2), y + int(ph * 0.3), x + int(pw * 0.8), y + int(ph * 0.75)]
        else:
            clip = [x + int(pw * 0.3), y + int(ph * 0.35), x + int(pw * 0.7), y + int(ph * 0.9)]
        recipe["overlays"][name] = {"scale": s, "x": x, "y": y, "clip": clip}
    # the pivots and where they sit: the reference's, at the same place relative to the parts
    rbh, rbw = ref_body.shape[:2]
    for name, pc in ref["parts"].items():
        if name not in boxes:
            continue
        rp = ref_sheet.small(name)
        sp = sheet.small(name)
        k = (sp.shape[1] / rp.shape[1], sp.shape[0] / rp.shape[0])
        recipe["parts"][name] = {"pivot": [round(pc["pivot"][0] * k[0], 1), round(pc["pivot"][1] * k[1], 1)],
                                 "at": [round(pc["at"][0] * bw / rbw), round(pc["at"][1] * bh / rbh)],
                                 "angles": pc["angles"], "every": pc.get("every", 1)}
    return recipe


# ---------- the circles' demons ----------
def circles():
    try:
        data = json.loads((SHELL / "story/circles.json").read_text())
    except (OSError, ValueError):
        return []
    return [k for k in data if k not in ("_comment", "base")]


def sheet_in(folder):
    pics = sorted(p for p in folder.glob("*.png") if not p.name.startswith(("rig-check", ".")))
    return pics[0] if pics else None


def skins(sprites):
    like = SPRITES / "demon-glitch/recipe.json"
    done = []
    for cid in circles():
        folder = sprites / cid
        sheet = sheet_in(folder) if folder.is_dir() else None
        if not sheet:
            continue
        rfile = folder / "recipe.json"
        if rfile.exists():
            recipe = json.load(open(rfile))
        else:
            recipe = guess(sheet, like)
            json.dump(recipe, open(rfile, "w"), indent=1, ensure_ascii=False)
        out = SPRITES / ("demon-" + cid)
        build(recipe, out)
        shutil.move(str(out / "rig-check.png"), str(folder / "rig-check.png"))
        json.dump(recipe, open(out / "recipe.json", "w"), indent=1, ensure_ascii=False)
        done.append(cid)
        print("demon-%s ← %s (look: %s)" % (cid, sheet.name, folder / "rig-check.png"))
    if not done:
        print("no sheets yet: put a PNG into %s/<circle>/" % sprites)
    return done


def verify():
    ref = SPRITES / "demon-glitch"
    recipe = json.load(open(ref / "recipe.json"))
    if not expand(recipe["sheet"]).exists():
        print("the sheet isn't on this machine: " + recipe["sheet"])
        return 2
    with tempfile.TemporaryDirectory(prefix="sprite-rig-") as tmp:
        build(recipe, tmp)
        bad = []
        for f in sorted(p.name for p in ref.iterdir() if p.suffix in (".png", ".json") and p.name != "recipe.json"):
            if f.endswith(".json"):
                same = json.load(open(ref / f)) == json.load(open(Path(tmp) / f))
            else:
                A = np.asarray(Image.open(ref / f).convert("RGBA"))
                B = np.asarray(Image.open(Path(tmp) / f).convert("RGBA"))
                same = A.shape == B.shape and bool((A == B).all())
            print(("same      " if same else "DIFFERENT ") + f)
            if not same:
                bad.append(f)
    return 1 if bad else 0


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__)
        return 2
    cmd = a[0]
    if cmd == "build" and len(a) >= 3:
        build(json.load(open(a[1])), a[2])
        return 0
    if cmd == "guess" and len(a) >= 2:
        like = a[a.index("--like") + 1] if "--like" in a else SPRITES / "demon-glitch/recipe.json"
        print(json.dumps(guess(a[1], like), indent=1, ensure_ascii=False))
        return 0
    if cmd == "skins":
        sprites = expand(a[a.index("--sprites") + 1]) if "--sprites" in a else expand("~/Pictures/angelos-sprites")
        skins(sprites)
        return 0
    if cmd == "verify":
        return verify()
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
