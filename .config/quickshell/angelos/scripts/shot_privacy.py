#!/usr/bin/env python3
"""Suggest privacy masks for a screenshot and copy the flattened, masked PNG."""
import csv
import io
import json
import os
import re
import subprocess
import sys

from PIL import Image, ImageOps

from capture_save import copy, encode


# UIs abbreviate email addresses after the first domain label. OCR can omit the
# ellipsis entirely, so accept a joined local@label but keep bare @mentions out.
EMAIL = re.compile(r"[\w.%+-]+(?<!\.)(?:\s*@\s*[\w-]+(?:\.\s*[\w-]+)+|@[\w-]+(?:\s*(?:…|\.{2,}))?)")
NUMBER = re.compile(r"(?<!\w)(?:\+?\d|\(\d{2,4}\))[\d(). \-]{7,}\d(?!\w)")
TOKEN = re.compile(
    r"(?<![\w-])(?:(?:gh[pousr]_|github_pat_|sk-|glpat-|xox[abprs]-)[\w-]{14,}"
    r"|(?:AKIA|ASIA)[A-Z0-9]{16}|eyJ[\w-]{8,}\.[\w-]{8,}\.[\w-]{8,})(?![\w-])"
)


def sensitive_number(text):
    digits = [int(d) for d in text if d.isdecimal()]
    length = len(digits)
    if length in (10, 11) or (text.startswith("+") and 10 <= length <= 15):
        return True
    if not 13 <= length <= 19 or len(set(digits)) == 1:
        return False
    checksum = sum(n if i % 2 == 0 else (2 * n - 9 if n > 4 else 2 * n)
                   for i, n in enumerate(reversed(digits)))
    return checksum % 10 == 0


def scan(shot):
    with Image.open(shot) as source:
        width, height = source.size
        page = ImageOps.grayscale(source)
    scale = 2 if width * height <= 1_500_000 else 1
    if scale > 1:
        page = page.resize((width * scale, height * scale), Image.Resampling.BICUBIC)
    env = dict(os.environ, OMP_THREAD_LIMIT="1")
    result = subprocess.run(
        ["tesseract", "stdin", "stdout", "-l", "eng", "--psm", "11", "tsv"],
        input=encode(page, False), capture_output=True, timeout=10, check=True, env=env,
    )
    lines = {}
    for row in csv.DictReader(io.StringIO(result.stdout.decode("utf-8")), dialect="excel-tab",
                              quoting=csv.QUOTE_NONE):
        if row["level"] == "5" and row["text"].strip():
            group = tuple(row[k] for k in ("page_num", "block_num", "par_num", "line_num"))
            lines.setdefault(group, []).append(row)

    boxes = []
    for words in lines.values():
        text = ""
        spans = []
        for word in words:
            if text:
                text += " "
            start = len(text)
            text += word["text"].strip()
            spans.append((start, len(text), word))
        matches = [*EMAIL.finditer(text), *TOKEN.finditer(text)]
        matches.extend(m for m in NUMBER.finditer(text) if sensitive_number(m.group()))
        for match in matches:
            rows = [w for start, end, w in spans if start < match.end() and end > match.start()]
            bounds = [(int(w["left"]), int(w["top"]), int(w["width"]), int(w["height"])) for w in rows]
            x0 = max(0, min(x for x, _, _, _ in bounds) // scale - 3)
            y0 = max(0, min(y for _, y, _, _ in bounds) // scale - 3)
            x1 = min(width, (max(x + w for x, _, w, _ in bounds) + scale - 1) // scale + 3)
            y1 = min(height, (max(y + h for _, y, _, h in bounds) + scale - 1) // scale + 3)
            if x1 > x0 and y1 > y0:
                box = {"x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0}
                if box not in boxes:
                    boxes.append(box)
    return {"width": width, "height": height, "boxes": boxes}


def masked_copy(shot, boxes):
    if not isinstance(boxes, list) or not boxes:
        raise ValueError("masks required")
    with Image.open(shot) as source:
        # Start with just the pixels: the new PNG should not carry screenshot metadata.
        mode = "RGBA" if "A" in source.getbands() or "transparency" in source.info else "RGB"
        image = Image.new(mode, source.size)
        image.paste(source.convert(mode))
    for box in boxes:
        x, y, w, h = (box[k] for k in ("x", "y", "w", "h"))
        if any(type(n) is not int for n in (x, y, w, h)):
            raise ValueError("invalid mask")
        x0, y0 = max(0, x), max(0, y)
        x1, y1 = min(image.width, x + w), min(image.height, y + h)
        if x0 >= x1 or y0 >= y1:
            raise ValueError("invalid mask")
        image.paste("#111111", (x0, y0, x1, y1))
    return copy(encode(image, False), "image/png")


def main(argv):
    try:
        if len(argv) == 2 and argv[0] == "scan":
            print(json.dumps(scan(argv[1])))
            return 0
        if len(argv) == 3 and argv[0] == "copy":
            return 0 if masked_copy(argv[1], json.loads(argv[2])) else 1
    except (OSError, ValueError, TypeError, KeyError, subprocess.SubprocessError):
        return 1
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
