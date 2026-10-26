#!/usr/bin/env python3
"""GTK in angelOS's colours and window decorations — live, heaven and hell.

usage: gtk-live.py PALETTE.json      (run by render-templates.py, entry "gtk-live")

GTK reads the user's gtk.css once per app, but reloads its *theme* whenever the theme
name changes. So, with Config.decor.gtkButtons on (palette key decorGtk), the palette
and the window buttons live in a theme of their own: adw-gtk3(-dark) underneath, the
angelOS colours (~/.config/gtk-3.0/angelos.css, rendered just before) and the
decorations (templates/gtk3-decor.css: the buttons as angel-niri draws its title bars — the
glyphs × _ □ over a shadow, a plate under the pointer, red under ×, or keys
(templates/gtk-decor-keys.css after it, palette key decorKeys); the header in the menu
colour; obsidian and blood in hell) on top. Two copies, angelOS-a and angelOS-b, take
turns: the new look goes into the one not in use and gtk-theme switches to it, so open
GTK 3 apps — and Helium/Chromium set to the "GTK" theme, its title bar buttons
included — change at once. The user's own gtk-3.0/angelos.css becomes a stub then (it
would outrank the theme with stale colours). GTK 4 / libadwaita ignores themes: it gets
~/.config/gtk-4.0/angelos-decor.css (templates/gtk4-decor.css), read when an app starts.
Off: gtk-theme goes back to adw-gtk3(-dark), the stub and the GTK 4 file are emptied.
Also sets the title bar buttons (org.gnome.desktop.wm.preferences button-layout and
gtk-decoration-layout in gtk-3.0/gtk-4.0 settings.ini) to decorButtons, e.g. "maximize,close".
The Golden Gate skin (palette key skin "goldengate"): the decorations are macOS's traffic lights
(templates/gtk3-decor-mac.css, gtk4-decor-mac.css) on the leading side, close,minimize,maximize:
— all three lit, their glyphs assets/mac-{close,minimize,maximize}.svg; off again, the leading
side goes back.
Always (on or off): the pixel frames the palette CSS draws its buttons, fields and menus with
(templates/gtk3.css, gtk4.css → assets/frame-raised.svg, frame-sunken.svg next to each CSS):
the outline in the palette's edge colour with stepped corners, and the bevel.
"""
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
SHELL = Path(__file__).resolve().parent.parent
THEMES = HOME / ".local/share/themes"
GTK3 = HOME / ".config/gtk-3.0"
GTK4 = HOME / ".config/gtk-4.0"
STUB = "/* angelOS: the colours live in the angelOS-a/b GTK theme now (gtk-live.py) */\n"

# angel-niri's CELL_GLYPHS (src/stacking_title.rs): one look for both
ICONS = {
    "close": ["#.....#", ".#...#.", "..#.#..", "...#...", "..#.#..", ".#...#.", "#.....#"],
    "maximize": ["#######", "#.....#", "#.....#", "#.....#", "#.....#", "#.....#", "#######"],
    "minimize": [".......", ".......", ".......", ".......", ".......", ".......", "#######"],
}


def render(text, pal):
    return re.sub(r"\{\{\s*([\w.]+)\s*\}\}", lambda m: str(pal.get(m.group(1), m.group(0))), text)


def _rects(rows, color, dx, dy):
    body = ""
    for y, row in enumerate(rows):
        x = 0
        while x < len(row):
            run = 1
            while x + run < len(row) and row[x + run] == row[x]:
                run += 1
            if row[x] == "#":
                body += '<rect x="%d" y="%d" width="%d" height="1" fill="%s"/>' % (x + dx, y + dy, run, color)
            x += run
    return body


def frame(edge, sunken):
    """A 12×12 nine-slice (4 px slices) of the angelOS pixel box: a 2 px outline whose corners
    step in by one 2 px art pixel, a 2 px bevel inside it — white and black at low alpha, so it
    shades whatever colour the widget paints under it (hover, accent, danger)."""
    hi, lo = ("#000000", "0.35"), ("#ffffff", "0.16")
    if not sunken:
        hi, lo = ("#ffffff", "0.18"), ("#000000", "0.35")
    cells = []
    for y in range(12):
        for x in range(12):
            cx = x if x < 4 else (11 - x if x >= 8 else None)
            cy = y if y < 4 else (11 - y if y >= 8 else None)
            if cx is not None and cy is not None:      # a corner: only the step
                if 2 <= cx < 4 and 2 <= cy < 4:
                    cells.append((x, y, edge, "1"))
                continue
            if y < 2 or y >= 10 or x < 2 or x >= 10:   # the outline
                cells.append((x, y, edge, "1"))
            elif y < 4 or x < 4:                       # the bevel: top and left …
                cells.append((x, y) + hi)
            elif y >= 8 or x >= 8:                     # … bottom and right
                cells.append((x, y) + lo)
    body = "".join('<rect x="%d" y="%d" width="1" height="1" fill="%s" fill-opacity="%s"/>' % c for c in cells)
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" '
            'shape-rendering="crispEdges">%s</svg>\n') % body


def _rgb(c):
    c = c.lstrip("#")
    return [int(c[i:i + 2], 16) for i in (0, 2, 4)]


def _lum(c):
    v = [x / 255 for x in _rgb(c)]
    v = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in v]
    return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2]


def _mix(a, b, t):
    return "#%02x%02x%02x" % tuple(round(x + (y - x) * t) for x, y in zip(_rgb(a), _rgb(b)))


def glyph(rows, ink, bg):
    """A button glyph over its shadow one art pixel down-right, as angel-niri draws it: dark under
    a light glyph, light under a dark one."""
    shadow = _mix(bg, "#000000", 0.55) if _lum(ink) > _lum(bg) else _mix(bg, "#ffffff", 0.6)
    w, h = len(rows[0]) + 1, len(rows) + 1
    body = _rects(rows, shadow, 1, 1) + _rects(rows, ink, 0, 0)
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" '
            'shape-rendering="crispEdges">%s</svg>\n') % (w * 2, h * 2, w, h, body)


# the keys' glyphs (angel-niri's KEY_GLYPHS), six by six on the key's face
KEY_ICONS = {
    "close": ["#....#", ".#..#.", "..##..", "..##..", ".#..#.", "#....#"],
    "maximize": ["######", "#....#", "#....#", "#....#", "#....#", "######"],
    "minimize": ["......", "......", "......", "......", "......", "######"],
}


def key(rows, face, ink, edge):
    """A key as angel-niri draws it (--button-look keys): ten art pixels square, a dark outline,
    its face, the glyph on it."""
    body = '<rect width="10" height="10" fill="%s"/><rect x="1" y="1" width="8" height="8" fill="%s"/>' % (edge, face)
    body += _rects(rows, ink, 2, 2)
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 10 10" '
            'shape-rendering="crispEdges">%s</svg>\n') % body


def frame_line(pal):
    """The outline: the palette's edge where it stands out from the window, else (dark
    palettes: edge ≈ background) a dim line of the text colour — like the shell's own boxes
    read in the dark. The same rule in scripts/qt-theme.py."""
    bg, edge, fg = pal.get("bg", "#000000"), pal.get("edge", "#000000"), pal.get("fg", "#ffffff")
    a, b = sorted((_lum(bg), _lum(edge)))
    if (b + 0.05) / (a + 0.05) >= 1.6:
        return edge
    return "#%02x%02x%02x" % tuple(round(x + (y - x) * 0.26) for x, y in zip(_rgb(bg), _rgb(fg)))


def frames(folder, pal):
    line = frame_line(pal)
    write(folder / "assets" / "frame-raised.svg", frame(line, False))
    write(folder / "assets" / "frame-sunken.svg", frame(line, True))


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_text() == text:
        return False
    tmp = path.with_name(path.name + ".angelos-tmp")
    tmp.write_text(text)
    tmp.replace(path)
    return True


# the Golden Gate lights' glyphs (×, −, +), drawn over the light under the pointer: GTK's own
# icons would give a square for zoom, and an icon is what adw-gtk3/libadwaita highlight
MAC_GLYPHS = {
    "close": "M4.6 4.6 9.4 9.4M9.4 4.6 4.6 9.4",
    "minimize": "M3.9 7h6.2",
    "maximize": "M7 3.9v6.2M3.9 7h6.2",
}


def mac_glyph(path):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 14 14">'
            '<path d="%s" fill="none" stroke="#000000" stroke-opacity="0.6" stroke-width="1.5" '
            'stroke-linecap="round"/></svg>\n') % path


def assets(folder, pal):
    ink, bg = pal.get("decorText", "#000000"), pal.get("decorHeader", "#ffffff")
    danger = pal.get("decorDanger", "#e0403a")
    if pal.get("decorKeys"):
        edge = _mix(bg, "#000000", 0.6)
        for lit in (False, True):
            tail = "-hover" if lit else ""
            for name, rows in KEY_ICONS.items():
                face = danger if name == "close" else _mix(bg, ink, 0.22)
                face = _mix(face, "#ffffff", 0.25) if lit else face
                on = "#ffffff" if name == "close" else ("#000000" if _lum(face) > 0.18 else "#ffffff")
                write(folder / "assets" / (name + tail + ".svg"), key(rows, face, on, edge))
    else:
        for name, rows in ICONS.items():
            write(folder / "assets" / (name + ".svg"), glyph(rows, ink, bg))
        write(folder / "assets" / "close-hover.svg", glyph(ICONS["close"], "#ffffff", danger))
    for name, path in MAC_GLYPHS.items():
        write(folder / "assets" / ("mac-" + name + ".svg"), mac_glyph(path))


def gsettings(schema, key, value=None):
    if value is None:
        r = subprocess.run(["gsettings", "get", schema, key], capture_output=True, text=True)
        return r.stdout.strip().strip("'")
    subprocess.run(["gsettings", "set", schema, key, value], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return value


def interface_defaults():
    """The icons, font and cursor of ~/.config/gtk-3.0/settings.ini into gsettings, for the keys
    nobody has set yet. GTK 4 apps under Wayland (Nautilus…) read gsettings through the portal,
    not settings.ini: on a fresh install they showed Adwaita's blue folders and font while the
    author's — set by hand long ago — had pixora and Cozette."""
    import configparser
    import shutil
    if not shutil.which("dconf"):
        return
    ini = configparser.ConfigParser(interpolation=None)
    try:
        ini.read(GTK3 / "settings.ini")
        s = ini["Settings"]
    except (configparser.Error, KeyError):
        return
    dirs = (HOME / ".local/share/icons", HOME / ".icons", Path("/usr/share/icons"))
    has_theme = lambda name, sub: any((d / name / sub).exists() for d in dirs)
    want = [("icon-theme", s.get("gtk-icon-theme-name"), lambda v: has_theme(v, "index.theme")),
            ("cursor-theme", s.get("gtk-cursor-theme-name"), lambda v: has_theme(v, "cursors")),
            ("font-name", (s.get("gtk-font-name") or "").replace(",", ""), lambda v: True)]
    size = s.get("gtk-cursor-theme-size")
    for key, value, ok in want:
        if not value or not ok(value):
            continue
        r = subprocess.run(["dconf", "read", "/org/gnome/desktop/interface/" + key], capture_output=True, text=True)
        if r.returncode == 0 and not r.stdout.strip():
            gsettings("org.gnome.desktop.interface", key, value)
            if key == "cursor-theme" and size and size.isdigit():
                gsettings("org.gnome.desktop.interface", "cursor-size", size)



def version_gtk4():
    """GTK 4 / libadwaita reads its user CSS once per app, but the pictures the CSS points at
    only when a widget first needs them. With the same file names rewritten in place, a Nautilus
    started before a theme change drew the old colours with the new frames — here and there, as
    new kinds of widgets came up. So the GTK 4 pictures live in a folder named after their
    content (assets/v-<hash>/) and the CSS points there: an app keeps its whole old look until it
    starts again (services/NautilusSetup restarts Nautilus once none of its windows is open)."""
    src = GTK4 / "assets"
    files = sorted(f for f in src.glob("*.svg") if f.is_file())
    if not files:
        return
    h = hashlib.sha1(b"".join(f.name.encode() + f.read_bytes() for f in files)).hexdigest()[:10]
    dest = src / ("v-" + h)
    if not dest.is_dir():
        tmp = src / (".v-" + h + ".tmp")
        shutil.rmtree(tmp, ignore_errors=True)
        tmp.mkdir(parents=True)
        for f in files:
            shutil.copy2(f, tmp / f.name)
        os.replace(tmp, dest)
    os.utime(dest)
    rx = re.compile(r"""url\(\s*(["']?)assets/(?:v-[0-9a-f]+/)?([\w.-]+\.svg)\1\s*\)""")
    for css in (GTK4 / "angelos.css", GTK4 / "angelos-decor.css"):
        if css.exists():
            text = css.read_text()
            fixed = rx.sub(lambda m: 'url("assets/v-%s/%s")' % (h, m.group(2)), text)
            if fixed != text:
                write(css, fixed)
    # old looks: a few stay for apps still running in them
    olds = sorted((d for d in src.glob("v-*") if d.is_dir() and d != dest), key=lambda d: d.stat().st_mtime, reverse=True)
    for d in olds[6:]:
        shutil.rmtree(d, ignore_errors=True)

def main():
    pal = json.loads(Path(sys.argv[1]).read_text())
    interface_defaults()
    suffix = "-dark" if pal.get("mode") == "dark" else ""
    base = "adw-gtk3" + suffix
    base_dir = next((d / base for d in (HOME / ".local/share/themes", HOME / ".themes", Path("/usr/share/themes")) if (d / base / "gtk-3.0/gtk.css").exists()), None)
    current = gsettings("org.gnome.desktop.interface", "gtk-theme")
    mac = pal.get("skin") == "goldengate"
    on = bool(pal.get("decorGtk")) or mac
    decor3_tpl = SHELL / ("templates/gtk3-decor-mac.css" if mac else "templates/gtk3-decor.css")
    decor4_tpl = SHELL / ("templates/gtk4-decor-mac.css" if mac else "templates/gtk4-decor.css")
    # Settings → Windows → «Window buttons» → Keys: their CSS after the decorations
    keys_css = "" if mac or not pal.get("decorKeys") else "\n" + (SHELL / "templates/gtk-decor-keys.css").read_text()
    # the palette CSS's frames, next to it, in the apps' colours (hell's while the demon rules)
    apps = dict(pal, **(pal.get("apps") or {}))
    frames(GTK3, apps)
    frames(GTK4, apps)

    if not on or base_dir is None:
        # back to the plain theme; the user's palette CSS comes back with the next render
        if current.startswith("angelOS-"):
            gsettings("org.gnome.desktop.interface", "gtk-theme", base)
        write(GTK4 / "angelos-decor.css", "/* angelOS window buttons: off */\n")
        version_gtk4()
        if (GTK3 / "angelos.css").exists() and (GTK3 / "angelos.css").read_text() == STUB:
            print("gtk3 palette stub stays until the next render")
        button_layout(pal, mac)
        print(json.dumps({"live": False, "theme": base if current.startswith("angelOS-") else current}))
        return

    # GTK 4 / libadwaita: the decorations next to its user CSS
    write(GTK4 / "angelos-decor.css", render(decor4_tpl.read_text(), pal) + keys_css)
    assets(GTK4, pal)
    version_gtk4()

    # GTK 3 (and Chromium's GTK mode): the live theme
    palette_css = (GTK3 / "angelos.css").read_text() if (GTK3 / "angelos.css").exists() else ""
    if palette_css == STUB:
        palette_css = ""
    decor3 = render(decor3_tpl.read_text(), pal) + keys_css
    css3 = '@import url("file://%s/gtk-3.0/gtk.css");\n\n%s\n%s' % (base_dir, palette_css, decor3)
    # inlined below the theme's own @import: an @import further down would be dropped
    palette4 = (GTK4 / "angelos.css").read_text() if (GTK4 / "angelos.css").exists() else ""
    palette4 = "\n".join(l for l in palette4.splitlines() if not l.lstrip().startswith("@import"))
    palette4 = re.sub(r"assets/v-[0-9a-f]+/", "assets/", palette4)   # the theme's own assets/ are plain
    css4 = '@import url("file://%s/gtk-4.0/gtk.css");\n\n%s\n%s' % (base_dir, palette4, render(decor4_tpl.read_text(), pal) + keys_css)
    in_use = THEMES / current if current in ("angelOS-a", "angelOS-b") else None
    if palette_css and in_use and (in_use / "gtk-3.0/gtk.css").exists() and (in_use / "gtk-3.0/gtk.css").read_text() == css3:
        print(json.dumps({"live": True, "theme": current, "changed": False}))
    else:
        name = "angelOS-b" if current == "angelOS-a" else "angelOS-a"
        d = THEMES / name
        write(d / "index.theme", "[Desktop Entry]\nType=X-GNOME-Metatheme\nName=%s\nComment=angelOS (generated, %s)\nEncoding=UTF-8\n\n[X-GNOME-Metatheme]\nGtkTheme=%s\n" % (name, pal.get("realm", "heaven"), name))
        write(d / "gtk-3.0/gtk.css", css3)
        write(d / "gtk-4.0/gtk.css", css4)
        assets(d / "gtk-3.0", pal)
        assets(d / "gtk-4.0", pal)
        frames(d / "gtk-3.0", apps)
        frames(d / "gtk-4.0", apps)
        if palette_css:
            gsettings("org.gnome.desktop.interface", "gtk-theme", name)
        print(json.dumps({"live": True, "theme": name, "changed": True}))
    # the palette now comes with the theme: the user CSS would outrank it with stale colours
    if palette_css:
        write(GTK3 / "angelos.css", STUB)
    button_layout(pal, mac)


def button_layout(pal, mac):
    """The title bar buttons' order for GTK (gsettings, which GTK 4 gets through the portal, and
    settings.ini for GTK 3 under another session): set with the decorations on or off, so a
    layout written once ("close" only, say) never stays behind."""
    layout = pal.get("decorButtons") or "maximize,close"
    cur_layout = gsettings("org.gnome.desktop.wm.preferences", "button-layout")
    left = cur_layout.split(":")[0] if ":" in cur_layout else "icon"
    if mac:
        want = "close,minimize,maximize:"
    else:
        # the Mac's lights on the leading side go back to the app icon there
        if "close" in left.split(","):
            left = "icon"
        want = left + ":" + layout
    if cur_layout != want:
        gsettings("org.gnome.desktop.wm.preferences", "button-layout", want)
    # settings.ini says the same (apps that read it, not the portal: GTK under another session)
    for folder in (GTK3, GTK4):
        ini = folder / "settings.ini"
        if ini.exists():
            text = ini.read_text()
            fixed = re.sub(r"(?m)^gtk-decoration-layout=.*$", "gtk-decoration-layout=" + want, text)
            if fixed != text:
                write(ini, fixed)


if __name__ == "__main__":
    main()
