#!/usr/bin/env python3
"""A picture → a layered scene the wallpaper editor can work on (modules/wallstudio, widgets/SceneWall).

    wall-studio.py inspect <picture>
        one line of JSON: {"width", "height", "art": [w, h] or null, "scale"}: is it pixel art, and
        how big is it without its upscaling
    wall-studio.py new <picture> <folder> --mode art|pixel|keep [--screen WxH]
        makes <folder>/<name>/ (scene.json, logical/background.png, reference/neutral.png), prints it
          art    pixel art: its own pixels, the upscaling taken off
          pixel  any picture made into pixel art: the 656×376 canvas, 64 colours
          keep   any picture as it is: the size of the screen, one texel a screen pixel

Exit 2 and the reason on stderr: not a picture this can read.
"""
import hashlib
import json
import math
import re
import sys
from functools import reduce
from pathlib import Path

try:
    import numpy as np
    from PIL import Image, ImageOps
except ImportError as e:
    print(f"wall-studio: {e}", file=sys.stderr)
    sys.exit(2)

MARGIN = 8           # SceneWall's: art past the edges of the view, for the movement to reveal
PIXEL = (656, 376)   # the releases' canvas (640×360 shown)
COLORS = 64
MAX_PIXELS = 100_000_000
Image.MAX_IMAGE_PIXELS = MAX_PIXELS  # past it PIL refuses: a bomb, not a wallpaper


def load(path):
    try:
        img = Image.open(path)
        img.load()
    except (OSError, ValueError, Image.DecompressionBombError) as e:
        print(f"wall-studio: {path}: {e}", file=sys.stderr)
        sys.exit(2)
    return ImageOps.exif_transpose(img).convert("RGBA")


def edges(a, axis):
    """Where the picture changes along an axis: the columns (rows) differing from the one before."""
    d = np.abs(np.diff(a.astype(np.int16), axis=axis)).sum(axis=2)
    # a little: what a PNG-8 or a light JPEG leaves
    return np.flatnonzero((d > 24).any(axis=1 - axis)) + 1


def inspect(img):
    a = np.asarray(img.convert("RGB"))
    h, w = a.shape[:2]
    xs, ys = edges(a, 1), edges(a, 0)
    scale = reduce(math.gcd, map(int, xs), reduce(math.gcd, map(int, ys), 0)) if len(xs) and len(ys) else 0
    colors = len(np.unique(a.reshape(-1, 3), axis=0)) if w * h <= 4_000_000 else 1 << 24
    # upscaled by a whole number; or native: small, and few colours (a photo of that size has thousands)
    art = scale >= 2 or (w <= 1280 and h <= 800 and colors <= 512)
    scale = max(scale, 1)
    return {"width": w, "height": h, "art": [w // scale, h // scale] if art else None, "scale": scale if art else 1}


def cover(img, size, method):
    return ImageOps.fit(img, size, method=method, centering=(0.5, 0.5))


def make(img, mode, screen):
    if mode == "art":
        info = inspect(img)
        s = info["scale"]
        return img.resize((img.width // s, img.height // s), Image.NEAREST)
    if mode == "pixel":
        small = cover(img, PIXEL, Image.LANCZOS)
        alpha = small.getchannel("A")
        small = small.convert("RGB").quantize(COLORS, method=Image.MEDIANCUT, dither=Image.NONE).convert("RGBA")
        small.putalpha(alpha)
        return small
    # shortcut: one texel a screen pixel on the screen given, a different one scales by nearest; a choice of size when someone asks
    return cover(img, (screen[0] + 2 * MARGIN, screen[1] + 2 * MARGIN), Image.LANCZOS)


def free_name(folder, stem):
    name = re.sub(r"[^\w\- ]+", "", stem, flags=re.UNICODE).strip() or "wallpaper"
    for i in range(1, 1000):
        out = folder / (name if i == 1 else f"{name}-{i}")
        if not out.exists():
            return out
    raise SystemExit(2)


def new(path, folder, mode, screen):
    # the same picture taken the same way: the wallpaper already made from it
    source = hashlib.sha256(Path(path).read_bytes()).hexdigest() + ":" + mode
    for made in Path(folder).glob("*/scene.json"):
        try:
            if json.loads(made.read_text()).get("source") == source:
                return made.parent
        except (OSError, ValueError):
            pass
    picture = make(load(path), mode, screen)
    out = free_name(Path(folder), Path(path).stem)
    (out / "logical").mkdir(parents=True)
    (out / "reference").mkdir()
    picture.save(out / "logical" / "background.png")
    picture.save(out / "reference" / "neutral.png")
    w, h = picture.size
    scene = {
        "schema": "angelos.layered-scene.v1",
        "title": out.name,
        "logical_canvas": {"width": w, "height": h},
        "neutral_pose": {"reference": "reference/neutral.png"},
        "layers": [{"id": "background", "file": "background.png", "z": 0, "role": "background", "visible": True,
                    "parallax_max_logical": [0, 0], "edge_mode": "clamp", "bounds_logical": [0, 0, w, h],
                    "animation": {"type": "none"}, "label_ru": "Картинка"}],
        "source": source,
        "builtin": False,
        "modifiers": [],
    }
    (out / "scene.json").write_text(json.dumps(scene, ensure_ascii=False, indent=2) + "\n")
    return out


def main(argv):
    if len(argv) >= 2 and argv[0] == "inspect":
        print(json.dumps(inspect(load(argv[1]))))
        return 0
    if len(argv) >= 3 and argv[0] == "new":
        opt = {k: v for k, v in zip(argv[3::2], argv[4::2])}
        mode = opt.get("--mode", "keep")
        screen = tuple(int(x) for x in opt.get("--screen", "1920x1080").split("x"))
        if mode not in ("art", "pixel", "keep"):
            print(f"wall-studio: no mode {mode}", file=sys.stderr)
            return 2
        print(new(argv[1], argv[2], mode, screen))
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
