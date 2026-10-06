#!/usr/bin/env python3
"""The angelOS login screen for SDDM (extras/sddm/angelos), dressed like the desktop.

  sddm-theme.py build [--wallpaper FILE] [--palette ngo|system] [--out DIR]
      puts the theme together in ~/.cache/angelos/sddm/angelos (or DIR): its QML, the
      pixel fonts, the pixelation shader, a copy of the wallpaper and a theme.conf with
      angelOS's NGO pink (the default) or the desktop's own colours
      (~/.cache/angelos/palette.json), and the shell's language
  sddm-theme.py install [same options]
      builds it, then asks for the admin password (pkexec) to copy it to
      /usr/share/sddm/themes/angelos and make it SDDM's theme
      (/etc/sddm.conf.d/zz-angelos.conf; a Current= in /etc/sddm.conf, which would win,
      is commented out with a backup next to it)
  sddm-theme.py status
      prints JSON: {"installed": bool, "current": theme or "", "sddm": bool}

Nothing personal goes into the theme: the colours, the wallpaper picture and the language.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent           # the angelOS folder
SRC = HERE / "extras" / "sddm" / "angelos"
HOME = Path.home()
CACHE = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "angelos"
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config")) / "angelos"
FONTS = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local" / "share")) / "fonts" / "pixel"
TARGET = Path("/usr/share/sddm/themes/angelos")
CONF_D = Path("/etc/sddm.conf.d/zz-angelos.conf")

# angelOS's NGO pink ("overdose" at night): the look of the lock's stream
NGO = {
    "desk": "#2a1b3d", "face": "#3a2350", "faceAlt": "#4a2c66", "sunken": "#1d1230",
    "edge": "#140c20", "hi": "#5c3a80", "lo": "#1d1230", "text": "#fdf3ff",
    "textDim": "#c7b2d8", "titleText": "#ffffff", "accent": "#ff5fa2", "accent2": "#c9a0ff",
    "accent3": "#ffd36a", "danger": "#ff4f6d", "title1": "#ff5fa2", "title2": "#c9a0ff",
}
KEYS = list(NGO)
HEX = re.compile(r"^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$")


def settings():
    try:
        return json.loads((CONFIG / "settings.json").read_text())
    except (OSError, ValueError):
        return {}


def system_palette():
    try:
        p = json.loads((CACHE / "palette.json").read_text())
    except (OSError, ValueError):
        return dict(NGO)
    out = dict(NGO)
    for k in KEYS:
        v = p.get(k)
        if isinstance(v, str) and HEX.match(v):
            out[k] = v[:7]
    return out


def wallpaper_of(s):
    w = s.get("wallpaper") or {}
    theme = (w.get("themes") or {}).get(w.get("themeOf") or "") or {}
    for p in (theme.get("fallback"), w.get("fallback")):
        if p:
            p = Path(os.path.expanduser(p))
            if p.is_file():
                return p
    return None


def build(out: Path, wallpaper, palette_name):
    if not (SRC / "Main.qml").is_file():
        sys.exit(f"no theme sources in {SRC}")
    if out.exists():
        # only ever a theme this script built (or an empty folder)
        if any(out.iterdir()) and not (out / "Main.qml").is_file():
            sys.exit(f"{out} is not an angelOS theme folder; not touching it")
        shutil.rmtree(out)
    shutil.copytree(SRC, out)
    shutil.copy2(HERE / "shaders" / "pixelate.frag.qsb", out / "pixelate.frag.qsb")
    fonts = out / "fonts"
    fonts.mkdir(exist_ok=True)
    found = []
    for name in ("PixeloidSans.ttf", "PixeloidSans-Bold.ttf", "CozetteVector.ttf"):
        if (FONTS / name).is_file():
            shutil.copy2(FONTS / name, fonts / name)
            found.append(name)
    (fonts / "LICENSES.txt").write_text(
        "Pixeloid Sans by GGBotNet: SIL Open Font License 1.1 (https://openfontlicense.org)\n"
        "CozetteVector by Ines (slavfox): MIT (https://github.com/the-moonwitch/Cozette)\n")
    s = settings()
    pal = system_palette() if palette_name == "system" else dict(NGO)
    lang = (s.get("appearance") or {}).get("language") or ("ru" if os.environ.get("LANG", "").startswith("ru") else "en")
    lock = s.get("lock") or {}
    suffix = (s.get("desktop") or {}).get("titleSuffix") or "exe"
    conf = {**pal, "language": lang, "pixelate": "true" if lock.get("pixelate", True) else "false", "palette": palette_name,
            "suffix": suffix if suffix in ("exe", "sh", "bin") else "exe"}
    wp = Path(wallpaper) if wallpaper else wallpaper_of(s)
    if wp and wp.is_file():
        dest = out / ("background" + wp.suffix.lower())
        shutil.copy2(wp, dest)
        conf["background"] = dest.name
    (out / "theme.conf").write_text("[General]\n" + "".join(f"{k}={v}\n" for k, v in conf.items()))
    return {"out": str(out), "fonts": found, "background": conf.get("background", ""), "palette": palette_name}


def current_theme():
    cur = ""
    files = sorted(Path("/etc/sddm.conf.d").glob("*.conf")) if Path("/etc/sddm.conf.d").is_dir() else []
    files.append(Path("/etc/sddm.conf"))      # read last: it wins
    for f in files:
        try:
            section = ""
            for line in f.read_text().splitlines():
                line = line.strip()
                if line.startswith("["):
                    section = line
                elif section == "[Theme]" and line.startswith("Current="):
                    cur = line.split("=", 1)[1].strip()
        except OSError:
            pass
    return cur


ROOT_SCRIPT = r'''
set -eu
src="$1"; target="$2"; confd="$3"
[ -f "$src/Main.qml" ] || { echo "no theme in $src" >&2; exit 2; }
case "$target" in /usr/share/sddm/themes/angelos) ;; *) echo "bad target" >&2; exit 2;; esac
stamp=$(date +%Y%m%d-%H%M%S)
rm -rf "$target.new"
cp -r "$src" "$target.new"
chmod -R a+rX "$target.new"
[ -d "$target" ] && mv "$target" "$target.old-$stamp"
mv "$target.new" "$target"
rm -rf "$target".old-*
mkdir -p "$(dirname "$confd")"
printf '[Theme]\nCurrent=angelos\n' > "$confd"
if [ -f /etc/sddm.conf ] && grep -Eq '^[[:space:]]*Current=' /etc/sddm.conf; then
  cp /etc/sddm.conf "/etc/sddm.conf.bak.$stamp"
  sed -i -E 's/^([[:space:]]*Current=)/# (angelOS: zz-angelos.conf sets the theme) \1/' /etc/sddm.conf
fi
echo installed
'''


def install(out: Path):
    if not shutil.which("pkexec"):
        sys.exit("pkexec is missing: run as root  sh -c '…'  or install polkit")
    r = subprocess.run(["pkexec", "sh", "-c", ROOT_SCRIPT, "sh", str(out), str(TARGET), str(CONF_D)])
    if r.returncode != 0:
        sys.exit(r.returncode)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["build", "install", "status"])
    ap.add_argument("--wallpaper")
    ap.add_argument("--palette", choices=["system", "ngo"], default="ngo")
    ap.add_argument("--out", default=str(CACHE / "sddm" / "angelos"))
    a = ap.parse_args()
    if a.cmd == "status":
        print(json.dumps({"installed": (TARGET / "Main.qml").is_file(), "current": current_theme(),
                          "sddm": shutil.which("sddm") is not None}))
        return
    info = build(Path(a.out), a.wallpaper, a.palette)
    if a.cmd == "install":
        install(Path(a.out))
        info["installed"] = True
    print(json.dumps(info))


if __name__ == "__main__":
    main()
