#!/usr/bin/env python3
"""The chest of heaven's prayers (modules/chest/ChestOverlay), drawn as pixel art in code.

  chest-art.py OUTDIR      → chest-closed.png, chest-open.png, chest-lid.png (64×56, 1×; the
                             overlay scales them up by whole factors without smoothing)

A wooden chest with gold bands and a heart-shaped lock plate; open, its inside is dark (the
overlay pours the rarity's light into it). numpy + Pillow (angelOS dependencies).
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

W, H = 64, 56
OUT = "#2a1206"
WOOD = ["#4a2510", "#6b3818", "#8a4c22", "#a8622c", "#c27a3a"]
GOLD = ["#6e3f17", "#a86b22", "#dc9d34", "#f7cc5c", "#fff1b5"]
INSIDE = ["#120804", "#1e0e06", "#2c160a"]


def hexc(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def canvas():
    return np.zeros((H, W, 4), np.uint8)


def put(a, mask, col):
    a[mask] = hexc(col)


def grid():
    y, x = np.mgrid[0:H, 0:W]
    return x.astype(float), y.astype(float)


def outline(a, col=OUT):
    m = a[..., 3] > 0
    o = np.zeros_like(m)
    o[1:] |= m[:-1]
    o[:-1] |= m[1:]
    o[:, 1:] |= m[:, :-1]
    o[:, :-1] |= m[:, 1:]
    put(a, o & ~m, col)


def body(a, X, Y, x0=6, x1=58, y0=30, y1=54):
    box = (X >= x0) & (X < x1) & (Y >= y0) & (Y < y1)
    # planks: vertical boards, lit from the upper left
    plank = ((X - x0) // 9).astype(int)
    shade = np.clip(3 - (plank % 2) - ((Y - y0) / (y1 - y0) * 2).astype(int), 0, 4)
    for i, c in enumerate(WOOD):
        put(a, box & (shade == i), c)
    put(a, box & (((X - x0) % 9) == 0) & (X > x0), WOOD[0])
    # gold bands: the left and right edges, a strap round the middle of the front
    for bx in (x0, x1 - 5):
        band = (X >= bx) & (X < bx + 5) & (Y >= y0) & (Y < y1)
        put(a, band, GOLD[2])
        put(a, band & (X == bx), GOLD[3])
        put(a, band & (X == bx + 4), GOLD[1])
        for ry in range(y0 + 3, y1 - 1, 7):
            put(a, (X == bx + 2) & (Y == ry), GOLD[4])
    strap = box & (Y >= y1 - 6) & (Y < y1 - 3)
    put(a, strap, GOLD[2])
    put(a, strap & (Y == y1 - 6), GOLD[3])
    put(a, (X >= x0) & (X < x1) & (Y == y1 - 1), WOOD[0])
    return box


def lock_plate(a, X, Y, cx=32, top=27):
    plate = (np.abs(X - cx + 0.5) <= 5) & (Y >= top) & (Y < top + 11)
    put(a, plate, GOLD[2])
    put(a, plate & (X <= cx - 4), GOLD[3])
    put(a, plate & (X >= cx + 4), GOLD[1])
    # a heart-shaped keyhole
    heart = ((np.abs(X - (cx - 2)) <= 1) | (np.abs(X - (cx + 1)) <= 1)) & (Y == top + 3)
    heart |= (np.abs(X - cx + 0.5) <= 2.5) & (Y == top + 4)
    heart |= (np.abs(X - cx + 0.5) <= 1.5) & (Y == top + 5)
    heart |= (np.abs(X - cx + 0.5) <= 0.5) & (Y == top + 6)
    put(a, heart, "#c2185b")
    put(a, (X == cx - 2) & (Y == top + 3), "#ff7ab0")
    put(a, plate & ((Y == top) | (Y == top + 10)), GOLD[0])


def lid_closed(a, X, Y, x0=4, x1=60, y0=12, y1=31):
    cx = (x0 + x1 - 1) / 2
    rx = (x1 - x0) / 2
    dome = ((X - cx) / rx) ** 2 + ((Y - y1) / (y1 - y0)) ** 2 <= 1
    dome &= Y < y1
    lit = np.clip(((X - cx) / rx) * -0.5 + (y1 - Y) / (y1 - y0) * 0.9, 0, 1)
    idx = np.clip((1 + lit * 3.2).astype(int), 0, 4)
    for i, c in enumerate(WOOD):
        put(a, dome & (idx == i), c)
    # boards running round the dome
    for k in (0.35, 0.7):
        ring = np.abs(np.sqrt(((X - cx) / rx) ** 2 + ((Y - y1) / (y1 - y0)) ** 2) - k) < 0.045
        put(a, dome & ring, WOOD[0])
    for bx in (x0 + 2, x1 - 7):
        band = dome & (X >= bx) & (X < bx + 5)
        put(a, band, GOLD[2])
        put(a, band & (X == bx), GOLD[3])
        put(a, band & (X == bx + 4), GOLD[1])
    rim = (X >= x0) & (X < x1) & (Y >= y1 - 3) & (Y < y1)
    put(a, rim, GOLD[2])
    put(a, rim & (Y == y1 - 3), GOLD[4])
    put(a, rim & (Y == y1 - 1), GOLD[1])
    return dome


def closed():
    a = canvas()
    X, Y = grid()
    body(a, X, Y)
    lid_closed(a, X, Y)
    lock_plate(a, X, Y)
    outline(a)
    return a


def opened():
    a = canvas()
    X, Y = grid()
    # the lid thrown back, seen from inside: a short band leaning away, narrower at the top
    top, bot = 14, 27
    k = (Y - top) / (bot - top)
    left, right = 9 - 4 * k, 55 + 4 * k
    back = (Y >= top) & (Y < bot) & (X >= left) & (X < right)
    put(a, back, WOOD[0])
    put(a, back & (Y < top + 4), WOOD[1])
    put(a, back & (((Y - top) % 4) == 3), "#3a1c0a")
    for frac in (0.08, 0.86):
        bx = left + (right - left) * frac
        put(a, back & (X >= bx) & (X < bx + 4), GOLD[1])
    put(a, (Y >= top - 2) & (Y < top) & (X >= 9) & (X < 55), GOLD[3])
    # the opening: dark inside (the overlay pours the rarity's light into it), a lit rim
    hole = (X >= 8) & (X < 56) & (Y >= 27) & (Y < 33)
    for i, c in enumerate(INSIDE):
        put(a, hole & (Y >= 27 + i * 2), c)
    body(a, X, Y, y0=31)
    put(a, (X >= 6) & (X < 58) & (Y >= 30) & (Y < 32), GOLD[3])
    lock_plate(a, X, Y, top=34)
    outline(a)
    return a


def lid():
    """the lid alone (it flies off in the burst)"""
    a = canvas()
    X, Y = grid()
    lid_closed(a, X, Y)
    outline(a)
    return a


if __name__ == "__main__":
    out = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    out.mkdir(parents=True, exist_ok=True)
    for name, fn in (("chest-closed", closed), ("chest-open", opened), ("chest-lid", lid)):
        Image.fromarray(fn(), "RGBA").save(out / f"{name}.png", optimize=True)
        print(out / f"{name}.png")
