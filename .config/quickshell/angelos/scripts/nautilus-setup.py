#!/usr/bin/env python3
"""angelOS defaults for Nautilus, plus the bundled mediafix.

  nautilus-setup.py status               -> JSON: what is installed and applied
  nautilus-setup.py apply [--no-prefs]   -> install the angelOS Nautilus extensions
                                            (open in terminal, mediafix) and the
                                            preference defaults below
  nautilus-setup.py remove               -> remove the angelOS extensions
  nautilus-setup.py restart              -> quit a running Nautilus (`nautilus -q`); the next
                                            window starts it fresh
  nautilus-setup.py mediafix [FILE…]     -> run mediafix in the angelOS terminal

Why a restart: Nautilus loads its python extensions and the GTK 4 user CSS
(~/.config/gtk-4.0/gtk.css → angelos.css) once, when it starts, and it keeps
running in the background (D-Bus activation: the file chooser portal, «show in
folder»). The gsettings keys reach it at once, but the folder view, zoom and the
like only show in new windows. So `apply` says {"restart": true} when Nautilus is
running and something it reads at start changed. Nautilus also writes two of the
keys itself — the zoom when you zoom, the archive format when you compress — so
«applied» can turn false later by your own hand; that is not an error.

Replaced files (older copies of the same extensions) are moved into a new
~/.local/state/angelos/backups/<stamp>-nautilus folder, never deleted.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

SHELL = Path(__file__).resolve().parents[1]
DATA = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
EXTENSIONS = DATA / "nautilus-python/extensions"
BACKUPS = Path.home() / ".local/state/angelos/backups"
OURS = ("angelos_open_terminal.py", "angelos_mediafix.py")
# earlier stand-alone versions of the same menu items (dotfiles / mediafix install.sh)
LEGACY = {"open_in_kitty.py": "class OpenInKitty", "mediafix.py": "class MediafixNautilus"}
# the author's Nautilus preferences, shipped as angelOS defaults
PREFS = [
    ("org.gnome.nautilus.compression", "default-compression-format", "'7z'"),
    ("org.gnome.nautilus.icon-view", "default-zoom-level", "'small-plus'"),
    ("org.gnome.nautilus.list-view", "use-tree-view", "false"),
    ("org.gnome.nautilus.preferences", "default-folder-viewer", "'icon-view'"),
    ("org.gnome.nautilus.preferences", "show-create-link", "false"),
]
PYTHON_EXTENSION = [Path("/usr/lib/nautilus/extensions-4/libnautilus-python.so"),
                    Path("/usr/lib64/nautilus/extensions-4/libnautilus-python.so")]


def gsettings(*args, errors=None):
    try:
        out = subprocess.run(["gsettings", *args], capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired) as error:
        if errors is not None:
            errors.append("gsettings " + " ".join(args[:3]) + ": " + str(error))
        return None
    if out.returncode != 0:
        if errors is not None:
            errors.append("gsettings " + " ".join(args[:3]) + ": " + (out.stderr.strip() or "exit %d" % out.returncode))
        return None
    return out.stdout.strip()


def running():
    try:
        return subprocess.run(["pgrep", "-x", "nautilus"], capture_output=True).returncode == 0
    except OSError:
        return False


def status():
    prefs = {f"{schema} {key}": gsettings("get", schema, key) for schema, key, _ in PREFS}
    return {
        "nautilus": bool(shutil.which("nautilus")),
        "python": any(p.exists() for p in PYTHON_EXTENSION),
        "ffmpeg": bool(shutil.which("ffmpeg")) and bool(shutil.which("ffprobe")),
        "extensions": {name: (EXTENSIONS / name).is_file() for name in OURS},
        "legacy": [name for name, marker in LEGACY.items() if is_legacy(EXTENSIONS / name, marker)],
        "prefs": {k: v for k, v in prefs.items()},
        "prefsApplied": all(prefs.get(f"{s} {k}") == v for s, k, v in PREFS),
        "prefsWanted": {f"{s} {k}": v for s, k, v in PREFS},
        "running": running(),
    }


def is_legacy(path, marker):
    try:
        return path.is_file() and not path.is_symlink() and marker in path.read_text(errors="ignore")
    except OSError:
        return False


def backup_dir():
    folder = BACKUPS / (time.strftime("%Y%m%d-%H%M%S") + "-nautilus")
    n = 1
    while folder.exists():
        folder = BACKUPS / (time.strftime("%Y%m%d-%H%M%S") + f"-nautilus-{n}")
        n += 1
    folder.mkdir(parents=True)
    return folder


def apply(prefs=True):
    done = []
    EXTENSIONS.mkdir(parents=True, exist_ok=True)
    backup = None
    for name, marker in LEGACY.items():
        path = EXTENSIONS / name
        if is_legacy(path, marker):
            backup = backup or backup_dir()
            shutil.move(str(path), backup / name)
            done.append("moved " + name + " → " + str(backup))
    for name in OURS:
        source, target = SHELL / "extras/nautilus" / name, EXTENSIONS / name
        text = source.read_text()
        if not target.exists() or target.read_text() != text:
            if target.exists():
                backup = backup or backup_dir()
                shutil.copy2(target, backup / name)
            tmp = target.with_suffix(".tmp")
            tmp.write_text(text)
            tmp.replace(target)
            done.append("installed " + name)
    errors = []
    if prefs:
        for schema, key, value in PREFS:
            if gsettings("get", schema, key) not in (None, value):
                # read back: a set that dconf did not take (no session bus, a read-only
                # profile) must not look like it worked
                if gsettings("set", schema, key, value, errors=errors) is not None and gsettings("get", schema, key) == value:
                    done.append(f"set {schema} {key} {value}")
                elif not errors:
                    errors.append(f"gsettings {schema} {key}: the value did not stick")
    result = {"ok": not errors, "changes": done, "status": status()}
    if errors:
        result["errors"] = errors
    result["restart"] = bool(done) and result["status"]["running"]
    return result


def restart():
    was = running()
    if was:
        subprocess.run(["nautilus", "-q"], capture_output=True, timeout=15)
    return {"ok": True, "quit": was, "status": status()}


def remove():
    removed = []
    backup = None
    for name in OURS:
        path = EXTENSIONS / name
        if path.is_file():
            backup = backup or backup_dir()
            shutil.move(str(path), backup / name)
            removed.append(name)
    return {"ok": True, "removed": removed, "status": status()}


def terminal():
    try:
        name = (json.loads((CONFIG / "angelos/settings.json").read_text()).get("system") or {}).get("terminal") or ""
    except (OSError, ValueError, AttributeError):
        name = ""
    search = os.environ.get("PATH", "") + os.pathsep + str(Path.home() / ".local/bin")
    for candidate in (name, "kitty", "foot", "alacritty", "wezterm", "gnome-terminal", "konsole", "xterm"):
        found = candidate and shutil.which(os.path.expanduser(candidate), path=search)
        if found:
            return found
    return None


def mediafix(files):
    term = terminal()
    if not term:
        return {"error": "no terminal found"}
    tool = SHELL / "extras/mediafix/mediafix.py"
    # the files travel as "$@" arguments, never through a shell string
    script = ('python3 "$0" "$@"; status=$?; printf "\\n♡ Готово. Окно закроется через 5 секунд, '
              'любая клавиша — сразу.\\n"; IFS= read -r -n 1 -t 5 _; exit $status')
    inner = ["bash", "-c", script, str(tool), *files]
    base = os.path.basename(term)
    argv = [term, *inner] if base in ("kitty", "foot") else [term, "start", "--", *inner] if base == "wezterm" \
        else [term, "--", *inner] if base == "gnome-terminal" else [term, "-e", *inner]
    subprocess.Popen(argv, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return {"ok": True}


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "status"
    try:
        if action == "status":
            result = status()
        elif action == "apply":
            result = apply(prefs="--no-prefs" not in sys.argv)
        elif action == "remove":
            result = remove()
            result["restart"] = bool(result["removed"]) and result["status"]["running"]
        elif action == "restart":
            result = restart()
        elif action == "mediafix":
            result = mediafix([f for f in sys.argv[2:] if os.path.exists(f)])
        else:
            result = {"error": "usage: nautilus-setup.py status | apply [--no-prefs] | remove | restart | mediafix [FILE…]"}
    except OSError as error:
        result = {"error": str(error)}
    print(json.dumps(result, ensure_ascii=False))
    return 1 if "error" in result else 0


if __name__ == "__main__":
    sys.exit(main())
