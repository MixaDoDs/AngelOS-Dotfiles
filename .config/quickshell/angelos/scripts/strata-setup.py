#!/usr/bin/env python3
"""angelOS for Strata, the file manager angelOS installs (data/apps-catalog.json: «strata»).

  strata-setup.py status            -> JSON: what is installed and applied
  strata-setup.py apply             -> angelOS's items in Strata's menu (Open in terminal, mediafix,
                                       Send nearby: ~/.config/strata/actions/angelos-*), the
                                       angelOS theme (scripts/strata-theme.py) as the one it uses
                                       and Pixora's icons (see below)
  strata-setup.py theme             -> only make «angelOS» the theme (apply does it too)
  strata-setup.py remove            -> take the items out (into a backup) and give the theme back
  strata-setup.py portal on|off     -> Strata's own Open/Save dialogs for every app (the file chooser
                                       portal: `strata --install-portal`), or back to the old ones
  strata-setup.py terminal PATH     -> the angelOS terminal in PATH's folder (the menu item)

The items are Strata's custom actions: one folder each with an action.toml (strict: unknown keys
are refused), commands run without a shell, the paths as separate arguments. Labels in the angelOS
language. A changed item moves the old copy into ~/.local/state/angelos/backups/<stamp>-strata.

The theme: Strata reads settings.toml once, at start, and writes it back from memory when its
settings change — a running Strata would put its old theme back over ours. So the theme is set
only while no Strata runs; otherwise apply says {"themePending": true} and the shell runs `theme`
once Strata is gone (services/StrataSetup). Its colours follow angelOS on the fly afterwards
(Strata watches ~/.config/strata/themes). The theme Strata had before is kept in
~/.local/state/angelos/strata-before.json for `remove`.

The icons: Strata reads them from inside its binary (GResource), so no icon theme reaches them.
GLib's G_RESOURCE_OVERLAYS, set for the session (environment.d, and systemd's user manager at
once), points their folders at ~/.local/share/angelos/strata-icons, which scripts/folder-tint.py
fills with Pixora's: a Strata started after that draws those. Only Strata's own path is
overlaid; a name missing there (or the whole folder, under another icon theme) is Strata's own.
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

SHELL = Path(__file__).resolve().parents[1]
HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config")
DATA = Path(os.environ.get("XDG_DATA_HOME") or HOME / ".local/share")
STRATA = CONFIG / "strata"
ACTIONS = STRATA / "actions"
SETTINGS = STRATA / "settings.toml"
STATE = HOME / ".local/state/angelos"
BEFORE = STATE / "strata-before.json"
BACKUPS = STATE / "backups"
DESKTOP = "io.github.lgse.Strata.desktop"
ENVD = CONFIG / "environment.d/angelos-strata-icons.conf"
OVERLAY = ":".join(f"/io/github/lgse/Strata/icons/{res}={DATA}/angelos/strata-icons/{own}"
                   for res, own in (("scalable/actions", "actions"), ("catppuccin", "catppuccin")))
VIDEO = ["mp4", "mkv", "mov", "avi", "mxf", "webm", "ts", "mts", "m2ts", "flv", "wmv", "mpg", "mpeg", "m4v", "3gp"]


def ru():
    try:
        lang = (json.loads((CONFIG / "angelos/settings.json").read_text()).get("appearance") or {}).get("language")
    except (OSError, ValueError, AttributeError):
        lang = None
    return (lang or os.environ.get("LANG", "ru")).startswith("ru")


def q(text):
    return json.dumps(text, ensure_ascii=False)  # a TOML basic string is a JSON string


def actions():
    r = ru()
    script, angelos = str(SHELL / "scripts/strata-setup.py"), str(SHELL / "bin/angelos")
    return {
        "angelos-terminal": {
            "name": "Открыть в терминале" if r else "Open in terminal",
            "description": "Терминал из настроек angelOS в этой папке" if r else "The angelOS terminal in this folder",
            "icon": "terminal", "menu": "top",
            "when": {"max_items": 1},
            "run": {"program": "python3", "args": [script, "terminal", "{path}"], "mode": "per-item"},
        },
        "angelos-mediafix": {
            "name": "Подготовить для DaVinci Resolve (mediafix)" if r else "Prepare for DaVinci Resolve (mediafix)",
            "description": "Перекодировать видео так, чтобы Resolve его открыл" if r else "Re-encode videos so Resolve opens them",
            "icon": "video", "menu": "submenu",
            "when": {"kinds": ["file"], "extensions": VIDEO},
            "run": {"program": "python3", "args": [str(SHELL / "scripts/nautilus-setup.py"), "mediafix", "{paths}"],
                    "mode": "whole-selection"},
        },
        "angelos-share": {
            "name": "Отправить рядом (LocalSend)" if r else "Send nearby (LocalSend)",
            "description": "Окно angelOS «Отправить рядом» с этими файлами" if r else "angelOS's Send nearby window with these files",
            "icon": "send", "menu": "top",
            "when": {},
            "run": {"program": angelos, "args": ["share", "{paths}"], "mode": "whole-selection"},
        },
    }


def manifest(aid, a):
    lines = ["# written by angelOS (scripts/strata-setup.py); Settings → Default apps → Files · Strata",
             "schema_version = 1", f"id = {q(aid)}", f"name = {q(a['name'])}",
             f"description = {q(a['description'])}", f"icon = {q(a['icon'])}", "enabled = true",
             f"menu = {q(a['menu'])}", "", "[when]"]
    for k, v in a["when"].items():
        lines.append(f"{k} = {q(v) if not isinstance(v, int) else v}")
    run = a["run"]
    lines += ["", "[run]", 'runtime = "command"', f"program = {q(run['program'])}", f"args = {q(run['args'])}",
              f"mode = {q(run['mode'])}", 'on_error = "stop"', 'working_directory = "parent"', "confirm = false"]
    return "\n".join(lines) + "\n"


def binary():
    for p in (HOME / ".local/bin/strata", Path("/usr/bin/strata")):
        if p.is_file():
            return p
    found = shutil.which("strata")
    return Path(found) if found else None


def strata_pids():
    """this user's Strata processes (by the executable's name, never another user's)"""
    out = []
    for d in Path("/proc").iterdir():
        if not d.name.isdigit():
            continue
        try:
            if d.stat().st_uid != os.getuid():
                continue
            if Path(os.readlink(d / "exe")).name == "strata":
                out.append(int(d.name))
        except OSError:
            continue
    return out


def read_settings():
    try:
        return SETTINGS.read_text()
    except OSError:
        return ""


def setting(text, key):
    m = re.search(rf'(?m)^{key}\s*=\s*"([^"]*)"', text)
    return m.group(1) if m else None


def put(text, key, value):
    line = f"{key} = {q(value)}"
    if re.search(rf"(?m)^{key}\s*=", text):
        return re.sub(rf"(?m)^{key}\s*=.*$", line.replace("\\", "\\\\"), text, count=1)
    # top-level keys go before the first [table]
    m = re.search(r"(?m)^\[", text)
    return text[:m.start()] + line + "\n" + text[m.start():] if m else line + "\n" + text


def write_settings(text):
    STRATA.mkdir(parents=True, exist_ok=True)
    tmp = SETTINGS.with_name(".settings.toml.angelos")
    tmp.write_text(text)
    tmp.chmod(0o600)
    tmp.replace(SETTINGS)


def default_is_strata():
    try:
        r = subprocess.run(["xdg-mime", "query", "default", "inode/directory"], capture_output=True, text=True, timeout=5)
        return r.stdout.strip() == DESKTOP
    except (OSError, subprocess.TimeoutExpired):
        return False


def file_manager1():
    for f in (DATA / "dbus-1/services").glob("*.service"):
        try:
            text = f.read_text()
        except OSError:
            continue
        if "Name=org.freedesktop.FileManager1" in text and "strata" in text:
            return True
    return False


def status():
    text = read_settings()
    want = actions()
    have = {aid: (ACTIONS / aid / "action.toml").is_file() and (ACTIONS / aid / "action.toml").read_text() == manifest(aid, a)
            for aid, a in want.items()}
    exe = binary()
    return {
        "installed": bool(exe), "bin": str(exe or ""),
        "running": bool(strata_pids()),
        "default": default_is_strata(),
        "fileManager1": file_manager1(),
        "actions": have,
        "theme": (STRATA / "themes/angelos.toml").is_file(),
        "themeSelected": setting(text, "theme") == "angelos" and setting(text, "mode") in (None, "theme"),
        "portal": (DATA / "xdg-desktop-portal/portals/strata.portal").is_file(),
        "icons": ENVD.is_file(),
        "ffmpeg": bool(shutil.which("ffmpeg")),
        "localsend": bool(shutil.which("localsend") or shutil.which("localsend_app")),
    }


def backup_dir():
    n = 0
    while True:
        folder = BACKUPS / (time.strftime("%Y%m%d-%H%M%S") + (f"-strata-{n}" if n else "-strata"))
        if not folder.exists():
            folder.mkdir(parents=True)
            return folder
        n += 1


def build_theme(errors):
    palette = HOME / ".cache/angelos/palette.json"
    if (STRATA / "themes/angelos.toml").is_file():
        return
    if not palette.is_file():
        errors.append("no palette yet (~/.cache/angelos/palette.json)")
        return
    subprocess.run([sys.executable, str(SHELL / "scripts/strata-theme.py"), "build", str(palette)],
                   stdout=subprocess.DEVNULL)


def select_theme(done):
    """«angelOS» as Strata's theme — only while no Strata runs (see the docstring)"""
    if strata_pids():
        return False
    text = read_settings()
    if setting(text, "theme") == "angelos" and setting(text, "mode") in (None, "theme"):
        return True
    if not BEFORE.exists():
        STATE.mkdir(parents=True, exist_ok=True)
        BEFORE.write_text(json.dumps({"theme": setting(text, "theme"), "mode": setting(text, "mode")}))
    write_settings(put(put(text, "mode", "theme"), "theme", "angelos"))
    done.append("theme = angelos")
    return True


def icons(on, done):
    """the session's G_RESOURCE_OVERLAYS for Strata's icons (see the docstring)"""
    text = f"G_RESOURCE_OVERLAYS={OVERLAY}\n"
    if (ENVD.is_file() and ENVD.read_text() == text) if on else not ENVD.exists():
        return
    if on:
        ENVD.parent.mkdir(parents=True, exist_ok=True)
        ENVD.write_text(text)
    else:
        ENVD.unlink()
    # the tests run in a home of their own, and systemctl would reach the real session
    if shutil.which("systemctl") and os.environ.get("ANGELOS_TEST") != "1":
        subprocess.run(["systemctl", "--user", "set-environment" if on else "unset-environment",
                        f"G_RESOURCE_OVERLAYS={OVERLAY}" if on else "G_RESOURCE_OVERLAYS"],
                       stderr=subprocess.DEVNULL, check=False)
    done.append("Pixora icons " + ("on" if on else "off"))


def apply():
    done, errors = [], []
    backup = None
    ACTIONS.mkdir(parents=True, exist_ok=True)
    ACTIONS.chmod(0o700)
    for aid, a in actions().items():
        folder, text = ACTIONS / aid, manifest(aid, a)
        target = folder / "action.toml"
        if target.is_file() and target.read_text() == text:
            continue
        if folder.exists():
            backup = backup or backup_dir()
            shutil.move(str(folder), backup / aid)
        folder.mkdir(mode=0o700)
        tmp = folder / ".action.toml.tmp"
        tmp.write_text(text)
        tmp.chmod(0o600)
        tmp.replace(target)
        done.append("installed " + aid)
    build_theme(errors)
    icons(True, done)
    pending = not select_theme(done)
    return {"done": done, "errors": errors, "themePending": pending, "backup": str(backup or ""), "status": status()}


def remove():
    done = []
    backup = None
    for aid in actions():
        if (ACTIONS / aid).exists():
            backup = backup or backup_dir()
            shutil.move(str(ACTIONS / aid), backup / aid)
            done.append("removed " + aid)
    icons(False, done)
    text = read_settings()
    if setting(text, "theme") == "angelos" and not strata_pids():
        try:
            before = json.loads(BEFORE.read_text())
        except (OSError, ValueError):
            before = {}
        text = put(text, "theme", before.get("theme") or "azure-glow")
        if before.get("mode"):
            text = put(text, "mode", before["mode"])
        write_settings(text)
        BEFORE.unlink(missing_ok=True)
        done.append("theme back to " + (before.get("theme") or "azure-glow"))
    return {"done": done, "backup": str(backup or ""), "status": status()}


def portal(on):
    exe = binary()
    if not exe:
        return {"error": "Strata is not installed", "status": status()}
    r = subprocess.run([str(exe), "--install-portal" if on else "--uninstall-portal"],
                       capture_output=True, text=True, timeout=120)
    return {"ok": r.returncode == 0, "log": (r.stdout + r.stderr).strip()[-2000:], "status": status()}


def terminal_argv(term, folder):
    base = os.path.basename(term)
    if base in ("kitty", "foot", "alacritty"):
        return [term, "--working-directory", folder]
    if base == "wezterm":
        return [term, "start", "--cwd", folder]
    if base == "gnome-terminal":
        return [term, "--working-directory=" + folder]
    if base == "konsole":
        return [term, "--workdir", folder]
    return [term]


def terminal(path):
    try:
        name = (json.loads((CONFIG / "angelos/settings.json").read_text()).get("system") or {}).get("terminal") or ""
    except (OSError, ValueError, AttributeError):
        name = ""
    search = os.environ.get("PATH", "") + os.pathsep + str(HOME / ".local/bin")
    term = next((f for c in (name, "kitty", "foot", "alacritty", "wezterm", "gnome-terminal", "konsole", "xterm")
                 if c and (f := shutil.which(os.path.expanduser(c), path=search))), None)
    folder = path if os.path.isdir(path) else os.path.dirname(path)
    if not os.path.isdir(folder):
        folder = str(HOME)
    if not term:
        print("no terminal found", file=sys.stderr)
        return 1
    subprocess.Popen(terminal_argv(term, folder), cwd=folder, start_new_session=True,
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return 0


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "status"
    if action == "status":
        print(json.dumps(status()))
    elif action == "apply":
        print(json.dumps(apply(), ensure_ascii=False))
    elif action == "theme":
        done = []
        ok = select_theme(done)
        print(json.dumps({"done": done, "themePending": not ok, "status": status()}))
    elif action == "remove":
        print(json.dumps(remove(), ensure_ascii=False))
    elif action == "portal" and sys.argv[2:] in (["on"], ["off"]):
        print(json.dumps(portal(sys.argv[2] == "on"), ensure_ascii=False))
    elif action == "terminal" and len(sys.argv) == 3:
        raise SystemExit(terminal(sys.argv[2]))
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
