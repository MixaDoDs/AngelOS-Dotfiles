#!/usr/bin/env python3
"""scripts/capture_regions.py on drawn frames (exit 0 = all good):
  - a window with a photo, a paragraph, a card and a button (dark and light), windows in logical
    pixels × scale, a window past the frame's edge, an empty desktop, frames that cannot be read;
  - a gallery: three photos 10 px apart (three pictures, not one), a dark video with a big flat
    black part (one picture), two text columns 40 px apart, two paragraphs 32 px apart, list
    items 16–18 px apart and a column 18 px beside them (twelve blocks), a label 6 px from a card's
    border (the label alone), a button with a soft shadow (not a picture);
  - the time, 1080×1920 and 1920×1080: under 400 ms on a quiet machine; on a loaded one its own
    work against Python + numpy starting at the same moment (both slow down alike)."""
import json
import os
import subprocess
import sys
import tempfile
import time

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

DIR = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "../..")
SCRIPT = os.path.join(DIR, "scripts/capture_regions.py")
sys.path.insert(0, os.path.join(DIR, "scripts"))
import capture_regions as cr  # noqa: E402

FONT = next((p for p in ("/usr/share/fonts/TTF/DejaVuSans.ttf", "/usr/share/fonts/noto/NotoSans-Regular.ttf") if os.path.exists(p)), None)
MONO = next((p for p in ("/usr/share/fonts/TTF/DejaVuSansMono.ttf", "/usr/share/fonts/noto/NotoSansMono-Regular.ttf") if os.path.exists(p)), None)
bad = 0


def check(ok, what):
    global bad
    print(("  ✓ " if ok else "  ✕ ") + what, flush=True)
    bad += not ok


def font(size):
    return ImageFont.truetype(FONT, size) if FONT else ImageFont.load_default()


def photo(w, h, seed):
    """A photo-like picture: smooth colour fields, a gradient and grain."""
    r = np.random.default_rng(seed)
    small = r.integers(0, 255, (h // 40 + 2, w // 40 + 2, 3)).astype(np.uint8)
    im = np.asarray(Image.fromarray(small).resize((w, h), Image.BICUBIC), np.float32)
    im += np.linspace(-30, 30, w)[None, :, None] + r.normal(0, 9, (h, w, 3))
    return Image.fromarray(np.clip(im, 0, 255).astype(np.uint8))


WORDS = "the quick brown fox jumps over a lazy dog Съешь же ещё этих мягких булок".split()


def text(d, x, y, lines, size, fill, width=40):
    """Lines of words; the box their ink really covers (x, y, w, h)."""
    x0 = y0 = 1 << 30
    x1 = y1 = 0
    for i in range(lines):
        s = " ".join(WORDS[(i * 3 + k) % len(WORDS)] for k in range(width // 5))
        d.text((x, y + i * int(size * 1.5)), s, font=font(size), fill=fill)
        a, b, c, e = d.textbbox((x, y + i * int(size * 1.5)), s, font=font(size))
        x0, y0, x1, y1 = min(x0, a), min(y0, b), max(x1, c), max(y1, e)
    return (x0, y0, x1 - x0, y1 - y0)


def best(regs, box, kind=None):
    rb = {"x": box[0], "y": box[1], "w": box[2], "h": box[3]}
    return max([cr.iou(r, rb) for r in regs if kind is None or r["kind"] == kind] or [0])


def overlap(r, box):
    """The share of box that region r covers."""
    x0, y0 = max(r["x"], box[0]), max(r["y"], box[1])
    x1, y1 = min(r["x"] + r["w"], box[0] + box[2]), min(r["y"] + r["h"], box[1] + box[3])
    return max(0, x1 - x0) * max(0, y1 - y0) / float(box[2] * box[3])


def run(path, *args):
    out = subprocess.run(["python3", SCRIPT, path, *args], capture_output=True, text=True)
    try:
        return out.returncode, json.loads(out.stdout)
    except ValueError:
        return out.returncode, {"error": "not JSON: " + out.stdout[:200] + out.stderr[-300:]}


def colours(dark):
    return ((30, 30, 46), (24, 24, 37), (205, 214, 244), (49, 50, 68)) if dark else ((210, 214, 222), (250, 250, 250), (20, 20, 20), (232, 236, 243))


def scene(dark):
    W, H = 1080, 1920
    bg, win, ink, card = colours(dark)
    im = Image.new("RGB", (W, H), bg)
    d = ImageDraw.Draw(im)
    wb = (60, 120, 960, 1500)
    d.rectangle((wb[0], wb[1], wb[0] + wb[2] - 1, wb[1] + wb[3] - 1), fill=win)
    pb = (120, 200, 640, 400)
    im.paste(photo(pb[2], pb[3], 7 if dark else 3), pb[:2])
    tb = text(d, 120, 680, 6, 22, ink)
    cb = (120, 980, 840, 260)
    d.rounded_rectangle((cb[0], cb[1], cb[0] + cb[2] - 1, cb[1] + cb[3] - 1), 14, fill=card)
    text(d, 150, 1010, 2, 20, ink, 30)
    bb = (120, 1300, 240, 64)
    d.rounded_rectangle((bb[0], bb[1], bb[0] + bb[2] - 1, bb[1] + bb[3] - 1), 12, fill=(137, 180, 250))
    d.text((150, 1318), "Отправить", font=font(24), fill=(17, 17, 27))
    return im, wb, pb, tb, cb, bb


def gallery(dark):
    W, H = 1080, 1920
    bg, win, ink, card = colours(dark)
    im = Image.new("RGB", (W, H), win)
    d = ImageDraw.Draw(im)
    boxes = {}
    # three photos in a row, 10 px apart
    boxes["photos"] = [(60 + i * 230, 80, 220, 160) for i in range(3)]
    for i, b in enumerate(boxes["photos"]):
        im.paste(photo(b[2], b[3], 11 + i), b[:2])
    # a dark video frame: a big flat black part inside it
    vb = boxes["video"] = (60, 300, 480, 270)
    v = np.asarray(photo(vb[2], vb[3], 5), np.float32) * 0.45
    v[40:230, 60:300] = 0
    im.paste(Image.fromarray(v.astype(np.uint8)), vb[:2])
    # two columns of text 40 px apart, two paragraphs 32 px apart
    boxes["colA"] = text(d, 60, 640, 4, 18, ink, 20)
    boxes["colB"] = text(d, boxes["colA"][0] + boxes["colA"][2] + 40, 640, 4, 18, ink, 20)
    boxes["paraC"] = text(d, 60, 820, 3, 18, ink, 35)
    boxes["paraD"] = text(d, 60, boxes["paraC"][1] + boxes["paraC"][3] + 32, 3, 18, ink, 35)
    # a list: items 16, 17, 18 px apart (whatever the cells, a gap over the 13 px of a line's);
    # beside it a second column 18 px away (over the 14 px of a word's)
    y = boxes["paraD"][1] + boxes["paraD"][3] + 40
    for i, gap in enumerate((0, 16, 17, 18)):
        if i:
            prev = boxes["item%d" % i]
            y = prev[1] + prev[3] + gap - 3   # (a line's ink starts ~3 px under where it is drawn)
        boxes["item%d" % (i + 1)] = b = text(d, 60, y, 1, 16, ink, 15)
        boxes["side%d" % (i + 1)] = text(d, b[0] + b[2] + 18, y, 1, 16, ink, 10)
    # a card with a 1 px border; a label ending 6 px before it
    cb = boxes["card"] = (600, 1150, 400, 180)
    d.rectangle((cb[0], cb[1], cb[0] + cb[2] - 1, cb[1] + cb[3] - 1), fill=card, outline=(120, 124, 150) if dark else (150, 155, 170))
    text(d, cb[0] + 24, cb[1] + 30, 3, 18, ink, 20)
    lb = d.textbbox((0, 0), "Подпись слева", font=font(18))
    lx = cb[0] - 6 - (lb[2] - lb[0]) - lb[0]
    d.text((lx, cb[1] + 60), "Подпись слева", font=font(18), fill=ink)
    a, b, c, e = d.textbbox((lx, cb[1] + 60), "Подпись слева", font=font(18))
    boxes["label"] = (a, b, c - a, e - b)
    # a photo on a patterned panel (faint dots, like a chat's wallpaper)
    d.rectangle((600, 1400, 1039, 1719), fill=bg)
    for yy in range(1404, 1716, 12):
        for xx in range(604 + (yy // 12) % 2 * 6, 1036, 12):
            d.rectangle((xx, yy, xx + 1, yy + 1), fill=tuple(min(255, c + 14) for c in bg))
    ob = boxes["onpattern"] = (668, 1452, 300, 196)
    im.paste(photo(ob[2], ob[3], 21), ob[:2])
    # a button with a soft shadow under it
    bb = boxes["button"] = (60, 1500, 260, 56)
    sh = Image.new("L", (W, H), 0)
    ImageDraw.Draw(sh).rounded_rectangle((bb[0] + 2, bb[1] + 6, bb[0] + bb[2] + 2, bb[1] + bb[3] + 6), 12, fill=150)
    sh = sh.filter(ImageFilter.GaussianBlur(7))
    im = Image.composite(Image.new("RGB", (W, H), (0, 0, 0)), im, sh)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((bb[0], bb[1], bb[0] + bb[2] - 1, bb[1] + bb[3] - 1), 12, fill=(137, 180, 250))
    d.text((bb[0] + 40, bb[1] + 14), "Сохранить", font=font(22), fill=(17, 17, 27))
    return im, boxes


def wall(cmd):
    t0 = time.perf_counter()
    subprocess.run(cmd, capture_output=True)
    return time.perf_counter() - t0


def timing(frame):
    """Wall seconds, the best of 5 runs each (the least disturbed), interleaved: Python + numpy
    starting, and the script on the frame. A loaded machine slows both alike, so the script's own
    work is judged against the start it shares; on a quiet machine (the start under 0.15 s) the
    whole run must also fit the contract's 400 ms."""
    base, full = [], []
    for _ in range(5):
        base.append(wall(["python3", "-c", "import numpy"]))
        full.append(wall(["python3", SCRIPT, frame]))
    b, f = min(base), min(full)
    ok = f - b < max(0.15, 1.5 * b) and (b >= 0.15 or f < 0.4)
    return ok, b, f


with tempfile.TemporaryDirectory() as T:
    for dark in (True, False):
        im, wb, pb, tb, cb, bb = scene(dark)
        name = "dark" if dark else "light"
        path = os.path.join(T, name + ".ppm")
        im.save(path)
        wins = json.dumps([{"x": wb[0] / 2, "y": wb[1] / 2, "w": wb[2] / 2, "h": wb[3] / 2, "title": "Files", "app_id": "nautilus"}])
        _, out = run(path, "--windows", wins, "--scale", "2")
        regs = out.get("regions", [])
        check(best(regs, wb, "window") >= 0.95 and any(r["label"] == "Files" for r in regs), name + ": the window, scaled (logical × 2)")
        check(best(regs, pb, "image") >= 0.8, name + ": the photo (IoU %.2f)" % best(regs, pb, "image"))
        check(best(regs, tb, "text") >= 0.75, name + ": the paragraph (IoU %.2f)" % best(regs, tb, "text"))
        check(best(regs, cb, "ui") >= 0.8, name + ": the card (IoU %.2f)" % best(regs, cb, "ui"))
        check(best(regs, bb) >= 0.8 and best(regs, bb, "image") < 0.5, name + ": the button, not a picture (IoU %.2f)" % best(regs, bb))
        check(0 < len(regs) <= cr.MAX and regs == sorted(regs, key=lambda r: -r["score"]), name + ": at most %d, best first (%d)" % (cr.MAX, len(regs)))
        check(all(cr.iou(a, b) <= 0.6 for i, a in enumerate(regs) for b in regs[i + 1:]), name + ": no duplicates")
        check(all(set(r) == {"x", "y", "w", "h", "kind", "score", "label"} and r["kind"] in ("window", "image", "text", "ui")
                  and r["x"] >= 0 and r["y"] >= 0 and r["x"] + r["w"] <= 1080 and r["y"] + r["h"] <= 1920 for r in regs),
              name + ": the contract's fields and kinds, all inside the frame")

        im, B = gallery(dark)
        path = os.path.join(T, name + "-gallery.ppm")
        im.save(path)
        _, out = run(path)
        regs = out.get("regions", [])
        ious = [best(regs, b, "image") for b in B["photos"]]
        two = [r for r in regs if r["kind"] == "image" and sum(overlap(r, b) > 0.3 for b in B["photos"]) > 1]
        check(min(ious) >= 0.8 and not two, name + ": three photos 10 px apart are three pictures (IoU %s)" % " ".join("%.2f" % i for i in ious))
        def err(b):  # the worst side of the picture found for b, in pixels
            r = max((r for r in regs if r["kind"] == "image"), key=lambda r: cr.iou(r, {"x": b[0], "y": b[1], "w": b[2], "h": b[3]}))
            return max(abs(r["x"] - b[0]), abs(r["y"] - b[1]), abs(r["x"] + r["w"] - b[0] - b[2]), abs(r["y"] + r["h"] - b[1] - b[3]))
        errs = [err(b) for b in B["photos"] + [B["onpattern"]]]
        check(max(errs) <= 2, name + ": theirs and one's on a patterned panel: edges to the pixel, not to the 8 px cells (off by %s px)" % " ".join(map(str, errs)))
        check(best(regs, B["video"], "image") >= 0.8, name + ": a dark video, a big part of it flat black, is one picture (IoU %.2f)" % best(regs, B["video"], "image"))
        for k in ("colA", "colB", "paraC", "paraD") + tuple("%s%d" % (a, i) for a in ("item", "side") for i in range(1, 5)):
            check(best(regs, B[k], "text") >= 0.6, name + ": text block %s on its own (IoU %.2f)" % (k, best(regs, B[k], "text")))
        lab = [r for r in regs if r["kind"] == "text" and overlap(r, B["label"]) > 0.5]
        check(best(regs, B["label"], "text") >= 0.6 and all(r["x"] + r["w"] <= B["card"][0] + 2 for r in lab),
              name + ": a label 6 px from a card's border stays apart from it (IoU %.2f)" % best(regs, B["label"], "text"))
        check(best(regs, B["card"]) >= 0.8, name + ": the bordered card (IoU %.2f)" % best(regs, B["card"]))
        check(best(regs, B["button"]) >= 0.7 and best(regs, B["button"], "image") < 0.3,
              name + ": a button with a soft shadow, not a picture (IoU %.2f)" % best(regs, B["button"]))

    # what goes in: PNG, a PPM with a comment, a cut PPM, a missing file
    im, *_ = scene(True)
    im.save(os.path.join(T, "f.png"))
    rc, out = run(os.path.join(T, "f.png"))
    raw = im.tobytes()
    with open(os.path.join(T, "c.ppm"), "wb") as f:
        f.write(b"P6\n# grim\n1080 1920\n255\n" + raw)
    rc2, out2 = run(os.path.join(T, "c.ppm"))
    check(rc == 0 and rc2 == 0 and out.get("regions") and out["regions"] == out2.get("regions"), "a PNG and a PPM with a comment read the same")
    with open(os.path.join(T, "cut.ppm"), "wb") as f:
        f.write(b"P6\n1080 1920\n255\n" + raw[:1000])
    rc, out = run(os.path.join(T, "cut.ppm"))
    check(rc == 1 and out.get("regions") == [] and out.get("error"), "a cut frame: an error, no regions")
    rc, out = run("/nonexistent.ppm")
    check(rc == 1 and out.get("regions") == [] and out.get("error"), "a missing frame: an error, no regions")
    rc, out = run(os.path.join(T, "c.ppm"), "--windows", "not json")
    check(rc == 1 and out.get("regions") == [], "windows that are not JSON: an error, no regions")

    # nothing on an empty desktop; a window past the edge is cut to the frame; a window a picture
    # fills is still there
    empty = Image.new("RGB", (1080, 1920), (30, 30, 46))
    check(cr.regions(np.asarray(empty), []) == [], "an empty desktop: no regions")
    regs = cr.regions(np.asarray(empty), [{"x": -100, "y": 1800, "w": 400, "h": 400}])
    check(len(regs) == 1 and regs[0]["x"] == 0 and regs[0]["y"] + regs[0]["h"] <= 1920, "a window past the edge is cut to the frame")
    full = empty.copy()
    full.paste(photo(440, 440, 9), (130, 130))
    regs = cr.regions(np.asarray(full), [{"x": 96, "y": 96, "w": 508, "h": 508, "title": "Фото"}])
    check(any(r["kind"] == "window" and r["label"] == "Фото" for r in regs) and best(regs, (130, 130, 440, 440), "image") >= 0.8,
          "a window its picture nearly fills: both are there")

    # tiled windows niri gives no place for (x/y null, their column): found on the frame — the
    # view scrolled so the focused column is out of it, a column cut by each side, a gap of 24,
    # the bar under them; nothing outside the windows (wallpaper, bar) is an area
    strip = [(941, "#1e1e2e", "#cdd6f4"), (1255, "#f4f0e8", "#202124"), (937, "#2b2d31", "#dbdee1"), (1000, "#101010", "#eeeeee")]
    lefts, x = [], -519
    for wd, *_ in strip:
        lefts.append(x)
        x += wd + 24
    desk = Image.fromarray((np.asarray(photo(1920, 1080, 4), np.float32) * 0.6).astype(np.uint8))
    d = ImageDraw.Draw(desk)
    d.rectangle((0, 1040, 1919, 1079), fill="#111018")
    d.text((20, 1050), "angelOS  12:40", font=font(13), fill="#dddddd")
    for (wd, bg, fg), lx in zip(strip, lefts):
        d.rectangle((lx, 15, lx + wd - 1, 1024), fill=bg)
        text(d, lx + 40, 60, 12, 14, fg, 60)
    # an editor in a monospaced font (its letters stand in columns, quiet runs between them),
    # line numbers beside: no panel or picture inside its text
    mono = ImageFont.truetype(MONO, 17) if MONO else font(17)
    d.rectangle((460, 280, 1300, 820), fill="#1e1e2e")
    for i in range(20):
        d.text((480, 300 + i * 24), "%2d" % (20 - i), font=mono, fill="#888888")
        d.text((530, 300 + i * 24), "%d. %s, %s → %s." % (i + 1, *(" ".join(WORDS[(i + k + j) % len(WORDS)] for k in range(3)) for j in (0, 3, 6))),
               font=mono, fill="#cdd6f4")
    desk.save(os.path.join(T, "tiled.ppm"))
    wins = [{"x": None, "y": None, "w": wd, "h": 1010, "col": i + 1, "row": 1, "title": "w%d" % (i + 1), "focused": i == 3}
            for i, (wd, *_) in enumerate(strip)]
    rc, out = run(os.path.join(T, "tiled.ppm"), "--windows", json.dumps(wins))
    got = {w["title"]: w for w in out.get("windows", [])}
    want = {"w1": (0, 15, 422, 1010), "w2": (446, 15, 1255, 1010), "w3": (1725, 15, 195, 1010)}
    check(rc == 0 and set(got) == set(want) and all(max(abs(got[k][f] - v) for f, v in zip("xywh", want[k])) <= 2 for k in want),
          "tiled windows without a place: found on the frame, the focused one out of view (%s)"
          % {k: (w["x"], w["y"], w["w"], w["h"]) for k, w in got.items()})
    regs = out.get("regions", [])
    check(sum(r["kind"] == "window" for r in regs) == 3 and all(
        r["kind"] == "window" or any(overlap(r, (w["x"], w["y"], w["w"], w["h"])) > 0 and cr.cover(r, w) >= 0.95 for w in got.values())
        for r in regs), "nothing outside the windows (wallpaper, bar) is an area")
    texts = [r for r in regs if r["kind"] == "text"]
    check(not [r for r in regs if r["kind"] in ("ui", "image") and any(t["w"] * t["h"] > r["w"] * r["h"] and cr.cover(r, t) >= 0.7 for t in texts)],
          "no panel or picture inside a block of text (the gaps between letters, a column of line numbers)")
    flat = Image.new("RGB", (1920, 1080), (30, 30, 46))
    flat.save(os.path.join(T, "flat.ppm"))
    rc, out = run(os.path.join(T, "flat.ppm"), "--windows", json.dumps(wins))
    check(rc == 0 and out.get("windows") == [] and out.get("regions") == [], "tiled windows on a frame with no edges: left out, no error")

    # the time: 1080×1920 and 1920×1080, three runs each, medians
    a, *_ = scene(True)
    g, _ = gallery(True)
    wide = Image.fromarray(np.concatenate([np.asarray(a)[:1080, :960], np.asarray(g)[:1080, :960]], axis=1))
    a.save(os.path.join(T, "tall.ppm"))
    wide.save(os.path.join(T, "wide.ppm"))
    for name in ("tall", "wide"):
        ok, b, f = timing(os.path.join(T, name + ".ppm"))
        if not ok:  # once more: a burst of load in the middle of the runs is not the script
            ok, b, f = timing(os.path.join(T, name + ".ppm"))
        check(ok, "%s in %.0f ms: its own work %.0f ms over %.0f ms of Python + numpy starting (load %.1f)"
              % ("1080×1920" if name == "tall" else "1920×1080", f * 1e3, (f - b) * 1e3, b * 1e3, os.getloadavg()[0]))

sys.exit(1 if bad else 0)
