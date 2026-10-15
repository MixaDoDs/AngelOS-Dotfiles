#!/usr/bin/env python3
"""scripts/circle.py ocr on drawn pieces of screen: light text on dark, dark on light and
words on coloured buttons in one picture (what the old whole-picture turn-over lost), a
link tesseract doubts, small UI text in both themes, columns and paragraphs in reading
order, Russian (when its tessdata is there) and pictures without text that must give no
words at all (the overlay shows every word it gets).
  test_ocr.py <angelOS dir>      exit 0 = all good, 77 = no tesseract/cairo"""
import json
import math
import os
import random
import shutil
import subprocess
import sys
import tempfile

try:
    import cairo
except ImportError:
    sys.exit(77)
if not shutil.which("tesseract"):
    sys.exit(77)

CIRCLE = os.path.join(sys.argv[1], "scripts/circle.py")
RUS = "rus" in subprocess.run(["tesseract", "--list-langs"], capture_output=True, text=True).stdout.split()


def rgb(h):
    return tuple(int(h[i:i + 2], 16) / 255 for i in (1, 3, 5))


def save(s, path, w, h):
    s.flush()
    data, stride = bytes(s.get_data()), s.get_stride()
    rgbs = b"".join(bytes((data[r * stride + i + 2], data[r * stride + i + 1], data[r * stride + i]))
                    for r in range(h) for i in range(0, w * 4, 4))
    with open(path, "wb") as f:
        f.write(b"P6\n%d %d\n255\n" % (w, h) + rgbs)


def piece(path, w, h, bg, plates, texts):
    s = cairo.ImageSurface(cairo.FORMAT_RGB24, w, h)
    c = cairo.Context(s)
    c.set_source_rgb(*rgb(bg))
    c.paint()
    for x, y, pw, ph, f in plates:
        c.set_source_rgb(*rgb(f))
        c.rectangle(x, y, pw, ph)
        c.fill()
    c.select_font_face("Sans")
    for x, y, t, col, px in texts:
        c.set_font_size(px)
        c.set_source_rgb(*rgb(col))
        c.move_to(x, y)
        c.show_text(t)
    save(s, path, w, h)


def photo(path, w, h, seed):
    """No letters: a sky gradient, leaves and branches, blobs of light, grain."""
    rnd = random.Random(seed)
    s = cairo.ImageSurface(cairo.FORMAT_RGB24, w, h)
    c = cairo.Context(s)
    g = cairo.LinearGradient(0, 0, 0, h)
    g.add_color_stop_rgb(0, rnd.random(), rnd.random(), rnd.random())
    g.add_color_stop_rgb(1, rnd.random() * .4, rnd.random() * .4, rnd.random() * .4)
    c.set_source(g)
    c.paint()
    for _ in range(400):
        c.set_source_rgba(rnd.random(), rnd.random(), rnd.random(), rnd.uniform(.3, 1))
        x, y = rnd.uniform(0, w), rnd.uniform(0, h)
        if rnd.random() < .5:
            c.arc(x, y, rnd.uniform(2, 14), 0, 2 * math.pi)
            c.fill()
        else:
            c.set_line_width(rnd.uniform(1, 3))
            c.move_to(x, y)
            c.curve_to(x + rnd.uniform(-20, 20), y + rnd.uniform(-20, 20), x + rnd.uniform(-20, 20),
                       y + rnd.uniform(-20, 20), x + rnd.uniform(-25, 25), y + rnd.uniform(-25, 25))
            c.stroke()
    for _ in range(w * h // 6):
        v = rnd.random()
        c.set_source_rgba(v, v, v, .35)
        c.rectangle(rnd.randrange(w), rnd.randrange(h), 1, 1)
        c.fill()
    save(s, path, w, h)


def ocr(path, box=None):
    a = ["python3", CIRCLE, "ocr", path] + [str(v) for v in box or ()]
    r = subprocess.run(a, capture_output=True, text=True, timeout=120)
    return json.loads(r.stdout or "{}")


def read(path, w, h):
    return ocr(path, (0, 0, w, h)).get("text", "")


fail = 0


def check(name, ok, detail):
    global fail
    print("  %s %s %s" % ("✓" if ok else "✕", name, "" if ok else detail))
    fail |= not ok


def has(got, want):
    """The wanted words that are not among the ones read (punctuation around them aside)."""
    got = {g.strip(".,:;!?()«»\"'") for g in got}
    return [wd for wd in want if wd.strip(".,:;!?") not in got]


# the words as the overlay lights them (circle.tidy), on what tesseract really gave: a place read
# twice ("evening." and "1ing,"), a box drawn on over the next word ("minutes" over "ago"), a
# line over two rows, words of a row at different heights
sys.path.insert(0, os.path.join(sys.argv[1], "scripts"))
import circle  # noqa: E402


def W(t, x, y, w, h, line, conf=95):
    return {"x": x, "y": y, "w": w, "h": h, "t": t, "line": line, "conf": conf}


got = circle.tidy([W("Good", 13, 276, 81, 26, "1"), W("evening.", 101, 277, 126, 25, "1", 92), W("1ing,", 165, 277, 62, 32, "1", 75),
                   W("angelos", 234, 276, 113, 33, "1", 92), W("a", 235, 283, 16, 19, "1", 96),
                   W("Last", 10, 40, 20, 8, "2"), W("minutes", 74, 40, 71, 10, "2"), W("ago", 115, 39, 16, 13, "2"), W("by", 135, 39, 11, 13, "2"),
                   W("png/", 553, 65, 47, 28, "3"), W("видео", 841, 71, 59, 22, "3"), W("Куда", 553, 90, 47, 28, "3"), W("папка?", 1249, 95, 71, 12, "3")])
t = [w["t"] for w in got]
check("tidy-read-twice-once", t[:3] == ["Good", "evening.", "angelos"], "got %r" % t)
check("tidy-long-box-keeps-neighbour", "ago" in t and next(w for w in got if w["t"] == "minutes")["x"] + next(w for w in got if w["t"] == "minutes")["w"] <= 115,
      "got %r" % [(w["t"], w["x"], w["w"]) for w in got])
rows = {}
for w in got:
    rows.setdefault(w["line"], []).append(w)
check("tidy-row-one-band", all(len({(w["y"], w["h"]) for w in r}) == 1 for r in rows.values()), "rows %r" % {k: [(w["t"], w["y"], w["h"]) for w in r] for k, r in rows.items()})
two = [w for w in got if w["t"] in ("png/", "видео", "Куда", "папка?")]
check("tidy-two-rows-split", len({w["line"] for w in two}) == 2 and max(w["y"] + w["h"] for w in two if w["t"] in ("png/", "видео")) <= min(w["y"] for w in two if w["t"] in ("Куда", "папка?")),
      "got %r" % [(w["t"], w["line"], w["y"], w["h"]) for w in two])

with tempfile.TemporaryDirectory(prefix="aos-ocr-") as tmp:
    p = os.path.join(tmp, "mixed.ppm")
    # dark page | light card, red and green buttons with white words, a yellow one with black
    piece(p, 620, 170, "#111318", [(310, 0, 310, 90, "#f2f2f2"), (10, 100, 180, 40, "#da373c"), (210, 100, 180, 40, "#248046"), (410, 100, 180, 40, "#f0b232")], [
        (16, 40, "Dark side of the screen", "#e8e8e8", 15),
        (326, 40, "Light card with words", "#1a1a1a", 15),
        (26, 126, "Delete", "#ffffff", 15),
        (226, 126, "Subscribe", "#ffffff", 15),
        (426, 126, "Warning", "#000000", 15),
    ])
    got = read(p, 620, 170).split()
    want = ["Dark", "screen", "Light", "card", "Delete", "Subscribe", "Warning"]
    check("ocr-mixed-polarity", not has(got, want), "missing %s in %r" % (has(got, want), " ".join(got)))

    p = os.path.join(tmp, "link.ppm")
    piece(p, 520, 60, "#1e1e2e", [], [(12, 38, "github.com/angelos/Dotfiles-Example", "#89b4fa", 14)])
    got = read(p, 520, 60)
    check("ocr-link-kept", "github.com/" in got, "got %r" % got)

    # small UI text (11 px), a light and a dark theme, read as a whole frame
    lines = ["Storage used: 14.2 GB of 15 GB", "Last edited 5 minutes ago by Mia", "Notifications are muted until morning"]
    for name, bg, fg in (("light", "#ffffff", "#3c4043"), ("dark", "#1f2430", "#c0c5ce")):
        p = os.path.join(tmp, "small-%s.ppm" % name)
        piece(p, 360, 90, bg, [], [(10, 22 + 26 * i, t, fg, 11) for i, t in enumerate(lines)])
        j = ocr(p)
        got = j.get("text", "").split()
        want = "Storage used edited minutes ago Mia Notifications muted until morning".split()
        check("ocr-small-11px-" + name, not has(got, want), "missing %s in %r" % (has(got, want), j.get("text")))
        ws = j.get("words", [])
        check("ocr-word-fields-" + name, ws and all({"x", "y", "w", "h", "t", "line", "conf"} <= set(w) for w in ws),
              "words %r" % ws[:2])
        check("ocr-lines-" + name, j.get("text", "").count("\n") == 2, "text %r" % j.get("text"))

    # two columns: the left one all the way down, then the right one (which starts a bit higher)
    p = os.path.join(tmp, "cols.ppm")
    left = ["Left column starts here", "and goes on below it", "ending on this line"]
    right = ["Right column comes next", "with its second line", "and its final words"]
    piece(p, 640, 110, "#202124", [], [(20, 30 + 26 * i, t, "#e0e0e0", 13) for i, t in enumerate(left)] +
          [(360, 20 + 26 * i, t, "#e0e0e0", 13) for i, t in enumerate(right)])
    t = read(p, 640, 110)
    order = [t.find(wd) for wd in ("Left", "below", "ending", "Right", "second", "final")]
    check("ocr-columns-order", -1 not in order and order == sorted(order), "text %r" % t)

    # two paragraphs: kept apart, in order
    p = os.path.join(tmp, "paras.ppm")
    piece(p, 470, 200, "#ffffff", [], [(20, 30, "The first paragraph is about the", "#202124", 14),
                                       (20, 52, "screenshot overlay and its text.", "#202124", 14),
                                       (20, 130, "Second paragraph after a gap.", "#202124", 14)])
    j = ocr(p, (0, 0, 470, 200))
    t = j.get("text", "")
    ws = j.get("words", [])
    paras = {(w.get("block"), w.get("para")) for w in ws}
    check("ocr-paragraphs", t.find("first") < t.find("overlay") < t.find("Second") and len(paras) == 2,
          "text %r, paragraphs %r" % (t, paras))

    if RUS:
        p = os.path.join(tmp, "rus.ppm")
        piece(p, 520, 80, "#1b1b1f", [], [(14, 30, "Скачать обновление до вечера", "#dddddd", 13),
                                          (14, 58, "Settings: Night Light включён", "#dddddd", 13)])
        got = read(p, 520, 80).split()
        want = ["Скачать", "обновление", "вечера", "Settings:", "Night", "Light", "включён"]
        check("ocr-russian-english", not has(got, want), "missing %s in %r" % (has(got, want), " ".join(got)))

    # pictures with no letters: not one word, the whole frame or a piece of it
    junk = []
    for seed in range(3):
        p = os.path.join(tmp, "photo%d.ppm" % seed)
        photo(p, 640, 360, seed)
        for box in (None, (0, 0, 640, 360), (100, 60, 300, 200)):
            junk += [w["t"] for w in ocr(p, box).get("words", [])]
    check("ocr-no-junk-on-pictures", not junk, "read %r" % junk)

sys.exit(fail)
