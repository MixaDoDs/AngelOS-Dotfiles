#!/usr/bin/env python3
"""The apps' own icons for the setup wizard, in angelOS's pixels: data/app-icons/<id>.png.

  app-icons.py [ID…]        (re)make them (all the catalog's apps by default); needs the network

The source is the app's real icon — Flathub's (its appstream), else the one an installed app
brings (its .desktop's Icon= in hicolor), else Simple Icons (CC0) for the tools without one of
their own (Go, Zig, .NET…). It is cut to its shape, boxed down to 16×16, held to a few colours
with a hard edge, and gets the 1-pixel ink outline PxIcon's icons have: 18×18 in the end.
The logos stay their owners' trademarks (THIRD-PARTY.md); this is a maintainer tool, the PNGs
are what ships.
"""
import io
import json
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "data/apps-catalog.json"
OUT = ROOT / "data/app-icons"
GRID = 16
INK = (42, 24, 48, 255)   # PxIcon's outline
# no Flathub id and nothing installed here to take the icon from: Simple Icons' slug and colour
SIMPLE = {"go": ("go", "00ADD8"), "zig": ("zig", "F7A41D"), "dotnet": ("dotnet", "512BD4"),
          "java": ("openjdk", "E76F00"), "docker": ("docker", "2496ED"), "qemu": ("qemu", "FF6600"),
          "basedevel": ("archlinux", "1793D1"), "codex": ("openai", "10A37F"), "claude": ("claude", "D97757"),
          "protonge": ("steam", "C7D5E0"), "lrctty": ("gnometerminal", "E8E4F0"), "reaper": ("reaper", "5A5A5A"),
          "throne": ("v2ray", "1C8BE0"), "shelly": ("archlinux", "1793D1"), "helium": ("googlechrome", "7A5AF8"),
          "freshgram": ("telegram", "26A5E4"), "qview": ("googlephotos", "4285F4")}
# installed here: the .desktop whose Icon= to use when Flathub has none
DESKTOP = {"helium": "helium.desktop", "freshgram": "io.github.snowyfluffy.freshgram.desktop",
           "qview": "com.interversehq.qView.desktop", "claude": "claude-desktop.desktop",
           "reaper": "cockos-reaper.desktop", "throne": "throne.desktop"}


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "angelOS app-icons"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read()


def raster(data, name=""):
    """an image from PNG or SVG bytes (SVG through rsvg-convert, big enough to box down)"""
    if data.lstrip()[:5] in (b"<?xml", b"<svg ") or name.endswith(".svg"):
        data = subprocess.run(["rsvg-convert", "-w", "256", "-h", "256", "--keep-aspect-ratio"],
                              input=data, capture_output=True, check=True).stdout
    return Image.open(io.BytesIO(data)).convert("RGBA")


def from_flathub(app_id):
    meta = json.loads(fetch(f"https://flathub.org/api/v2/appstream/{app_id}"))
    icons = sorted((i for i in meta.get("icons", []) if i.get("url")), key=lambda i: -int(i.get("width") or 0))
    url = icons[0]["url"] if icons else meta.get("icon")
    return raster(fetch(url), url) if url else None


def from_desktop(did):
    for base in (Path.home() / ".local/share/applications", Path("/usr/share/applications"),
                 Path("/var/lib/flatpak/exports/share/applications")):
        f = base / did
        if f.is_file():
            icon = next((ln.split("=", 1)[1].strip() for ln in f.read_text(errors="ignore").splitlines()
                         if ln.startswith("Icon=")), "")
            break
    else:
        return None
    if icon.startswith("/"):
        return raster(Path(icon).read_bytes(), icon)
    for d in ("scalable", "512x512", "256x256", "128x128", "64x64", "48x48"):
        for ext in ("svg", "png"):
            p = Path(f"/usr/share/icons/hicolor/{d}/apps/{icon}.{ext}")
            if p.is_file():
                return raster(p.read_bytes(), p.name)
    p = Path(f"/usr/share/pixmaps/{icon}.png")
    return raster(p.read_bytes(), p.name) if p.is_file() else None


def from_simple(slug, colour):
    return raster(fetch(f"https://cdn.simpleicons.org/{slug}/{colour}"), "x.svg")


def pixelate(img, colours=10):
    box = img.getbbox()
    if box:
        img = img.crop(box)
    side = max(img.size)
    sq = Image.new("RGBA", (side, side))
    sq.paste(img, ((side - img.width) // 2, (side - img.height) // 2))
    small = sq.resize((GRID, GRID), Image.Resampling.BOX, reducing_gap=None)
    # a hard edge: a pixel is there or it isn't
    alpha = small.getchannel("A").point(lambda a: 255 if a >= 110 else 0)
    rgb = Image.new("RGB", small.size, (0, 0, 0))
    rgb.paste(small.convert("RGB"), mask=alpha)
    q = rgb.quantize(colors=colours, method=Image.Quantize.MEDIANCUT).convert("RGB")
    out = Image.new("RGBA", (GRID + 2, GRID + 2))
    px, a = q.load(), alpha.load()
    o = out.load()
    for y in range(GRID):
        for x in range(GRID):
            if a[x, y]:
                o[x + 1, y + 1] = px[x, y] + (255,)
    # the ink outline around the shape (4-neighbours), as PxIcon draws its icons
    for y in range(GRID + 2):
        for x in range(GRID + 2):
            if o[x, y][3]:
                continue
            if any(0 <= x + dx < GRID + 2 and 0 <= y + dy < GRID + 2 and o[x + dx, y + dy][3] == 255
                   and o[x + dx, y + dy] != INK for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                o[x, y] = INK
    return out


def main(ids):
    if not shutil.which("rsvg-convert"):
        sys.exit("rsvg-convert (librsvg) is needed")
    apps = json.loads(CATALOG.read_text())["apps"]
    OUT.mkdir(parents=True, exist_ok=True)
    for a in apps:
        if ids and a["id"] not in ids:
            continue
        img, how = None, ""
        try:
            if a.get("flatpak"):
                img, how = from_flathub(a["flatpak"]), "flathub"
        except Exception as e:  # noqa: BLE001
            print(f"  {a['id']}: flathub: {e}")
        if img is None and a["id"] in DESKTOP:
            img, how = from_desktop(DESKTOP[a["id"]]), "installed"
        if img is None and a["id"] in SIMPLE:
            try:
                img, how = from_simple(*SIMPLE[a["id"]]), "simple-icons"
            except Exception as e:  # noqa: BLE001
                print(f"  {a['id']}: simple-icons: {e}")
        if img is None:
            print(f"✕ {a['id']}: no source (its kind's pixel icon stays)")
            continue
        pixelate(img).save(OUT / f"{a['id']}.png", optimize=True)
        print(f"✓ {a['id']} ({how})")


if __name__ == "__main__":
    main(sys.argv[1:])
