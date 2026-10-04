#!/usr/bin/env python3
"""Pixel fonts for angelOS, and the Golden Gate skin's smooth ones: list, install, remove.

  fonts.py list             -> JSON catalog with installed state
  fonts.py install <id>     -> download, verify SHA-256, install into
                               ~/.local/share/fonts/angelos/<id>/, fc-cache
  fonts.py remove <id>      -> delete a font installed by this script

Downloads come only from the pinned HTTPS URLs below and must match their
SHA-256; from archives only the named members are extracted. Nothing is
executed from a download. Python standard library only.
"""
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile

FONT_DIR = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "fonts/angelos"
MAX_DOWNLOAD = 8 * 1024 * 1024
GF = "https://raw.githubusercontent.com/google/fonts/main/ofl/"

# native: pixel size of one glyph cell; UI sizes snap to its multiples so glyphs stay crisp.
CATALOG = [
    {"id": "pixeloid", "families": ["Pixeloid Sans", "Pixeloid Mono"], "native": 9, "cyrillic": True,
     "roles": ["title", "body", "mono"], "license": "OFL", "note": "angelOS default titles",
     "homepage": "https://ggbot.itch.io/pixeloid-font", "assets": []},
    {"id": "cozette", "families": ["CozetteVector"], "native": 13, "cyrillic": True,
     "roles": ["body", "mono"], "license": "MIT", "note": "angelOS default text",
     "homepage": "https://github.com/the-moonwitch/Cozette",
     "assets": [
         {"url": "https://github.com/the-moonwitch/Cozette/releases/download/v.1.30.0/CozetteVector.ttf",
          "sha256": "2d54a586f824f32d9d2dd01ec3b990c2a4d6445efa77e20177efe382ebe51627"},
         {"url": "https://github.com/the-moonwitch/Cozette/releases/download/v.1.30.0/CozetteVectorBold.ttf",
          "sha256": "9f113791362001d53cd4c09cbe91f9125c050ca7aab49d48393601e79b2b1d41"}]},
    {"id": "pixelify", "families": ["Pixelify Sans"], "native": 11, "cyrillic": True,
     "roles": ["title", "body"], "license": "OFL", "note": "soft rounded pixels",
     "homepage": "https://fonts.google.com/specimen/Pixelify+Sans",
     "assets": [{"url": GF + "pixelifysans/PixelifySans%5Bwght%5D.ttf", "name": "PixelifySans.ttf",
                 "sha256": "9ba86cd010a4de309d263ceff8e8044092c9db7efda869620cb9ff1c4389e8a5"}]},
    {"id": "tiny5", "families": ["Tiny5"], "native": 8, "cyrillic": True,
     "roles": ["body", "title"], "license": "OFL", "note": "tiny and very crisp",
     "homepage": "https://fonts.google.com/specimen/Tiny5",
     "assets": [{"url": GF + "tiny5/Tiny5-Regular.ttf",
                 "sha256": "cb8168f80cfee2f47f6db59f2a7afbde31cdcdcdcf262e7a993e4d468a5bf4b0"}]},
    {"id": "pressstart", "families": ["Press Start 2P"], "native": 8, "cyrillic": True,
     "roles": ["title"], "license": "OFL", "note": "arcade headings",
     "homepage": "https://fonts.google.com/specimen/Press+Start+2P",
     "assets": [{"url": GF + "pressstart2p/PressStart2P-Regular.ttf",
                 "sha256": "034c77f1f05ec89421e4a63f0e3a4ca1ecf852cc6d2bf611f126f275728e017d"}]},
    {"id": "monocraft", "families": ["Monocraft"], "native": 9, "cyrillic": True,
     "roles": ["mono", "body"], "license": "OFL", "note": "Minecraft-like monospace",
     "homepage": "https://github.com/IdreesInc/Monocraft",
     "assets": [{"url": "https://github.com/IdreesInc/Monocraft/releases/download/v4.2.1/Monocraft-ttf.zip",
                 "sha256": "897faffbef8cc27fadd0d5aa51872ab5f908e22a89bb8fa5b191366025d503e0",
                 "members": {"Monocraft-ttf/Monocraft.ttf": "c3906e842d1b7e99947abcc5ae3c8b409abf8cefd1006cbba1890f1096e132f2",
                             "Monocraft-ttf/weights/Monocraft-Bold.ttf": "423961fc22c64ec000990ef1059281ee818ceaf544e6348bf37a06181a690f17"}}]},
    {"id": "departure", "families": ["Departure Mono"], "native": 11, "cyrillic": True,
     "roles": ["mono", "body"], "license": "OFL", "note": "retro-futuristic monospace",
     "homepage": "https://departuremono.com",
     "assets": [{"url": "https://github.com/rektdeckard/departure-mono/releases/download/v1.500/DepartureMono-1.500.zip",
                 "sha256": "bf3e48059aeef4617ec585bdea81dcc3491c576b3e7a472f52faf40e09ee5c3a",
                 "members": {"DepartureMono-1.500/DepartureMono-Regular.otf": "4d53f663155cf8bf7ffc8e688776e719625f7bbb80a8d90073438b249261a2e0"}}]},
    {"id": "silkscreen", "families": ["Silkscreen"], "native": 8, "cyrillic": False,
     "roles": ["title"], "license": "OFL", "note": "Latin only",
     "homepage": "https://fonts.google.com/specimen/Silkscreen",
     "assets": [{"url": GF + "silkscreen/Silkscreen-Regular.ttf",
                 "sha256": "c845473330b94c2079ce9af01c51ac8ba2d99c24f4d14c039843bbb8e642ebd8"},
                {"url": GF + "silkscreen/Silkscreen-Bold.ttf",
                 "sha256": "768476aa712d4f5c3e18d3bce80f980a8bd3f72b7094d22ec5e768df3acfed61"}]},
    # the Golden Gate skin's fonts (smooth, native 0): Inter — open, drawn close to SF Pro — and
    # JetBrains Mono for code; pinned to a google/fonts commit
    {"id": "inter", "families": ["Inter"], "native": 0, "cyrillic": True,
     "roles": ["body", "title"], "license": "OFL", "note": "the Golden Gate skin's font, close to SF Pro",
     "homepage": "https://rsms.me/inter/",
     "assets": [{"url": "https://raw.githubusercontent.com/google/fonts/0b58fb370093f9a9f4ff785d94405710b79de67c/ofl/inter/Inter%5Bopsz%2Cwght%5D.ttf",
                 "name": "Inter.ttf",
                 "sha256": "29160a80ff49ddcab2c97711247e08b1fab27a484a329ce8b813d820dc559031"}]},
    {"id": "jetbrains-mono", "families": ["JetBrains Mono"], "native": 0, "cyrillic": True,
     "roles": ["mono"], "license": "OFL", "note": "the Golden Gate skin's monospace",
     "homepage": "https://www.jetbrains.com/lp/mono/",
     "assets": [{"url": "https://raw.githubusercontent.com/google/fonts/6e4b84c976cadb3c49a40fd9a1c203e4f7fcf2da/ofl/jetbrainsmono/JetBrainsMono%5Bwght%5D.ttf",
                 "name": "JetBrainsMono.ttf",
                 "sha256": "48715a42ec242c21e9f02692891e147d022299a52e48d5e413e1a942193ffeda"}]},
    {"id": "vt323", "families": ["VT323"], "native": 0, "cyrillic": False,
     "roles": ["mono", "body"], "license": "OFL", "note": "Latin only, terminal look",
     "homepage": "https://fonts.google.com/specimen/VT323",
     "assets": [{"url": GF + "vt323/VT323-Regular.ttf",
                 "sha256": "cf4de751ada78ceac033dbe16a687742939995b77bc2a052ae17a4957958594d"}]},
]


def system_families():
    try:
        out = subprocess.run(["fc-list", "--format", "%{family}\n"], capture_output=True,
                             text=True, timeout=15).stdout
    except (OSError, subprocess.TimeoutExpired):
        return set()
    return {name.strip() for line in out.splitlines() for name in line.split(",")}


def own_files(font_id):
    folder = FONT_DIR / font_id
    if not folder.is_dir() or folder.is_symlink():
        return []
    return sorted(str(p) for p in folder.iterdir()
                  if p.suffix.lower() in (".ttf", ".otf") and p.is_file() and not p.is_symlink())


def listing():
    have = system_families()
    rows = []
    for font in CATALOG:
        files = own_files(font["id"])
        rows.append({key: font[key] for key in ("id", "families", "native", "cyrillic", "roles",
                                                  "license", "note", "homepage")}
                    | {"installed": bool(files) or all(f in have for f in font["families"]),
                       "files": files, "installable": bool(font["assets"]),
                       "removable": bool(files)})
    return {"dir": str(FONT_DIR), "fonts": rows}


def fetch(url):
    if not url.startswith("https://"):
        raise ValueError("Only HTTPS downloads are allowed")
    request = urllib.request.Request(url, headers={"User-Agent": "angelOS-fonts/1"})
    with urllib.request.urlopen(request, timeout=60) as response:
        data = response.read(MAX_DOWNLOAD + 1)
    if len(data) > MAX_DOWNLOAD:
        raise ValueError("Download is too large")
    return data


def checked(data, expected, what):
    digest = hashlib.sha256(data).hexdigest()
    if digest != expected:
        raise ValueError(f"Checksum mismatch for {what}")
    return data


def install(font_id):
    font = next((f for f in CATALOG if f["id"] == font_id), None)
    if not font or not font["assets"]:
        raise ValueError("Unknown or non-downloadable font")
    FONT_DIR.mkdir(parents=True, exist_ok=True)
    target = FONT_DIR / font_id
    staging = Path(tempfile.mkdtemp(prefix=".install-", dir=FONT_DIR))
    try:
        for asset in font["assets"]:
            data = checked(fetch(asset["url"]), asset["sha256"], asset["url"])
            if "members" in asset:
                with zipfile.ZipFile(io.BytesIO(data)) as archive:
                    for member, digest in asset["members"].items():
                        payload = checked(archive.read(member), digest, member)
                        (staging / Path(member).name).write_bytes(payload)
            else:
                name = asset.get("name") or Path(asset["url"]).name
                (staging / Path(name).name).write_bytes(data)
        for path in staging.iterdir():
            path.chmod(0o644)
        staging.chmod(0o755)
        if target.exists() or target.is_symlink():
            shutil.rmtree(target) if target.is_dir() and not target.is_symlink() else target.unlink()
        staging.rename(target)
    finally:
        if staging.exists():
            shutil.rmtree(staging)
    subprocess.run(["fc-cache", "-f", str(target)], capture_output=True, timeout=60)
    return {"installed": font_id, "files": own_files(font_id)}


def remove(font_id):
    if not any(f["id"] == font_id for f in CATALOG):
        raise ValueError("Unknown font")
    target = FONT_DIR / font_id
    if target.is_dir() and not target.is_symlink():
        shutil.rmtree(target)
        subprocess.run(["fc-cache", "-f", str(FONT_DIR)], capture_output=True, timeout=60)
    return {"removed": font_id}


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "list"
    try:
        if action == "list":
            result = listing()
        elif action in ("install", "remove") and len(sys.argv) == 3:
            result = (install if action == "install" else remove)(sys.argv[2])
        else:
            raise ValueError("usage: fonts.py list | install <id> | remove <id>")
    except (OSError, ValueError, KeyError, zipfile.BadZipFile, subprocess.TimeoutExpired) as error:
        result = {"error": str(error)}
    print(json.dumps(result, ensure_ascii=False))
    return 1 if "error" in result else 0


if __name__ == "__main__":
    sys.exit(main())
