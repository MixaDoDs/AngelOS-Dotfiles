#!/usr/bin/env python3
"""The angelOS login screen for SDDM (extras/sddm/angelos), dressed like the desktop.

  sddm-theme.py build [--wallpaper FILE] [--tall FILE] [--palette ngo|system] [--look LOOK] [--out DIR]
      puts the theme together in ~/.cache/angelos/sddm/angelos (or DIR): its QML, the
      pixel fonts, the wallpaper shader, the sleeping angel (modules/y2k/sprites/angel),
      the wallpapers (walls/wide.jpg for landscape screens, walls/tall.jpg for portrait
      ones; --tall defaults to --wallpaper) and a theme.conf with angelOS's NGO pink (the
      default) or the desktop's own colours (~/.cache/angelos/palette.json), the look
      (stream, heaven, retro, hell, quiet — see extras/sddm/angelos/Main.qml) and the
      shell's language
  sddm-theme.py install [same options]
      builds it, then asks for the admin password (pkexec) to copy it to
      /usr/share/sddm/themes/angelos and make it SDDM's theme
      (/etc/sddm.conf.d/zz-angelos.conf; a Current= in /etc/sddm.conf or in another
      drop-in, which could win, is commented out with a backup next to it). The theme's walls/ folder is left to
      the user, so the wallpapers and the look can follow the desktop without a password
      (theme.conf.user, which SDDM reads over theme.conf, is a link to walls/theme.conf.user):
  sddm-theme.py walls [--wallpaper FILE] [--tall FILE]
      puts these pictures into the installed theme's walls/ (angelOS runs it whenever the
      wallpaper changes); a picture already there is not redone; prints JSON
  sddm-theme.py look LOOK [--palette ngo|system]
      the installed theme takes this look (and these colours) from now on: written into
      walls/theme.conf.user, no password; prints JSON {"set": bool}
  sddm-theme.py status
      prints JSON: {"installed": bool, "current": theme or "", "sddm": bool, "walls": bool,
      "look": the installed look, "user": theme.conf.user is in place}

Nothing personal goes into the theme: the colours, the wallpaper picture and the language.
"""
import argparse
import hashlib
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
LOOKS = ("stream", "heaven", "retro", "hell", "quiet")
WALL_BOX = "2560x2560"                                   # walls are fitted into this
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


def fit_wall(src: Path, dest: Path):
    """src → dest (JPEG fitted into WALL_BOX), through a temporary file; True when done."""
    tmp = dest.with_name("." + dest.stem + ".tmp.jpg")
    if shutil.which("vipsthumbnail"):
        cmd = ["vipsthumbnail", str(src), "--size", WALL_BOX, "-o", f"{tmp}[Q=90,strip]"]
    elif shutil.which("magick"):
        cmd = ["magick", str(src) + "[0]", "-resize", WALL_BOX + ">", "-strip", "-quality", "90", str(tmp)]
    else:
        return False
    if subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 0 or not tmp.is_file():
        tmp.unlink(missing_ok=True)
        return False
    os.chmod(tmp, 0o644)
    os.replace(tmp, dest)
    return True


def stamp_of(src: Path):
    # which picture a wall was made from, without saying where it lives
    st = src.stat()
    return hashlib.sha1(f"{src.resolve()}|{st.st_size}|{st.st_mtime_ns}".encode()).hexdigest()[:16]


def put_walls(walls: Path, wide, tall):
    """walls/wide.jpg and walls/tall.jpg from the pictures given; unchanged ones are kept."""
    done = {}
    try:
        stamps = json.loads((walls / "stamps.json").read_text())
    except (OSError, ValueError):
        stamps = {}
    for name, src in (("wide", wide), ("tall", tall or wide)):
        if not src:
            continue
        src = Path(os.path.expanduser(str(src)))
        if not src.is_file():
            continue
        st = stamp_of(src)
        dest = walls / (name + ".jpg")
        if stamps.get(name) == st and dest.is_file():
            done[name] = "kept"
            continue
        if fit_wall(src, dest):
            stamps[name] = st
            done[name] = "new"
    tmp = walls / ".stamps.tmp"
    tmp.write_text(json.dumps(stamps))
    os.chmod(tmp, 0o644)
    os.replace(tmp, walls / "stamps.json")
    return done


def angel_into(out: Path):
    """the sleeping angel of the second camera: the rig's pictures and its layout as JS"""
    rig_dir = HERE / "modules" / "y2k" / "sprites" / "angel"
    rig = None
    try:
        rig = json.loads((rig_dir / "rig.json").read_text())
    except (OSError, ValueError):
        pass
    names = ["body", "eyes"] + list((rig or {}).get("parts", {}))
    if rig and all((rig_dir / f"{n}.png").is_file() for n in names):
        (out / "angel").mkdir(exist_ok=True)
        for n in names:
            shutil.copy2(rig_dir / f"{n}.png", out / "angel" / f"{n}.png")
    else:
        rig = None
    (out / "AngelRig.js").write_text(
        "// written by `angelos sddm build` from modules/y2k/sprites/angel/rig.json\n"
        ".pragma library\n\nvar rig = " + json.dumps(rig) + ";\n")


def conf_lines(conf):
    return "[General]\n" + "".join(f"{k}={v}\n" for k, v in conf.items())


def build(out: Path, wallpaper, palette_name, tall=None, look="stream"):
    if not (SRC / "Main.qml").is_file():
        sys.exit(f"no theme sources in {SRC}")
    if out.exists():
        # only ever a theme this script built (or an empty folder)
        if any(out.iterdir()) and not (out / "Main.qml").is_file():
            sys.exit(f"{out} is not an angelOS theme folder; not touching it")
        shutil.rmtree(out)
    shutil.copytree(SRC, out)
    shutil.copy2(HERE / "shaders" / "sddm_wall.frag.qsb", out / "sddm_wall.frag.qsb")
    angel_into(out)
    fonts = out / "fonts"
    fonts.mkdir(exist_ok=True)
    found = []
    for name in ("PixeloidSans.ttf", "PixeloidSans-Bold.ttf", "CozetteVector.ttf"):
        if (FONTS / name).is_file():
            shutil.copy2(FONTS / name, fonts / name)
            found.append(name)
    # hell's blackletter with Cyrillic (angelOS's own build of Jacquard 12)
    if (HERE / "data" / "fonts" / "Jacquard12Hell-Regular.ttf").is_file():
        shutil.copy2(HERE / "data" / "fonts" / "Jacquard12Hell-Regular.ttf", fonts / "Jacquard12Hell-Regular.ttf")
        found.append("Jacquard12Hell-Regular.ttf")
    (fonts / "LICENSES.txt").write_text(
        "Pixeloid Sans by GGBotNet: SIL Open Font License 1.1 (https://openfontlicense.org)\n"
        "CozetteVector by Ines (slavfox): MIT (https://github.com/the-moonwitch/Cozette)\n"
        "Jacquard 12 by Sarah Cadigan-Fried, Cyrillic added for angelOS: SIL Open Font License 1.1\n")
    s = settings()
    pal = system_palette() if palette_name == "system" else dict(NGO)
    lang = (s.get("appearance") or {}).get("language") or ("ru" if os.environ.get("LANG", "").startswith("ru") else "en")
    lock = s.get("lock") or {}
    suffix = (s.get("desktop") or {}).get("titleSuffix") or "exe"
    conf = {**pal, "language": lang, "pixelate": "true" if lock.get("pixelate", True) else "false", "palette": palette_name,
            "suffix": suffix if suffix in ("exe", "sh", "bin") else "exe", "look": look if look in LOOKS else "stream"}
    wp = Path(wallpaper) if wallpaper else wallpaper_of(s)
    if wp and wp.is_file():
        # the last resort when walls/ has nothing (the theme prefers walls/)
        dest = out / "background.jpg"
        if fit_wall(wp, dest):
            conf["background"] = dest.name
    walls = out / "walls"
    walls.mkdir(exist_ok=True)
    put_walls(walls, wp if wp and wp.is_file() else None, Path(tall) if tall else None)
    (out / "theme.conf").write_text(conf_lines(conf))
    # what angelOS changes later without a password: the look and the colours
    user_conf(walls, look, pal, palette_name)
    return {"out": str(out), "fonts": found, "background": conf.get("background", ""), "palette": palette_name, "look": conf["look"]}


def user_conf(walls: Path, look, pal, palette_name):
    conf = {**pal, "palette": palette_name, "look": look if look in LOOKS else "stream"}
    tmp = walls / ".theme.conf.user.tmp"
    tmp.write_text(conf_lines(conf))
    os.chmod(tmp, 0o644)
    os.replace(tmp, walls / "theme.conf.user")


def read_conf(path: Path):
    out = {}
    try:
        for line in path.read_text().splitlines():
            if "=" in line and not line.startswith(("[", "#", ";")):
                k, v = line.split("=", 1)
                out[k.strip()] = v.strip()
    except OSError:
        pass
    return out


def source_fingerprint(here: Path = HERE, fonts: Path = FONTS):
    """All local inputs copied or interpreted while building the SDDM theme."""
    inputs = [here / "shaders" / "sddm_wall.frag.qsb",
              here / "data" / "fonts" / "Jacquard12Hell-Regular.ttf",
              here / "scripts" / "sddm-theme.py"]
    inputs.extend((here / "extras" / "sddm" / "angelos").rglob("*"))
    inputs.extend((here / "modules" / "y2k" / "sprites" / "angel").rglob("*"))
    inputs.extend(fonts / name for name in ("PixeloidSans.ttf", "PixeloidSans-Bold.ttf", "CozetteVector.ttf"))
    digest = hashlib.sha256()
    for path in sorted((p for p in inputs if p.is_file()), key=str):
        label = path.relative_to(here) if path.is_relative_to(here) else Path("user-fonts") / path.name
        digest.update(str(label).encode())
        digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()


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
src="$1"; target="$2"; confd="$3"; owner="$4"; prefix="${5:-}"; mode="${6:-preserve}"
# $5 is empty on a real machine and a fake system root in the tests (scripts/check.sh)
case "$prefix" in ''|/*) ;; *) echo "bad system root" >&2; exit 2;; esac
case "$mode" in preserve|replace) ;; *) echo "bad install mode" >&2; exit 2;; esac
case "$owner" in ''|*[!0-9]*) echo "bad owner" >&2; exit 2;; esac
[ -f "$src/Main.qml" ] || { echo "no theme in $src" >&2; exit 2; }
case "$target" in "$prefix"/usr/share/sddm/themes/angelos) ;; *) echo "bad target" >&2; exit 2;; esac
case "$confd" in "$prefix"/etc/sddm.conf.d/*.conf) ;; *) echo "bad confd" >&2; exit 2;; esac
stamp=$(date +%Y%m%d-%H%M%S)
mkdir -p "$(dirname "$target")"
rm -rf "$target.new"
cp -r "$src" "$target.new"
chmod -R a+rX "$target.new"
[ -n "$prefix" ] || chown -R 0:0 "$target.new"
# walls/ only: the wallpapers follow the desktop without a password (`sddm-theme.py walls`)
mkdir -p "$target.new/walls"
if [ -d "$target/walls" ]; then
  if [ "$mode" = preserve ]; then
    cp -a "$target/walls/." "$target.new/walls/"
  else
    # Settings requested a new look/wallpaper: use its newly built files,
    # but keep any old wall for which the build had no replacement.
    for old_wall in "$target/walls/"*; do
      [ -e "$old_wall" ] || [ -L "$old_wall" ] || continue
      new_wall="$target.new/walls/$(basename "$old_wall")"
      [ -e "$new_wall" ] || cp -a "$old_wall" "$new_wall"
    done
  fi
fi
[ -n "$prefix" ] || chown -R "$owner" "$target.new/walls"
# SDDM reads theme.conf.user over theme.conf: the user's copy in walls/
ln -sfn walls/theme.conf.user "$target.new/theme.conf.user"
[ ! -d "$target" ] || mv "$target" "$(dirname "$target")/.angelos.bak.$stamp-$$"
mv "$target.new" "$target"
mkdir -p "$(dirname "$confd")"
printf '[Theme]\nCurrent=angelos\nCursorTheme=capitaine-cursors\n' > "$confd"
# SDDM reads EVERY file of sddm.conf.d in alphabetical order, not only *.conf, and the last
# Current= wins. So backups never go in there: the old zz-pixelstreetart.conf.bak.<stamp> next to
# it sorted last and put pixel-cyberpunk back on every boot. Backups: /etc/angelos-sddm-backups.
bakdir="$prefix/etc/angelos-sddm-backups"
mkdir -p "$bakdir"
for f in "$(dirname "$confd")"/*; do
  [ -f "$f" ] && [ "$f" != "$confd" ] || continue
  sed -n '/^[[:space:]]*\[Theme[[:space:]]*\]/,/^[[:space:]]*\[/p' "$f" | grep -Eq '^[[:space:]]*Current[[:space:]]*=' || continue
  # a backup (earlier runs left *.bak.<stamp> here) goes out; another drop-in that names a theme
  # (the installer's old zz-pixelstreetart.conf sorts after zz-angelos.conf) is commented out
  case "$f" in *.conf) ;; *) mv "$f" "$bakdir/"; echo "moved out of sddm.conf.d: $(basename "$f")"; continue ;; esac
  cp -p "$f" "$bakdir/$(basename "$f").$stamp"
  sed -i -E '/^[[:space:]]*\[Theme[[:space:]]*\]/,/^[[:space:]]*\[/ s/^([[:space:]]*Current[[:space:]]*=)/# (angelOS: zz-angelos.conf sets the theme) \1/' "$f"
done
main="$prefix/etc/sddm.conf"
if [ -f "$main" ] && sed -n '/^[[:space:]]*\[Theme[[:space:]]*\]/,/^[[:space:]]*\[/p' "$main" | grep -Eq '^[[:space:]]*Current[[:space:]]*='; then
  cp "$main" "$bakdir/sddm.conf.$stamp"
  sed -i -E '/^[[:space:]]*\[Theme[[:space:]]*\]/,/^[[:space:]]*\[/ s/^([[:space:]]*Current[[:space:]]*=)/# (angelOS: zz-angelos.conf sets the theme) \1/' "$main"
fi
# The theme that came with the installer before angelOS's own: nothing else points at it now.
old="$prefix/usr/share/sddm/themes/pixel-cyberpunk"
if [ -d "$old" ]; then
  backup="$(dirname "$old")/.pixel-cyberpunk.bak.$stamp-$$"
  mv "$old" "$backup"
  echo "removed: the old pixel-cyberpunk theme (backup: $backup)"
fi
echo installed
'''


def install(out: Path, prefix: str = "", replace: bool = False):
    if not shutil.which("pkexec"):
        sys.exit("pkexec is missing: run as root  sh -c '…'  or install polkit")
    # pkexec refuses to run when $SHELL is not in /etc/shells (a wrapper in ~/.local/bin)
    env = {**os.environ, "SHELL": "/bin/sh"}
    if prefix and not Path(prefix).is_absolute():
        sys.exit("--prefix must be an absolute path")
    target, confd = f"{prefix}/usr/share/sddm/themes/angelos", f"{prefix}/etc/sddm.conf.d/zz-angelos.conf"
    r = subprocess.run(["pkexec", "sh", "-c", ROOT_SCRIPT, "sh", str(out), target, confd,
                        str(os.getuid()), prefix, "replace" if replace else "preserve"], env=env)
    if r.returncode != 0:
        sys.exit(r.returncode)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["build", "install", "status", "walls", "look", "fingerprint"])
    ap.add_argument("look_name", nargs="?", choices=LOOKS)
    ap.add_argument("--wallpaper")
    ap.add_argument("--tall", help="the picture for portrait screens (default: --wallpaper)")
    ap.add_argument("--palette", choices=["system", "ngo"], default=None)
    ap.add_argument("--look", choices=LOOKS, default=None)
    ap.add_argument("--out", default=str(CACHE / "sddm" / "angelos"))
    ap.add_argument("--prefix", default="", help="a fake system root (tests); empty on a real machine")
    a = ap.parse_args()
    if a.cmd == "fingerprint":
        print(source_fingerprint())
        return
    if a.cmd == "status":
        walls = TARGET / "walls"
        installed = {**read_conf(TARGET / "theme.conf"), **read_conf(walls / "theme.conf.user")}
        print(json.dumps({"installed": (TARGET / "Main.qml").is_file(), "current": current_theme(),
                          "sddm": shutil.which("sddm") is not None,
                          "walls": walls.is_dir() and os.access(walls, os.W_OK),
                          "look": installed.get("look", "stream") if (TARGET / "Main.qml").is_file() else "",
                          "palette": installed.get("palette", "ngo"),
                          "user": (TARGET / "theme.conf.user").is_symlink() and (TARGET / "HeavenLook.qml").is_file()}))
        return
    if a.cmd == "look":
        walls = TARGET / "walls"
        if not a.look_name or not (TARGET / "theme.conf.user").is_symlink() or not os.access(walls, os.W_OK):
            # installed before the looks: `install --look` once
            print(json.dumps({"set": False, "reason": "the installed theme predates the looks: install it again"}))
            return
        name = a.palette or read_conf(walls / "theme.conf.user").get("palette") or "ngo"
        pal = system_palette() if name == "system" else dict(NGO)
        user_conf(walls, a.look_name, pal, name)
        print(json.dumps({"set": True, "look": a.look_name, "palette": name}))
        return
    if a.cmd == "walls":
        walls = TARGET / "walls"
        if not (TARGET / "Main.qml").is_file() or not walls.is_dir() or not os.access(walls, os.W_OK):
            # not installed, or installed before walls/ was the user's: `install` again
            print(json.dumps({"synced": False, "reason": "no writable " + str(walls)}))
            return
        print(json.dumps({"synced": True, "walls": put_walls(walls, a.wallpaper, a.tall)}))
        return
    # unsaid: what the installed theme has now
    now = {**read_conf(TARGET / "theme.conf"), **read_conf(TARGET / "walls" / "theme.conf.user")}
    palette = a.palette or now.get("palette") or "ngo"
    look = a.look or now.get("look") or "stream"
    info = build(Path(a.out), a.wallpaper, palette if palette in ("ngo", "system") else "ngo", a.tall, look if look in LOOKS else "stream")
    if a.cmd == "install":
        install(Path(a.out), a.prefix, any(v is not None for v in (a.look, a.palette, a.wallpaper, a.tall)))
        info["installed"] = True
    print(json.dumps(info))


if __name__ == "__main__":
    main()
