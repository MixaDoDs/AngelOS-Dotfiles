#!/usr/bin/env python3
"""The pictures angel-niri shows on stream over a hidden window (services/Privacy: niri's
set-privacy-look image): a small pixel-art PNG it centres on the window's place in the
background colour and scales up in whole steps.

  plate  the eye (widgets/Icons.js, twice as big) over «PRIVACY ON» (Departure Mono,
         data/fonts), accent
  cat    the Halo's cat asleep (modules/halo/HaloCat.js, its first breath), ink
  angel  the angel sprite's face (modules/y2k/sprites/angel: body, eyes, mouth), as drawn
  pause  the card of the pause for viewers (niri's set-cast-pause): the Halo's cat asleep over
         «СКОРО ВЕРНУСЬ» (or the text given) and three dots, accent; niri centres it on the background
  picture  the owner's own picture <src> (any format PIL reads, a GIF's first frame), as a PNG
         no bigger than 1920 px; niri fills the window with it

Prints the PNG's path.

    privacy-look.py <plate|cat|angel> <out.png> <ink #rrggbb> <accent #rrggbb>
    privacy-look.py pause <out.png> <ink #rrggbb> <accent #rrggbb> [text]
    privacy-look.py picture <out.png> <src>
    privacy-look.py --batch '[["plate", out, ink, accent], ["picture", out, src], …]'
"""
import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SHELL = Path(__file__).resolve().parent.parent


def rgba(hex_):
    h = hex_.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def js_rows(path, name):
    """The first bitmap («"…",» rows) after `name` in a .js file."""
    text = path.read_text()
    at = re.search(r"\b" + re.escape(name) + r"\s*[:=]\s*\[", text)
    if not at:
        sys.exit(f"{name} not in {path}")
    rows = []
    for m in re.finditer(r'"([^"]*)"|\]', text[at.end():]):
        if m.group(0) == "]":
            if rows:
                break
            continue
        rows.append(m.group(1))
    return rows


def bitmap(rows, colours):
    im = Image.new("RGBA", (max(map(len, rows)), len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c in colours:
                im.putpixel((x, y), colours[c])
    return im


def plate(ink, accent):
    eye = bitmap(js_rows(SHELL / "widgets/Icons.js", "eye"), {"#": accent, "w": ink})
    eye = eye.resize((eye.width * 2, eye.height * 2), Image.NEAREST)
    font = ImageFont.truetype(str(SHELL / "data/fonts/DepartureMono-Regular.otf"), 11)
    text = "PRIVACY ON"
    l, t, r, b = font.getbbox(text)
    w = max(eye.width, r - l)
    gap = 4
    im = Image.new("RGBA", (w, eye.height + gap + b - t), (0, 0, 0, 0))
    im.paste(eye, ((w - eye.width) // 2, 0))
    draw = ImageDraw.Draw(im)
    draw.fontmode = "1"
    draw.text(((w - (r - l)) // 2 - l, eye.height + gap - t), text, font=font, fill=accent)
    return im


def cat(ink, accent):
    im = bitmap(js_rows(SHELL / "modules/halo/HaloCat.js", "nap"), {"#": ink})
    return im.crop(im.getbbox())


def angel(ink, accent):
    d = SHELL / "modules/y2k/sprites/angel"
    im = Image.open(d / "body.png").convert("RGBA")
    for part in ("eyes", "mouth"):
        im.alpha_composite(Image.open(d / f"{part}.png").convert("RGBA"))
    return im.crop(im.getbbox())


def pause(ink, accent, text="СКОРО ВЕРНУСЬ"):
    sleeper = cat(ink, accent)
    font = ImageFont.truetype(str(SHELL / "data/fonts/DepartureMono-Regular.otf"), 11)
    l, t, r, b = font.getbbox(text)
    tw, th = r - l, b - t
    gap = 6
    # the dots under the text: three art pixels two apart, the middle one in the ink
    w = max(sleeper.width, tw)
    im = Image.new("RGBA", (w, sleeper.height + gap + th + gap + 2), (0, 0, 0, 0))
    im.paste(sleeper, ((w - sleeper.width) // 2, 0))
    draw = ImageDraw.Draw(im)
    draw.fontmode = "1"
    y = sleeper.height + gap
    draw.text(((w - tw) // 2 - l, y - t), text, font=font, fill=accent)
    y += th + gap
    for i, c in enumerate((accent, ink, accent)):
        x = w // 2 - 5 + i * 4
        draw.rectangle((x, y, x + 1, y + 1), fill=c)
    return im


def picture(src):
    im = Image.open(src)
    im.seek(0)
    im = im.convert("RGBA")
    im.thumbnail((1920, 1920))
    return im


def make(args):
    if len(args) == 3 and args[0] == "picture":
        out = args[1]
        im = picture(args[2])
    elif len(args) == 4 and args[0] in ("plate", "cat", "angel"):
        kind, out, ink, accent = args
        im = {"plate": plate, "cat": cat, "angel": angel}[kind](rgba(ink), rgba(accent))
    elif len(args) in (4, 5) and args[0] == "pause":
        out, ink, accent = args[1:4]
        im = pause(rgba(ink), rgba(accent), *args[4:])
    else:
        sys.exit(__doc__)
    Path(out).parent.mkdir(parents=True, exist_ok=True)
    im.save(out)
    print(out)


def main():
    if len(sys.argv) == 3 and sys.argv[1] == "--batch":
        failed = False
        for args in json.loads(sys.argv[2]):
            try:
                make(args)
            except Exception as e:  # one bad picture: the others still go
                print(f"privacy-look: {args[0]}: {e}", file=sys.stderr)
                failed = True
        sys.exit(1 if failed else 0)
    make(sys.argv[1:])


if __name__ == "__main__":
    main()
