#!/usr/bin/env python3
"""GTK in angelOS's colours and window decorations — live, heaven and hell.

usage: gtk-live.py PALETTE.json      (run by render-templates.py, entry "gtk-live")

GTK reads the user's gtk.css once per app, but reloads its *theme* whenever the theme
name changes. So, with Config.decor.gtkButtons on (palette key decorGtk), the palette
and the window buttons live in a theme of their own: adw-gtk3(-dark) underneath, the
angelOS colours (~/.config/gtk-3.0/angelos.css, rendered just before) and the
decorations (templates/gtk3-decor.css: bevelled pixel buttons, the header in the menu
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
import json
import re
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
SHELL = Path(__file__).resolve().parent.parent
THEMES = HOME / ".local/share/themes"
GTK3 = HOME / ".config/gtk-3.0"
GTK4 = HOME / ".config/gtk-4.0"
STUB = "/* angelOS: the colours live in the angelOS-a/b GTK theme now (gtk-live.py) */\n"

ICONS = {
    "close": ["##...##", "###.###", ".#####.", "..###..", ".#####.", "###.###", "##...##"],
    "maximize": ["#######", "#######", "#.....#", "#.....#", "#.....#", "#.....#", "#######"],
    "minimize": [".......", ".......", ".......", ".......", ".......", "######.", "######."],
}


def render(text, pal):
    return re.sub(r"\{\{\s*([\w.]+)\s*\}\}", lambda m: str(pal.get(m.group(1), m.group(0))), text)


def svg(rows, color):
    body = ""
    for y, row in enumerate(rows):
        x = 0
        while x < len(row):
            run = 1
            while x + run < len(row) and row[x + run] == row[x]:
                run += 1
            if row[x] == "#":
                body += '<rect x="%d" y="%d" width="%d" height="1" fill="%s"/>' % (x, y, run, color)
            x += run
    w, h = max(len(r) for r in rows), len(rows)
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" '
            'shape-rendering="crispEdges">%s</svg>\n') % (w * 2, h * 2, w, h, body)


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
    ink = pal.get("decorText", "#000000")
    for name, rows in ICONS.items():
        write(folder / "assets" / (name + ".svg"), svg(rows, ink))
    write(folder / "assets" / "close-hover.svg", svg(ICONS["close"], "#ffffff"))
    for name, path in MAC_GLYPHS.items():
        write(folder / "assets" / ("mac-" + name + ".svg"), mac_glyph(path))


def gsettings(schema, key, value=None):
    if value is None:
        r = subprocess.run(["gsettings", "get", schema, key], capture_output=True, text=True)
        return r.stdout.strip().strip("'")
    subprocess.run(["gsettings", "set", schema, key, value], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return value


def main():
    pal = json.loads(Path(sys.argv[1]).read_text())
    suffix = "-dark" if pal.get("mode") == "dark" else ""
    base = "adw-gtk3" + suffix
    base_dir = next((d / base for d in (HOME / ".local/share/themes", HOME / ".themes", Path("/usr/share/themes")) if (d / base / "gtk-3.0/gtk.css").exists()), None)
    current = gsettings("org.gnome.desktop.interface", "gtk-theme")
    mac = pal.get("skin") == "goldengate"
    on = bool(pal.get("decorGtk")) or mac
    decor3_tpl = SHELL / ("templates/gtk3-decor-mac.css" if mac else "templates/gtk3-decor.css")
    decor4_tpl = SHELL / ("templates/gtk4-decor-mac.css" if mac else "templates/gtk4-decor.css")
    # the palette CSS's frames, next to it, in the apps' colours (hell's while the demon rules)
    apps = dict(pal, **(pal.get("apps") or {}))
    frames(GTK3, apps)
    frames(GTK4, apps)

    if not on or base_dir is None:
        # back to the plain theme; the user's palette CSS comes back with the next render
        if current.startswith("angelOS-"):
            gsettings("org.gnome.desktop.interface", "gtk-theme", base)
        write(GTK4 / "angelos-decor.css", "/* angelOS window buttons: off */\n")
        if (GTK3 / "angelos.css").exists() and (GTK3 / "angelos.css").read_text() == STUB:
            print("gtk3 palette stub stays until the next render")
        print(json.dumps({"live": False, "theme": base if current.startswith("angelOS-") else current}))
        return

    # GTK 4 / libadwaita: the decorations next to its user CSS
    write(GTK4 / "angelos-decor.css", render(decor4_tpl.read_text(), pal))
    assets(GTK4, pal)

    # GTK 3 (and Chromium's GTK mode): the live theme
    palette_css = (GTK3 / "angelos.css").read_text() if (GTK3 / "angelos.css").exists() else ""
    if palette_css == STUB:
        palette_css = ""
    decor3 = render(decor3_tpl.read_text(), pal)
    css3 = '@import url("file://%s/gtk-3.0/gtk.css");\n\n%s\n%s' % (base_dir, palette_css, decor3)
    # inlined below the theme's own @import: an @import further down would be dropped
    palette4 = (GTK4 / "angelos.css").read_text() if (GTK4 / "angelos.css").exists() else ""
    palette4 = "\n".join(l for l in palette4.splitlines() if not l.lstrip().startswith("@import"))
    css4 = '@import url("file://%s/gtk-4.0/gtk.css");\n\n%s\n%s' % (base_dir, palette4, render(decor4_tpl.read_text(), pal))
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
