#!/usr/bin/env python3
"""The demo wallpaper: a pastel pixel sky with clouds, stars and hearts, drawn here (MIT, no
picture of anyone's), so the README's screenshots show nothing borrowed.

  wallpaper.py OUT.png [--dark] [--size 1920x1080]

Drawn at 1/8 of the size and scaled up without smoothing: real pixels. Pillow only.
"""
import argparse
import random

from PIL import Image, ImageDraw

HEART = ["0110110", "1111111", "1111111", "0111110", "0011100", "0001000"]
STAR = ["010", "111", "010"]


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def stamp(px, shape, x0, y0, colour, w, h):
    for dy, row in enumerate(shape):
        for dx, c in enumerate(row):
            if c == "1" and 0 <= x0 + dx < w and 0 <= y0 + dy < h:
                px[x0 + dx, y0 + dy] = colour


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--dark", action="store_true")
    ap.add_argument("--size", default="1920x1080")
    a = ap.parse_args()
    W, H = (int(v) for v in a.size.split("x"))
    w, h = W // 8, H // 8
    rnd = random.Random(1999)
    if a.dark:
        top, bottom = (36, 20, 52), (112, 52, 110)
        cloud, cloud2 = (150, 86, 150), (122, 66, 128)
        star, heart = (255, 214, 240), (255, 120, 190)
    else:
        top, bottom = (255, 214, 236), (196, 178, 255)
        cloud, cloud2 = (255, 247, 252), (246, 226, 245)
        star, heart = (255, 255, 255), (255, 128, 192)
    im = Image.new("RGB", (w, h))
    px = im.load()
    bands = 14                                   # stepped gradient: pixel-art banding
    for y in range(h):
        t = min(bands - 1, y * bands // h) / (bands - 1)
        c = lerp(top, bottom, t)
        for x in range(w):
            px[x, y] = c
    d = ImageDraw.Draw(im)
    for _ in range(7):                           # clouds: stacked rounded slabs
        cx, cy, cw = rnd.randrange(0, w), rnd.randrange(h // 3, h - 10), rnd.randrange(18, 40)
        for i, (dx, dy, ww) in enumerate([(0, 0, cw), (cw // 5, -3, cw * 3 // 5), (cw // 3, -6, cw // 3)]):
            d.rectangle([cx + dx, cy + dy, cx + dx + ww, cy + dy + 3], fill=cloud if i else cloud2)
    for _ in range(60):
        stamp(px, STAR if rnd.random() < 0.3 else ["1"], rnd.randrange(w), rnd.randrange(h * 2 // 3), star, w, h)
    for _ in range(9):
        stamp(px, HEART, rnd.randrange(4, w - 10), rnd.randrange(4, h - 10), heart, w, h)
    im.resize((W, H), Image.NEAREST).save(a.out)


if __name__ == "__main__":
    main()
