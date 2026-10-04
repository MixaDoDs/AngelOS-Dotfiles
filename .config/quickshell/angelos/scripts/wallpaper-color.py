#!/usr/bin/env python3
"""Pick a usable saturated accent from a wallpaper without modifying it.

  wallpaper-color.py IMAGE          {"accent": "#rrggbb"}
  wallpaper-color.py IMAGE --bar    {"bar": 0.0…1.0}: how light the strip under a top bar is
                                    (the Golden Gate menu bar writes black on light, white on dark)
"""
import colorsys
import json
import sys

try:
    from PIL import Image, ImageOps
except ImportError:
    sys.exit("python-pillow is required to read wallpaper colours")

try:
    with Image.open(sys.argv[1]) as source:
        source.seek(0)  # first frame of animated images
        image = ImageOps.exif_transpose(source).convert("RGB")
        if "--bar" in sys.argv[2:]:
            # the top 3 % (a 24 px bar on a 1080 px screen), as the wallpaper is cropped to fill
            w, h = image.size
            strip = image.crop((0, 0, w, max(1, round(h * 0.03)))).resize((64, 4))
            lum = [0.2126 * r + 0.7152 * g + 0.0722 * b for r, g, b in strip.getdata()]
            print(json.dumps({"bar": round(sum(lum) / len(lum) / 255, 3)}))
            sys.exit(0)
        image.thumbnail((160, 160))
        image = image.quantize(colors=12)
        palette = image.getpalette()
        candidates = []
        for count, index in image.getcolors():
            rgb = palette[index * 3:index * 3 + 3]
            h, s, v = colorsys.rgb_to_hsv(*(c / 255 for c in rgb))
            score = count * (0.2 + s) * (1 if 0.18 < v < 0.95 else 0.2)
            candidates.append((score, h, max(0.35, s), max(0.6, v)))
except (OSError, IndexError, ValueError) as error:
    sys.exit("cannot read wallpaper: " + str(error))

_, h, s, v = max(candidates)
rgb = colorsys.hsv_to_rgb(h, min(s, 0.8), min(v, 0.9))
print(json.dumps({"accent": "#" + "".join(f"{round(c * 255):02x}" for c in rgb)}))
