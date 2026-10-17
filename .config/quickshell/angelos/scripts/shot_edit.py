#!/usr/bin/env python3
"""One step of the screenshot editor (services/ShotEdit, modules/capture/ShotPreview): a picture
in, the picture with one change out. Every step is a file of its own, so Ctrl+Z is the one before.

  shot_edit.py <in> <out> rotate cw|ccw
  shot_edit.py <in> <out> crop X,Y,W,H        (pixels of <in>)
  shot_edit.py <in> <out> hide X,Y,W,H        big pixels over it: a name, a number, a face
  shot_edit.py <in> <out> flip h|v
  shot_edit.py <in> <out> copy -               the same picture, as a PNG of the editor's own
  shot_edit.py recent <dir>...                the newest pictures in them (and below), newest first
  shot_edit.py --selftest

Prints {"w": W, "h": H} of <out>, or {"error": "..."} with exit 1.
"""
import json
import os
import sys


def box(arg, im):
    x, y, w, h = (int(round(float(v))) for v in arg.split(","))
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(im.width, x + w), min(im.height, y + h)
    if x1 - x0 < 2 or y1 - y0 < 2:
        raise ValueError("the box is outside the picture")
    return x0, y0, x1, y1


def step(im, op, arg):
    from PIL import Image
    if op == "rotate":
        return im.transpose(Image.Transpose.ROTATE_270 if arg == "cw" else Image.Transpose.ROTATE_90)
    if op == "copy":   # the shot as the editor's own first picture (the shot itself may be saved over)
        return im
    if op == "flip":
        return im.transpose(Image.Transpose.FLIP_LEFT_RIGHT if arg == "h" else Image.Transpose.FLIP_TOP_BOTTOM)
    if op == "crop":
        return im.crop(box(arg, im))
    if op == "hide":
        x0, y0, x1, y1 = box(arg, im)
        part = im.crop((x0, y0, x1, y1))
        # blocks big enough that nothing under them can be read back (a blur can be undone)
        n = max(8, min(part.width, part.height) // 6)
        small = part.resize((max(1, part.width // n), max(1, part.height // n)), Image.Resampling.BOX)
        im = im.copy()
        im.paste(small.resize(part.size, Image.Resampling.NEAREST), (x0, y0))
        return im
    raise ValueError("unknown step: " + op)


def run(src, out, op, arg):
    from PIL import Image
    im = Image.open(src)
    im.load()
    im = step(im.convert("RGBA") if im.mode in ("RGBA", "LA", "P") else im.convert("RGB"), op, arg)
    tmp = out + ".part"
    im.save(tmp, "PNG", compress_level=1)
    os.replace(tmp, out)
    return {"w": im.width, "h": im.height}


def recent(dirs, n=24):
    found = []
    for d in dirs:
        for root, subs, files in os.walk(os.path.expanduser(d)):
            subs[:] = [s for s in subs if not s.startswith(".")]
            for f in files:
                if f.lower().endswith((".png", ".jpg", ".jpeg", ".webp")) and not f.endswith(".part"):
                    p = os.path.join(root, f)
                    try:
                        found.append((os.path.getmtime(p), p))
                    except OSError:
                        pass
    return [p for _, p in sorted(found, reverse=True)[:n]]


def selftest():
    from PIL import Image
    im = Image.new("RGB", (40, 20), "white")
    for x in range(40):
        im.putpixel((x, 0), (x * 6, 0, 0))
    r = step(im, "rotate", "cw")
    assert r.size == (20, 40) and r.getpixel((19, 0)) == (0, 0, 0), r.size
    assert step(im, "rotate", "ccw").getpixel((0, 39)) == (0, 0, 0)
    assert step(im, "crop", "5,0,10,10").size == (10, 10)
    assert step(im, "flip", "h").getpixel((0, 0)) == im.getpixel((39, 0))
    assert step(im, "crop", "-5,-5,100,100").size == (40, 20)
    h = step(im, "hide", "0,0,40,20")
    assert h.getpixel((0, 0)) == h.getpixel((7, 0)) and h.size == im.size
    try:
        step(im, "crop", "100,100,5,5")
        raise AssertionError("a box outside should fail")
    except ValueError:
        pass
    print("shot_edit: ok")


def main(argv):
    if argv[:1] == ["--selftest"]:
        selftest()
        return 0
    if argv[:1] == ["recent"]:
        print(json.dumps(recent(argv[1:])))
        return 0
    if len(argv) != 4:
        print(__doc__)
        return 2
    try:
        print(json.dumps(run(*argv)))
        return 0
    except (OSError, ValueError) as e:
        print(json.dumps({"error": str(e)}))
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
