#!/usr/bin/env python3
"""Pixora's folders in angelOS's colours (Settings → Appearance → Folders; the wizard's look).

  folder-tint.py PALETTE.json     the render hook (templates.json "folders"): palette keys
                                  folderTint ("pixora" = as drawn | anything else = tinted),
                                  folderFill, folderShade (#rrggbb), skin
  folder-tint.py status           JSON {"base", "theme", "tint"}

Pixora (CC BY 4.0, tsora1603) draws its folders in three colours: #E3C896 body, #AB947A shade,
#3E3546 ink. A tinted copy of its folder icons goes into ~/.local/share/icons/angelos-folders-a
(or -b: the name swaps on every change, so GTK apps reload the theme live), inheriting the Pixora
in use, and becomes the icon theme (gtk-3.0/gtk-4.0 settings.ini, gsettings). "pixora" puts the
Pixora theme back. Another icon theme than Pixora (Golden Gate's, the user's own) is left alone.
"""
import configparser
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
ICONS = Path(os.environ.get("XDG_DATA_HOME") or HOME / ".local/share") / "icons"
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config")
INIS = [CONFIG / "gtk-3.0/settings.ini", CONFIG / "gtk-4.0/settings.ini"]
OURS = ("angelos-folders-a", "angelos-folders-b")
BASES = ("pixora", "pixora-dark")
BODY, SHADE = "E3C896", "AB947A"
SHADES = ("A48875", "A48675", "9E7C71")   # the few in-between pixels of some folders
CONTEXTS = ("places",)


def theme_dirs(name):
    return [d / name for d in (ICONS, HOME / ".icons", Path("/usr/share/icons")) if (d / name / "index.theme").is_file()]


def current():
    for ini in INIS:
        cp = configparser.ConfigParser(interpolation=None)
        try:
            cp.read(ini)
            v = cp.get("Settings", "gtk-icon-theme-name", fallback="")
        except configparser.Error:
            v = ""
        if v:
            return v
    return ""


def base_of(name):
    """the Pixora a theme of ours stands on (its first Inherits), else the name itself"""
    if name in OURS:
        for d in theme_dirs(name):
            m = re.search(r"^Inherits=([^,\n]+)", (d / "index.theme").read_text(), re.M)
            if m:
                return m.group(1).strip()
        return "pixora-dark"
    return name


def set_theme(name):
    for ini in INIS:
        if not ini.exists():
            continue
        text = ini.read_text()
        new = re.sub(r"^gtk-icon-theme-name=.*$", f"gtk-icon-theme-name={name}", text, flags=re.M)
        if new == text and "gtk-icon-theme-name=" not in text:
            new = text.replace("[Settings]", f"[Settings]\ngtk-icon-theme-name={name}", 1)
        if new != text:
            ini.write_text(new)
    # the tests run in a home of their own, and gsettings would reach the real session
    if shutil.which("gsettings") and os.environ.get("ANGELOS_TEST") != "1":
        subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", name],
                       stderr=subprocess.DEVNULL, check=False)


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def tint_svg(text, fill, shade):
    text = re.sub("#" + BODY, "#" + fill, text, flags=re.I)
    for c in (SHADE,) + SHADES:
        text = re.sub("#" + c, "#" + shade, text, flags=re.I)
    return text


def tint_png(src, dst, fill, shade):
    from PIL import Image
    im = Image.open(src).convert("RGBA")
    swap = {hexrgb(BODY): hexrgb(fill)} | {hexrgb(c): hexrgb(shade) for c in (SHADE,) + SHADES}
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if (r, g, b) in swap and a:
                px[x, y] = swap[(r, g, b)] + (a,)
    im.save(dst)


def build(name, base, fill, shade):
    src = theme_dirs(base)[0]
    out = ICONS / name
    shutil.rmtree(out, ignore_errors=True)
    index = (src / "index.theme").read_text()
    index = re.sub(r"^Name=.*$", "Name=angelOS folders", index, count=1, flags=re.M)
    index = re.sub(r"^Comment=.*$", f"Comment=Pixora's folders in angelOS's colours (from {base})", index, count=1, flags=re.M)
    index = re.sub(r"^Inherits=(.*)$", lambda m: f"Inherits={base},{m.group(1)}", index, count=1, flags=re.M)
    n = 0
    # pixora-dark's folders are links to pixora's: walk through them
    files = [Path(r) / f for r, _, fs in os.walk(src, followlinks=True) for f in fs]
    for f in files:
        rel = f.relative_to(src)
        if not f.is_file() or len(rel.parts) < 3 or rel.parts[1] not in CONTEXTS:
            continue
        stem = f.name.rsplit(".", 1)[0]
        if not (stem.startswith("folder") or stem in ("inode-directory", "stock_folder", "user-home", "user-desktop")):
            continue
        dst = out / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        if f.suffix == ".svg":
            dst.write_text(tint_svg(f.read_text(), fill, shade))
        elif f.suffix == ".png":
            tint_png(f, dst, fill, shade)
        n += 1
    out.mkdir(parents=True, exist_ok=True)
    (out / "index.theme").write_text(index)
    if shutil.which("gtk-update-icon-cache"):
        subprocess.run(["gtk-update-icon-cache", "-q", "-f", "-t", str(out)], stderr=subprocess.DEVNULL, check=False)
    return n


def apply(palette):
    if palette.get("skin") == "goldengate":
        return "Golden Gate's icons: folders left alone"
    cur = current()
    base = base_of(cur)
    if base not in BASES or not theme_dirs(base):
        return f"icon theme {cur or '?'} is not Pixora: folders left alone"
    tint = palette.get("folderTint") or "pixora"
    if tint == "pixora":
        if cur != base:
            set_theme(base)
        for name in OURS:
            shutil.rmtree(ICONS / name, ignore_errors=True)
        return f"folders as Pixora draws them ({base})"
    fill = (palette.get("folderFill") or "#" + BODY).lstrip("#")[:6]
    shade = (palette.get("folderShade") or "#" + SHADE).lstrip("#")[:6]
    stamp = ICONS / ".angelos-folders"
    want = f"{base} {fill} {shade}"
    if cur in OURS and stamp.is_file() and stamp.read_text() == want and theme_dirs(cur):
        return f"folders {fill} already ({cur})"
    name = OURS[1] if cur == OURS[0] else OURS[0]
    n = build(name, base, fill, shade)
    stamp.write_text(want)
    set_theme(name)
    other = OURS[0] if name == OURS[1] else OURS[1]
    shutil.rmtree(ICONS / other, ignore_errors=True)
    return f"folders {fill}/{shade}: {n} icons in {name} over {base}"


def main():
    if sys.argv[1:] == ["status"]:
        cur = current()
        print(json.dumps({"base": base_of(cur), "theme": cur, "tint": cur in OURS}))
        return
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    palette = json.loads(Path(sys.argv[1]).read_text())
    print(apply(palette))


if __name__ == "__main__":
    main()
