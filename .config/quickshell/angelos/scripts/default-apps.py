#!/usr/bin/env python3
"""Default applications for angelOS settings.

  default-apps.py list [lang]          -> JSON {category: {current, candidates:[{id,name,icon}]}}
  default-apps.py set CATEGORY ID      -> make ID (a .desktop id) the default for the category
  default-apps.py browser              -> the default browser's id; one that isn't installed (the
                                          dotfiles' mimeapps.list names the author's Helium) gives
                                          way to an installed browser first, "" when there is none
  default-apps.py open-browser         -> start it (Mod+B): Helium with its own profile, else `gio launch`

Writes through `xdg-mime default` (~/.config/mimeapps.list); the terminal also goes
to ~/.config/xdg-terminals.list. mimeapps.list is copied into a fresh backup folder first.
"""
import configparser
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

CATEGORIES = {
    "browser": {"mimes": ["x-scheme-handler/http", "x-scheme-handler/https", "text/html",
                          "x-scheme-handler/about", "x-scheme-handler/unknown"], "cat": "WebBrowser"},
    "editor": {"mimes": ["text/plain"], "cat": "TextEditor"},
    "files": {"mimes": ["inode/directory"], "cat": "FileManager"},
    "terminal": {"mimes": [], "cat": "TerminalEmulator"},
    "image": {"mimes": ["image/png", "image/jpeg", "image/gif", "image/webp", "image/bmp", "image/svg+xml"], "cat": "Viewer"},
    "video": {"mimes": ["video/mp4", "video/x-matroska", "video/webm", "video/quicktime", "video/x-msvideo"], "cat": "Video"},
    "audio": {"mimes": ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-wav", "audio/mp4"], "cat": "Audio"},
    "pdf": {"mimes": ["application/pdf"], "cat": ""},
    "mail": {"mimes": ["x-scheme-handler/mailto"], "cat": "Email"},
    "archive": {"mimes": ["application/zip", "application/x-7z-compressed", "application/x-tar", "application/vnd.rar", "application/x-compressed-tar"], "cat": "Archiving"},
}
HOME = Path.home()
RU = (os.environ.get("ANGELOS_LANG") or os.environ.get("LANG", "ru")).startswith("ru")
# who takes over when the default browser isn't installed: the catalog's browsers first
BROWSERS = ["helium.desktop", "firefox.desktop", "org.mozilla.firefox.desktop", "chromium.desktop",
            "brave-browser.desktop", "com.brave.Browser.desktop", "google-chrome.desktop"]


def app_dirs():
    data_home = os.environ.get("XDG_DATA_HOME", str(HOME / ".local/share"))
    dirs = [data_home] + os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
    dirs += [str(HOME / ".local/share/flatpak/exports/share"), "/var/lib/flatpak/exports/share"]
    return [Path(d) / "applications" for d in dirs]


def entries(lang):
    seen = {}
    for base in app_dirs():
        if not base.is_dir():
            continue
        for p in sorted(base.rglob("*.desktop")):
            did = str(p.relative_to(base)).replace("/", "-")
            if did in seen:
                continue  # user entries shadow system ones
            cp = configparser.ConfigParser(interpolation=None, strict=False)
            try:
                cp.read(p, encoding="utf-8")
                e = cp["Desktop Entry"]
            except Exception:  # noqa: BLE001
                continue
            if e.get("Type", "Application") != "Application":
                continue
            hidden = e.getboolean("NoDisplay", fallback=False) or e.getboolean("Hidden", fallback=False)
            seen[did] = {
                "id": did,
                "name": e.get(f"Name[{lang}]") or e.get("Name", did),
                "icon": e.get("Icon", ""),
                "mimes": [m for m in e.get("MimeType", "").split(";") if m],
                "cats": [c for c in e.get("Categories", "").split(";") if c],
                "hidden": hidden,
            }
    return seen


def query(mime):
    try:
        r = subprocess.run(["xdg-mime", "query", "default", mime], capture_output=True, text=True, timeout=5)
        return r.stdout.strip()
    except Exception:  # noqa: BLE001
        return ""


def current_terminal():
    f = HOME / ".config/xdg-terminals.list"
    if f.exists():
        for line in f.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                return line
    return ""


def list_all(lang):
    apps = entries(lang)
    out = {}
    for key, c in CATEGORIES.items():
        cands = []
        for a in apps.values():
            if a["hidden"]:
                continue
            if key == "browser":
                ok = is_browser(a)
            elif key == "terminal":
                ok = "TerminalEmulator" in a["cats"]
            else:
                ok = any(m in a["mimes"] for m in c["mimes"])
            if ok:
                cands.append({"id": a["id"], "name": a["name"], "icon": a["icon"]})
        cur = current_terminal() if key == "terminal" else (query(c["mimes"][0]) if c["mimes"] else "")
        if cur and cur not in [x["id"] for x in cands] and cur in apps:
            cands.append({"id": cur, "name": apps[cur]["name"], "icon": apps[cur]["icon"]})
        cands.sort(key=lambda x: x["name"].lower())
        out[key] = {"current": cur, "candidates": cands}
    return out


def is_browser(a):
    return "x-scheme-handler/http" in a["mimes"] or "WebBrowser" in a["cats"]


def desktop_file(did):
    for base in app_dirs():
        p = base / did
        if p.is_file():
            return p
        # a "vendor-app.desktop" id can live as vendor/app.desktop
        if "-" in did:
            q = base / did.replace("-", "/", 1)
            if q.is_file():
                return q
    return None


def ensure_browser():
    apps = entries("en")
    cur = query(CATEGORIES["browser"]["mimes"][0])
    if cur in apps and not apps[cur]["hidden"]:
        return cur
    cands = [a["id"] for a in apps.values() if not a["hidden"] and is_browser(a)]
    if not cands:
        return ""
    pick = next((b for b in BROWSERS if b in cands), sorted(cands)[0])
    set_default("browser", pick)
    return pick


def open_browser():
    did = ensure_browser()
    if did == "helium.desktop" and shutil.which("helium-browser"):
        # the author's bind: straight into the Default profile, no profile picker
        os.execvp("helium-browser", ["helium-browser", "--profile-directory=Default"])
    path = desktop_file(did) if did else None
    if not path:
        subprocess.run(["notify-send", "-i", "dialog-warning", "angelOS",
                        "Браузер не установлен (Настройки → Обновления → программы)" if RU else
                        "No browser installed (Settings → Updates → the apps)"], stderr=subprocess.DEVNULL)
        raise SystemExit(1)
    os.execvp("gio", ["gio", "launch", str(path)])


def backup():
    src = HOME / ".config/mimeapps.list"
    base = HOME / ".local/state/angelos/backups" / (time.strftime("%Y%m%d-%H%M%S") + "-default-apps")
    dst, n = base, 1
    while dst.exists():
        n += 1
        dst = base.with_name(base.name + f"-{n}")
    dst.mkdir(parents=True)
    for f in (src, HOME / ".config/xdg-terminals.list"):
        if f.exists():
            shutil.copy2(f, dst / f.name)
    return dst


def set_default(key, did):
    if key not in CATEGORIES:
        raise SystemExit("unknown category")
    apps = entries("en")
    if did not in apps:
        raise SystemExit("unknown application: " + did)
    b = backup()
    if key == "terminal":
        f = HOME / ".config/xdg-terminals.list"
        rest = [l for l in (f.read_text().splitlines() if f.exists() else []) if l.strip() and l.strip() != did]
        f.write_text("\n".join([did] + rest) + "\n")
    else:
        subprocess.run(["xdg-mime", "default", did] + CATEGORIES[key]["mimes"], check=True)
        if key == "browser":
            subprocess.run(["xdg-settings", "set", "default-web-browser", did], stderr=subprocess.DEVNULL)
    print(f"ok · {did} · backup {b}")


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "list":
        print(json.dumps(list_all(sys.argv[2] if len(sys.argv) > 2 else "ru"), ensure_ascii=False))
    elif len(sys.argv) == 4 and sys.argv[1] == "set":
        set_default(sys.argv[2], sys.argv[3])
    elif sys.argv[1:] == ["browser"]:
        print(ensure_browser())
    elif sys.argv[1:] == ["open-browser"]:
        open_browser()
    else:
        raise SystemExit(__doc__)
