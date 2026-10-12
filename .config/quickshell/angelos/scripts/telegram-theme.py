#!/usr/bin/env python3
"""Telegram Desktop in angelOS's colours, heaven and hell (Settings → Window behavior →
Apps follow the theme; entry "telegram" of templates/templates.json).

  telegram-theme.py build PALETTE.json   write the theme for the palette (and realm)
  telegram-theme.py apply                hand the theme to the running ones (see push), and put
                                         its path on the clipboard for "Choose from file" where
                                         that can't be done
  telegram-theme.py push [--ask]         Freshgram (and any build with the local control socket):
                                         apply the theme there by itself — build runs it too
  telegram-theme.py status               what is set up, as JSON

Freshgram (and the Telegram builds with its "local automation") apply a theme from outside:
"CTRL:theme-apply:<base64 path>;" on the single-instance socket (an abstract one,
"@<md5 of its working dir>-<app name>"). The first time it asks the user, twice, whether to
allow local automation; after that every new palette reaches it with nothing to click. So the
theme goes there on every build when the app runs and isn't on it already — and the question is
asked once a day at the most (--ask: now, from Settings), so a "no" doesn't come back on every
theme change.

Telegram keeps watching the theme file it has applied (QFileSystemWatcher in
window_theme.cpp) and applies it again whenever the file changes. So the theme is applied
once — Telegram → Settings → Chat Settings → ⋮ → "Choose from file" → this file (`apply`
puts its path on the clipboard: Ctrl+L, Ctrl+V in the file dialog) — and from then on angelOS rewrites
~/.local/share/angelos/telegram/angelOS.tdesktop-theme for every new palette, the dark
or light mode, the demon's hell, and Telegram follows on the fly.

The colours: Telegram's own day or night palette (data/telegram/*.palette, every key
resolved) recoloured — its greys onto angelOS's surfaces and text by brightness, its blues
onto the accent, the rest (names, file icons, red and green) left alone. The chat
background is a tile of faint pixel hearts on the desk colour; in hell, embers and
pentagrams on obsidian.

Telegram draws its own text fields with these keys (historyComposeArea*, inputBorderFg,
activeLineFg, filterInput*); a box around its message field was never one of them but
angelOS's Qt stylesheet (scripts/qt-theme.py), which now leaves Telegram's fields alone.
"""
import base64
import colorsys
import io
import json
import re
import shutil
import socket
import subprocess
import sys
import time
import zipfile
from pathlib import Path

HOME = Path.home()
SHELL = Path(__file__).resolve().parent.parent
BASE = HOME / ".local/share/angelos/telegram"
THEME = BASE / "angelOS.tdesktop-theme"
STATE = BASE / "applied.json"

# hell's colours, the same as scripts/browser-theme.py and Theme.hell*
HELL = {
    "body": "#160609", "face": "#2a0b10", "faceAlt": "#3d1016", "sunken": "#0c0305",
    "edge": "#050102", "hi": "#6e1a21", "blood": "#b3142b", "ember": "#ff6a1a",
    "flame": "#ffb02e", "gold": "#d9a441", "text": "#f3d9c0", "textDim": "#a8857a",
}


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def hexa(c, alpha=""):
    return "#" + "".join("%02x" % max(0, min(255, round(v * 255))) for v in c) + alpha


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def chroma(c):
    return max(c) - min(c)


def load_palette(name):
    out = {}
    for line in (SHELL / "data/telegram" / (name + ".palette")).read_text().splitlines():
        m = re.match(r"\s*([A-Za-z]\w*)\s*:\s*(#[0-9a-fA-F]{6,8})\s*;", line)
        if m:
            out[m.group(1)] = m.group(2).lower()
    return out


def scheme(pal):
    """The surfaces, the text and the accents the theme is made of."""
    if pal.get("realm") == "hell":
        h = {k: rgb(v) for k, v in HELL.items()}
        return {
            "dark": True,
            "deep": h["edge"], "desk": h["sunken"], "face": h["body"], "faceAlt": h["face"],
            "hover": h["faceAlt"], "line": h["hi"], "textDim": h["textDim"], "text": h["text"],
            "accent": h["blood"], "accentText": h["ember"], "onAccent": h["text"],
            "bg": h["sunken"], "pattern": h["blood"],
        }
    dark = pal.get("mode") == "dark"
    p = {k: rgb(v) for k, v in pal.items() if isinstance(v, str) and re.fullmatch(r"#[0-9a-fA-F]{6}", v)}
    accent = p.get("accent", rgb("#ff8fb8"))
    text = p.get("text", rgb("#fafafa" if dark else "#2a1a22"))
    on_accent = p.get("selectText", p.get("desk")) if lum(accent) > 0.62 else rgb("#ffffff")
    return {
        "dark": dark,
        "deep": mix(p["desk"], (0, 0, 0), 0.45) if dark else mix(p["desk"], text, 0.12),
        "desk": p["desk"], "face": p["face"], "faceAlt": p["faceAlt"],
        "hover": mix(p["faceAlt"], accent, 0.12),
        "line": p.get("hi", p["faceAlt"]), "textDim": p["textDim"], "text": text,
        "accent": accent,
        # links and online text: the lighter accent in a dark theme, a deeper one in a light one
        "accentText": p.get("accent2", accent) if dark else mix(accent, text, 0.25),
        "onAccent": on_accent,
        "bg": p["desk"], "pattern": accent,
    }


def recolour(base, s):
    """Telegram's palette, key by key, in the scheme's colours."""
    dark = s["dark"]
    # Telegram's own landmarks: where its greys sit, and its two blues
    if dark:
        ramp = [(0.0, s["deep"]), (0.085, s["desk"]), (0.125, s["face"]), (0.18, s["faceAlt"]),
                (0.26, s["line"]), (0.5, s["textDim"]), (0.93, s["text"]), (1.0, mix(s["text"], (1, 1, 1), 0.5))]
        ref_dark, ref_light = rgb(base["windowBgActive"]), rgb(base["windowActiveTextFg"])
    else:
        ramp = [(0.0, s["text"]), (0.14, s["text"]), (0.6, s["textDim"]), (0.86, s["line"]),
                (0.9, s["hover"]), (0.945, s["faceAlt"]), (1.0, s["face"])]
        ref_dark, ref_light = rgb(base["windowActiveTextFg"]), rgb(base["windowBgActive"])

    def neutral(c):
        y = lum(c)
        for (y0, c0), (y1, c1) in zip(ramp, ramp[1:]):
            if y <= y1:
                return mix(c0, c1, 0 if y1 == y0 else (y - y0) / (y1 - y0))
        return ramp[-1][1]

    def hls(c):
        return colorsys.rgb_to_hls(*c)

    tgt_dark, tgt_light = hls(s["accent"]), hls(s["accentText"])
    src_dark, src_light = hls(ref_dark), hls(ref_light)

    def accent(c):
        h, l, sat = hls(c)
        # how far towards the light reference this blue is
        lo, hi = sorted((src_dark[1], src_light[1]))
        w = 0.5 if hi == lo else min(1, max(0, (l - lo) / (hi - lo)))
        if src_dark[1] > src_light[1]:
            w = 1 - w
        src = tuple(src_dark[i] + (src_light[i] - src_dark[i]) * w for i in range(3))
        tgt = tuple(tgt_dark[i] + (tgt_light[i] - tgt_dark[i]) * w for i in range(3))
        nh = (tgt[0] + (h - src[0]) * 0.3) % 1.0
        nl = min(0.96, max(0.04, l + (tgt[1] - src[1])))
        ns = min(1.0, max(0.0, sat * (tgt[2] / src[2] if src[2] > 0.01 else 1)))
        return colorsys.hls_to_rgb(nh, nl, ns)

    out = {}
    for key, val in base.items():
        c, alpha = rgb(val[:7]), val[7:9]
        h = colorsys.rgb_to_hls(*c)[0] * 360
        if val[:7] == "#ffffff" and re.search(r"Active|activeButton|Unread|Badge", key) and not re.search(r"Bg(Over|Ripple|Active)?$", key):
            n = s["onAccent"]                                # white on a filled accent
        elif key in ("imageBg", "imageBgTransparent") or (val[:7] == "#000000" and alpha):
            n = c                                            # shadows and photo fills stay
        elif chroma(c) < 0.22:
            n = neutral(c)
        elif 180 <= h <= 245:
            n = accent(c)
        else:
            n = c                                            # names, file icons, red, green
        out[key] = hexa(n, alpha)
    return out


def tile(s):
    """The chat background: a 48 px tile, faint pixel hearts (or embers and a pentagram)."""
    from PIL import Image, ImageDraw
    hell = s["pattern"] == rgb(HELL["blood"])
    size = 48
    bg = s["bg"]
    img = Image.new("RGB", (size, size), hexa(bg))
    d = ImageDraw.Draw(img)
    ink = mix(bg, s["pattern"], 0.16 if s["dark"] else 0.2)
    ink2 = mix(bg, s["pattern"], 0.09 if s["dark"] else 0.12)
    px = 2

    def blit(rows, x0, y0, col):
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch == "#":
                    d.rectangle([x0 + x * px, y0 + y * px, x0 + x * px + px - 1, y0 + y * px + px - 1], fill=hexa(col))

    if hell:
        star = ["..#..", "#####", ".#.#.", "#...#"]           # a tiny pentagram-ish star
        blit(star, 6, 8, ink)
        for (x, y) in ((34, 30), (38, 6), (14, 38), (26, 20)):
            d.rectangle([x, y, x + 1, y + 1], fill=hexa(mix(bg, rgb(HELL["ember"]), 0.22)))
        blit(star, 30, 36, ink2)
    else:
        heart = [".#.#.", "#####", "#####", ".###.", "..#.."]
        blit(heart, 6, 6, ink)
        blit(heart, 30, 30, ink2)
        for (x, y) in ((36, 10), (12, 36)):
            d.rectangle([x, y, x + 1, y + 1], fill=hexa(ink2))
    buf = io.BytesIO()
    img.save(buf, "PNG")
    return buf.getvalue()


def build(pal):
    s = scheme(pal)
    base = load_palette("night" if s["dark"] else "day")
    colours = recolour(base, s)
    head = "// angelOS — %s (rewritten by angelOS on every theme change; Telegram follows the file)\n" % (
        "hell, while the demon rules" if pal.get("realm") == "hell" else "heaven, the angelOS palette")
    text = head + "".join("%s: %s;\n" % kv for kv in colours.items())
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        # a fixed date: the same colours give the same bytes, so nothing is rewritten for nothing
        for name, data in (("colors.tdesktop-theme", text.encode()), ("tiled.png", tile(s))):
            info = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, data)
    data = buf.getvalue()
    if THEME.exists() and THEME.read_bytes() == data:
        return False
    BASE.mkdir(parents=True, exist_ok=True)
    tmp = THEME.with_name(THEME.name + ".tmp")
    tmp.write_bytes(data)
    tmp.replace(THEME)
    return True


# the apps with the single-instance socket of Telegram Desktop's kind; the ones without local
# control just log an unknown command
SOCKET = re.compile(r"^@([0-9a-f]{32})-(freshGram|Telegram|AyuGram\w*|64Gram|Kotatogram|exteraGram)$")
ASK_EVERY = 24 * 3600


def own_hashes():
    """md5 of the folders an app of this home could keep its data in: the socket's name is the
    md5 of its working dir, so only this user's own apps match — /proc/net/unix lists every
    socket of the machine (a test's throw-away home must never reach the real Freshgram)"""
    import hashlib
    out = set()
    for base in (HOME / ".local/share", *(HOME / ".var/app").glob("*/data")):
        try:
            dirs = [d for d in base.iterdir() if d.is_dir()]
        except OSError:
            continue
        for d in dirs:
            out.add(hashlib.md5(str(d.resolve()).encode()).hexdigest())
    return out


def sockets():
    names, mine = [], own_hashes()
    try:
        for line in Path("/proc/net/unix").read_text().splitlines()[1:]:
            parts = line.split()
            m = SOCKET.match(parts[-1]) if len(parts) >= 8 else None
            if m and m.group(1) in mine and parts[-1] not in names:
                names.append(parts[-1])
    except OSError:
        pass
    return names


def control(name, command):
    """one local-control command → its JSON answer (None: no answer, an older build)"""
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(3)
    try:
        s.connect("\0" + name[1:])
        s.sendall(("CTRL:" + command + ";").encode())
        buf = b""
        while not buf.endswith(b";"):
            chunk = s.recv(65536)
            if not chunk:
                break
            buf += chunk
    except OSError:
        return None
    finally:
        s.close()
    m = re.search(rb"DATA:([A-Za-z0-9+/=]*);", buf)
    if not m:
        return None
    try:
        return json.loads(base64.b64decode(m.group(1)))
    except ValueError:
        return None


def load_state():
    try:
        return json.loads(STATE.read_text())
    except (OSError, ValueError):
        return {}


def save_state(st):
    BASE.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(st) + "\n")


def push(ask=False):
    """the theme into every running app that takes it from outside; {app: what happened}"""
    if not THEME.exists():
        return {}
    names = sockets()
    if not names:
        return {}
    st = load_state()
    before = json.dumps(st, sort_keys=True)
    apps = st.setdefault("apps", {})
    out = {}
    for name in names:
        app = name.split("-", 1)[1]
        seen = apps.setdefault(app, {})
        # its question about local automation: once a day at the most, unless asked from Settings
        if not seen.get("allowed") and not ask and time.time() - seen.get("askedAt", 0) < ASK_EVERY:
            out[app] = "waiting for the user's yes"
            continue
        now = control(name, "theme")
        if now is None:
            out[app] = "no local control"
            seen["control"] = False
            continue
        seen["control"] = True
        if not now.get("ok"):
            # "local automation is disabled — confirm in the Telegram window": it asks the user now
            seen["allowed"] = False
            seen["askedAt"] = time.time()
            out[app] = "asked the user to allow it"
            continue
        seen["allowed"] = True
        if now.get("path") == str(THEME) or now.get("editing"):
            out[app] = "on the theme already" if not now.get("editing") else "its theme editor is open"
            continue
        # once it had ours, another theme there is the user's pick: left alone until Settings asks
        if seen.get("applied") and not ask:
            out[app] = "another theme picked there: left alone"
            continue
        r = control(name, "theme-apply:" + base64.b64encode(str(THEME).encode()).decode())
        ok = bool(r and r.get("ok"))
        seen["applied"] = seen.get("applied") or ok
        out[app] = "applied" if ok else "not applied: " + str((r or {}).get("error", "no answer"))
    # only what changed is written (an update's restore puts every file back as it was)
    if json.dumps(st, sort_keys=True) != before:
        save_state(st)
    return out


def telegram_bin():
    for b in ("Telegram", "telegram-desktop"):
        if shutil.which(b):
            return [b]
    if shutil.which("flatpak") and subprocess.run(["flatpak", "info", "org.telegram.desktop"], capture_output=True).returncode == 0:
        return ["flatpak", "run", "org.telegram.desktop"]
    return None


def apply():
    """The running apps with local control get the theme straight away (asking the user to
    allow it, the first time); official Telegram has no way from outside — a file handed to it
    on the command line is offered for sending to a chat — so its user picks it once in
    "Choose from file": the path goes on the clipboard."""
    if not THEME.exists():
        print(json.dumps({"ok": False, "error": "no theme yet: change the palette once, or run build"}))
        return 1
    pushed = push(ask=True)
    subprocess.run(["wl-copy", str(THEME)], capture_output=True)
    st = load_state()
    st["asked"] = True
    save_state(st)
    print(json.dumps({"ok": True, "copied": str(THEME), "pushed": pushed}))
    return 0


def status():
    st = load_state()
    asked = st.get("asked", False)
    print(json.dumps({
        "apps": st.get("apps", {}),
        "installed": telegram_bin() is not None,
        "running": subprocess.run(["pgrep", "-x", "Telegram"], capture_output=True).returncode == 0
        or subprocess.run(["pgrep", "-x", "telegram-deskto"], capture_output=True).returncode == 0,
        "theme": str(THEME),
        "exists": THEME.exists(),
        "asked": asked,
    }))


def main():
    a = sys.argv[1:]
    if len(a) == 2 and a[0] == "build":
        pal = json.loads(Path(a[1]).read_text())
        changed = build(pal)
        pushed = push()
        print(json.dumps({"ok": True, "changed": changed, "realm": pal.get("realm", "heaven"), "pushed": pushed}))
    elif a == ["apply"]:
        sys.exit(apply())
    elif a and a[0] == "push":
        print(json.dumps(push(ask="--ask" in a)))
    elif a == ["status"]:
        status()
    else:
        print(__doc__, file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
