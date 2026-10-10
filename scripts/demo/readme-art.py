#!/usr/bin/env python3
"""The README's drawn pieces, pixel-crisp (drawn at 1x, scaled ×2 with nearest):

  docs/readme/install-note.png      a torn scrap of lined paper with the install commands
  docs/readme/release-NN-name.png   every release's wallpapers, day over night, from Pictures/AngelOS

  scripts/demo/readme-art.py [--out docs/readme]
"""
import argparse
import json
import random
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
FONTS = ROOT / ".local/share/fonts/pixel"
PAPER, LINE, MARGIN, INK, PINK, PINK_DARK, SHADOW = (
    (246, 239, 220, 255), (201, 214, 232, 255), (236, 168, 186, 255), (52, 38, 60, 255),
    (255, 92, 173, 255), (178, 48, 118, 255), (20, 10, 30, 110))


def font(name, size):
    return ImageFont.truetype(str(FONTS / name), size)


def torn_edge(width, step, depth, rnd):
    """y offsets of a torn edge: one value per `step` px, a random walk clamped to `depth`."""
    ys, y = [], rnd.randint(0, depth)
    for _ in range(width // step + 1):
        y = max(0, min(depth, y + rnd.choice((-3, -2, -1, 0, 0, 1, 2, 3))))
        ys.append(y)
    return ys


def paper_polygon(w, h, rnd, step=4, depth=10):
    top, bottom = torn_edge(w, step, depth, rnd), torn_edge(w, step, depth, rnd)
    pts = [(min(i * step, w), top[i]) for i in range(len(top))]
    pts += [(w - min(i * step, w), h - bottom[i]) for i in range(len(bottom))]
    return pts


WORDS = {
    "en": ("for whoever finds this:", "one command. it asks you the rest.",
           "CachyOS or Arch, niri. it backs up what it touches.", "~ welcome back, internet angel ~", "re-run = safe"),
    "ru": ("тому, кто это найдёт:", "одна команда. остальное она спросит сама.",
           "CachyOS или Arch, niri. всё, что трогает, бэкапит.", "~ с возвращением, интернет-ангел ~", "повторно = безопасно"),
}


def install_note(out, lang="en"):
    rnd = random.Random(2026)
    w, h = 560, 196
    im = Image.new("RGBA", (w + 16, h + 16), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    poly = paper_polygon(w, h, rnd)
    draw.polygon([(x + 8 + 3, y + 8 + 4) for x, y in poly], fill=SHADOW)      # the shadow
    draw.polygon([(x + 8, y + 8) for x, y in poly], fill=PAPER)
    # ruled lines and the red margin, clipped to the paper by a mask
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).polygon([(x + 8, y + 8) for x, y in poly], fill=255)
    rule = Image.new("RGBA", im.size, (0, 0, 0, 0))
    rd = ImageDraw.Draw(rule)
    for y in range(8 + 34, h, 18):
        rd.line([(8, y), (8 + w, y)], fill=LINE, width=1)
    rd.line([(8 + 36, 8), (8 + 36, 8 + h)], fill=MARGIN, width=1)
    im.paste(rule, (0, 0), Image.composite(rule, Image.new("RGBA", im.size, (0, 0, 0, 0)), mask))
    draw = ImageDraw.Draw(im)
    # a strip of pink tape at the top left
    tape = Image.new("RGBA", (74, 18), (255, 143, 200, 175))
    im.alpha_composite(tape, (8 + 22, 8 - 6))
    # the words
    hand, mono, small = font("CozetteVector.ttf", 13), font("CozetteVectorBold.ttf", 13), font("CozetteVector.ttf", 13)
    t = WORDS[lang]
    x0 = 8 + 48
    draw.text((x0, 8 + 22), t[0], font=hand, fill=PINK_DARK)
    y = 8 + 44
    for line in ("git clone https://github.com/MixaDoDs/AngelOS-Dotfiles.git",
                 "cd AngelOS-Dotfiles",
                 "./install.sh"):
        draw.text((x0, y), line, font=mono, fill=INK)
        y += 18
    draw.text((x0, y + 10), t[1], font=hand, fill=INK)
    draw.text((x0, y + 28), t[2], font=hand, fill=INK)
    draw.text((x0, y + 46), t[3], font=hand, fill=PINK)
    draw.text((8 + w - 150, 8 + h - 30), t[4], font=small, fill=PINK_DARK)
    # a pixel heart
    heart = ["..##.##..", ".#######.", "#########", ".#######.", "..#####..", "...###...", "....#...."]
    hx, hy = 8 + w - 40, 8 + 20
    for j, row in enumerate(heart):
        for i, c in enumerate(row):
            if c == "#":
                draw.rectangle([hx + i * 2, hy + j * 2, hx + i * 2 + 1, hy + j * 2 + 1], fill=PINK)
    im = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
    name = "install-note.png" if lang == "en" else f"install-note.{lang}.png"
    im.save(out / name, optimize=True)
    print(out / name, im.size)


def release_strip(folder, out, height=169, gap=8):
    """One strip per release: a column per picture (and per shape of it), day over night."""
    meta = json.loads((folder / "release.json").read_text())
    label, big = font("PixeloidSans.ttf", 9), font("PixeloidSans-Bold.ttf", 9)
    cols = []                                               # (name, day, night)
    for wall in meta["walls"]:
        if wall.get("day") or wall.get("night"):
            cols.append((wall.get("name", ""), wall.get("day"), wall.get("night")))
        shapes = {}
        for v in wall.get("variants", []):
            if v.get("shape") in ("9:16", "21:9"):
                shapes.setdefault(v["shape"], {})[v["time"]] = v["file"]
        for shape, files in shapes.items():
            cols.append((shape, files.get("day"), files.get("night")))
    widths = []
    for _, day, night in cols:
        pic = Image.open(folder / (day or night))
        widths.append(max(60, round(height * pic.width / pic.height)))
    header = 30
    w = gap + sum(widths) + gap * len(cols)
    h = header + 2 * height + 3 * gap
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    num = f"{meta.get('number', 0):02d}"
    draw.text((gap, 8), f"release {num} · {meta.get('codename', folder.name)} · {meta.get('date', '')}", font=big, fill=PINK)
    draw.text((w - gap - 70, 8), "day / night", font=label, fill=(255, 179, 217, 255))
    x = gap
    for (name, day, night), cw in zip(cols, widths):
        for j, file in enumerate((day, night)):
            y = header + gap + j * (height + gap)
            src = file or (night if j == 0 else day)       # one of the two missing: the other, dimmed
            pic = Image.open(folder / src).convert("RGB").resize((cw, height), Image.LANCZOS)
            if not file:
                pic = Image.blend(pic, Image.new("RGB", pic.size, (24, 12, 34)), 0.55)
            im.paste(pic, (x, y))
        if name:
            draw.text((x + 4, header + gap + 4), name, font=label, fill=(255, 255, 255, 255))
        x += cw + gap
    name = re.sub(r"[^a-z0-9]+", "-", meta.get("codename", folder.name).lower()).strip("-")
    path = out / f"release-{num}-{name}.png"
    im.save(path, optimize=True)
    print(path, im.size)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(ROOT / "docs/readme"))
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    install_note(out, "en")
    install_note(out, "ru")
    for folder in sorted((ROOT / "Pictures/AngelOS").iterdir()):
        if (folder / "release.json").exists():
            release_strip(folder, out)


if __name__ == "__main__":
    main()
