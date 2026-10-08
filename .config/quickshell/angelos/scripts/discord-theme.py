#!/usr/bin/env python3
"""Discord and Vesktop in angelOS's pixels and colours, heaven and hell (Settings → Window
behavior → Apps follow the theme; entry "discord" of templates/templates.json).

  discord-theme.py build PALETTE.json   write the theme for the palette (realm, circle, mode,
                                        fonts) and put it in every Vencord's themes folder
  discord-theme.py apply [CLIENT]       make it the client's theme (the client closed; the two
                                        keys it changes are saved once, for revert)
  discord-theme.py revert [CLIENT]      put those two keys back
  discord-theme.py launch [ARGS…]       Discord without Vencord: start it with a debugging
                                        port on localhost and keep the theme in it
  discord-theme.py inject --port N [--once]
                                        the same, into a Chromium already listening on N
  discord-theme.py launcher on|off      open Discord through `launch` from the app menu
  discord-theme.py status               what is set up, as JSON

With Vencord (Vesktop has it built in; Equibop and Equicord are its forks): the theme is
~/.local/share/angelos/discord/angelOS.theme.css, copied into <client>/themes/. Vencord
watches that folder (its patcher.js: watch(THEMES_DIR) → "VencordThemeUpdate") and reloads
the themes when a file there changes, so an open Discord follows every palette, light or
dark, heaven or the demon's hell, on the fly. A file of that name angelOS did not write (no
"written by angelOS" in its head) is left alone. Vencord does not watch its settings.json and
writes it back from memory while it runs: `apply` only touches it with the client closed;
with it open, Vencord → Themes → angelOS is one click.

Without Vencord Discord takes no themes, so `launch` starts it with
--remote-debugging-port=<a free port> (its own chromiumSwitches in settings.json take no
values) and puts the theme into its page over the DevTools protocol (Runtime.evaluate: a
constructed stylesheet, which no CSP blocks), again after a reload (Ctrl+R) and whenever the
theme file changes. That port lets any local program — any Flatpak with network access too
— drive the open Discord: it is only opened when the person asked for it (`launcher on`),
never with --remote-allow-origins, so no web page can reach it. A Discord with Vencord and
the theme active is started as it is, no port.

The look (data/discord/angelos.css on the --ao-* variables written here): corners a little
round everywhere (--ao-r), squared-off avatars and server icons, Win98 bevels, hard pixel shadows, the window's top
strip like an angelOS title bar, pixel fonts, faint pixel hearts behind the chat (embers and
a pentagram in hell).
"""
import base64
import hashlib
import json
import os
import re
import shutil
import signal
import socket
import struct
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

HOME = Path.home()
SHELL = Path(__file__).resolve().parent.parent
SRC = SHELL / "data/discord/angelos.css"
HELL_FONT = SHELL / "data/fonts/Jacquard12Hell-Regular.ttf"
BASE = HOME / ".local/share/angelos/discord"
NAME = "angelOS.theme.css"
THEME = BASE / NAME
BEFORE = BASE / "before.json"
MARK = "written by angelOS"
STATE = Path(os.environ.get("XDG_RUNTIME_DIR") or BASE) / "angelos-discord.json"
APPS = Path(os.environ.get("XDG_DATA_HOME") or HOME / ".local/share") / "applications"
# the page Discord's app is (the tests point it at a page of their own)
URL_MATCH = os.environ.get("ANGELOS_DISCORD_URL_MATCH", "discord.com")
FLATPAK = "com.discordapp.Discord"
VAR = HOME / ".var/app"
CFG = HOME / ".config"

# every Vencord there can be: (id, name, its data folder, how it runs: process names or a Flatpak id)
CLIENTS = [
    ("vencord", "Discord + Vencord", CFG / "Vencord", {"proc": ["Discord", "discord", "DiscordPTB", "DiscordCanary"]}),
    ("vencord-flatpak", "Discord + Vencord (Flatpak)", VAR / FLATPAK / "config/Vencord", {"flatpak": FLATPAK}),
    ("vesktop", "Vesktop", CFG / "vesktop", {"proc": ["vesktop", "Vesktop"]}),
    ("vesktop-flatpak", "Vesktop (Flatpak)", VAR / "dev.vencord.Vesktop/config/vesktop", {"flatpak": "dev.vencord.Vesktop"}),
    ("equibop", "Equibop", CFG / "equibop", {"proc": ["equibop", "Equibop"]}),
    ("equibop-flatpak", "Equibop (Flatpak)", VAR / "io.github.equicord.equibop/config/equibop", {"flatpak": "io.github.equicord.equibop"}),
    ("equicord", "Discord + Equicord", CFG / "Equicord", {"proc": ["Discord", "discord", "DiscordPTB", "DiscordCanary"]}),
    ("equicord-flatpak", "Discord + Equicord (Flatpak)", VAR / FLATPAK / "config/Equicord", {"flatpak": FLATPAK}),
]

# Discord itself (for `launch`): native installs and the Flatpak
DISCORD_BINS = ["discord", "Discord", "/opt/discord/Discord", "/usr/lib/discord/Discord", "/usr/share/discord/Discord"]
DISCORD_ASARS = ["/opt/discord/resources/app.asar", "/usr/lib/discord/resources/app.asar",
                 "/usr/share/discord/resources/app.asar", "/usr/lib/discord/app.asar"]
FLATPAK_ROOTS = [HOME / ".local/share/flatpak/app" / FLATPAK / "current/active/files",
                 Path("/var/lib/flatpak/app") / FLATPAK / "current/active/files"]


# ---- colours ----

def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def hexa(c):
    return "#" + "".join("%02x" % max(0, min(255, round(v * 255))) for v in c)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def rel(c):
    """relative luminance (WCAG), for contrast"""
    f = [v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4 for v in c]
    return 0.2126 * f[0] + 0.7152 * f[1] + 0.0722 * f[2]


def contrast(a, b):
    la, lb = sorted((rel(a), rel(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def apart(c, ground, toward, need, most=1.0):
    """c moved towards `toward` (at most `most` of the way) until it stands `need` apart from
    `ground`: a bevel or a frame that a wallpaper palette made the colour it sits on"""
    t = 0.0
    out = c
    while contrast(out, ground) < need and t < most - 1e-9:
        t += 0.05
        out = mix(c, toward, t)
    return out


def scheme(pal):
    """The --ao-* colours: the surfaces from the rail to the chat, the bevel, the text, the
    accents. Heaven from angelOS's palette (its light or dark mode, not Discord's); hell from
    the circle the demon rules (pal["hell"]), like scripts/steam-theme.py."""
    hell = pal.get("realm") == "hell" and pal.get("hell")
    if hell:
        h = {k: rgb(v) for k, v in hell.items() if isinstance(v, str) and v.startswith("#")}
        dark = True
        s = {
            "deep": h["edge"], "desk": h["body"], "face": h["face"], "faceAlt": h["faceAlt"],
            "sunken": h["sunken"], "hi": h["hi"], "lo": h["lo"], "edge": h["edge"],
            "text": h["text"], "textDim": h["textDim"],
            "accent": h["accent"], "accent2": h["flame"],
            "accentText": mix(h["accent"], h["text"], 0.35),
            "title1": mix(h["faceAlt"], h["blood"], 0.55), "title2": h["face"],
            "titleText": h["flame"],
            "danger": mix(h["accent"], h["blood"], 0.3), "ok": h["ok"], "warn": h["gold"],
            "shadow": (0, 0, 0), "pattern": h["blood"], "ember": h["ember"],
        }
    else:
        p = {k: rgb(v) for k, v in pal.items() if isinstance(v, str) and re.fullmatch(r"#[0-9a-fA-F]{6}", v)}
        dark = pal.get("mode") != "light"
        text = p.get("text", rgb("#fafafa" if dark else "#2a1a22"))
        accent = p.get("accent", rgb("#ff8fb8"))
        face = p.get("face", rgb("#2a2440" if dark else "#f4e8f0"))
        desk = p.get("desk", face)
        face_alt = p.get("faceAlt", face)
        s = {
            "deep": mix(desk, (0, 0, 0), 0.45) if dark else mix(desk, text, 0.12),
            "desk": desk, "face": face, "faceAlt": face_alt,
            "sunken": p.get("sunken", desk),
            "hi": p.get("hi", face_alt), "lo": p.get("lo", desk), "edge": p.get("edge", desk),
            "text": text, "textDim": p.get("textDim", mix(text, face, 0.35)),
            "accent": accent, "accent2": p.get("accent2", accent),
            # links: the lighter accent in a dark theme, a deeper one in a light one
            "accentText": p.get("accent2", accent) if dark else mix(accent, text, 0.25),
            "title1": p.get("title1", accent), "title2": p.get("title2", accent),
            "titleText": p.get("titleText", rgb("#ffffff")),
            "danger": p.get("danger", rgb("#ff4f6d")), "ok": p.get("ok", rgb("#57e3a2")),
            "warn": p.get("color3", rgb("#e2b45a")),
            "shadow": p.get("shadow", (0, 0, 0)), "pattern": accent, "ember": accent,
        }
    # the bevel and the frame: a wallpaper palette can make hi the face, lo and edge the desk —
    # nothing would show. Light up hi, darken lo and edge until they read against the face.
    white, black = (1, 1, 1), (0, 0, 0)
    s["hi"] = apart(s["hi"], s["face"], white, 1.35)
    s["lo"] = apart(s["lo"], s["face"], black, 1.35, 0.6)
    s["edge"] = apart(s["edge"], s["face"], black if dark else s["text"], 1.8)
    s["dark"] = dark
    s["hell"] = bool(hell)
    s["hover"] = mix(s["faceAlt"], s["accent"], 0.14)
    s["active"] = mix(s["faceAlt"], s["accent"], 0.28)
    s["muted"] = mix(s["textDim"], s["face"], 0.4)
    s["strong"] = mix(s["text"], white if dark else black, 0.35)
    s["accentHover"] = mix(s["accent"], white if dark else black, 0.12)
    s["accentActive"] = mix(s["accent"], black, 0.18)
    s["onAccent"] = (s["text"] if hell else rgb("#ffffff")) if lum(s["accent"]) < 0.62 else s["desk"]
    return s


def pattern(s):
    """The chat's ground: a 48 px tile of faint pixel hearts (in hell embers and a pentagram),
    its colours baked in, as an SVG data URL."""
    bg = s["sunken"]
    ink = hexa(mix(bg, s["pattern"], 0.16 if s["dark"] else 0.2))
    ink2 = hexa(mix(bg, s["pattern"], 0.09 if s["dark"] else 0.12))
    rects = []

    def blit(rows, x0, y0, col, px=2):
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch == "#":
                    rects.append('<rect x="%d" y="%d" width="%d" height="%d" fill="%s"/>' % (x0 + x * px, y0 + y * px, px, px, col))

    if s["hell"]:
        star = ["..#..", "#####", ".#.#.", "#...#"]
        blit(star, 6, 8, ink)
        blit(star, 30, 36, ink2)
        ember = hexa(mix(bg, s["ember"], 0.22))
        for (x, y) in ((34, 30), (38, 6), (14, 38), (26, 20)):
            rects.append('<rect x="%d" y="%d" width="2" height="2" fill="%s"/>' % (x, y, ember))
    else:
        heart = [".#.#.", "#####", "#####", ".###.", "..#.."]
        blit(heart, 6, 6, ink)
        blit(heart, 30, 30, ink2)
        for (x, y) in ((36, 10), (12, 36)):
            rects.append('<rect x="%d" y="%d" width="2" height="2" fill="%s"/>' % (x, y, ink2))
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" shape-rendering="crispEdges">'
           + "".join(rects) + "</svg>")
    return 'url("data:image/svg+xml,%s")' % re.sub(r'[<>#"%]', lambda m: "%%%02X" % ord(m.group(0)), svg)


def font_stack(name, *fallback):
    names = [name] + [f for f in fallback if f and f != name]
    return ", ".join('"%s"' % n for n in names) + ", sans-serif"


def variables(pal, s):
    hell = s["hell"]
    title = pal.get("fontTitle") or "Pixeloid Sans"
    if hell:
        # hell's own gothic Jacquard for the headings
        title_stack = font_stack("Jacquard 12 Hell", "Pixeloid Sans", title)
    else:
        title_stack = font_stack(title, "Pixeloid Sans")
    # what is read and typed stays a plain sans at Discord's own size: pixel fonts are too
    # small and tiring there (the user's call, 2026-10-08) — only the headings are pixel
    body_stack = font_stack("gg sans", "Inter", "Noto Sans")
    mono_stack = '"gg mono", "JetBrains Mono", "DejaVu Sans Mono", monospace'
    shadow = hexa(s["shadow"])
    names = ["deep", "desk", "face", "faceAlt", "sunken", "hover", "active", "hi", "lo", "edge",
             "text", "textDim", "muted", "strong", "accent", "accent2", "accentText", "accentHover",
             "accentActive", "onAccent", "title1", "title2", "titleText", "danger", "ok", "warn"]
    out = ["    --ao-%s: %s;" % (n, hexa(s[n])) for n in names]
    out += [
        "    --ao-shadow: color-mix(in srgb, %s %d%%, transparent);" % (shadow, 55 if s["dark"] else 35),
        "    --ao-font-title: %s;" % title_stack,
        "    --ao-font-body: %s;" % body_stack,
        "    --ao-font-mono: %s;" % mono_stack,
        "    --ao-pattern: %s;" % pattern(s),
        "    --ao-realm: %s;" % ("hell" if hell else "heaven"),
        "    --ao-scheme: %s;" % ("dark" if s["dark"] else "light"),
    ]
    return ":root {\n" + "\n".join(out) + "\n}\n"


def hell_font():
    """Jacquard 12 Hell is angelOS's own (loaded by the shell, not installed): in the theme
    itself, as a data: URL (Vencord lets data: fonts through Discord's CSP; without Vencord the
    font falls back to Pixeloid)."""
    try:
        data = base64.b64encode(HELL_FONT.read_bytes()).decode()
    except OSError:
        return ""
    return ('@font-face {\n    font-family: "Jacquard 12 Hell";\n    src: local("Jacquard 12 Hell"), '
            'url(data:font/ttf;base64,%s) format("truetype");\n    font-display: swap;\n}\n' % data)


def theme(pal):
    s = scheme(pal)
    realm = "hell (%s)" % pal["hell"].get("circle", "") if s["hell"] else "heaven, %s" % ("dark" if s["dark"] else "light")
    head = ("/**\n * @name angelOS\n * @author angelOS\n"
            " * @description Discord in angelOS's pixels: heaven and hell, light and dark — it follows the desktop on the fly.\n"
            " * @version 1.0.0\n */\n"
            "/* %s (scripts/discord-theme.py) for %s: rewritten on every theme change, edits here are lost */\n" % (MARK, realm))
    return head + variables(pal, s) + (hell_font() if s["hell"] else "") + SRC.read_text()


# ---- files ----

def write(path, text):
    """Write when it changed (Vencord reloads the themes on every change it sees), atomically."""
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_file() and path.read_text(errors="replace") == text:
        return False
    tmp = path.with_name("." + path.name + ".tmp")
    tmp.write_text(text)
    tmp.replace(path)
    return True


def ours(path):
    try:
        with open(path, errors="replace") as f:
            return MARK in f.read(2048)
    except OSError:
        return False


def clients():
    """The Vencords there are: their data folder exists (each makes it on its first start)."""
    return [c for c in CLIENTS if c[2].is_dir()]


def pick(cid):
    found = clients()
    if not cid:
        return found
    return [c for c in found if c[0] == cid]


def build(palette_file):
    pal = json.loads(Path(palette_file).read_text())
    text = theme(pal)
    changed = write(THEME, text)
    out = {"ok": True, "changed": changed, "realm": pal.get("realm", "heaven"), "theme": str(THEME), "clients": {}}
    for cid, _, data, _ in clients():
        dest = data / "themes" / NAME
        if dest.exists() and not ours(dest):
            out["clients"][cid] = "skipped: not angelOS's"
            continue
        out["clients"][cid] = "changed" if write(dest, text) else "same"
    print(json.dumps(out))


# ---- the clients' settings ----

def flatpak_running(app):
    try:
        r = subprocess.run(["flatpak", "ps", "--columns=application"], capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return False
    return app in r.stdout.split()


def native_running(names):
    """A process of one of these names outside a Flatpak (a Flatpak's Discord runs /app/…)."""
    me = os.getuid()
    for d in Path("/proc").iterdir():
        if not d.name.isdigit():
            continue
        try:
            if d.stat().st_uid != me:
                continue
            comm = (d / "comm").read_text().strip()
            if comm not in names:
                continue
            argv0 = (d / "cmdline").read_bytes().split(b"\0")[0].decode(errors="replace")
        except OSError:
            continue
        if not argv0.startswith("/app/"):
            return True
    return False


def running(client):
    how = client[3]
    if "flatpak" in how:
        return flatpak_running(how["flatpak"])
    return native_running(how["proc"])


def settings_path(client):
    return client[2] / "settings/settings.json"


def read_json(path, default):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return default


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name("." + path.name + ".tmp")
    tmp.write_text(json.dumps(data, indent=4, ensure_ascii=False) + "\n")
    tmp.replace(path)


def apply(cid):
    """enabledThemes := [angelOS], themeLinks := [] (a linked theme is always on in Vencord and
    would paint over ours); useQuickCss and the rest stay. The two keys as they were go to
    before.json once, the whole settings.json to settings.json.angelos-before once."""
    targets = pick(cid)
    if not targets:
        return {"ok": False, "error": "no Vencord" if not cid else "no such client: " + cid}
    out = {"ok": True, "done": [], "running": [], "already": []}
    before = read_json(BEFORE, {})
    for c in targets:
        if running(c):
            out["running"].append(c[0])
            continue
        path = settings_path(c)
        cfg = read_json(path, None)
        if not isinstance(cfg, dict):
            cfg = {}
        if cfg.get("enabledThemes") == [NAME] and not cfg.get("themeLinks"):
            out["already"].append(c[0])
            continue
        if c[0] not in before:
            before[c[0]] = {k: cfg[k] for k in ("enabledThemes", "themeLinks") if k in cfg}
            write_json(BEFORE, before)
        if path.exists():
            backup = path.with_name("settings.json.angelos-before")
            if not backup.exists():
                shutil.copy2(path, backup)
        cfg["enabledThemes"] = [NAME]
        cfg["themeLinks"] = []
        write_json(path, cfg)
        out["done"].append(c[0])
    if out["running"]:
        out["ok"] = bool(out["done"] or out["already"])
        out["error"] = "running"
    return out


def revert(cid):
    targets = pick(cid)
    before = read_json(BEFORE, {})
    out = {"ok": True, "done": [], "running": []}
    for c in targets:
        if c[0] not in before:
            continue
        if running(c):
            out["running"].append(c[0])
            continue
        path = settings_path(c)
        cfg = read_json(path, {})
        for k in ("enabledThemes", "themeLinks"):
            if k in before[c[0]]:
                cfg[k] = before[c[0]][k]
            else:
                cfg.pop(k, None)
        write_json(path, cfg)
        del before[c[0]]
        out["done"].append(c[0])
    write_json(BEFORE, before)
    if out["running"]:
        out["ok"] = False
        out["error"] = "running"
    return out


def active(client):
    cfg = read_json(settings_path(client), {})
    return isinstance(cfg, dict) and NAME in (cfg.get("enabledThemes") or [])


# ---- Discord itself ----

def asar_vencord(path):
    """app.asar of a patched Discord is a one-line require of Vencord's (or Equicord's) patcher"""
    try:
        with open(path, "rb") as f:
            head = f.read(4096)
    except OSError:
        return False
    return b"Vencord" in head or b"Equicord" in head or b"patcher.js" in head


def discord():
    """How Discord is started here, and whether Vencord sits in it: {"cmd": […], "kind", "vencord"}"""
    cmd = os.environ.get("ANGELOS_DISCORD_CMD")
    if cmd:
        return {"cmd": cmd.split(), "kind": "test", "vencord": False, "clients": []}
    for b in DISCORD_BINS:
        path = shutil.which(b) if "/" not in b else (b if os.access(b, os.X_OK) else None)
        if path:
            real = os.path.realpath(path)
            asars = [os.path.join(os.path.dirname(real), "resources/app.asar")] + DISCORD_ASARS
            return {"cmd": [path], "kind": "native", "vencord": any(asar_vencord(a) for a in asars),
                    "clients": ["vencord", "equicord"]}
    if shutil.which("flatpak"):
        for root in FLATPAK_ROOTS:
            if root.is_dir():
                return {"cmd": ["flatpak", "run", FLATPAK], "kind": "flatpak",
                        "vencord": asar_vencord(root / "discord/resources/app.asar"),
                        "clients": ["vencord-flatpak", "equicord-flatpak"]}
    return None


def discord_running(d):
    if d["kind"] == "flatpak":
        return flatpak_running(FLATPAK)
    if d["kind"] == "native":
        return native_running(["Discord", "discord"])
    return False


def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def notify(text):
    if shutil.which("notify-send") and not os.environ.get("ANGELOS_TEST"):
        subprocess.run(["notify-send", "-a", "angelOS", "Discord", text], capture_output=True)
    print(text, file=sys.stderr)


def launch(args):
    d = discord()
    if not d:
        notify("Discord не найден")
        return 1
    themed = d["vencord"] and any(active(c) for c in pick(None) if c[0] in d["clients"])
    if themed:
        # Vencord shows the theme itself: no port to open
        os.execvp(d["cmd"][0], d["cmd"] + args)
    st = read_json(STATE, {})
    if st.get("pid") and pid_alive(st["pid"]):
        # our own launch is running and keeps the theme: Discord just comes to the front
        subprocess.Popen(d["cmd"] + args, start_new_session=True)
        return 0
    if discord_running(d):
        notify("Discord уже открыт без angelOS — тема появится, когда он будет запущен заново через angelOS "
               "(закрой Discord и открой его снова из меню)")
        subprocess.Popen(d["cmd"] + args, start_new_session=True)
        return 0
    port = free_port()
    child = subprocess.Popen(d["cmd"] + ["--remote-debugging-port=%d" % port] + args, start_new_session=True)
    write_json(STATE, {"pid": os.getpid(), "port": port, "child": child.pid})
    try:
        loop(port, alive=lambda: child.poll() is None)
    finally:
        if read_json(STATE, {}).get("pid") == os.getpid():
            try:
                STATE.unlink()
            except OSError:
                pass
    return 0


def pid_alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except (OSError, TypeError):
        return False


# ---- a WebSocket client on the standard library (no websocket module here) ----

class WS:
    def __init__(self, url, timeout=5):
        m = re.match(r"ws://([^/:]+):(\d+)(/.*)", url)
        if not m:
            raise ValueError("not a ws:// url: " + url)
        host, port, path = m.group(1), int(m.group(2)), m.group(3)
        self.sock = socket.create_connection((host, port), timeout=timeout)
        key = base64.b64encode(os.urandom(16)).decode()
        # no Origin header: Chromium only lets origins it was told about (--remote-allow-origins) in
        self.sock.sendall(("GET %s HTTP/1.1\r\nHost: %s:%d\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
                           "Sec-WebSocket-Key: %s\r\nSec-WebSocket-Version: 13\r\n\r\n" % (path, host, port, key)).encode())
        head = b""
        while b"\r\n\r\n" not in head:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise ConnectionError("closed during the handshake")
            head += chunk
        head, self.buf = head.split(b"\r\n\r\n", 1)
        if b" 101 " not in head.split(b"\r\n")[0]:
            raise ConnectionError(head.split(b"\r\n")[0].decode(errors="replace"))
        accept = base64.b64encode(hashlib.sha1((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest())
        if accept not in head:
            raise ConnectionError("bad Sec-WebSocket-Accept")
        self.id = 0

    def _send(self, op, data):
        mask = os.urandom(4)
        n = len(data)
        if n < 126:
            hdr = struct.pack("!BB", 0x80 | op, 0x80 | n)
        elif n < 1 << 16:
            hdr = struct.pack("!BBH", 0x80 | op, 0x80 | 126, n)
        else:
            hdr = struct.pack("!BBQ", 0x80 | op, 0x80 | 127, n)
        self.sock.sendall(hdr + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))

    def _read(self, n):
        while len(self.buf) < n:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise ConnectionError("closed")
            self.buf += chunk
        out, self.buf = self.buf[:n], self.buf[n:]
        return out

    def recv(self):
        """one whole text message (fragments joined; pings answered)"""
        parts = []
        while True:
            b0, b1 = self._read(2)
            op, n = b0 & 0x0F, b1 & 0x7F
            if n == 126:
                n = struct.unpack("!H", self._read(2))[0]
            elif n == 127:
                n = struct.unpack("!Q", self._read(8))[0]
            mask = self._read(4) if b1 & 0x80 else None
            data = self._read(n)
            if mask:
                data = bytes(b ^ mask[i % 4] for i, b in enumerate(data))
            if op == 0x9:
                self._send(0xA, data)
                continue
            if op == 0xA:
                continue
            if op == 0x8:
                raise ConnectionError("closed by the browser")
            parts.append(data)
            if b0 & 0x80:
                return b"".join(parts).decode(errors="replace")

    def call(self, method, params=None):
        self.id += 1
        self._send(0x1, json.dumps({"id": self.id, "method": method, "params": params or {}}).encode())
        while True:
            msg = json.loads(self.recv())
            if msg.get("id") == self.id:
                if "error" in msg:
                    raise RuntimeError(msg["error"].get("message", "CDP error"))
                return msg.get("result", {})

    def evaluate(self, expr):
        r = self.call("Runtime.evaluate", {"expression": expr, "returnByValue": True})
        if r.get("exceptionDetails"):
            raise RuntimeError(r["exceptionDetails"].get("text", "exception"))
        return r.get("result", {}).get("value")

    def close(self):
        try:
            self._send(0x8, b"")
            self.sock.close()
        except OSError:
            pass


# ---- the theme into the page ----

PROBE = "(window.__angelosDiscord && document.adoptedStyleSheets.includes(window.__angelosDiscord.sheet)) ? window.__angelosDiscord.v : ''"

INJECT = """(function (css, v) {
    var st = window.__angelosDiscord;
    var sheet = st && st.sheet || new CSSStyleSheet();
    sheet.replaceSync(css);
    if (!document.adoptedStyleSheets.includes(sheet))
        document.adoptedStyleSheets = document.adoptedStyleSheets.concat([sheet]);
    window.__angelosDiscord = {v: v, sheet: sheet};
    var mark = document.getElementById("angelos-discord");
    if (!mark) {
        mark = document.createElement("meta");
        mark.id = "angelos-discord";
        document.head.appendChild(mark);
    }
    mark.dataset.v = v;
    return v;
})(%s, %s)"""


def targets(port):
    with urllib.request.urlopen("http://127.0.0.1:%d/json/list" % port, timeout=3) as r:
        return [t for t in json.loads(r.read()) if t.get("type") == "page" and URL_MATCH in t.get("url", "")
                and t.get("webSocketDebuggerUrl")]


def theme_text():
    """The theme for the page: @font-face rules and all; its hash is its version."""
    text = THEME.read_text()
    return text, hashlib.sha1(text.encode()).hexdigest()[:12]


def loop(port, alive=lambda: True, once=False, interval=1.0):
    """Keep the theme in every Discord page on that port: a cheap probe each round, the whole
    theme only when the page lacks it (new page, Ctrl+R) or the file changed."""
    socks = {}
    mtime, text, ver = None, "", ""
    applied = 0
    deadline = time.monotonic() + 60
    while alive():
        try:
            m = THEME.stat().st_mtime_ns
            if m != mtime:
                text, ver = theme_text()
                mtime = m
        except OSError:
            text, ver = "", ""
        try:
            pages = targets(port)
        except (OSError, ValueError):
            pages = None
        if pages is not None and text:
            seen = set()
            for t in pages:
                seen.add(t["id"])
                try:
                    ws = socks.get(t["id"]) or WS(t["webSocketDebuggerUrl"])
                    socks[t["id"]] = ws
                    if ws.evaluate(PROBE) != ver:
                        ws.evaluate(INJECT % (json.dumps(text), json.dumps(ver)))
                        applied += 1
                except (OSError, ValueError, RuntimeError, ConnectionError):
                    ws = socks.pop(t["id"], None)
                    if ws:
                        ws.close()
            for gone in set(socks) - seen:
                socks.pop(gone).close()
            if once and pages:
                break
        if once and time.monotonic() > deadline:
            break
        time.sleep(interval)
    for ws in socks.values():
        ws.close()
    return applied


# ---- the app menu ----

def desktop_source():
    """The installed Discord's .desktop file: the Flatpak's export or the package's."""
    dirs = (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":")
    dirs += [str(HOME / ".local/share/flatpak/exports/share"), "/var/lib/flatpak/exports/share"]
    for name in (FLATPAK + ".desktop", "discord.desktop", "Discord.desktop"):
        for d in dirs:
            p = Path(d) / "applications" / name
            if p.is_file():
                return p
    return None


def launcher(on):
    src = desktop_source()
    if not src:
        return {"ok": False, "error": "no Discord"}
    dest = APPS / src.name
    if not on:
        if dest.exists() and "X-AngelOS=discord" in dest.read_text(errors="replace"):
            dest.unlink()
            return {"ok": True, "launcher": False}
        return {"ok": True, "launcher": False, "note": "not ours" if dest.exists() else "none"}
    if dest.exists() and "X-AngelOS=discord" not in dest.read_text(errors="replace"):
        return {"ok": False, "error": "%s is someone else's" % dest}
    exe = "python3 %s launch" % SHELL.joinpath("scripts/discord-theme.py")
    out = []
    for line in src.read_text(errors="replace").splitlines():
        if line.startswith("Exec="):
            # the file's own argument (%U, a discord:// link) goes through to Discord
            line = "Exec=%s%s" % (exe, " %U" if "%U" in line or "%u" in line else "")
        elif line.startswith(("TryExec=", "DBusActivatable=", "X-AngelOS=")):
            continue
        out.append(line)
        if line.strip() == "[Desktop Entry]":
            out.append("X-AngelOS=discord")
    write(dest, "\n".join(out) + "\n")
    if shutil.which("update-desktop-database") and not os.environ.get("ANGELOS_TEST"):
        subprocess.run(["update-desktop-database", str(APPS)], capture_output=True)
    return {"ok": True, "launcher": True, "file": str(dest)}


def launcher_on():
    src = desktop_source()
    if not src:
        return False
    dest = APPS / src.name
    return dest.is_file() and "X-AngelOS=discord" in dest.read_text(errors="replace")


def status():
    found = clients()
    d = discord()
    return {
        "theme": str(THEME),
        "exists": THEME.exists(),
        "clients": [{
            "id": c[0], "name": c[1], "dir": str(c[2]),
            "installed": ours(c[2] / "themes" / NAME),
            "active": active(c),
            "running": running(c),
        } for c in found],
        "found": bool(found) or bool(d),
        "vencord": bool(found),
        "active": bool(found) and all(active(c) for c in found),
        "discord": None if not d else {"kind": d["kind"], "vencord": d["vencord"], "running": discord_running(d)},
        "launcher": launcher_on(),
        "launched": pid_alive(read_json(STATE, {}).get("pid")),
    }


def main():
    a = sys.argv[1:]
    if len(a) == 2 and a[0] == "build":
        build(a[1])
    elif a[:1] in (["apply"], ["revert"]) and len(a) <= 2:
        print(json.dumps((apply if a[0] == "apply" else revert)(a[1] if len(a) > 1 else None)))
    elif a[:1] == ["launch"]:
        sys.exit(launch(a[1:]))
    elif a[:1] == ["inject"] and "--port" in a:
        port = int(a[a.index("--port") + 1])
        n = loop(port, once="--once" in a)
        print(json.dumps({"ok": True, "applied": n}))
    elif len(a) == 2 and a[0] == "launcher" and a[1] in ("on", "off"):
        print(json.dumps(launcher(a[1] == "on")))
    elif a == ["status"]:
        print(json.dumps(status()))
    else:
        print(__doc__, file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    main()
