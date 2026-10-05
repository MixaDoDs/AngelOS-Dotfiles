#!/usr/bin/env python3
"""Pixel cursor themes for angelOS, and one cursor everywhere.

  cursors.py list                      -> JSON: catalog, installed themes, what is applied where
  cursors.py install <id> [--accent #rrggbb --edge #rrggbb --light #rrggbb]
  cursors.py apply <theme> <size> [--no-flatpak]
  cursors.py preview <theme>           -> PNG strip in ~/.cache/angelos/cursors/<theme>.png

Themes are downloaded from pinned archives (SHA-256 checked) or built from the
pixel-cursors assets (mikaeladev, GPL-3.0) recoloured with the angelOS palette.
The hell themes ("realm": "hell") are pixel-cursors too: their own palettes, some
shapes redrawn (a devil's tail, a pitchfork, claws, a skull) and two animated
(embers rising, lava flowing). Each circle of hell has its own as well, described in
story/circles.json → "cursor" (palette, shapes, fx: angelOS-Circle-<Circle>), with two
variations for the mood (Cursors.mood): "Tip" — the tip in the circle's accent — and
"Alive" — its rare animation, played in the cursor's own frames so it shows over every
app (an oil drop swelling and falling, a glint, eyes opening…). angelOS puts the circle's
on while the demon rules, or the one picked (Settings → Cursor → Hell). Every theme is
built on first use. The pixel-cursors archive is cached.
`apply` sets the theme for niri (Wayland + XWayland via xwayland-satellite),
GTK 3/4 (settings.ini, gsettings, xsettingsd), plain X11 clients and Steam
(~/.icons/default, ~/.icons/<theme>), the systemd/D-Bus activation environment
and Flatpak apps. niri's config is validated before it is written.
"""
import io
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tarfile
import tempfile
import tomllib
import urllib.error
import urllib.request

HOME = Path.home()
SHELL = Path(__file__).resolve().parent.parent
CIRCLES = SHELL / "story/circles.json"
ICONS = HOME / ".local/share/icons"
LEGACY_ICONS = HOME / ".icons"
CACHE = HOME / ".cache/angelos/cursors"
NIRI = HOME / ".config/niri"
BACKUPS = HOME / ".local/state/angelos/backups"

PIXEL_SRC = ("https://codeload.github.com/mikaeladev/pixel-cursors/tar.gz/736814216bcd5558ec904287b18deeabd0b91f78",
             "679a2df495b1333208a61f01fff3fe7bfba28fd81a28e61b6508d4a2ac9d5dfb")
CATALOG = [
    {"id": "angelos", "theme": "angelOS-Pixel", "name": "angelOS Pixel",
     "about": "pixel-cursors in the angelOS colours (accent, edge, light)", "license": "GPL-3.0 (mikaeladev/pixel-cursors)",
     "build": "pixel", "palette": None},
    {"id": "glitter", "theme": "angelOS-Glitter", "name": "angelOS Glitter",
     "about": "angelOS Pixel with twinkling Y2K sparkles", "license": "GPL-3.0 (mikaeladev/pixel-cursors)",
     "build": "pixel", "palette": None, "glitter": True},
    {"id": "pixel-amethyst", "theme": "Pixel-Amethyst", "name": "Pixel Amethyst",
     "about": "lavender 8-bit set", "license": "GPL-3.0 (mikaeladev/pixel-cursors)",
     "build": "pixel", "palette": {"primary": "#fad6ff", "secondary": "#9c8bdb", "border": "#7864c6"}},
    {"id": "pixel-golden", "theme": "Pixel-Golden", "name": "Pixel Golden",
     "about": "warm retro set", "license": "GPL-3.0 (mikaeladev/pixel-cursors)",
     "build": "pixel", "palette": {"primary": "#eceabe", "secondary": "#c07b67", "border": "#5e2f44"}},
    {"id": "pink-hearts", "theme": "pink-heart-cursors", "name": "Pink Hearts",
     "about": "pink cursors with little hearts", "license": "not stated by the author (SimonCantCode)",
     "url": "https://codeload.github.com/SimonCantCode/pink-heart-cursors/tar.gz/36f3910044ffe8305bcf16242d70e8e43378e721",
     "sha256": "a3583953b485b0170c05d1cf8af1bc7da8af82cd5fd97c6b61f4201310e8b070"},
    {"id": "modern-xp", "theme": "ModernXP", "name": "Modern XP",
     "about": "pixel-perfect Windows XP set, HiDPI sizes", "license": "GPL-3.0 (na0miluv/modernXP-cursor-theme)",
     "url": "https://github.com/na0miluv/modernXP-cursor-theme/releases/download/final/ModernXP.tar.gz",
     "sha256": "5b439d1b838f19b667d565f9bc7c5e435118a7ef60cb2975f4695ce216b6be03"},
    # macOS's black arrow, redrawn from scratch as SVG (not Apple's files), HiDPI sizes 16…96: the
    # Golden Gate skin's cursor (Cursors.macTheme). No open port of Golden Gate's own (its glove
    # hand) exists; this is the closest open one
    {"id": "macos", "theme": "macOS", "name": "macOS",
     "about": "macOS-like black arrow and hands, HiDPI sizes", "license": "GPL-3.0 (ful1e5/apple_cursor)",
     "url": "https://github.com/ful1e5/apple_cursor/releases/download/v2.0.1/macOS.tar.xz",
     "sha256": "9c6e5e13b068ce51a9e90a9abd6ce232ec7d25d4ceb05aa8ac76efbb99c76762",
     "subdir": "macOS"},  # the archive holds macOS-White too
    {"id": "pixel-linux", "theme": "Pixel-Linux-Cursor", "name": "Pixel Linux",
     "about": "black-and-white pixel set with a skull", "license": "BSD-3-Clause (da0ab/Pixel-Linux-Cursor)",
     "url": "https://codeload.github.com/da0ab/Pixel-Linux-Cursor/tar.gz/fdef33f8c87bff22812048c6060d6f36a12f1aaa",
     "sha256": "6039f887cec4d32de0b5cea9b87a55c009a9e2975fde1e87211ee57b57dbe55a"},
    # the angel cold towards the player for good (Story.angelStep, Cursors.heavenTheme): angelOS
    # Pixel in ice, frost along its upper rim — put on instead of angelOS's own, never listed
    {"id": "frost", "theme": "angelOS-Frost", "name": "angelOS Frost", "about": "angelOS Pixel in ice, frost on the rim",
     "license": "GPL-3.0 (mikaeladev/pixel-cursors)", "build": "pixel", "hidden": True, "frostRim": "#d8ecff",
     "palette": {"primary": "#eef6ff", "secondary": "#a9cbe8", "border": "#2c4560"}},
    # ---- hell: while the demon rules (pixel-cursors, GPL-3.0) ----
    {"id": "hell", "theme": "angelOS-Hell", "name": "angelOS Hell", "realm": "hell",
     "about": "blood and obsidian; the arrow grew a devil's tail", "license": "GPL-3.0 (mikaeladev/pixel-cursors)",
     "build": "pixel", "palette": {"primary": "#ff4a3d", "secondary": "#8e1022", "border": "#14040a"},
     "shapes": {"default": "tail"}},
    {"id": "hell-ember", "theme": "angelOS-Hell-Ember", "name": "Hell Ember", "realm": "hell",
     "about": "smouldering: embers float up off the pointer", "license": "GPL-3.0 (mikaeladev/pixel-cursors)",
     "build": "pixel", "palette": {"primary": "#ffb02e", "secondary": "#d9431b", "border": "#1c0606"}, "fx": "embers"},
    {"id": "hell-pitchfork", "theme": "angelOS-Hell-Pitchfork", "name": "Hell Pitchfork", "realm": "hell",
     "about": "the arrow is a pitchfork, the rest dark crimson", "license": "GPL-3.0 (mikaeladev/pixel-cursors)",
     "build": "pixel", "palette": {"primary": "#c9283c", "secondary": "#6a0d1c", "border": "#120306"},
     "shapes": {"default": "pitchfork"}},
    {"id": "hell-claw", "theme": "angelOS-Hell-Claw", "name": "Hell Claw", "realm": "hell",
     "about": "the hands are the demon's claws", "license": "GPL-3.0 (mikaeladev/pixel-cursors)",
     "build": "pixel", "palette": {"primary": "#ff3b6b", "secondary": "#7a1e46", "border": "#1a0a14"},
     "shapes": {"hand-pointing": "claw", "hand-open": "claw-open", "hand-closed": "claw-closed"}},
    {"id": "hell-bone", "theme": "angelOS-Hell-Bone", "name": "Hell Bone", "realm": "hell",
     "about": "bone white; “forbidden” is a skull", "license": "GPL-3.0 (mikaeladev/pixel-cursors)",
     "build": "pixel", "palette": {"primary": "#efe6d0", "secondary": "#a89a7c", "border": "#1a1010"},
     "shapes": {"forbidden": "skull"}},
    {"id": "hell-brimstone", "theme": "angelOS-Hell-Brimstone", "name": "Hell Brimstone", "realm": "hell",
     "about": "lava flows through every pointer", "license": "GPL-3.0 (mikaeladev/pixel-cursors)",
     "build": "pixel", "palette": {"primary": "#ff8a1a", "secondary": "#b3142b", "border": "#0d0303"}, "fx": "lava"},
]

# Redrawn hell shapes on the 12×12 pixel-cursors grid: # border, o primary,
# + secondary (the theme's palette), w bone, r ember-yellow. (rows, hotspot)
HELL_SHAPES = {
    "tail": ([
        "............",
        "............",
        "..##........",
        "..#o#.......",
        "..#oo#......",
        "..#ooo#.....",
        "..#oooo#....",
        "..#ooo+#....",
        "..#oo+##....",
        "..#####+#...",
        ".......#+#..",
        "........##.."], (2, 2)),
    "pitchfork": ([
        "w..w..w.....",
        "w..w..w.....",
        "#w.#w.#w....",
        ".#w#w#w#....",
        "..#www#.....",
        "...#w+#.....",
        "....#+#.....",
        ".....#+#....",
        "......#+#...",
        ".......#+#..",
        "........#+#.",
        ".........##."], (0, 0)),
    "claw": ([
        "....w.......",
        "....#w......",
        "....#o#.....",
        "....#o##....",
        "..w##ooo#w..",
        "..#o#o+o+#..",
        "..#+ooo++#..",
        "..##++++##..",
        "...######...",
        "............",
        "............",
        "............"], (4, 0)),
    "claw-open": ([
        "............",
        "..w..w..w...",
        "..#w.#w.#w..",
        "..#o##o##o#.",
        "..#o#o#o#o#.",
        "..#ooooooo#.",
        "..#+ooooo+#.",
        "..#++ooo++#.",
        "...#+++++#..",
        "....#####...",
        "............",
        "............"], (6, 6)),
    "claw-closed": ([
        "............",
        "............",
        "............",
        "...#######..",
        "..#ooooooo#.",
        "..#w#w#w#o#.",
        "..#ooooooo#.",
        "..#+ooooo+#.",
        "..#++ooo++#.",
        "...#+++++#..",
        "....#####...",
        "............"], (6, 6)),
    "skull": ([
        "............",
        "...######...",
        "..#oooooo#..",
        ".#oooooooo#.",
        ".#o##oo##o#.",
        ".#o#r+o#ro#.",
        ".#oo++oooo#.",
        "..#ooo#oo#..",
        "...#o#o#o#..",
        "...#o+o+o#..",
        "....#####...",
        "............"], (5, 5)),
}
SHAPE_EXTRA = {"w": "#ece6d8", "r": "#ffd23f"}
NAME_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.+-]{0,63}\Z")
HEX_RE = re.compile(r"#[0-9a-fA-F]{6}\Z")
# names apps ask for that pixel-cursors does not list
EXTRA_ALIASES = {"default": ["progress-fallback"], "wait": ["progress", "left_ptr_watch", "half-busy", "watch",
                 "3ecb610c1bf2410f44200f48c40d3599", "00000000000000020006000e7e9ffc3f", "08e8e1c95fe2fc01f976f1e063a24ccd"]}


class Fail(Exception):
    pass


# ---------- downloads ----------
def fetch(url, sha):
    req = urllib.request.Request(url, headers={"User-Agent": "angelOS-cursors/1"})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read(64 * 1024 * 1024 + 1)
    if len(data) > 64 * 1024 * 1024:
        raise Fail("download too large")
    import hashlib
    if hashlib.sha256(data).hexdigest() != sha:
        raise Fail("checksum mismatch for " + url)
    return data


def safe_members(tar):
    for m in tar.getmembers():
        p = Path(m.name)
        if p.is_absolute() or ".." in p.parts or m.isdev():
            raise Fail("unsafe path in archive: " + m.name)
        if m.issym() or m.islnk():
            target = Path(m.linkname)
            if target.is_absolute() or ".." in target.parts:
                raise Fail("unsafe link in archive: " + m.name)
        yield m


def install_archive(entry):
    data = fetch(entry["url"], entry["sha256"])
    with tempfile.TemporaryDirectory(prefix="angelos-cursor-") as tmp:
        with tarfile.open(fileobj=io.BytesIO(data)) as tar:
            tar.extractall(tmp, members=list(safe_members(tar)), filter="data")
        # the theme root is the directory holding cursors/
        roots = [p.parent for p in Path(tmp).rglob("cursors") if p.is_dir()]
        # an archive with several themes names the one wanted ("subdir")
        if entry.get("subdir"):
            roots = [p for p in roots if p.name == entry["subdir"]]
        if not roots:
            raise Fail("no cursors/ directory in the archive")
        root = min(roots, key=lambda p: (len(p.parts), str(p)))
        index = root / "index.theme"
        if not index.exists():
            index.write_text(f"[Icon Theme]\nName={entry['name']}\nComment={entry['about']}\n")
        place(root, entry["theme"])


def place(src, theme):
    ICONS.mkdir(parents=True, exist_ok=True)
    dest = ICONS / theme
    tmp = ICONS / f".{theme}.new"
    shutil.rmtree(tmp, ignore_errors=True)
    shutil.copytree(src, tmp, symlinks=True)
    if dest.exists() or dest.is_symlink():
        old = ICONS / f".{theme}.old"
        shutil.rmtree(old, ignore_errors=True)
        dest.rename(old)
        tmp.rename(dest)
        shutil.rmtree(old, ignore_errors=True)
    else:
        tmp.rename(dest)
    legacy_link(theme)


def legacy_link(theme):
    # Steam's runtime and old X11 clients only look in ~/.icons
    LEGACY_ICONS.mkdir(parents=True, exist_ok=True)
    link = LEGACY_ICONS / theme
    if (ICONS / theme).is_dir() and not link.exists() and not link.is_symlink():
        link.symlink_to(ICONS / theme)


# ---------- xcursor ----------
def xcursor_bytes(images):
    """images: [(nominal, w, h, xhot, yhot, delay, rgba bytes)] -> .xcursor file"""
    toc, chunks = [], []
    pos = 16 + 12 * len(images)
    for nominal, w, h, xh, yh, delay, rgba in images:
        px = bytearray()
        for i in range(0, len(rgba), 4):
            r, g, b, a = rgba[i:i + 4]
            px += bytes((b * a // 255, g * a // 255, r * a // 255, a))    # premultiplied BGRA (LE ARGB)
        chunk = struct.pack("<9I", 36, 0xFFFD0002, nominal, 1, w, h, xh, yh, delay) + bytes(px)
        toc.append(struct.pack("<3I", 0xFFFD0002, nominal, pos))
        chunks.append(chunk)
        pos += len(chunk)
    return struct.pack("<4s3I", b"Xcur", 16, 0x10000, len(images)) + b"".join(toc) + b"".join(chunks)


def xcursor_first_image(path, want=32):
    data = path.read_bytes()
    if data[:4] != b"Xcur":
        raise Fail("not an xcursor file")
    _, hsize, _, ntoc = struct.unpack("<4s3I", data[:16])
    entries = [struct.unpack("<3I", data[hsize + 12 * i:hsize + 12 * i + 12]) for i in range(ntoc)]
    images = [e for e in entries if e[0] == 0xFFFD0002]
    if not images:
        raise Fail("no images")
    best = min(images, key=lambda e: abs(e[1] - want))
    pos = best[2]
    _, _, _, _, w, h, xh, yh, _ = struct.unpack("<9I", data[pos:pos + 36])
    raw = data[pos + 36:pos + 36 + w * h * 4]
    rgba = bytearray()
    for i in range(0, len(raw), 4):
        b, g, r, a = raw[i:i + 4]
        if a:
            r, g, b = min(255, r * 255 // a), min(255, g * 255 // a), min(255, b * 255 // a)
        rgba += bytes((r, g, b, a))
    return w, h, bytes(rgba)


# ---------- pixel-cursors build ----------
def hex_rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def glitterize(img, accent, light, frames=6):
    """Y2K glitter: the cursor on a larger canvas (hotspot unchanged) with
    sparkles twinkling around it, one after another."""
    from PIL import Image
    x0, y0, x1, y1 = img.getbbox() or (0, 0, img.width, img.height)
    canvas = (max(img.width, x1 + 5), max(img.height, y1 + 5))
    my, mx = (y0 + y1) // 2, (x0 + x1) // 2
    spots = [(x1 + 1, y0 + 1), (x1 + 3, my), (mx + 2, y1 + 2), (x0 + 1, y1 + 3), (x1 + 2, y1 + 2)]
    out = []
    for f in range(frames):
        c = Image.new("RGBA", canvas, (0, 0, 0, 0))
        c.paste(img, (0, 0), img)
        px = c.load()
        for i, (x, y) in enumerate(spots):
            size = (0, 1, 2, 1, 0, 0)[(f + i * 2) % frames]
            col = (accent if i % 2 else light) + (255,)
            if size >= 1 and 0 <= x < canvas[0] and 0 <= y < canvas[1] and px[x, y][3] == 0:
                px[x, y] = (255, 255, 255, 255) if size == 2 else col
            if size == 2:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < canvas[0] and 0 <= yy < canvas[1] and px[xx, yy][3] == 0:
                        px[xx, yy] = col
        out.append(c)
    return out


def hell_shape(name, palette, flop):
    """A redrawn 12×12 shape in the theme's palette; hotspot follows a flop."""
    from PIL import Image
    rows, (hx, hy) = HELL_SHAPES[name]
    colours = {"#": palette["border"], "o": palette["primary"], "+": palette["secondary"], **SHAPE_EXTRA}
    img = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in colours:
                img.putpixel((x, y), hex_rgb(colours[ch]) + (255,))
    if flop:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
        hx = 11 - hx
    return img, hx, hy


def embers(img, frames=6):
    """Hell Ember: sparks float up along the pointer's right side and fade,
    yellow → orange → blood (the canvas grows right/down only: same hotspot)."""
    from PIL import Image
    x0, y0, x1, y1 = img.getbbox() or (0, 0, img.width, img.height)
    canvas = (max(img.width, x1 + 4), max(img.height, y1 + 2))
    ramp = [(255, 236, 140), (255, 210, 63), (255, 138, 26), (217, 67, 27), (142, 16, 34), None]
    # (x, start row, phase): each spark climbs one pixel a frame
    sparks = [(x1 + 1, y1, 0), (x1 + 3, y1 - 1, 2), ((x0 + x1) // 2 + 2, y1 + 1, 4)]
    out = []
    for f in range(frames):
        c = Image.new("RGBA", canvas, (0, 0, 0, 0))
        c.paste(img, (0, 0), img)
        px = c.load()
        for x, y, phase in sparks:
            age = (f + phase) % frames
            col, yy = ramp[age], y - age
            if col and 0 <= x < canvas[0] and 0 <= yy < canvas[1] and px[x, yy][3] == 0:
                px[x, yy] = col + (255,)
        out.append(c)
    return out


def lava(img, palette, frames=6):
    """Hell Brimstone: the fill flows like lava, a bright band sliding down-right."""
    primary, secondary = hex_rgb(palette["primary"]), hex_rgb(palette["secondary"])
    hot = [(255, 236, 140), (255, 210, 63), (255, 138, 26), (232, 64, 28), (179, 20, 43), (232, 64, 28)]
    cool = [(232, 64, 28), (179, 20, 43), (110, 10, 24), (70, 6, 14), (110, 10, 24), (179, 20, 43)]
    out = []
    for f in range(frames):
        c = img.copy()
        px = c.load()
        for y in range(c.height):
            for x in range(c.width):
                r, g, b, a = px[x, y]
                if not a:
                    continue
                k = (x + y * 2 - f) % frames
                if (r, g, b) == primary:
                    px[x, y] = hot[k] + (a,)
                elif (r, g, b) == secondary:
                    px[x, y] = cool[k] + (a,)
        out.append(c)
    return out


def pixel_source():
    """The pixel-cursors archive, kept in the cache (checked against its SHA-256)."""
    import hashlib
    url, sha = PIXEL_SRC
    cached = CACHE / f"pixel-cursors-{sha[:16]}.tar.gz"
    if cached.is_file():
        data = cached.read_bytes()
        if hashlib.sha256(data).hexdigest() == sha:
            return data
    data = fetch(url, sha)
    CACHE.mkdir(parents=True, exist_ok=True)
    tmp = cached.with_suffix(".part")
    tmp.write_bytes(data)
    os.replace(tmp, cached)
    return data


def build_pixel(entry, accent=None, edge=None, light=None):
    from PIL import Image
    data = pixel_source()
    with tempfile.TemporaryDirectory(prefix="angelos-pixel-") as tmp:
        with tarfile.open(fileobj=io.BytesIO(data)) as tar:
            tar.extractall(tmp, members=list(safe_members(tar)), filter="data")
        src = next(Path(tmp).iterdir())
        cfg = tomllib.loads((src / "config.toml").read_text())
        default = cfg["themes"]["default"]
        palette = entry["palette"] or {"primary": light or "#fff4fb", "secondary": accent or "#ff77c8",
                                       "border": edge or "#2b1d33"}
        recolor = {hex_rgb(default[k]): hex_rgb(palette[k]) for k in ("primary", "secondary", "border")}
        out = Path(tmp) / "theme"
        (out / "cursors").mkdir(parents=True)
        scales = (2, 3, 4)
        for name, spec in cfg["cursors"].items():
            asset = spec.get("asset", name)
            opts = asset if isinstance(asset, dict) else {"name": asset}
            hx, hy = int(spec.get("hot_x", 0)), int(spec.get("hot_y", 0))
            shape = (entry.get("shapes") or {}).get(opts["name"])
            if shape:
                img, hx, hy = hell_shape(shape, palette, opts.get("flop"))
            else:
                img = Image.open(src / "assets" / (opts["name"] + ".png")).convert("RGBA")
                px = img.load()
                for y in range(img.height):
                    for x in range(img.width):
                        r, g, b, a = px[x, y]
                        if a and (r, g, b) in recolor:
                            px[x, y] = recolor[(r, g, b)] + (a,)
                if opts.get("flop"):
                    img = img.transpose(Image.FLIP_LEFT_RIGHT)
            frames = [img]
            delay = 0
            delays = None
            if "frames" in opts:
                tile = img.width
                cut = [img.crop((0, i * tile, tile, (i + 1) * tile)) for i in range(img.height // tile)]
                frames = [cut[i] for i in opts["frames"]]
                delay = int(opts.get("delay", 200))
            if opts.get("rotate"):
                frames = [f.rotate(-int(opts["rotate"]), expand=True) for f in frames]
            if entry.get("glitter") and len(frames) == 1:
                frames = glitterize(frames[0], hex_rgb(palette["secondary"]), hex_rgb(palette["primary"]))
                delay = 110
            elif entry.get("fx") == "embers" and len(frames) == 1:
                frames = embers(frames[0])
                delay = 130
            elif entry.get("fx") == "lava":
                frames = [g for f in frames for g in lava(f, palette)] if len(frames) == 1 else frames
                delay = delay or 150
            elif entry.get("circle") and entry.get("fx") and len(frames) == 1 and (entry.get("variant") == "alive" or not entry.get("still", True)):
                # a circle's own: its animation in the frames, rarely (Alive), or always for the
                # one whose sign it is (Gluttony's dripping oil), a long still pause between
                rest = 900 if entry.get("variant") == "alive" else 2600
                pairs = fx_frames(entry["fx"], frames[0], hex_rgb(entry.get("fxColour", "#ffffff")), rest, hex_rgb(palette["primary"]))
                frames, delays = [f for f, _ in pairs], [d for _, d in pairs]
            if entry.get("frostRim"):
                frames = [frost_rim(f, hex_rgb(entry["frostRim"])) for f in frames]
            # the mood: closer, the tip takes her accent (Tip); closest, that and the animation (Alive)
            if entry.get("variant") in ("tip", "alive"):
                frames = [tip_accent(f, hx, hy, hex_rgb(entry["accent"])) for f in frames]
            images = []
            for s in scales:
                for i, f in enumerate(frames):
                    big = f.resize((f.width * s, f.height * s), Image.NEAREST)
                    images.append((12 * s, big.width, big.height, hx * s + s // 2, hy * s + s // 2, delays[i] if delays else delay, big.tobytes()))
            (out / "cursors" / name).write_bytes(xcursor_bytes(images))
            for alias in list(spec.get("aliases", [])) + EXTRA_ALIASES.get(name, []):
                link = out / "cursors" / alias
                if NAME_RE.fullmatch(alias) and not link.exists():
                    link.symlink_to(name)
        (out / "index.theme").write_text(f"[Icon Theme]\nName={entry['name']}\nComment={entry['about']}\n")
        place(out, entry["theme"])


# ---------- the circles' own (story/circles.json → cursor) ----------
def circle_entries():
    """A theme for every circle that describes one, and its two mood variations (hidden
    from the lists: Cursors picks them): the base, "-Tip" (its accent on the tip) and
    "-Alive" (its rare animation)."""
    try:
        circles = json.loads(CIRCLES.read_text())
    except (OSError, ValueError):
        return []
    out = []
    for cid, c in circles.items():
        spec = c.get("cursor") if isinstance(c, dict) else None
        if cid in ("_comment", "base") or not isinstance(spec, dict) or not spec.get("palette"):
            continue
        name = (c.get("name") or {}).get("en") or cid.capitalize()
        theme = "angelOS-Circle-" + cid.capitalize()
        about = (spec.get("about") or {}).get("en", "")
        base = {"id": "circle-" + cid, "theme": theme, "name": "Circle %s: %s" % (c.get("n", ""), name), "realm": "hell",
                "circle": cid, "about": about, "license": "GPL-3.0 (mikaeladev/pixel-cursors)", "build": "pixel",
                "palette": spec["palette"], "shapes": spec.get("shapes") or {}, "accent": tip_colour(spec, c, circles),
                "fx": spec.get("fx") or "", "fxColour": spec.get("fxColour") or spec.get("accent") or "#ffffff", "still": spec.get("still", True)}
        out.append(base)
        out.append(dict(base, id=base["id"] + "-tip", theme=theme + "-Tip", variant="tip", hidden=True))
        out.append(dict(base, id=base["id"] + "-alive", theme=theme + "-Alive", variant="alive", hidden=True))
    return out


def tip_colour(spec, circle, circles):
    """the mood's tip: the circle's accent — or, where it is too like the fill to be seen
    (Limbo's ash), its blood"""
    pal = dict((circles.get("base") or {}).get("palette") or {}, **(circle.get("palette") or {}))
    accent = spec.get("accent") or pal.get("accent", "#ffffff")
    fill = spec["palette"]["primary"]
    if sum(abs(a - b) for a, b in zip(hex_rgb(accent), hex_rgb(fill))) < 120:
        return pal.get("blood", "#6b2420")
    return accent


def catalog():
    return CATALOG + circle_entries()


def tip_accent(img, hx, hy, accent):
    """the mood "Tip": the pixels near the hotspot that aren't the outline, in the accent"""
    out = img.copy()
    px = out.load()
    border = None
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a and abs(x - hx) + abs(y - hy) <= 3:
                # the darkest colour near the tip is the outline: it stays
                lum = r * 3 + g * 6 + b
                if border is None or lum < border[0]:
                    border = (lum, (r, g, b))
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a and abs(x - hx) + abs(y - hy) <= 3 and (r, g, b) != border[1]:
                px[x, y] = accent + (a,)
    return out


def frost_rim(img, colour):
    """frost along the upper and left rim: outline pixels with nothing above or left of them"""
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            if px[x, y][3] and (y == 0 or not px[x, y - 1][3] or x == 0 or not px[x - 1, y][3]) and (x + y) % 2 == 0:
                px[x, y] = colour + (px[x, y][3],)
    return out


def body_pixels(img, fill):
    """the pixels of the fill colour (the palette's primary), top to bottom"""
    px = img.load()
    return [(x, y) for y in range(img.height) for x in range(img.width) if px[x, y][3] and px[x, y][:3] == fill]


def fx_frames(kind, img, colour, rest, fill_colour):
    """A circle's rare animation in the cursor's own frames: [(image, delay ms)], the first
    one held for `rest` (the still pointer). The canvas only grows right and down, so the
    hotspot stays where it is."""
    from PIL import Image
    x0, y0, x1, y1 = img.getbbox() or (0, 0, img.width, img.height)
    fill = body_pixels(img, fill_colour)

    def canvas(extra_w=0, extra_h=0):
        c = Image.new("RGBA", (img.width + extra_w, img.height + extra_h), (0, 0, 0, 0))
        c.paste(img, (0, 0), img)
        return c

    if kind == "drip":
        # an oil drop swells under the body, falls, and is gone
        bottom = [p for p in fill if p[1] >= y1 - 3] or fill
        sx, sy = max(bottom, key=lambda p: (p[1], -abs(p[0] - (x0 + x1) // 2))) if bottom else (x0, y1 - 1)
        while sy + 1 < img.height and img.getpixel((sx, sy + 1))[3]:
            sy += 1
        frames = [(canvas(0, 7), rest)]
        shine = tuple(min(255, int(v * 1.6) + 40) for v in colour)
        for k, ms in ((1, 220), (2, 220)):
            c = canvas(0, 7)
            for d in range(k):
                c.putpixel((sx, sy + 1 + d), colour + (255,))
            if k == 2:
                c.putpixel((sx, sy + 1), shine + (255,))
            frames.append((c, ms))
        for fall in range(1, 6):
            c = canvas(0, 7)
            y = sy + 2 + fall
            if y + 1 < c.height:
                c.putpixel((sx, y), shine + (255,))
                c.putpixel((sx, y + 1), colour + (255,))
            frames.append((c, 70))
        return frames
    if kind == "glint":
        # a light runs down the body along its diagonal
        line = sorted(fill, key=lambda p: (p[0] + p[1], p[1]))
        frames = [(canvas(), rest)]
        steps = sorted({p[0] + p[1] for p in line})
        for s in steps[::max(1, len(steps) // 6)]:
            c = canvas()
            for x, y in line:
                if x + y in (s, s + 1):
                    c.putpixel((x, y), colour + (255,))
            frames.append((c, 60))
        return frames
    if kind == "blink":
        # eyes open in the body, look, and close
        mid = (y0 + y1) // 2
        row = sorted(p for p in fill if p[1] == mid) or sorted(fill)
        eyes = [row[0], row[min(len(row) - 1, 2)]] if row else []
        frames = [(canvas(), rest)]
        for ms, on in ((90, "half"), (900, "open"), (90, "half")):
            c = canvas()
            for x, y in eyes:
                c.putpixel((x, y), colour + (255 if on == "open" else 140,))
            frames.append((c, ms))
        return frames
    if kind == "boil":
        # a bubble rises through the body and bursts
        col = sorted({p[0] for p in fill})
        cx = col[len(col) // 2] if col else x0
        path = sorted((p for p in fill if p[0] == cx), key=lambda p: -p[1])
        frames = [(canvas(), rest)]
        for x, y in path[::max(1, len(path) // 5)]:
            c = canvas()
            c.putpixel((x, y), colour + (255,))
            frames.append((c, 110))
        return frames
    if kind == "fog":
        # it thins into the fog for a moment: the fill goes half see-through, in a checker
        frames = [(canvas(), rest)]
        for k in (1, 2, 1):
            c = canvas()
            for x, y in fill:
                if (x + y) % 2 == 0 or k == 2:
                    r, g, b, a = c.getpixel((x, y))
                    c.putpixel((x, y), (r, g, b, 96 if k == 2 else 150))
            frames.append((c, 260))
        return frames
    if kind == "wisp":
        # a wisp of wind tugs at the pointer's tail, three sways
        tx, ty = x1, y1 - 1
        offs = [(0, 0), (1, -1), (2, -1), (1, 0), (2, 1), (1, 1)]
        frames = [(canvas(3, 2), rest)]
        for k in range(6):
            c = canvas(3, 2)
            for d in range(3):
                ox, oy = offs[(k + d) % len(offs)]
                x, y = tx + 1 + d, ty + oy
                if 0 <= x < c.width and 0 <= y < c.height and not c.getpixel((x, y))[3]:
                    c.putpixel((x, y), colour + (220 - d * 60,))
            frames.append((c, 120))
        return frames
    if kind == "embers":
        return [(canvas(4, 2), rest)] + [(f, 130) for f in embers(img)]
    return [(img, 0)]


# ---------- previews ----------
def preview(theme):
    from PIL import Image
    root = theme_dir(theme)
    if not root:
        raise Fail("theme not installed: " + theme)
    names = [("left_ptr", "default"), ("hand2", "pointer"), ("xterm", "text"), ("watch", "wait"), ("grabbing", "closedhand"), ("not-allowed", "crossed_circle")]
    tiles = []
    for pair in names:
        f = next((root / "cursors" / n for n in pair if (root / "cursors" / n).exists()), None)
        if not f:
            continue
        try:
            w, h, rgba = xcursor_first_image(f.resolve())
        except (Fail, OSError, struct.error):
            continue
        tiles.append(Image.frombytes("RGBA", (w, h), rgba))
    if not tiles:
        raise Fail("no previewable cursors")
    cell = 40
    strip = Image.new("RGBA", (cell * len(tiles), cell), (0, 0, 0, 0))
    for i, t in enumerate(tiles):
        t.thumbnail((cell, cell), Image.NEAREST)
        strip.alpha_composite(t, (i * cell + (cell - t.width) // 2, (cell - t.height) // 2))
    CACHE.mkdir(parents=True, exist_ok=True)
    out = CACHE / f"{theme}.png"
    strip.save(out)
    return str(out)


# ---------- where themes live ----------
def theme_dirs():
    found = {}
    for base in (Path("/usr/share/icons"), LEGACY_ICONS, ICONS):
        if base.is_dir():
            for d in base.iterdir():
                if d.name != "default" and (d / "cursors").is_dir():
                    found[d.name] = d
    return found


def theme_dir(theme):
    return theme_dirs().get(theme)


# ---------- apply everywhere ----------
def set_ini(path, pairs):
    text = path.read_text() if path.exists() else ""
    if "[Settings]" not in text:
        text = "[Settings]\n" + text
    for key, value in pairs.items():
        line = f"{key}={value}"
        if re.search(rf"(?m)^{re.escape(key)}\s*=", text):
            text = re.sub(rf"(?m)^{re.escape(key)}\s*=.*$", line, text)
        else:
            text = text.replace("[Settings]\n", f"[Settings]\n{line}\n", 1)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def niri_cursor(theme, size):
    """Rewrite niri's `cursor { }` block (validated, backed up, rolled back on failure)."""
    files = [p for p in [NIRI / "config.kdl"] + sorted((NIRI / "cfg").glob("*.kdl")) if p.is_file()]
    block = re.compile(r"(?ms)^([ \t]*)cursor\s*\{(.*?)^\1\}")
    target = next((p for p in files if block.search(p.read_text())), NIRI / "cfg/misc.kdl")
    old = target.read_text() if target.exists() else ""
    m = block.search(old)
    body = m.group(2) if m else ""
    indent = m.group(1) if m else "    "
    body = re.sub(r'(?m)^\s*xcursor-theme\s+"[^"]*"\s*\n?', "", body)
    body = re.sub(r"(?m)^\s*xcursor-size\s+\d+\s*\n?", "", body)
    inner = f'{indent}    xcursor-theme "{theme}"\n{indent}    xcursor-size {size}\n' + body.lstrip("\n")
    new_block = f"{indent}cursor {{\n{inner.rstrip()}\n{indent}}}"
    new = old[:m.start()] + new_block + old[m.end():] if m else old.rstrip() + f"\n\ncursor {{\n{inner.rstrip()}\n}}\n"
    if new == old:
        return
    with tempfile.TemporaryDirectory(prefix="angelos-cursor-niri-") as tmp:
        staged = Path(tmp) / "niri"
        shutil.copytree(NIRI, staged, symlinks=True)
        (staged / target.relative_to(NIRI)).write_text(new)
        r = subprocess.run(["niri", "validate", "-c", str(staged / "config.kdl")], capture_output=True, text=True)
        if r.returncode:
            raise Fail("niri validate: " + (r.stderr or r.stdout).strip()[-300:])
    BACKUPS.mkdir(parents=True, exist_ok=True)
    backup = Path(tempfile.mkdtemp(prefix="cursor-", dir=BACKUPS))
    if target.exists():
        shutil.copy2(target, backup / target.name)
    fd, name = tempfile.mkstemp(prefix=".cursor-", dir=target.parent)
    with os.fdopen(fd, "w") as f:
        f.write(new)
    os.replace(name, target)


def run(argv):
    try:
        return subprocess.run(argv, capture_output=True, text=True, timeout=20).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def apply(theme, size, flatpak=True):
    if not NAME_RE.fullmatch(theme):
        raise Fail("bad theme name")
    if not theme_dir(theme):
        raise Fail("theme not installed: " + theme)
    size = max(16, min(96, int(size)))
    done = []
    legacy_link(theme)
    niri_cursor(theme, size)
    done.append("niri")
    for d in (LEGACY_ICONS / "default", ICONS / "default"):
        d.mkdir(parents=True, exist_ok=True)
        (d / "index.theme").write_text(f"[Icon Theme]\nName=Default\nComment=Default cursor (angelOS)\nInherits={theme}\n")
    done.append("x11")
    for g in ("gtk-3.0", "gtk-4.0"):
        set_ini(HOME / f".config/{g}/settings.ini", {"gtk-cursor-theme-name": theme, "gtk-cursor-theme-size": size})
    done.append("gtk")
    if shutil.which("gsettings"):
        run(["gsettings", "set", "org.gnome.desktop.interface", "cursor-theme", theme])
        run(["gsettings", "set", "org.gnome.desktop.interface", "cursor-size", str(size)])
        done.append("gsettings")
    xs = HOME / ".config/xsettingsd/xsettingsd.conf"
    if xs.exists():
        text = xs.read_text()
        for key, value in (("Gtk/CursorThemeName", f'"{theme}"'), ("Gtk/CursorThemeSize", str(size))):
            if re.search(rf"(?m)^{re.escape(key)}\s", text):
                text = re.sub(rf"(?m)^{re.escape(key)}\s.*$", f"{key} {value}", text)
            else:
                text = text.rstrip("\n") + f"\n{key} {value}\n"
        xs.write_text(text)
        run(["pkill", "-HUP", "-x", "xsettingsd"])
        done.append("xsettingsd")
    env = dict(os.environ, XCURSOR_THEME=theme, XCURSOR_SIZE=str(size))
    if shutil.which("systemctl"):
        run(["systemctl", "--user", "set-environment", f"XCURSOR_THEME={theme}", f"XCURSOR_SIZE={size}"])
        done.append("systemd")
    if shutil.which("dbus-update-activation-environment"):
        subprocess.run(["dbus-update-activation-environment", "XCURSOR_THEME", "XCURSOR_SIZE"], env=env,
                       capture_output=True, timeout=20)
        done.append("dbus")
    # the shell's own service reads the login's environment back from session.env (bin/angelos,
    # scripts/session-env.py): without this a restart would bring the old cursor back to Qt
    senv = Path(os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}") / "angelos/session.env"
    if senv.is_file():
        text = senv.read_text()
        for key, value in (("XCURSOR_THEME", theme), ("XCURSOR_SIZE", str(size))):
            line = f'{key}="{value}"'
            text = re.sub(rf"(?m)^{key}=.*$", line, text) if re.search(rf"(?m)^{key}=", text) else text.rstrip("\n") + "\n" + line + "\n"
        senv.write_text(text)
        done.append("session.env")
    if flatpak and shutil.which("flatpak"):
        # read-only access to ~/.local/share/icons only (where angelOS puts the themes)
        ok = run(["flatpak", "override", "--user", "--filesystem=xdg-data/icons:ro", "--nofilesystem=~/.icons",
                  f"--env=XCURSOR_THEME={theme}", f"--env=XCURSOR_SIZE={size}",
                  f"--env=XCURSOR_PATH={ICONS}:/run/host/user-share/icons:/run/host/share/icons:/usr/share/icons"])
        if ok:
            done.append("flatpak")
    return done


def status():
    out = {}
    for p in [NIRI / "config.kdl"] + sorted((NIRI / "cfg").glob("*.kdl")):
        m = re.search(r'xcursor-theme\s+"([^"]*)"', p.read_text()) if p.is_file() else None
        if m:
            s = re.search(r"xcursor-size\s+(\d+)", p.read_text())
            out["niri"] = [m.group(1), int(s.group(1)) if s else None]
    for g in ("gtk-3.0", "gtk-4.0"):
        p = HOME / f".config/{g}/settings.ini"
        if p.exists():
            m = re.search(r"(?m)^gtk-cursor-theme-name\s*=\s*(.*)$", p.read_text())
            out[g] = m.group(1).strip() if m else None
    idx = LEGACY_ICONS / "default/index.theme"
    if idx.exists():
        m = re.search(r"(?m)^Inherits\s*=\s*(.*)$", idx.read_text())
        out["x11"] = m.group(1).strip() if m else None
    if shutil.which("gsettings"):
        r = subprocess.run(["gsettings", "get", "org.gnome.desktop.interface", "cursor-theme"], capture_output=True, text=True)
        out["gsettings"] = r.stdout.strip().strip("'") or None
    return out


def listing():
    dirs = theme_dirs()
    items = []
    for e in catalog():
        item = {k: e[k] for k in ("id", "theme", "name", "about", "license")}
        item["realm"] = e.get("realm", "heaven")
        item["circle"] = e.get("circle", "")
        item["hidden"] = bool(e.get("hidden"))
        item["installed"] = e["theme"] in dirs
        prev = CACHE / f"{e['theme']}.png"
        item["preview"] = str(prev) if prev.exists() else ""
        items.append(item)
    known = {e["theme"] for e in catalog()}
    other = sorted(n for n in dirs if n not in known)
    return {"catalog": items, "other": other, "status": status()}


def main():
    args = sys.argv[1:]
    try:
        cmd = args[0] if args else "list"
        if cmd == "list":
            print(json.dumps(listing()))
        elif cmd == "install":
            entry = next((e for e in catalog() if e["id"] == args[1]), None)
            if not entry:
                raise Fail("unknown theme id")
            opts = {k: args[args.index("--" + k) + 1] for k in ("accent", "edge", "light") if "--" + k in args}
            if any(not HEX_RE.fullmatch(v) for v in opts.values()):
                raise Fail("colours must be #rrggbb")
            if entry.get("build") == "pixel":
                build_pixel(entry, **opts)
            else:
                install_archive(entry)
            try:
                preview(entry["theme"])
            except Exception:
                pass
            print(json.dumps({"ok": True, "theme": entry["theme"]}))
        elif cmd == "apply":
            done = apply(args[1], args[2], "--no-flatpak" not in args)
            print(json.dumps({"ok": True, "done": done}))
        elif cmd == "preview":
            if not NAME_RE.fullmatch(args[1]):
                raise Fail("bad theme name")
            print(json.dumps({"ok": True, "preview": preview(args[1])}))
        else:
            raise Fail("unknown command")
    except (Fail, OSError, ValueError, IndexError, KeyError, tarfile.TarError, urllib.error.URLError) as error:
        print(json.dumps({"error": str(error)}))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
