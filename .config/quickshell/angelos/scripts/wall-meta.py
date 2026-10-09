#!/usr/bin/env python3
"""Wallpaper variants: which pictures are one wallpaper, and what each of them is.

A wallpaper can come as several files: a day and a night one, and cuts for other
screens (21:9, 32:9, 9:16 for a monitor on its side …). They are one wallpaper when
their names differ only by such marks:

    ozero.png  ozero-night.png  ozero-21x9.png  ozero-night-21x9.png  ozero-9x16.png
    Озеро день.png  Озеро ночь.png  Озеро 21 на 9.png  Озеро вертикальные.png
    Ozero/day.png  Ozero/night.png  Ozero/32x9.png      (no name left: the folder's)

The size comes from the file itself (only its header is read), so a cut needs no mark
in its name at all; a mark of shape (21x9, 3440x1440, vertical, wide; 4K, UHD) is taken off the
name only when the picture has that shape, so "level-2-3.png" stays its own picture.

  wall-meta.py [--cache FILE]   paths on stdin, one per line
  -> JSON {path: {"w", "h", "time": "day" | "night" | "", "key", "name"}}
     key: the same for every file of one wallpaper; name: its name for people
"""
import json
import os
from pathlib import Path
import re
import struct
import sys

TIME = {
    "day": "day", "den": "day", "день": "day", "дневной": "day", "дневные": "day", "дневная": "day",
    "light": "day", "светлая": "day", "светлые": "day", "светлый": "day", "morning": "day", "утро": "day",
    "night": "night", "noch": "night", "ночь": "night", "ночной": "night", "ночные": "night", "ночная": "night",
    "dark": "night", "тёмная": "night", "темная": "night", "тёмные": "night", "темные": "night",
    "тёмный": "night", "темный": "night", "evening": "night", "вечер": "night",
}
TALL = {"vertical", "portrait", "tall", "phone", "вертикальные", "вертикальная", "вертикальный", "вертикаль", "верт", "портрет"}
WIDE = {"horizontal", "landscape", "wide", "ultrawide", "superwide", "uw", "горизонтальные", "горизонтальная",
        "горизонтальный", "широкие", "широкая", "широкий"}
SEP = r"[\s_\-.,()\[\]+]"
WORD = re.compile(r"[^\s_\-.,()\[\]+]+")
# 21x9, 21:9, 21×9, 21-9, 21 на 9, 9x16; and 3440x1440 (a resolution)
RATIO = re.compile(r"(?<![0-9])(\d{1,2})\s*(?:x|х|×|:|-|_|\s*на\s*)\s*(\d{1,2})(?![0-9])", re.I)
RES = re.compile(r"(?<![0-9])(\d{3,5})\s*[x×х]\s*(\d{3,5})(?![0-9])", re.I)


def size(path):
    """(w, h) from the file's header, or None."""
    try:
        with open(path, "rb") as f:
            head = f.read(32)
            if head[:8] == b"\x89PNG\r\n\x1a\n":
                return struct.unpack(">II", head[16:24])
            if head[:6] in (b"GIF87a", b"GIF89a"):
                return struct.unpack("<HH", head[6:10])
            if head[:2] == b"BM":
                w, h = struct.unpack("<ii", head[18:26])
                return w, abs(h)
            if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
                kind = head[12:16]
                if kind == b"VP8 ":
                    f.seek(26)
                    w, h = struct.unpack("<HH", f.read(4))
                    return w & 0x3FFF, h & 0x3FFF
                if kind == b"VP8L":
                    b = head[21:25]
                    w = 1 + (((b[1] & 0x3F) << 8) | b[0])
                    h = 1 + (((b[3] & 0xF) << 10) | (b[2] << 2) | ((b[1] & 0xC0) >> 6))
                    return w, h
                if kind == b"VP8X":
                    f.seek(24)
                    b = f.read(6)
                    return 1 + int.from_bytes(b[0:3], "little"), 1 + int.from_bytes(b[3:6], "little")
                return None
            if head[:2] == b"\xff\xd8":
                f.seek(2)
                while True:
                    m = f.read(2)
                    if len(m) < 2 or m[0] != 0xFF:
                        return None
                    while m[1] == 0xFF:
                        m = m[:1] + f.read(1)
                    if m[1] in (0xD8, 0x01) or 0xD0 <= m[1] <= 0xD7:
                        continue
                    seg = struct.unpack(">H", f.read(2))[0]
                    if m[1] in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
                        h, w = struct.unpack(">xHH", f.read(5))
                        return w, h
                    f.seek(seg - 2, 1)
    except (OSError, struct.error, IndexError):
        return None
    return None


def near(a, b, tol):
    return a > 0 and b > 0 and abs(a / b - 1) <= tol


def parse(path, w, h):
    """(time, base name, name for people) of one file."""
    p = Path(path)
    stem = p.stem
    aspect = w / h if w and h else 0
    cut = []                                   # spans of stem that are marks, not the name
    for m in RES.finditer(stem):
        a, b = int(m.group(1)), int(m.group(2))
        if not aspect or near(a / b, aspect, 0.03):
            cut.append(m.span())
    for m in RATIO.finditer(stem):
        a, b = int(m.group(1)), int(m.group(2))
        if a and b and aspect and near(a / b, aspect, 0.1) and not any(s <= m.start() < e for s, e in cut):
            cut.append(m.span())
    time = ""
    for m in WORD.finditer(stem):
        word = m.group(0).lower()
        if any(s <= m.start() < e for s, e in cut):
            continue
        if word in TIME:
            time = time or TIME[word]
            cut.append(m.span())
        elif (word in TALL and aspect and aspect < 1) or (word in WIDE and aspect and aspect > 1) or re.fullmatch(r"\d{1,2}k|uhd|fhd|qhd|hd", word):
            cut.append(m.span())
    keep = "".join(c for i, c in enumerate(stem) if not any(s <= i < e for s, e in cut))
    name = re.sub(SEP + "+", " ", keep).strip()
    if not name:                               # Ozero/night.png: the folder is the wallpaper
        return time, str(p.parent.parent) + "/" + p.parent.name.lower(), p.parent.name
    return time, str(p.parent) + "/" + re.sub(r"\s+", "-", name.lower()), name


def main():
    args = sys.argv[1:]
    cache_file = Path(args[args.index("--cache") + 1]) if "--cache" in args else None
    cache = {}
    if cache_file:
        try:
            cache = json.loads(cache_file.read_text())
        except (OSError, ValueError):
            cache = {}
    out, fresh = {}, {}
    for line in sys.stdin:
        path = line.rstrip("\n")
        if not path:
            continue
        try:
            st = os.stat(path)
        except OSError:
            continue
        stamp = [st.st_mtime_ns, st.st_size]
        c = cache.get(path)
        if c and c[:2] == stamp:
            w, h = c[2], c[3]
        else:
            wh = size(path)
            w, h = wh if wh else (0, 0)
        fresh[path] = stamp + [w, h]
        time, key, name = parse(path, w, h)
        out[path] = {"w": w, "h": h, "time": time, "key": key, "name": name}
    if cache_file and fresh != cache:
        try:
            cache_file.parent.mkdir(parents=True, exist_ok=True)
            tmp = cache_file.with_suffix(".tmp")
            tmp.write_text(json.dumps(fresh))
            tmp.replace(cache_file)
        except OSError:
            pass
    json.dump(out, sys.stdout, ensure_ascii=False)


if __name__ == "__main__":
    main()
