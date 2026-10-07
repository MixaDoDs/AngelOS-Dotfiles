"""NEEDY GIRL OVERDOSE skins for the region screenshot / recording tools.

Used by ~/.local/bin/niri-screenshot-region (selection) and niri-record-overlay
(frame shown while recording). The skin comes from ~/.config/angelos/settings.json
(capture.skin): "ropes" is the tools' own look, handled there; this module adds

  window  — the selection is a "screenshot.exe" window: bevelled frame, pink title
            bar, marching ants, pixel hearts in the corners, size badge;
            while recording: "● REC recording.exe 00:12".
  stream  — Ame-chan's stream: a chain of marching pixel hearts, LIVE badge, a
            "kawaii" size bubble, scanlines; while recording: LIVE + viewers + timer.

Colours are the NGO palette, or the current angelOS theme when capture.themeColors
is on. Pure cairo; everything snaps to a 3 px art pixel.
"""
import json
import os
from pathlib import Path
import random
import time

import cairo

CELL = 3
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "angelos/settings.json"
PALETTE = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "angelos/palette.json"
NGO = {"accent": "#ff5cad", "accent2": "#b36bff", "accent3": "#4fe3ff", "title1": "#ff4fa3",
       "title2": "#7b4dff", "desk": "#1a0f24", "face": "#241432", "hi": "#ffd1e8", "lo": "#5b1a8f",
       "edge": "#07030b", "text": "#ffe1f1", "danger": "#ff2e7e", "yellow": "#ffe066"}
HEART = [".##...##.", "#wo#.#oo#", "#ooo#ooo#", "#ooooooo#", ".#ooooo#.", "..#ooo#..", "...#o#...", "....#...."]
SPARKLE = ["...o...", "...o...", "..ooo..", "ooowooo", "..ooo..", "...o...", "...o..."]
FONT = "Pixeloid Sans"


def rgb(value, alpha=1.0):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) / 255 for i in (0, 2, 4)) + (alpha,)


def settings():
    try:
        return json.loads(CONFIG.read_text()).get("capture") or {}
    except (OSError, ValueError, AttributeError):
        return {}


def exe(name):
    """"screenshot" → "screenshot.exe": the ending of Settings → Appearance (I18n.exe in QML)"""
    try:
        ext = (json.loads(CONFIG.read_text()).get("desktop") or {}).get("titleSuffix") or "exe"
    except (OSError, ValueError, AttributeError):
        ext = "exe"
    return name + "." + (ext if ext in ("exe", "sh", "bin") else "exe")


def load(name=None):
    """The skin to use, or None for the built-in ropes."""
    conf = settings()
    name = name or os.environ.get("ANGELOS_CAPTURE_SKIN") or conf.get("skin") or "ropes"
    if name not in SKINS:
        return None
    colors = dict(NGO)
    if conf.get("themeColors"):
        try:
            theme = json.loads(PALETTE.read_text())
            for key in ("accent", "accent2", "accent3", "title1", "title2", "desk", "face", "hi", "lo", "edge", "text"):
                if isinstance(theme.get(key), str) and theme[key].startswith("#"):
                    colors[key] = theme[key]
        except (OSError, ValueError):
            pass
    return SKINS[name](colors)


class Skin:
    fps = 20
    record_fps = 4

    def __init__(self, colors):
        self.c = colors
        self.t0 = time.monotonic()
        self._dots = None

    # ---- pixel helpers ----
    def px(self, cr, x, y, w, h, color):
        cr.set_source_rgba(*color)
        cr.rectangle(round(x), round(y), round(w), round(h))
        cr.fill()

    def heart(self, cr, x, y, cell, fill, ink=None):
        ink = ink or rgb(self.c["edge"])
        for j, row in enumerate(HEART):
            for i, ch in enumerate(row):
                color = ink if ch == "#" else fill if ch == "o" else (1, 1, 1, 1) if ch == "w" else None
                if color:
                    cr.set_source_rgba(*color)
                    cr.rectangle(round(x + i * cell), round(y + j * cell), cell, cell)
                    cr.fill()

    def sparkle(self, cr, x, y, cell, color):
        for j, row in enumerate(SPARKLE):
            for i, ch in enumerate(row):
                if ch != ".":
                    cr.set_source_rgba(*((1, 1, 1, color[3]) if ch == "w" else color))
                    cr.rectangle(round(x + i * cell), round(y + j * cell), cell, cell)
                    cr.fill()

    # symbols pixel fonts lack are drawn as pixel icons
    ICONS = {
        "♡": HEART,
        "✧": SPARKLE,
        "✕": ["#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
        "□": ["#####", "#...#", "#...#", "#...#", "#####"],
    }

    def _font(self, cr, size, bold):
        cr.select_font_face(FONT, cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD if bold else cairo.FONT_WEIGHT_NORMAL)
        cr.set_font_size(size)
        options = cairo.FontOptions()
        options.set_antialias(cairo.ANTIALIAS_NONE)
        options.set_hint_style(cairo.HINT_STYLE_FULL)
        cr.set_font_options(options)

    def _segments(self, value):
        part = ""
        for ch in value:
            if ch in self.ICONS:
                if part:
                    yield part
                    part = ""
                yield ch
            else:
                part += ch
        if part:
            yield part

    def _icon_size(self, rows, size):
        cell = max(1, round(size * 0.8 / len(rows)))
        return cell, len(rows[0]) * cell + max(2, cell)

    def text(self, cr, x, y, value, size, color, shadow=None, bold=False):
        self._font(cr, size, bold)
        cx = round(x)
        for seg in self._segments(value):
            if seg in self.ICONS:
                rows = self.ICONS[seg]
                cell, adv = self._icon_size(rows, size)
                top = round(y - size * 0.8)
                for j, row in enumerate(rows):
                    for i, ch in enumerate(row):
                        if ch == ".":
                            continue
                        c = (1, 1, 1, color[3]) if ch == "w" else color
                        cr.set_source_rgba(*c)
                        cr.rectangle(cx + i * cell, top + j * cell, cell, cell)
                        cr.fill()
                cx += adv
                continue
            if shadow:
                cr.set_source_rgba(*shadow)
                cr.move_to(cx + 2, round(y) + 2)
                cr.show_text(seg)
            cr.set_source_rgba(*color)
            cr.move_to(cx, round(y))
            cr.show_text(seg)
            cx += cr.text_extents(seg).x_advance
        return cx - round(x)

    def text_width(self, cr, value, size, bold=False):
        self._font(cr, size, bold)
        width = 0
        for seg in self._segments(value):
            width += self._icon_size(self.ICONS[seg], size)[1] if seg in self.ICONS else cr.text_extents(seg).x_advance
        return width

    def box(self, cr, x, y, w, h, face, sunken=False):
        """Win98 bevelled box."""
        hi, lo = rgb(self.c["hi"]), rgb(self.c["lo"])
        self.px(cr, x, y, w, h, rgb(self.c["edge"]))
        self.px(cr, x + CELL, y + CELL, w - 2 * CELL, h - 2 * CELL, face)
        a, b = (lo, hi) if sunken else (hi, lo)
        self.px(cr, x + CELL, y + CELL, w - 2 * CELL, CELL, a)
        self.px(cr, x + CELL, y + CELL, CELL, h - 2 * CELL, a)
        self.px(cr, x + CELL, y + h - 2 * CELL, w - 2 * CELL, CELL, b)
        self.px(cr, x + w - 2 * CELL, y + CELL, CELL, h - 2 * CELL, b)

    def dim(self, cr, w, h, alpha):
        cr.set_operator(cairo.OPERATOR_SOURCE)
        cr.set_source_rgba(*rgb(self.c["desk"], alpha))
        cr.rectangle(0, 0, w, h)
        cr.fill()
        cr.set_operator(cairo.OPERATOR_OVER)

    def dots(self, cr, w, h, color, step=6):
        """Ordered dot pattern over the dim, as one repeating pattern (cheap)."""
        tile = cairo.ImageSurface(cairo.FORMAT_ARGB32, step, step)
        t = cairo.Context(tile)
        t.set_source_rgba(*color)
        t.rectangle(0, 0, 2, 2)
        t.fill()
        pattern = cairo.SurfacePattern(tile)
        pattern.set_extend(cairo.EXTEND_REPEAT)
        cr.set_source(pattern)
        cr.rectangle(0, 0, w, h)
        cr.fill()

    def hole(self, cr, x, y, w, h):
        cr.set_operator(cairo.OPERATOR_CLEAR)
        cr.rectangle(x, y, w, h)
        cr.fill()
        cr.set_operator(cairo.OPERATOR_OVER)

    def hint(self, cr, w, h, title, line):
        size = 18
        tw = max(self.text_width(cr, title, size, True), self.text_width(cr, line, 14)) + 48
        bw, bh = tw, 86
        x, y = (w - bw) // 2, (h - bh) // 2
        self.box(cr, x, y, bw, bh, rgb(self.c["face"], 0.96))
        self.px(cr, x + 2 * CELL, y + 2 * CELL, bw - 4 * CELL, 24, rgb(self.c["title1"]))
        self.text(cr, x + 14, y + 2 * CELL + 18, title, size, (1, 1, 1, 1), rgb(self.c["edge"], 0.6), True)
        self.text(cr, x + 14, y + 66, line, 14, rgb(self.c["text"]))

    def elapsed(self):
        s = int(time.monotonic() - self.t0)
        return f"{s // 60:02d}:{s % 60:02d}"


class WindowSkin(Skin):
    name = "window"
    fps = 12
    record_fps = 2

    def frame(self, cr, x, y, w, h, title, t, ants=True, recording=False):
        c = self.c
        bar = 27
        # frame just outside the hole so it is never part of the capture
        fx, fy, fw, fh = x - 3 * CELL, y - 3 * CELL - bar, w + 6 * CELL, h + 6 * CELL + bar
        above = fy >= 0
        if not above:  # no room above: the title bar goes below the region
            fy = y - 3 * CELL
            fh = h + 6 * CELL + bar
        # bevelled border (only the frame ring; the hole stays clear)
        self.box(cr, fx, fy, fw, fh, rgb(c["face"], 0.97))
        self.hole(cr, x, y, w, h)
        # title bar with a stepped two-tone gradient
        by = fy + 2 * CELL if above else y + h + CELL
        steps = 12
        for i in range(steps):
            a, b = rgb(c["title1"]), rgb(c["title2"])
            f = i / (steps - 1)
            col = tuple(a[k] + (b[k] - a[k]) * f for k in range(3)) + (1,)
            self.px(cr, fx + 2 * CELL + i * (fw - 4 * CELL) / steps, by, (fw - 4 * CELL) / steps + 1, bar - CELL, col)
        self.heart(cr, fx + 3 * CELL, by + 4, 2, rgb(c["accent"]))
        if recording and int(t * 2) % 2 == 0:
            self.px(cr, fx + 3 * CELL + 24, by + 9, 9, 9, rgb(c["danger"]))
        buttons = fw > 200
        title_end = fx + fw - 2 * CELL - (3 * 24 + 4 if buttons else 0)
        cr.save()   # a long title never runs under the buttons
        cr.rectangle(fx, by, max(0, title_end - fx), bar)
        cr.clip()
        self.text(cr, fx + 3 * CELL + (40 if recording else 26), by + 18, title, 15, (1, 1, 1, 1), rgb(c["edge"], 0.55), True)
        cr.restore()
        # ♡ ▢ ✕ buttons
        for i, glyph in enumerate(("♡", "□", "✕") if buttons else ()):
            bx = fx + fw - 2 * CELL - (3 - i) * 24
            self.box(cr, bx, by + 2, 21, bar - 3 * CELL, rgb(c["face"]))
            self.text(cr, bx + 5, by + 17, glyph, 12, rgb(c["text"]))
        # marching ants inside the frame edge
        if ants:
            cr.set_antialias(cairo.ANTIALIAS_NONE)
            cr.set_line_width(2)
            cr.rectangle(x - 1, y - 1, w + 2, h + 2)
            cr.set_dash([6, 6], (t * 24) % 12)
            cr.set_source_rgba(*rgb(c["accent"]))
            cr.stroke_preserve()
            cr.set_dash([6, 6], (t * 24 + 6) % 12)
            cr.set_source_rgba(1, 1, 1, 1)
            cr.stroke()
            cr.set_dash([])
        # pixel hearts on the corners
        for hx, hy in ((fx - 8, fy - 8), (fx + fw - 19, fy - 8), (fx - 8, fy + fh - 16), (fx + fw - 19, fy + fh - 16)):
            self.heart(cr, hx, hy, 3, rgb(c["accent"] if (hx + hy) % 2 else c["accent2"]))

    def badge(self, cr, x, y, value):
        size = 14
        w = self.text_width(cr, value, size, True) + 18
        self.box(cr, x, y, w, 26, rgb(self.c["accent"]))
        self.text(cr, x + 9, y + 18, value, size, (1, 1, 1, 1), rgb(self.c["edge"], 0.5), True)

    def draw_select(self, cr, W, H, sel):
        t = time.monotonic() - self.t0
        self.dim(cr, W, H, 0.42)
        self.dots(cr, W, H, rgb(self.c["accent"], 0.10))
        if sel is None:
            self.hint(cr, W, H, "✧ " + exe("screenshot") + " ✧", "выдели область или кликни по окну ♡  ·  Esc — отмена")
            return
        x, y, w, h = sel
        self.hole(cr, x, y, w, h)
        self.frame(cr, x, y, w, h, exe("screenshot"), t)
        bx = min(max(0, x + w - 110), W - 120)
        by = y + h + 3 * CELL + 6 if y + h + 40 < H else y + 6
        self.badge(cr, bx, by, f"{w} × {h}")

    def draw_record(self, cr, W, H, hole):
        t = time.monotonic() - self.t0
        self.dim(cr, W, H, 0.25)
        x, y, w, h = hole
        self.hole(cr, x, y, w, h)
        self.frame(cr, x, y, w, h, "REC  " + exe("recording") + "  " + self.elapsed(), t, ants=False, recording=True)


class StreamSkin(Skin):
    name = "stream"
    fps = 15
    record_fps = 8

    def __init__(self, colors):
        super().__init__(colors)
        self.viewers = random.randint(900, 2400)
        self.phrase = random.choice(["OMG kawaii ♡", "ангел, снимай!", "лайк за кадр ♡", "internet angel ✧",
                                     "чат, смотрите!", "кадр века ✧"])

    def scanlines(self, cr, W, H):
        tile = cairo.ImageSurface(cairo.FORMAT_ARGB32, 1, 4)
        t = cairo.Context(tile)
        t.set_source_rgba(0, 0, 0, 0.18)
        t.rectangle(0, 0, 1, 1)
        t.fill()
        pattern = cairo.SurfacePattern(tile)
        pattern.set_extend(cairo.EXTEND_REPEAT)
        cr.set_source(pattern)
        cr.rectangle(0, 0, W, H)
        cr.fill()

    def chain(self, cr, x, y, w, h, t):
        """Pixel hearts marching around the rectangle."""
        c = self.c
        step = 30
        perimeter = 2 * (w + h)
        if perimeter <= 0:
            return
        offset = (t * 36) % step
        n = int(perimeter // step) + 1
        for i in range(n):
            d = (i * step + offset) % perimeter
            if d < w:
                px, py = x + d, y
            elif d < w + h:
                px, py = x + w, y + (d - w)
            elif d < 2 * w + h:
                px, py = x + w - (d - w - h), y + h
            else:
                px, py = x, y + h - (d - 2 * w - h)
            fill = rgb(c["accent"] if i % 2 else c["accent2"])
            self.heart(cr, px - 9, py - 8, 2, fill)

    def live(self, cr, x, y, extra):
        """LIVE badge (+ extra text); returns its width."""
        c = self.c
        self.box(cr, x, y, 64, 26, rgb(c["danger"]))
        self.px(cr, x + 10, y + 9, 8, 8, (1, 1, 1, 1))
        self.text(cr, x + 24, y + 18, "LIVE", 14, (1, 1, 1, 1), None, True)
        if not extra:
            return 64
        w = self.text_width(cr, extra, 14) + 20
        self.box(cr, x + 70, y, w, 26, rgb(c["face"], 0.95))
        self.text(cr, x + 80, y + 18, extra, 14, rgb(c["text"]))
        return 70 + w

    def bubble(self, cr, x, y, value):
        c = self.c
        w = self.text_width(cr, value, 14, True) + 24
        self.box(cr, x, y, w, 28, (1, 1, 1, 0.97))
        self.px(cr, x + 14, y + 28, 9, 3, (1, 1, 1, 0.97))
        self.px(cr, x + 14, y + 31, 6, 3, (1, 1, 1, 0.97))
        self.text(cr, x + 12, y + 19, value, 14, rgb(c["title1"]), None, True)

    def draw_select(self, cr, W, H, sel):
        t = time.monotonic() - self.t0
        self.dim(cr, W, H, 0.45)
        self.px(cr, 0, 0, W, H, rgb(self.c["accent"], 0.06))
        self.scanlines(cr, W, H)
        if sel is None:
            self.hint(cr, W, H, "♡ angel stream ♡", "выдели кадр или кликни по окну  ·  Esc — отмена")
            return
        x, y, w, h = sel
        self.hole(cr, x, y, w, h)
        cr.set_source_rgba(*rgb(self.c["accent"], 0.55))
        cr.set_line_width(2)
        cr.rectangle(x - 1, y - 1, w + 2, h + 2)
        cr.stroke()
        self.chain(cr, x - 4, y - 4, w + 8, h + 8, t)
        for i, (sx, sy) in enumerate(((x - 30, y - 30), (x + w + 10, y - 30), (x - 30, y + h + 10), (x + w + 10, y + h + 10))):
            if int(t * 3 + i) % 3:
                self.sparkle(cr, sx, sy, 3, rgb(self.c["yellow"]))
        above = y > 50
        ly = y - 40 if above else y + h + 14
        used = self.live(cr, x, ly, f"{w}×{h}")
        bw = self.text_width(cr, self.phrase, 14, True) + 24
        bx = min(x + w - bw, W - bw - 4)
        if bx >= x + used + 10:          # same row as LIVE, right-aligned
            self.bubble(cr, bx, ly - 2, self.phrase)
        elif above and y + h + 60 < H:   # no room beside it: the other side
            self.bubble(cr, max(4, bx), y + h + 18, self.phrase)
        elif not above and y > 50:
            self.bubble(cr, max(4, bx), y - 44, self.phrase)

    def draw_record(self, cr, W, H, hole):
        t = time.monotonic() - self.t0
        self.dim(cr, W, H, 0.28)
        self.px(cr, 0, 0, W, H, rgb(self.c["accent"], 0.05))
        x, y, w, h = hole
        self.hole(cr, x, y, w, h)
        self.chain(cr, x - 6, y - 6, w + 12, h + 12, t)
        if random.random() < 0.3:
            self.viewers += random.randint(-3, 9)
        ly = y - 44 if y > 54 else y + h + 16
        self.live(cr, x, ly, f"{self.viewers} ♡  ·  {self.elapsed()}")


SKINS = {"window": WindowSkin, "stream": StreamSkin}


def run_record_overlay(skin, gx, gy, gw, gh):
    """Click-through recording frame on the monitor that holds the region."""
    import gi
    gi.require_version("Gdk", "3.0")
    gi.require_version("Gtk", "3.0")
    gi.require_version("GtkLayerShell", "0.1")
    from gi.repository import Gdk, GLib, Gtk, GtkLayerShell

    display = Gdk.Display.get_default()
    monitor = display.get_monitor_at_point(gx + gw // 2, gy + gh // 2) or display.get_primary_monitor()
    geo = monitor.get_geometry()
    win = Gtk.Window()
    win.set_app_paintable(True)
    win.set_decorated(False)
    win.set_accept_focus(False)
    win.set_size_request(geo.width, geo.height)
    visual = win.get_screen().get_rgba_visual()
    if visual is not None:
        win.set_visual(visual)
    GtkLayerShell.init_for_window(win)
    GtkLayerShell.set_namespace(win, "niri-record-overlay")
    GtkLayerShell.set_layer(win, GtkLayerShell.Layer.OVERLAY)
    GtkLayerShell.set_keyboard_mode(win, GtkLayerShell.KeyboardMode.NONE)
    GtkLayerShell.set_exclusive_zone(win, -1)
    GtkLayerShell.set_monitor(win, monitor)
    for edge in (GtkLayerShell.Edge.LEFT, GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.RIGHT, GtkLayerShell.Edge.BOTTOM):
        GtkLayerShell.set_anchor(win, edge, True)
    hole = (gx - geo.x, gy - geo.y, gw, gh)

    def draw(_w, cr):
        cr.set_operator(cairo.OPERATOR_SOURCE)
        cr.set_source_rgba(0, 0, 0, 0)
        cr.paint()
        cr.set_operator(cairo.OPERATOR_OVER)
        cr.set_antialias(cairo.ANTIALIAS_NONE)
        skin.draw_record(cr, geo.width, geo.height, hole)
        return False

    def clickthrough(*_):
        stub = cairo.Region(cairo.RectangleInt(0, 0, 1, 1))
        win.input_shape_combine_region(stub)
        gdk_window = win.get_window()
        if gdk_window is not None:
            gdk_window.input_shape_combine_region(stub, 0, 0)
        return False

    win.connect("draw", draw)
    win.connect("realize", clickthrough)
    win.show_all()
    GLib.idle_add(clickthrough)
    GLib.timeout_add(int(1000 / skin.record_fps), lambda: (win.queue_draw(), True)[1])
    Gtk.main()


def draw_ropes_sketch(cr, width, height, sel):
    """A still of the tools' own rope look (the real one is a physics simulation)."""
    x, y, w, h = sel
    cr.set_source_rgba(0, 0, 0, 0.35)
    cr.rectangle(0, 0, width, height)
    cr.fill()
    cr.set_operator(cairo.OPERATOR_CLEAR)
    cr.rectangle(x, y, w, h)
    cr.fill()
    cr.set_operator(cairo.OPERATOR_OVER)
    cr.set_line_cap(cairo.LINE_CAP_ROUND)
    corners = ((0, 0, x, y), (width, 0, x + w, y), (width, height, x + w, y + h), (0, height, x, y + h))
    paths = [(ax, ay, bx, by, 26) for ax, ay, bx, by in corners]
    paths += [(x, y, x + w, y, 4), (x + w, y + h, x, y + h, 4), (x + w, y, x + w, y + h, 1), (x, y + h, x, y, 1)]
    for lw, color in ((9, (0.22, 0.12, 0.05, 1)), (5, (0.42, 0.26, 0.12, 1)), (3, (0.70, 0.50, 0.28, 1))):
        cr.set_line_width(lw)
        cr.set_source_rgba(*color)
        for ax, ay, bx, by, sag in paths:
            cr.move_to(ax, ay)
            cr.curve_to(ax + (bx - ax) / 3, ay + (by - ay) / 3 + sag, ax + 2 * (bx - ax) / 3, ay + 2 * (by - ay) / 3 + sag, bx, by)
            cr.stroke()


def preview(name, out, width=480, height=270):
    """Offline preview for Settings: the selection over a soft pixel backdrop."""
    skin = SKINS[name](load(name).c if load(name) else dict(NGO)) if name in SKINS else None
    surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, width, height)
    cr = cairo.Context(surface)
    cr.set_antialias(cairo.ANTIALIAS_NONE)
    for i in range(0, height, 6):   # stepped sunset backdrop
        f = i / height
        cr.set_source_rgba(0.35 + 0.4 * f, 0.25 + 0.2 * f, 0.55 - 0.1 * f, 1)
        cr.rectangle(0, i, width, 6)
        cr.fill()
    layer = cairo.ImageSurface(cairo.FORMAT_ARGB32, width, height)
    lc = cairo.Context(layer)
    lc.set_antialias(cairo.ANTIALIAS_NONE)
    sel = (width // 4, height // 3, width // 2, height // 2 - 10)
    if skin is None:
        draw_ropes_sketch(lc, width, height, sel)
    else:
        skin.t0 = time.monotonic() - 5
        skin.draw_select(lc, width, height, sel)
    cr.set_source_surface(layer)
    cr.paint()
    surface.write_to_png(out)


if __name__ == "__main__":
    import sys
    if len(sys.argv) == 4 and sys.argv[1] == "--preview" and sys.argv[2] in ("ropes", *SKINS):
        preview(sys.argv[2], sys.argv[3])
