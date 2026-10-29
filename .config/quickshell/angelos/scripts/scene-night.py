#!/usr/bin/env python3
"""The night of a layered scene, baked from a night picture of the same place (an author's tool).

  scene-night.py SCENE NIGHT_PACK   -> SCENE/logical/night/: every layer recoloured to night,
                                       the event's light and sprites; scene.json gets "night"

The night picture (an image model's take on the scene: the same courtyard, drawn again) never
lines up with the day's layers pixel for pixel, and has no palette. So its layers are not used:
each layer of the scene keeps its own pixels and gets the night's colours instead — wind,
parallax, the clouds and the depth text all keep working, and day and night share every edge.

  colour   for each colour of the scene's palette, the median the night picture has where the
           day's neutral frame shows it (the CRT's screen left out: it glows the same at night)
  deep     then a night of angelOS's own over it (OKLab): darker, the shadows deepest, every hue
           drawn to a deep blue, the warm ones (the picture's dusk: pink clouds, rust trees) all
           but grey, the sky near black at the top. The night picture alone read as a sunset
  palette  every pixel snapped to one night palette (median cut of the recolouring): pixel art
           again, no in-between colours; written as night/palette.json — the depth text and what
           the wind tears off take their colours from it at night, not from the day's bright ones
  stars    single pixels in the open sky (masks/sky.png), seeded; scene.json → "night" → "stars"
  debris   not here: scripts/scene-shards.py lays the meteor's shards (kept when baked again)
  keep     the CRT's screen and the window glints: the screen glows, the sun's glints are off

By hand in scene.json → "night": "depth_text" {"rect", …} — the text's place at night, when the
day's stands in the event's way (merged over the day's depth_text; kept when baked again).

NIGHT_PACK is the author's night pack (reference/night_master.png, effects/, the meteor's path in
manifest.json). Also written: light.png (r: the meteor's light as it comes near, g: the blast's,
broad, art px), meteor.png and fire.png (the sprites on few colours). The light's colours, the
meteor's path and the fire's origin go to scene.json → "night"; widgets/SceneWall reads them.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

SCENE = Path(sys.argv[1]).expanduser().resolve()
PACK = Path(sys.argv[2]).expanduser().resolve()
LOGICAL = SCENE / "logical"
OUT = LOGICAL / "night"
COLOURS = 80
STARS = 46


def rgba(path):
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.float64)


def blur(a, s):
    """a separable gaussian, edges held (numpy only)"""
    r = int(3 * s)
    x = np.arange(-r, r + 1)
    k = np.exp(-x * x / (2.0 * s * s))
    k /= k.sum()
    p = np.pad(a, ((r, r), (r, r)) + ((0, 0),) * (a.ndim - 2), mode="edge")
    p = np.apply_along_axis(lambda v: np.convolve(v, k, "valid"), 0, p)
    return np.apply_along_axis(lambda v: np.convolve(v, k, "valid"), 1, p)


def key(rgb):
    rgb = rgb.astype(np.int64)
    return rgb[..., 0] * 65536 + rgb[..., 1] * 256 + rgb[..., 2]


scene = json.loads((SCENE / "scene.json").read_text())
manifest = json.loads((PACK / "manifest.json").read_text())
day = rgba(SCENE / scene["neutral_pose"]["reference"])[..., :3]
night = rgba(PACK / "reference/night_master.png")[..., :3]
if day.shape != night.shape:
    sys.exit(f"the night picture is {night.shape[1]}×{night.shape[0]}, the scene {day.shape[1]}×{day.shape[0]}")
h, w = day.shape[:2]
screen = np.asarray(Image.open(LOGICAL / "masks/crt_screen.png").convert("L")) > 127 if (LOGICAL / "masks/crt_screen.png").exists() else np.zeros((h, w), bool)

# colour: the night's median for each colour of the day
dk = key(day)
lut = {}
for c in np.unique(dk):
    m = (dk == c) & ~screen
    if m.any():
        lut[int(c)] = np.median(night[m], axis=0)
known = np.array(list(lut.keys()))
known_rgb = np.stack([(known >> 16) & 255, (known >> 8) & 255, known & 255], -1).astype(np.float64)
known_night = np.array([lut[int(c)] for c in known])


# the open sky, weighted to its top: there the night is darkest
sky_mask = LOGICAL / "masks/sky.png"
sky = np.asarray(Image.open(sky_mask).convert("L")) / 255.0 if sky_mask.exists() else np.zeros((h, w))
rows = np.nonzero(sky.max(1) > 0.5)[0]
horizon = rows.max() + 1 if rows.size else 1
sky_top = sky * np.clip(1 - np.arange(h)[:, None] / horizon, 0, 1) ** 0.8

# OKLab (Björn Ottosson's), for the deep night
M1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929], [0.2119034982, 0.6806995451, 0.1073969566], [0.0883024619, 0.2817188376, 0.6299787005]])
M2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468], [1.9779984951, -2.4285922050, 0.4505937099], [0.0259040371, 0.7827717662, -0.8086757660]])


def to_lab(rgb):
    c = rgb / 255.0
    lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    return np.cbrt(lin @ M1.T) @ M2.T


def from_lab(lab):
    lin = np.clip(((lab @ np.linalg.inv(M2).T) ** 3) @ np.linalg.inv(M1).T, 0, 1)
    return 255 * np.where(lin <= 0.0031308, lin * 12.92, 1.055 * lin ** (1 / 2.4) - 0.055)


def deep(rgb):
    """the night picture's colours → angelOS's night: darker (the shadows most), blue, the warm
    hues nearly grey, the open sky darker toward its top"""
    lab = to_lab(rgb)
    c, hue = np.hypot(lab[..., 1], lab[..., 2]), np.arctan2(lab[..., 2], lab[..., 1])
    warm = np.clip(np.cos(hue - 0.9) * 1.2, 0, 1)      # orange, pink, yellow
    c = c * (0.7 - 0.62 * warm)
    lum = 0.92 * np.clip(lab[..., 0], 0, 1) ** 1.2
    a = c * np.cos(hue) * 0.75 - 0.006
    b = c * np.sin(hue) * 0.75 - 0.034 * (1 - 0.4 * lum)
    lum, b = lum * (1 - 0.45 * sky_top), b - 0.015 * sky_top
    return from_lab(np.stack([lum, a, b], -1))


def recolour(rgb):
    """day colours → night colours; one the neutral frame never shows takes its nearest's"""
    cols, inv = np.unique(rgb.reshape(-1, 3), axis=0, return_inverse=True)
    d = ((cols[:, None, :] - known_rgb[None, :, :]) ** 2).sum(-1)
    return deep(known_night[d.argmin(1)][inv.reshape(-1)].reshape(rgb.shape))


base = recolour(day)
# each colour counted once: by pixel count the dark masses took every bucket, the moonlit
# planks and petals merged into the dusk
uniq = np.unique(base[~screen].clip(0, 255).astype(np.uint8), axis=0)
palette_img = Image.fromarray(uniq[None]).quantize(COLOURS, method=Image.Quantize.MEDIANCUT)
night_palette = np.array(palette_img.getpalette()[:COLOURS * 3]).reshape(-1, 3)


def snap(rgb):
    im = Image.fromarray(rgb.clip(0, 255).astype(np.uint8)).quantize(palette=palette_img, dither=Image.Dither.NONE)
    return np.asarray(im.convert("RGB"))


def keep(layer):
    return layer.get("role") == "screen"


OUT.mkdir(parents=True, exist_ok=True)
done = []
for layer in scene["layers"]:
    if keep(layer):
        continue
    src = rgba(LOGICAL / layer["file"])
    a = src[..., 3]
    rgb = snap(recolour(src[..., :3]))
    out = np.dstack([rgb, a.astype(np.uint8)])
    out[a == 0] = 0
    dst = OUT / layer["file"]
    dst.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(out, "RGBA").save(dst, optimize=True)
    done.append(layer["id"])

# the neutral night, for the list's thumbnail and checking against
stack = np.zeros((h, w, 3))
for layer in sorted(scene["layers"], key=lambda l: l["z"]):
    if layer.get("visible") is False:
        continue
    f = (LOGICAL / layer["file"]) if keep(layer) else (OUT / layer["file"])
    if layer.get("animation", {}).get("type") == "frame_sequence":
        f = LOGICAL / layer["animation"]["frames"][0]
    im = rgba(f)
    m = im[..., 3:] / 255.0
    stack = stack * (1 - m) + im[..., :3] * m
Image.fromarray(stack.astype(np.uint8)).save(OUT / "neutral-656x376.png", optimize=True)
(OUT / "palette.json").write_text(json.dumps({"rgb": sorted(map(list, {tuple(int(v) for v in c) for c in night_palette}))}) + "\n")

# the stars: in the open sky, a few pixels from its edges (not on a roof's or a leaf's rim),
# seeded so a bake gives the same ones; most faint, every fifth bright. Each comes out at its own
# depth of the dusk (`at`, the night's mix), so they light one by one
rng = np.random.default_rng(2004)
open_sky = sky > 0.5
for _ in range(3):
    open_sky = open_sky & np.roll(open_sky, 1, 0) & np.roll(open_sky, -1, 0) & np.roll(open_sky, 1, 1) & np.roll(open_sky, -1, 1)
ys, xs = np.nonzero(open_sky & (np.arange(h)[:, None] < horizon * 0.85))
# their two colours are their own, a cold white and a dimmer one: the night's lightest are dim
faint, bright = (from_lab(np.array([L, -0.01, -0.04])).round() for L in (0.62, 0.88))
stars = []
for i in rng.permutation(len(xs))[:STARS * 8]:
    if len(stars) == STARS:
        break
    x, y = int(xs[i]), int(ys[i])
    if all(abs(x - sx) + abs(y - sy) > 9 for sx, sy, *_ in stars):
        stars.append([x, y, 1 if len(stars) % 5 == 0 else 0, round(float(rng.uniform(0.35, 0.95)), 2)])

# the event's light: broad, so it lands on the scene's own walls and leaves, not the night
# picture's; its colour is a uniform (warm), the map only says how much
approach = rgba(PACK / "effects/approach_light_add.png")
blast = rgba(PACK / "effects/blast_light.png")
a_amt = approach[..., :3].max(-1)
b_amt = blast[..., 3] * blast[..., :3].max(-1) / 255.0
a_map, b_map = blur(a_amt, 3), blur(b_amt, 3)
light = np.dstack([a_map / max(a_map.max(), 1e-6), b_map / max(b_map.max(), 1e-6), np.zeros((h, w)), np.ones((h, w))])
Image.fromarray((light * 255).clip(0, 255).astype(np.uint8), "RGBA").save(OUT / "light.png", optimize=True)


def colour_of(rgb, weight):
    c = (rgb * weight[..., None]).sum((0, 1)) / max(weight.sum(), 1e-6)
    return [round(float(v) / max(c.max(), 1e-6), 3) for v in c]


# the sprites on few colours: the meteor is light added (black = nothing), the fire drawn over
meteor = Image.open(PACK / manifest["meteor"]["file"]).convert("RGB")
meteor.quantize(12, method=Image.Quantize.MEDIANCUT).convert("RGB").save(OUT / "meteor.png", optimize=True)
fire = rgba(PACK / manifest["explosion"]["file"])
fa = fire[..., 3]
fire_rgb = np.asarray(Image.fromarray(fire[..., :3].astype(np.uint8)).quantize(12, method=Image.Quantize.MEDIANCUT).convert("RGB"))
# the edge: no half-transparent pixels, a thing either is fire or is not
Image.fromarray(np.dstack([fire_rgb, np.where(fa >= 96, 255, 0).astype(np.uint8)]), "RGBA").save(OUT / "fire.png", optimize=True)

# what the author set by hand stays (the depth text's place at night), and the shards
kept = {k: v for k, v in (scene.get("night") or {}).items() if k in ("depth_text", "debris")}
scene["night"] = kept | {
    "layers": "night/",
    "keep": [l["id"] for l in scene["layers"] if keep(l)],
    "neutral": "logical/night/neutral-656x376.png",
    "palette": "night/palette.json",
    "stars": {"z": 2, "faint": [int(v) for v in faint], "bright": [int(v) for v in bright], "at": stars},
    "light": "night/light.png",
    "approach_color": colour_of(approach[..., :3], a_amt),
    "blast_color": colour_of(blast[..., :3], b_amt),
    "event": {
        "z": 15,
        "meteor": {"file": "night/meteor.png", "head": manifest["meteor"]["head_in_crop"],
                   "path": manifest["meteor"]["head_path"], "scale": [0.32, 1.0]},
        "fire": {"file": "night/fire.png", "origin": manifest["explosion"]["origin"], "scale": 0.65, "rise": 120},
    },
}
(SCENE / "scene.json").write_text(json.dumps(scene, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({"layers": done, "colours": COLOURS, "out": str(OUT)}, ensure_ascii=False))
