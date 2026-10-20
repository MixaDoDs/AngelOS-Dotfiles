#!/usr/bin/env python3
"""How far each spot of a layered scene bends in the wind (widgets/SceneWall): one field for the
whole scene, so the plants of every layer move together where they meet. The pack cuts one crown
into several layers (a far tree, the bush in front of it, the fence inside the bush); bent each
its own way they parted and what is under them showed through (it tore).

A picture of the canvas: red — how far it bends, 0 at a plant's root and wherever it is held by
a thing (ivy lying on the TV, flowers over the bench, the fence inside a bush: layers of role
object / screen and scene.json "hold_masks"), fading in over a few art px round them; green — how
near it is (the layers' parallax, for the hair of depth the plants add to the camera). Smooth
across the layers' seams and a little past the plants' edges, so an edge can move out too.
Cached per scene and its files' times; prints the picture's path (nothing for a scene without
plants).

    scene-hold.py <scene dir> <cache dir>
"""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

FADE = 10   # art px from a thing to a free plant: steeper, and the pixels next to it tear
BLEND = 4   # art px: the seams between the layers of one crown even out over this
NEAR = 3.0  # the parallax of the nearest plants

scene_dir, cache = Path(sys.argv[1]), Path(sys.argv[2])
scene = json.loads((scene_dir / "scene.json").read_text())
visible = [l for l in scene["layers"] if l.get("visible", True)]
plants = sorted((l for l in visible if (l.get("animation") or {}).get("type") == "wind"), key=lambda l: l["z"])
if not plants:
    sys.exit(0)
things = [scene_dir / "logical" / l["file"] for l in visible if l.get("role") in ("object", "screen")]
things += [scene_dir / "logical" / f for f in scene.get("hold_masks", [])]
files = [scene_dir / "scene.json", Path(__file__)] + things + [scene_dir / "logical" / l["file"] for l in plants]
key = hashlib.md5("|".join(f"{f}:{f.stat().st_mtime_ns}" for f in files).encode()).hexdigest()
out = cache / f"{key}.png"


def alpha(f):
    im = Image.open(f)
    return np.asarray(im.convert("RGBA"))[..., 3] > 0 if "A" in im.getbands() else np.asarray(im.convert("L")) > 127


def blur(a, r):
    """Gaussian, sigma r, edges clamped."""
    x = np.arange(-3 * r, 3 * r + 1)
    k = np.exp(-x * x / (2 * r * r))
    k /= k.sum()
    a = np.pad(a, 3 * r, mode="edge")
    a = np.apply_along_axis(lambda v: np.convolve(v, k, "valid"), 0, a)
    return np.apply_along_axis(lambda v: np.convolve(v, k, "valid"), 1, a)


if not out.exists():
    w, h = scene["logical_canvas"]["width"], scene["logical_canvas"]["height"]
    y = np.arange(h, dtype=np.float32)[:, None]
    bend = np.zeros((h, w), np.float32)
    depth = np.zeros((h, w), np.float32)
    cover = np.zeros((h, w), np.float32)
    for l in plants:  # by z: the nearest plant on a spot says how it bends
        a = alpha(scene_dir / "logical" / l["file"])
        anim = l["animation"]
        b = l.get("bounds_logical") or [0, 0, w, h]
        root = anim.get("root_y", 0)
        span = max(1, abs(b[1] - root), abs(b[3] - 1 - root))
        par = abs((l.get("parallax_max_logical") or [0, 0])[0])
        # the root still, the free end bends; the nearer, the further; the far trees hardly
        # (a far crown that sways a pixel tears)
        gain = 0.6 if "far" in l["id"] else 1 + 0.5 * par
        pin = np.clip(np.abs(y - root) / span, 0, 1) ** 1.5 * np.ones((1, w), np.float32)
        bend[a] = (pin * gain * anim.get("amplitude", 1) / (1 + 0.5 * NEAR))[a]
        depth[a] = par / NEAR
        cover[a] = 1
    # one field: averaged across the seams, and carried a little past the edges
    c = blur(cover, BLEND)
    bend = np.where(c > 1e-3, blur(bend * cover, BLEND) / np.maximum(c, 1e-3), 0)
    depth = np.where(c > 1e-3, blur(depth * cover, BLEND) / np.maximum(c, 1e-3), 0)
    bend *= np.clip(c * 4, 0, 1)
    held = np.zeros((h, w), bool)
    for f in things:
        held |= alpha(f)
    m = Image.fromarray((held * 255).astype(np.uint8))
    grey = np.asarray(m, dtype=np.float32) / 255
    for r in range(1, FADE + 1):
        grown = np.asarray(m.filter(ImageFilter.MaxFilter(2 * r + 1)), dtype=np.float32) / 255
        grey = np.maximum(grey, grown * (1 - r / (FADE + 1)))
    bend *= 1 - grey
    rgb = np.stack([bend, depth, np.zeros_like(bend)], -1)
    cache.mkdir(parents=True, exist_ok=True)
    # opaque: Qt premultiplies alpha, and a see-through picture would lose its values
    Image.fromarray(np.round(np.clip(rgb, 0, 1) * 255).astype(np.uint8)).save(out)
print(out)
