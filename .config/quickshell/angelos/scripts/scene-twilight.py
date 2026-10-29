#!/usr/bin/env python3
"""The dusk and the dawn of a layered scene with a night (an author's tool).

  scene-twilight.py SCENE   -> SCENE/logical/dusk/, SCENE/logical/dawn/: every layer recoloured;
                               scene.json gets "twilight"

Run after scripts/scene-night.py (it reads the night's neutral frame). No picture of the hour is
needed: angelOS's own grade over the day's colours, in OKLab, as the night has its own deep blue.

  dusk   the golden hour going blue: everything a little darker, what the sun lights golden, the
         shadows violet; the open sky peach at the horizon, pink, dusky violet at the top; the
         clouds lit pink-peach from below
  dawn   colder and paler: a faint mist lifting the shadows, light pink-peach, shadows blue-grey;
         the sky lavender at the top, pale pink, pale peach at the horizon

Each is snapped to a palette of its own (palette.json: 64 colours for the scene, 16 for its sky). And so the
colours that are picked from the palette (the depth text, what the wind tears off, the lock) can
flow from one hour into the next instead of jumping: "twilight" → "aligned" — for each colour of
the day's palette, the colour it becomes at dusk, at dawn and at night (where the neutral frames
show it, else its grade), the same order (widgets/SceneWall mixes them by the hour); "glow" — the
colours of the scene's own light (the CRT's screen), the depth text's neon at night.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

SCENE = Path(sys.argv[1]).expanduser().resolve()
LOGICAL = SCENE / "logical"
COLOURS = 80

scene = json.loads((SCENE / "scene.json").read_text())
if not scene.get("night"):
    sys.exit("no night in scene.json: run scripts/scene-night.py first")


def rgba(path):
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.float64)


day = rgba(SCENE / scene["neutral_pose"]["reference"])[..., :3]
night = rgba(LOGICAL / scene["night"]["neutral"].replace("logical/", "", 1))[..., :3]
h, w = day.shape[:2]
keep = set(scene["night"].get("keep", []))

sky_mask = LOGICAL / "masks/sky.png"
sky = np.asarray(Image.open(sky_mask).convert("L")) / 255.0 if sky_mask.exists() else np.zeros((h, w))
rows = np.nonzero(sky.max(1) > 0.5)[0]
horizon = rows.max() + 1 if rows.size else h // 2
# 0 at the top of the picture … 1 at the horizon (and below)
height = np.clip(np.arange(h)[:, None] / horizon, 0, 1) * np.ones((1, w))

M1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929], [0.2119034982, 0.6806995451, 0.1073969566], [0.0883024619, 0.2817188376, 0.6299787005]])
M2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468], [1.9779984951, -2.4285922050, 0.4505937099], [0.0259040371, 0.7827717662, -0.8086757660]])


def to_lab(rgb):
    c = np.asarray(rgb, float) / 255.0
    lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    return np.cbrt(lin @ M1.T) @ M2.T


def from_lab(lab):
    lin = np.clip(((lab @ np.linalg.inv(M2).T) ** 3) @ np.linalg.inv(M1).T, 0, 1)
    return 255 * np.where(lin <= 0.0031308, lin * 12.92, 1.055 * lin ** (1 / 2.4) - 0.055)


def hexlab(s):
    return to_lab([int(s[i:i + 2], 16) for i in (1, 3, 5)])


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


HOURS = {
    "dusk": {"dark": 0.76, "shade": 0.12, "lift": 0.0, "chroma": 1.0,
             "lit": (0.034, 0.048), "shadow": (0.012, -0.026),
             "sky": ("#4b3f7c", "#b26a8e", "#f2a273"), "cloud": ("#6e5a88", "#f4b48c")},
    "dawn": {"dark": 0.84, "shade": 0.08, "lift": 0.02, "chroma": 0.82,
             "lit": (0.022, 0.012), "shadow": (-0.004, -0.024),
             "sky": ("#7d8dc2", "#c8aaca", "#f4caa9"), "cloud": ("#8f8aac", "#f6d2c2")},
}


def grade(rgb, kind, sky_w, height_v, cloud):
    """day colours → the hour's, per pixel: sky_w how much it is open sky, height_v 0 top … 1
    horizon, cloud whether it is a cloud"""
    p = HOURS[kind]
    lab = to_lab(rgb)
    L, a, b = lab[..., 0], lab[..., 1], lab[..., 2]
    lit = smooth(0.55, 0.85, L)
    L2 = L * (p["dark"] - p["shade"] * (1 - L)) + p["lift"] * (1 - L)
    a2 = a * p["chroma"] + p["lit"][0] * lit + p["shadow"][0] * (1 - lit)
    b2 = b * p["chroma"] + p["lit"][1] * lit + p["shadow"][1] * (1 - lit)
    out = np.stack([L2, a2, b2], -1)
    if sky_w is not None and np.any(sky_w > 0):
        top, mid, low = (hexlab(c) for c in p["sky"])
        v = height_v[..., None]
        grad = np.where(v < 0.55, top + (mid - top) * (v / 0.55), mid + (low - mid) * ((v - 0.55) / 0.45))
        # the day's sky texture (its bands, its haze) kept as a little lightness
        grad[..., 0] += (L - 0.75) * 0.35
        out = out * (1 - sky_w[..., None]) + grad * sky_w[..., None]
    if cloud is not None and np.any(cloud):
        shade, light = hexlab(p["cloud"][0]), hexlab(p["cloud"][1])
        t = smooth(0.45, 0.95, L)[..., None]
        c = shade + (light - shade) * t
        out = np.where(cloud[..., None], c, out)
    return from_lab(out)


def make_palette(scene_colours, sky_colours):
    """64 colours for the scene and 16 for its sky: the sky's gradient has thousands of colours
    and took every bucket of a common median cut (the leaves came out violet, no green left)"""
    def cut(c, n):
        uniq = np.unique(c.clip(0, 255).astype(np.uint8).reshape(-1, 3), axis=0)
        n = min(n, len(uniq))
        q = Image.fromarray(uniq[None]).quantize(n, method=Image.Quantize.MEDIANCUT)
        return q.getpalette()[:n * 3]
    flat = cut(scene_colours, COLOURS - 16) + (cut(sky_colours, 16) if len(sky_colours) else [])
    pal = Image.new("P", (1, 1))
    pal.putpalette(flat + flat[:3] * (256 - len(flat) // 3))
    return pal


def snap(rgb, pal):
    im = Image.fromarray(rgb.clip(0, 255).astype(np.uint8)).quantize(palette=pal, dither=Image.Dither.NONE)
    return np.asarray(im.convert("RGB")).astype(np.float64)


def frames_of(layer):
    fr = layer.get("frames") or []
    return list(dict.fromkeys([layer["file"]] + list(fr)))


day_pal = np.array(json.loads((SCENE / scene["palette"]["file"]).read_text())["rgb"], float)
twilight = {}
aligned = {"day": [[int(v) for v in c] for c in day_pal]}
for kind in HOURS:
    out_dir = LOGICAL / kind
    graded = {}
    for layer in scene["layers"]:
        if layer["id"] in keep:
            continue
        for f in frames_of(layer):
            src = rgba(LOGICAL / f)
            cloud = (src[..., 3] > 0) if layer.get("role") == "clouds" else None
            # only the sky itself takes the sky's gradient: the vine and the trees hanging in
            # front of it took it too and came out sky-coloured, see-through (the owner)
            sky_l = sky * (src[..., 3] > 0) if layer.get("role") == "background" else None
            graded[f] = (grade(src[..., :3], kind, sky_l, height, cloud), src[..., 3], cloud is not None, sky_l is not None)
    in_sky = [(g[0][(g[1] > 0) & (((sky > 0.5) & g[3]) | g[2])]) for g in graded.values()]
    off_sky = [(g[0][(g[1] > 0) & ~(((sky > 0.5) & g[3]) | g[2])]) for g in graded.values()]
    pal = make_palette(np.concatenate(off_sky), np.concatenate(in_sky))
    for f, (rgb, a, _, _) in graded.items():
        o = np.dstack([snap(rgb, pal), a]).astype(np.uint8)
        o[a == 0] = 0
        dst = out_dir / f
        dst.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray(o, "RGBA").save(dst, optimize=True)
    # the neutral frame of the hour
    stack = np.zeros((h, w, 3))
    for layer in sorted(scene["layers"], key=lambda l: l["z"]):
        if layer.get("visible") is False:
            continue
        f = layer["file"]
        if layer.get("animation", {}).get("type") == "frame_sequence":
            f = layer["animation"]["frames"][0]
        im = rgba((LOGICAL / f) if layer["id"] in keep or f not in graded else (out_dir / f))
        m = im[..., 3:] / 255.0
        stack = stack * (1 - m) + im[..., :3] * m
    Image.fromarray(stack.astype(np.uint8)).save(out_dir / "neutral-656x376.png", optimize=True)
    pal_rgb = np.array(pal.getpalette()[:COLOURS * 3]).reshape(-1, 3)
    (out_dir / "palette.json").write_text(json.dumps({"rgb": sorted(map(list, {tuple(int(v) for v in c) for c in pal_rgb}))}) + "\n")
    twilight[kind] = {"layers": f"{kind}/", "neutral": f"logical/{kind}/neutral-656x376.png", "palette": f"{kind}/palette.json"}
    aligned[kind] = stack
    print(kind, len(graded), "frames →", out_dir)

# each colour of the day's palette, where the day's neutral frame shows it: what it is at dusk,
# at dawn, at night there (the median). Not where something keeps its own colour (the CRT's
# screen glows the same at night): its bright teal stayed bright in the night's row, and the depth
# text, picking the accent's hue, came out neon at night. One it never shows elsewhere: its
# grade; every one snapped into that hour's palette
dk = day.astype(int)
own = np.zeros((h, w), bool)
for layer in scene["layers"]:
    if layer["id"] in keep and layer.get("visible") is not False:
        own |= rgba(LOGICAL / layer["file"])[..., 3] > 0
pals = {k: np.array(json.loads((LOGICAL / v["palette"]).read_text())["rgb"], float) for k, v in twilight.items()}
pals["night"] = np.array(json.loads((LOGICAL / scene["night"]["palette"]).read_text())["rgb"], float)
for kind in ("dusk", "dawn", "night"):
    frame = night if kind == "night" else aligned[kind]
    cols = []
    for c in day_pal.astype(int):
        m = np.all(dk == c, -1) & ~own
        if m.sum() >= 3:
            g = np.median(frame[m], 0)
        else:
            g = grade(c[None, None, :].astype(float), "dusk" if kind == "night" else kind, None, None, None)[0, 0]
            g = g * (0.35 if kind == "night" else 1)
        # a colour of that hour's own palette: at full night the depth text's colours are the
        # night's as before, only now they come to it gradually
        cols.append(pals[kind][np.abs(pals[kind] - g).sum(-1).argmin()])
    aligned[kind] = [[int(round(v)) for v in c] for c in cols]

twilight["aligned"] = aligned
# the light the scene makes itself (what keeps its own colour at night: the CRT's screen), its
# bright and colourful pixels: at night the depth text's neon glows with the screen's light, the
# night's palette alone has nothing to glow with (only deep blues: the neon came out grey)
glow = set()
for layer in scene["layers"]:
    if layer["id"] in keep and layer.get("visible") is not False:
        px = rgba(LOGICAL / layer["file"])
        for c in px[px[..., 3] > 0][:, :3]:
            mx, mn = c.max(), c.min()
            if mx > 90 and (mx - mn) / mx > 0.6:
                glow.add(tuple(int(v) for v in c))
twilight["glow"] = sorted(map(list, glow))
scene["twilight"] = twilight
(SCENE / "scene.json").write_text(json.dumps(scene, ensure_ascii=False, indent=2) + "\n")
print("scene.json → twilight")
