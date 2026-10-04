#!/usr/bin/env python3
"""The Golden Gate skin's wallpaper, drawn here (no image of Apple's is used or copied).

  goldengate-wallpaper.py OUT.jpg [--dark] [--size 3840x2160]

Folded layers sweeping up from the lower left like silk or paper — cream, sand and warm brown on
top, slate lilac and fog blue below, each edge catching a thin glossy highlight with a soft shadow
under it: the mood of macOS 27's abstract wallpaper and of the bridge in the evening fog, made of a
few smooth curves. --dark: the same folds at dusk. numpy + Pillow (both angelOS dependencies).
"""
import sys

import numpy as np
from PIL import Image, ImageFilter

args = sys.argv[1:]
out = args[0]
dark = "--dark" in args
size = "3840x2160"
if "--size" in args:
    size = args[args.index("--size") + 1]
W, H = (int(v) for v in size.split("x"))

y, x = np.mgrid[0:H, 0:W].astype(np.float32)
u = x / W
v = y / H


def mix(a, b, t):
    t = np.clip(t, 0, 1)[..., None]
    return a * (1 - t) + b * t


def rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


# the folds: each boundary is a curve v = f(u) sweeping up to the right with an S bend
def curve(u, a, b, c, w, k=0.0):
    return a - b * np.tanh((u - c) / w) - k * u


bounds = [
    curve(u, 0.10, 0.55, 0.30, 0.22, 0.10),
    curve(u, 0.42, 0.60, 0.42, 0.26, 0.15),
    curve(u, 0.78, 0.55, 0.55, 0.30, 0.20),
    curve(u, 1.10, 0.50, 0.68, 0.30, 0.18),
    curve(u, 1.45, 0.45, 0.80, 0.28, 0.15),
]
if dark:
    layers = [("#2d241f", "#5a4636"), ("#3a2c22", "#7a5c43"), ("#2a2533", "#5d5674"),
              ("#232430", "#4d5670"), ("#1d1f29", "#3f4a60"), ("#181a22", "#323a4c")]
    rim, shade = rgb("#e8c9a6"), 0.55
else:
    layers = [("#8b6b4f", "#efe3d1"), ("#a3825f", "#f5ecdf"), ("#6d6a87", "#d9d4dc"),
              ("#58607e", "#c8ccd6"), ("#6f7f97", "#e2e4e8"), ("#8696ab", "#eef0f2")]
    rim, shade = rgb("#fbf6ee"), 0.35

img = np.zeros((H, W, 3), np.float32)
region = np.zeros((H, W), np.int32)
for b in bounds:
    region += (v > b).astype(np.int32)
for i, (lo, hi) in enumerate(layers):
    m = region == i
    # light in each layer: brightest along the middle of the fold, dimmer in the crease under the
    # layer above, plus a broad light from the upper left
    top = bounds[i - 1] if i > 0 else np.full_like(v, -0.4)
    bot = bounds[i] if i < len(bounds) else np.full_like(v, 1.6)
    t = np.clip((v - top) / np.maximum(bot - top, 1e-3), 0, 1)
    fold = np.maximum(0, np.sin(np.pi * np.clip(t * 1.15, 0, 1))) ** 0.8
    light = 0.55 * fold + 0.45 * np.clip(1.15 - (0.6 * u + 0.5 * v), 0, 1)
    col = mix(rgb(lo), rgb(hi), light)
    img[m] = col[m]

# under each edge: a soft shadow on the layer below, on the edge: a thin glossy highlight
px = 1.0 / H
for b in bounds:
    d = (v - b) / px                       # distance below the edge in pixels (screen height units)
    sh = np.exp(-np.clip(d, 0, None) / (H * 0.035)) * (d > 0)
    img *= (1 - shade * 0.55 * sh)[..., None]
    gloss = np.exp(-((d + H * 0.0016) / (H * 0.0011)) ** 2)
    halo = np.exp(-((d + H * 0.002) / (H * 0.006)) ** 2) * 0.35
    img = mix(img, np.broadcast_to(rim, img.shape), np.clip(gloss * 0.9 + halo, 0, 1))

# a whisper of grain against banding
rng = np.random.default_rng(27)
img += rng.normal(0, 1.2, img.shape).astype(np.float32)
pic = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
pic = pic.filter(ImageFilter.GaussianBlur(radius=max(1, W // 2400)))
pic.save(out, quality=92, subsampling=0)
print(out)
