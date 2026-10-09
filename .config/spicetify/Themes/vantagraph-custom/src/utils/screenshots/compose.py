"""Builds the Marketplace preview images from the captured screenshots.

    python src/utils/screenshots/compose.py

Inputs  design/screenshots/palettes/palette-*.png, editor-picker.png  (capture.js)
Outputs design/screenshots/preview.png      800x800 card: six palettes, one screen
        design/screenshots/preview.gif      800x800 card, palettes wiping into each other
        design/screenshots/preview-logo.png 800x800 alternative: logo over a blurred app
        design/screenshots/palettes-grid.png  the six palettes side by side, for the README

The Marketplace draws previews in Spotify's square card with object-fit: cover,
so anything that is not square gets its sides cut off. Everything here is
square and keeps the whole app inside the frame.
"""
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SHOTS = os.path.join(ROOT, "design", "screenshots")
LOGO = os.path.join(ROOT, "design", "marketing", "for git", "Logo.png")
FONTS = os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Fonts")

ORDER = ["vantagraphblack", "plum", "ocean", "forest", "ember", "paper"]
NAMES = {"vantagraphblack": "VantagraphBlack", "plum": "Plum", "ocean": "Ocean",
         "ember": "Ember", "forest": "Forest", "paper": "Paper"}
ACCENT = {"vantagraphblack": "#B0B5B0", "plum": "#C79BFF", "ocean": "#38D1C8",
          "ember": "#FF8A3D", "forest": "#5EE39A", "paper": "#C4552D"}

SIZE = 800
APP_W = 760
APP_H = round(APP_W * 9 / 16)
APP_Y = 292
SKEW = 150  # how far a slice edge leans between the top and the bottom of the app


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def palette(name):
    im = Image.open(os.path.join(SHOTS, "palettes", "palette-%s.png" % name)).convert("RGB")
    return im.resize((APP_W, APP_H), Image.LANCZOS)


def background():
    """Near-black square with a faint glow of every accent along the bottom."""
    bg = Image.new("RGB", (SIZE, SIZE), "#07070A")
    glow = Image.new("RGB", (SIZE, SIZE), "#07070A")
    d = ImageDraw.Draw(glow)
    step = SIZE / len(ORDER)
    for i, name in enumerate(ORDER):
        cx = step * (i + 0.5)
        d.ellipse([cx - 170, SIZE - 330, cx + 170, SIZE + 10], fill=ACCENT[name])
    glow = glow.filter(ImageFilter.GaussianBlur(120))
    return Image.blend(bg, glow, 0.28)


def rounded_mask(w, h, r):
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w - 1, h - 1], r, fill=255)
    return m


def place_app(canvas, app):
    """Drop shadow, rounded corners and a hairline border around the app shot."""
    x = (SIZE - APP_W) // 2
    shadow = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(shadow).rounded_rectangle([x + 6, APP_Y + 18, x + APP_W - 6, APP_Y + APP_H + 18], 22, fill=190)
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    canvas.paste(Image.new("RGB", (SIZE, SIZE), "#000000"), (0, 0), shadow)
    canvas.paste(app, (x, APP_Y), rounded_mask(APP_W, APP_H, 18))
    ImageDraw.Draw(canvas).rounded_rectangle([x, APP_Y, x + APP_W - 1, APP_Y + APP_H - 1], 18, outline=(255, 255, 255, 40), width=1)


def slice_edges(n):
    """x positions (top, bottom) of the n-1 slanted edges between n slices."""
    span = APP_W + SKEW
    return [(-SKEW / 2 + span * i / n + SKEW / 2, -SKEW / 2 + span * i / n - SKEW / 2) for i in range(1, n)]


def sliced_app(names, edges):
    """One app image made of slanted slices, one palette each."""
    out = palette(names[0])
    bounds = [(-SKEW - 2, -SKEW - 2)] + edges + [(APP_W + SKEW + 2, APP_W + SKEW + 2)]
    for i, name in enumerate(names):
        (t0, b0), (t1, b1) = bounds[i], bounds[i + 1]
        m = Image.new("L", (APP_W, APP_H), 0)
        ImageDraw.Draw(m).polygon([(t0, 0), (t1, 0), (b1, APP_H), (b0, APP_H)], fill=255)
        out.paste(palette(name), (0, 0), m)
    d = ImageDraw.Draw(out, "RGBA")
    for t, b in edges:
        d.line([(t, 0), (b, APP_H)], fill=(255, 255, 255, 70), width=2)
    return out


def header(canvas):
    """Logo, name and one line of promise, sized to read on a 200px card."""
    logo = Image.open(LOGO).convert("RGBA")
    logo = logo.crop(logo.getchannel("A").getbbox())
    lh = 92
    logo = logo.resize((round(logo.width * lh / logo.height), lh), Image.LANCZOS)
    canvas.paste(logo, ((SIZE - logo.width) // 2, 34), logo)
    d = ImageDraw.Draw(canvas)
    d.text((SIZE / 2, 150), "Vantagraph Custom", font=font("segoeuib.ttf", 62), fill="#F4F4F8", anchor="mt")
    d.text((SIZE / 2, 228), "Every colour is yours", font=font("segoeui.ttf", 32), fill="#A9A9BC", anchor="mt")


def dots(canvas, active=None):
    """One dot per palette under the app; the shown one is ringed."""
    d = ImageDraw.Draw(canvas)
    y = APP_Y + APP_H + 34
    gap = 40
    x0 = SIZE / 2 - gap * (len(ORDER) - 1) / 2
    for i, name in enumerate(ORDER):
        x = x0 + gap * i
        if name == active:
            d.ellipse([x - 13, y - 13, x + 13, y + 13], outline="#F4F4F8", width=2)
        d.ellipse([x - 8, y - 8, x + 8, y + 8], fill=ACCENT[name])


def build_png():
    canvas = background()
    header(canvas)
    place_app(canvas, sliced_app(ORDER, slice_edges(len(ORDER))))
    dots(canvas)
    path = os.path.join(SHOTS, "preview.png")
    canvas.save(path, optimize=True)
    return path


def build_gif():
    """Hold each palette, then wipe the next one in along a slanted edge."""
    base = background()
    header(base)
    frames, durations = [], []
    wipe = 6
    for i, name in enumerate(ORDER):
        nxt = ORDER[(i + 1) % len(ORDER)]
        still = base.copy()
        place_app(still, palette(name))
        dots(still, name)
        frames.append(still)
        durations.append(1500)
        for k in range(1, wipe + 1):
            x = -SKEW / 2 + (APP_W + SKEW) * k / (wipe + 1)
            f = base.copy()
            place_app(f, sliced_app([nxt, name], [(x + SKEW / 2, x - SKEW / 2)]))
            dots(f, name if k <= wipe // 2 else nxt)
            frames.append(f)
            durations.append(55)
    # one shared colour table built from every palette's still, so no palette
    # gets mapped onto another's colours and static areas keep the same indices
    stills = [f for f, d in zip(frames, durations) if d == 1500]
    sheet = Image.new("RGB", (SIZE * len(stills), SIZE))
    for i, s in enumerate(stills):
        sheet.paste(s, (SIZE * i, 0))
    # the rainbow logo is small but needs the most colours: 64 of the table go
    # to the logo area alone, the other 191 to everything else
    ui = sheet.quantize(colors=191, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    mark = stills[0].crop((SIZE // 2 - 150, 20, SIZE // 2 + 150, 140))
    mark = mark.quantize(colors=64, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    table = ui.getpalette()[:191 * 3] + mark.getpalette()[:64 * 3]
    pal = Image.new("P", (1, 1))
    pal.putpalette(table + [0] * (768 - len(table)))
    q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
    path = os.path.join(SHOTS, "preview.gif")
    q[0].save(path, save_all=True, append_images=q[1:], duration=durations, loop=0, optimize=True, disposal=1)
    return path


def build_logo_variant():
    """The luminous / Appletify style: blurred, darkened app with the mark on top."""
    app = Image.open(os.path.join(SHOTS, "editor-picker.png")).convert("RGB")
    h = app.height
    app = app.crop(((app.width - h) // 2, 0, (app.width + h) // 2, h)).resize((SIZE, SIZE), Image.LANCZOS)
    app = app.filter(ImageFilter.GaussianBlur(9))
    canvas = Image.blend(app, Image.new("RGB", (SIZE, SIZE), "#050508"), 0.45)
    logo = Image.open(LOGO).convert("RGBA")
    logo = logo.crop(logo.getchannel("A").getbbox())
    lw = 380
    logo = logo.resize((lw, round(logo.height * lw / logo.width)), Image.LANCZOS)
    glow = Image.new("L", (SIZE, SIZE), 0)
    glow.paste(logo.getchannel("A"), ((SIZE - lw) // 2, 190))
    canvas.paste(Image.new("RGB", (SIZE, SIZE), "#FFFFFF"), (0, 0), glow.filter(ImageFilter.GaussianBlur(40)).point(lambda v: v * 0.35))
    canvas.paste(logo, ((SIZE - lw) // 2, 190), logo)
    d = ImageDraw.Draw(canvas)
    d.text((SIZE / 2, 560), "Vantagraph Custom", font=font("segoeuib.ttf", 64), fill="#FFFFFF", anchor="mt")
    d.text((SIZE / 2, 640), "Every colour is yours", font=font("segoeui.ttf", 32), fill="#D2D2DE", anchor="mt")
    path = os.path.join(SHOTS, "preview-logo.png")
    canvas.save(path, optimize=True)
    return path


def build_grid():
    """Six palettes, three by two, with their names, for the README."""
    cw, ch, gap, label = 512, 288, 24, 44
    w = cw * 3 + gap * 4
    h = (ch + label) * 2 + gap * 3
    canvas = Image.new("RGB", (w, h), "#07070A")
    d = ImageDraw.Draw(canvas)
    f = font("seguisb.ttf", 24)
    for i, name in enumerate(ORDER):
        col, row = i % 3, i // 3
        x = gap + col * (cw + gap)
        y = gap + row * (ch + label + gap)
        im = Image.open(os.path.join(SHOTS, "palettes", "palette-%s.png" % name)).convert("RGB").resize((cw, ch), Image.LANCZOS)
        canvas.paste(im, (x, y), rounded_mask(cw, ch, 12))
        d.ellipse([x + 2, y + ch + 16, x + 16, y + ch + 30], fill=ACCENT[name])
        d.text((x + 26, y + ch + 23), NAMES[name], font=f, fill="#E8E8F0", anchor="lm")
    path = os.path.join(SHOTS, "palettes-grid.png")
    canvas.save(path, optimize=True)
    return path


if __name__ == "__main__":
    for p in (build_png(), build_gif(), build_logo_variant(), build_grid()):
        im = Image.open(p)
        print("%-48s %dx%d  %d KB" % (os.path.relpath(p, ROOT), im.width, im.height, os.path.getsize(p) // 1024))
