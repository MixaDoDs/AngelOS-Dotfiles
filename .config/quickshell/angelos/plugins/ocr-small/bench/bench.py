#!/usr/bin/env python3
"""Bench the region-OCR pipeline against the setup it replaces — before adopting any engine.

    bench/bench.py                score every corpus case, print a table + totals
    bench/bench.py --make         only (re)draw the corpus images + ground truth
    bench/bench.py --engine rapidocr   score a different backend instead of tesseract

Corpus = drawn UI-ish regions with exact ground truth (dark-on-light, light-on-dark, Russian,
English, tiny text, a coloured button, a multi-line block). Each case is read two ways:

  baseline  the old niri-ocr: raw crop straight into `tesseract --psm 6 -l rus+eng`
  pipeline  preprocess (flip + upscale) + adaptive --psm  (engine_tesseract.read_region)

and scored on character error rate (CER, normalised Levenshtein, lower is better) plus latency.
The claim under test: the preprocessing alone beats the fixed-mode raw read, with no new engine.
Add real captures under corpus/ as <name>.png + <name>.txt to extend it.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, ROOT)

import preprocess  # noqa: E402

CORPUS = os.path.join(HERE, "corpus")
FONT_CANDIDATES = [
    "/usr/share/fonts/TTF/DejaVuSans.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/noto/NotoSans-Regular.ttf",
]
# the dotfiles' own UI fonts — unusual shapes are closer to a real desktop than DejaVu
UI_FONTS = [
    os.path.expanduser("~/.config/quickshell/angelos/data/fonts/DotGothic16-Regular.ttf"),
    os.path.expanduser("~/.config/quickshell/angelos/data/fonts/DepartureMono-Regular.otf"),
    os.path.expanduser("~/.config/quickshell/angelos/data/fonts/HandjetP5-Bold.ttf"),
]

# (name, text, bg, fg, px, realism) where realism is a set of degradations a real screenshot has
# and a clean render does not: "tiny" (small crisp text), "lowcon" (grey on grey), "frac"
# (fractional-scale blur — the classic OCR killer), "uifont" (a non-standard face), "jpeg".
CASES = [
    ("en-light",        "Clipboard ready to paste",      (255, 255, 255), (20, 20, 20),    22, set()),
    ("en-dark",         "Clipboard ready to paste",      (24, 24, 28),    (235, 235, 235), 22, set()),
    ("ru-light",        "Текст скопирован в буфер",      (255, 255, 255), (20, 20, 20),    22, set()),
    ("ru-dark",         "Текст скопирован в буфер",      (24, 24, 28),    (235, 235, 235), 22, set()),
    ("en-tiny-dark",    "Battery 87% remaining",         (18, 18, 22),    (220, 220, 220), 11, {"tiny"}),
    ("ru-tiny-dark",    "Заряд батареи 87 процентов",    (18, 18, 22),    (220, 220, 220), 11, {"tiny"}),
    ("ru-tiny-frac",    "Уровень громкости 40",          (18, 18, 22),    (220, 220, 220), 11, {"tiny", "frac"}),
    ("en-lowcon",       "Network connected",             (40, 40, 46),    (96, 96, 104),   15, {"lowcon"}),
    ("ru-lowcon",       "Подключение к сети",            (40, 40, 46),    (96, 96, 104),   15, {"lowcon"}),
    ("mixed-dark",      "Смешанный mixed текст 42",      (24, 24, 28),    (235, 235, 235), 18, set()),
    ("button",          "Save changes",                  (46, 120, 220),  (255, 255, 255), 20, set()),
    ("uifont-ru",       "Настройки системы",             (250, 250, 250), (15, 15, 15),    18, {"uifont"}),
    ("frac-en",         "Screenshot saved to folder",    (255, 255, 255), (20, 20, 20),    16, {"frac"}),
    ("block-light",     "Settings\nRegion\nCopy text",   (250, 250, 250), (15, 15, 15),    20, set()),
]


def font(px: int, realism: set):
    from PIL import ImageFont

    if "uifont" in realism:
        for p in UI_FONTS:
            if os.path.exists(p):
                return ImageFont.truetype(p, max(10, px))
    for p in FONT_CANDIDATES:
        if os.path.exists(p):
            return ImageFont.truetype(p, px)
    return ImageFont.load_default()


def degrade(img, realism: set):
    """Apply the degradations of a real screenshot capture to a crisp render."""
    from PIL import Image, ImageFilter

    if "frac" in realism:
        # fractional display scaling: render small, grow back -> soft, exactly like a 1.25x shot
        w, h = img.size
        img = img.resize((int(w * 0.8), int(h * 0.8)), Image.LANCZOS).resize((w, h), Image.BICUBIC)
        img = img.filter(ImageFilter.GaussianBlur(0.5))
    if "lowcon" in realism:
        img = img.filter(ImageFilter.GaussianBlur(0.4))
    return img


def draw_case(name: str, text: str, bg, fg, px: int, realism: set) -> None:
    from PIL import Image, ImageDraw

    lines = text.split("\n")
    f = font(px, realism)
    tmp = Image.new("RGB", (10, 10))
    d = ImageDraw.Draw(tmp)
    widths = [d.textlength(ln, font=f) for ln in lines]
    w = int(max(widths)) + 24
    lh = int(px * 1.45)
    h = lh * len(lines) + 16
    img = Image.new("RGB", (w, h), bg)
    d = ImageDraw.Draw(img)
    y = 8
    for ln in lines:
        d.text((12, y), ln, fill=fg, font=f)
        y += lh
    img = degrade(img, realism)
    img.save(os.path.join(CORPUS, name + ".png"))
    with open(os.path.join(CORPUS, name + ".txt"), "w", encoding="utf-8") as fh:
        fh.write(text.replace("\n", " ") + "\n")   # ground truth as one line for WER/CER


def make_corpus() -> list[tuple]:
    os.makedirs(CORPUS, exist_ok=True)
    for c in CASES:
        draw_case(*c)
    return load_corpus()


def load_corpus() -> list[tuple]:
    """Every <name>.png that has a <name>.txt beside it (drawn cases + any real captures)."""
    out = []
    for fn in sorted(os.listdir(CORPUS)):
        if fn.endswith(".png"):
            txt = os.path.join(CORPUS, fn[:-4] + ".txt")
            if os.path.exists(txt):
                out.append((os.path.join(CORPUS, fn), txt))
    return out


def norm(s: str) -> str:
    return " ".join(s.split())


def levenshtein(a: str, b: str) -> int:
    if a == b:
        return 0
    if not a:
        return len(b)
    if not b:
        return len(a)
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1]


def cer(ref: str, hyp: str) -> float:
    ref, hyp = norm(ref), norm(hyp)
    if not ref:
        return 0.0 if not hyp else 1.0
    return min(1.0, levenshtein(ref, hyp) / len(ref))


def baseline_read(path: str, langs: str = "rus+eng") -> tuple[str, float]:
    """Exactly the old niri-ocr: raw crop -> `tesseract --psm 6`, no preprocessing."""
    t0 = time.perf_counter()
    r = subprocess.run(["tesseract", path, "stdout", "-l", langs, "--psm", "6"],
                       capture_output=True, text=True)
    dt = (time.perf_counter() - t0) * 1000
    return "\n".join(l.rstrip() for l in r.stdout.splitlines() if l.strip()), dt


def pipeline_read(path: str, engine_name: str, langs: str = "rus+eng") -> tuple[str, float]:
    t0 = time.perf_counter()
    if engine_name == "rapidocr":
        import engine_rapidocr as eng
    else:
        import engine_tesseract as eng
    read = eng.read_region(path, langs=langs)
    return read.text, (time.perf_counter() - t0) * 1000


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--make", action="store_true", help="only redraw the drawn corpus")
    ap.add_argument("--engine", default="tesseract", help="backend for the pipeline column")
    a = ap.parse_args()

    pairs = make_corpus() if a.make else load_corpus()
    if not pairs:
        print("no corpus; run with --make", file=sys.stderr)
        return 2

    print(f"{'case':16} {'CER base':>9} {'CER pipe':>9} {'ms base':>8} {'ms pipe':>8}  better")
    tot_b = tot_p = 0.0
    tb = tp = 0.0
    wins = 0
    for img, txt in pairs:
        name = os.path.basename(img)[:-4]
        ref = open(txt, encoding="utf-8").read()
        b, dtb = baseline_read(img)
        p, dtp = pipeline_read(img, a.engine)
        cb, cp = cer(ref, b), cer(ref, p)
        tot_b += cb
        tot_p += cp
        tb += dtb
        tp += dtp
        better = "pipe" if cp < cb else ("base" if cb < cp else "=")
        wins += (cp < cb)
        print(f"{name:16} {cb:9.3f} {cp:9.3f} {dtb:8.0f} {dtp:8.0f}  {better}")

    n = len(pairs)
    print("-" * 62)
    print(f"{'TOTAL/mean':16} {tot_b/n:9.3f} {tot_p/n:9.3f} {tb/n:8.0f} {tp/n:8.0f}  "
          f"pipe wins {wins}/{n}")
    verdict = "pipeline is BETTER" if tot_p < tot_b else (
        "baseline is BETTER" if tot_b < tot_p else "tie")
    print(f"\n{verdict} (mean CER {tot_b/n:.3f} -> {tot_p/n:.3f}, engine={a.engine})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
