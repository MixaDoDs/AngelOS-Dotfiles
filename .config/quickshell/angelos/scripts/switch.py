#!/usr/bin/env python3
"""Switch the desktop shell between Noctalia and angelOS.

  switch.py angelos [--no-restart] [--no-validate]
                                     patch niri + app themes for angelOS, start it;
                                     --no-validate: the caller runs `niri validate` itself
                                     and undoes a failure (Settings → Updates), so no
                                     fallback to Noctalia here
  switch.py noctalia                 restore files from the last switch backup, start Noctalia
  switch.py status

Every run that touches files first copies them into a *new* folder
~/.local/state/angelos/backups/<stamp>-switch/ (never overwrites old backups).
Patching is idempotent, so it can be re-run after a dotfiles install.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

HOME = Path.home()
SHELL = Path(__file__).resolve().parent.parent
STATE = HOME / ".local/state/angelos"
MARK = HOME / ".config/angelos/active"
SETTINGS = HOME / ".config/angelos/settings.json"
PALETTE = HOME / ".cache/angelos/palette.json"   # the user's palette (services/ThemeExport)
NIRI = HOME / ".config/niri"
FILES = [
    NIRI / "config.kdl", NIRI / "cfg/autostart.kdl", NIRI / "cfg/keybinds.kdl", NIRI / "cfg/rules.kdl",
    HOME / ".config/kitty/kitty.conf", HOME / ".config/foot/foot.ini",
    HOME / ".config/alacritty/alacritty.toml",
    HOME / ".config/gtk-3.0/gtk.css", HOME / ".config/gtk-4.0/gtk.css",
]

CLI = "qs -c angelos ipc call angelos"
KEYS = [  # noctalia msg ... -> angelos function
    (r"panel-toggle wallpaper", "settings wallpaper", "angelOS: обои"),
    (r"panel-toggle control-center", "settings appearance", "angelOS: настройки"),
    (r"settings-toggle", "settings appearance", "angelOS: настройки"),
    (r"panel-toggle launcher", "launcher", "angelOS: программы"),
    (r"session lock", "lock", "angelOS: блокировка"),
    (r"panel-toggle session", "session", "angelOS: выключение"),
    (r"panel-toggle clipboard", "clipboard", "angelOS: буфер обмена"),
    (r"volume-up", "volumeUp", None),
    (r"volume-down", "volumeDown", None),
    (r"volume-mute", "mute", None),
    (r"mic-mute", "micMute", None),
    (r"media next", "media next", None),
    (r"media previous", "media previous", None),
    (r"media toggle", "media toggle", None),
    (r"media pause", "media pause", None),
]

RULES = '''
    // ─── angelOS (managed by angelos switch.py) ───
    layer-rule {
        match namespace="^angelos-wallpaper$"
        place-within-backdrop true
    }
    layer-rule {
        match namespace="^angelos-"
        background-effect {
            xray false
        }
    }
    window-rule {
        match app-id="^org.quickshell$" title="^angelOS"
        open-floating true
        geometry-corner-radius 0
        clip-to-geometry false
        border { off; }
        focus-ring { off; }
        shadow { off; }
        default-column-width { fixed 1040; }
        default-window-height { fixed 740; }
    }
    // ─── /angelOS ───
'''

EXTRA_BINDS = '''
    // ─── angelOS extras ───
    Mod+Alt+Y                           hotkey-overlay-title="angelOS: лирика вкл/выкл" { spawn-sh "qs -c angelos ipc call angelos lyrics"; }
    Mod+Alt+T                           hotkey-overlay-title="angelOS: светлая/тёмная" { spawn-sh "qs -c angelos ipc call angelos theme toggle"; }
'''


def log(*a):
    print("»", *a, flush=True)


def backup(tag):
    base = STATE / "backups" / (time.strftime("%Y%m%d-%H%M%S") + "-" + tag)
    dst, n = base, 1
    while dst.exists():  # always a fresh folder
        n += 1
        dst = base.with_name(base.name + f"-{n}")
    dst.mkdir(parents=True)
    for f in FILES + [NIRI / "noctalia.kdl", NIRI / "angelos.kdl"]:
        if f.exists():
            rel = f.relative_to(HOME)
            (dst / rel).parent.mkdir(parents=True, exist_ok=True)
            if not (dst / rel).exists():  # cp -n semantics
                shutil.copy2(f, dst / rel)
    (dst / "files.json").write_text(json.dumps([str(f.relative_to(HOME)) for f in FILES if f.exists()]))
    log("бэкап:", dst)
    return dst


def edit(path, fn):
    if not path.exists():
        return False
    old = path.read_text()
    new = fn(old)
    if new != old:
        path.write_text(new)
        log("изменён", path.relative_to(HOME))
        return True
    return False


def patch_keys(t):
    for pat, fn, title in KEYS:
        rx = re.compile(r'(hotkey-overlay-title="[^"]*"\s*)?\{\s*spawn-sh\s+"noctalia msg ' + pat + r'";\s*\}')
        repl = (f'hotkey-overlay-title="{title}" ' if title else "") + '{ spawn-sh "' + CLI + " " + fn + '"; }'
        t = rx.sub(lambda m: repl, t)
    # brightness keys have no target on desktop monitors: comment them out
    t = re.sub(r'^(\s*)(XF86MonBrightness\w+[^\n]*noctalia msg[^\n]*)$', r'\1// \2', t, flags=re.M)
    t = t.replace("// ─── noctalia-shell keybinds ───", "// ─── angelOS keybinds (were noctalia) ───")
    if "angelOS extras" not in t:
        t = t.rstrip()
        assert t.endswith("}")
        t = t[:-1].rstrip() + "\n" + EXTRA_BINDS + "}\n"
    return t


def patch_rules(t):
    if 'exclude app-id="^org.quickshell$" title="^angelOS"' not in t:
        t = t.replace('exclude app-id="^liquid-glass-test$"', 'exclude app-id="^liquid-glass-test$"\n    exclude app-id="^org.quickshell$" title="^angelOS"')
    t = t.replace('match title="^angelOS · "', 'match app-id="^org.quickshell$" title="^angelOS"')
    if "managed by angelos switch.py" in t:
        return t
    return t.rstrip() + "\n" + RULES


def render_themes():
    """The theme files (kitty, foot, Alacritty, GTK, niri's angelos.kdl…) in the user's own
    colours: the palette the shell exported last (services/ThemeExport), without the templates
    switched off in Settings → Appearance. The stock palette only before there is one (a first
    install): Settings → Updates runs this on every update, and when the shell wasn't restarted
    after it nothing rendered the user's palette again — the apps stayed in the stock pink."""
    try:
        appearance = json.loads(SETTINGS.read_text()).get("appearance") or {}
    except (OSError, ValueError, AttributeError):
        appearance = {}
    kdl = (NIRI / "angelos.kdl").exists()
    if appearance.get("themeApps") is False and kdl:
        log("темы приложений выключены в настройках — не трогаю")
        return
    try:
        own = isinstance(json.loads(PALETTE.read_text()), dict)
    except (OSError, ValueError):
        own = False
    palette = PALETTE if own else SHELL / "templates/palette-default.json"
    disabled = {str(i) for i in appearance.get("disabledTemplates") or [] if re.fullmatch(r"[\w.-]+", str(i))}
    if not kdl:
        disabled.discard("niri")
    log("темы:", palette.relative_to(HOME) if own else "палитра по умолчанию")
    subprocess.run([sys.executable, str(SHELL / "scripts/render-templates.py"), str(palette), ",".join(sorted(disabled))], check=False)


def one_voxtype(t):
    """Voxtype has one owner, its user service (the installer enables it): installs from before
    2026-10-04 also spawned the daemon from niri, and the service then failed on the lock and
    restarted every 5 s for as long as the session ran."""
    if not any((HOME / ".config/systemd/user").glob("*.wants/voxtype.service")):
        return t
    return re.sub(r'^[ \t]*spawn-at-startup[ \t]+"[^"\n]*/voxtype"[ \t]+"daemon"[ \t]*\n', "", t, flags=re.M)


def to_angelos(restart=True, validate=True):
    backup("switch")
    # theme files first: niri must never include a missing file
    render_themes()
    if not (NIRI / "angelos.kdl").exists():
        sys.exit("angelos.kdl не создан — отмена")
    # `angelos start` runs the shell as a systemd user service (restarted when it dies);
    # `angelos run` inside it sets the renderer environment (bin/angelos) before qs
    edit(NIRI / "cfg/autostart.kdl", lambda t: one_voxtype(re.sub(r'spawn-at-startup\s+(?:"noctalia"|"qs"\s+"-c"\s+"angelos"\s+"-n"|"angelos"\s+"run")', 'spawn-at-startup "angelos" "start"', t)))
    edit(NIRI / "config.kdl", lambda t: t.replace('include "noctalia.kdl"', 'include "angelos.kdl"'))
    edit(NIRI / "cfg/keybinds.kdl", patch_keys)
    edit(NIRI / "cfg/rules.kdl", patch_rules)
    edit(HOME / ".config/kitty/kitty.conf", lambda t: t.replace("include themes/noctalia.conf", "include themes/angelos.conf"))
    edit(HOME / ".config/foot/foot.ini", lambda t: t.replace("include=~/.config/foot/themes/noctalia", "include=~/.config/foot/themes/angelos"))
    edit(HOME / ".config/alacritty/alacritty.toml", lambda t: t.replace("themes/noctalia.toml", "themes/angelos.toml"))
    for g in ("gtk-3.0", "gtk-4.0"):
        edit(HOME / f".config/{g}/gtk.css", lambda t: t.replace('@import url("noctalia.css");', '@import url("angelos.css");'))
    r = subprocess.run(["niri", "validate"], capture_output=True, text=True) if validate else None
    if r and r.returncode != 0:
        log("niri validate НЕ прошёл — откатываю")
        print(r.stderr)
        to_noctalia(restart=False)
        sys.exit(1)
    if r:
        log("niri: конфиг валиден")
    MARK.parent.mkdir(parents=True, exist_ok=True)
    MARK.write_text("angelos\n")
    if restart:
        subprocess.run(["pkill", "-x", "noctalia"])
        time.sleep(0.8)
        subprocess.Popen([str(SHELL / "bin/angelos"), "start"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        log("angelOS запущен ♡")


def unpatch_keys(t):
    """angelOS keybinds back to `noctalia msg …` (inverse of patch_keys)."""
    for pat, fn, _title in KEYS:
        noct = pat.replace("\\", "")
        t = t.replace('spawn-sh "' + CLI + " " + fn + '"', 'spawn-sh "noctalia msg ' + noct + '"')
    t = re.sub(r'^(\s*)// (XF86MonBrightness\w+[^\n]*noctalia msg[^\n]*)$', r'\1\2', t, flags=re.M)
    t = re.sub(r"\n\s*// ─── angelOS extras ───\n(?:[^\n]*angelos[^\n]*\n)*", "\n", t)
    return t.replace("// ─── angelOS keybinds (were noctalia) ───", "// ─── noctalia-shell keybinds ───")


def unpatch_rules(t):
    return re.sub(r"\n?\s*// ─── angelOS \(managed by angelos switch.py\) ───.*?// ─── /angelOS ───\n?", "\n", t, flags=re.S)


def to_noctalia_forward():
    """No switch backup (e.g. a fresh install from the repo): rewrite the wiring in place."""
    backup("switch-back")
    edit(NIRI / "cfg/autostart.kdl", lambda t: re.sub(r'spawn-at-startup\s+(?:"qs"\s+"-c"\s+"angelos"\s+"-n"|"angelos"\s+"(?:run|start)")', 'spawn-at-startup "noctalia"', t))
    edit(NIRI / "config.kdl", lambda t: t.replace('include "angelos.kdl"', 'include "noctalia.kdl"'))
    edit(NIRI / "cfg/keybinds.kdl", unpatch_keys)
    edit(NIRI / "cfg/rules.kdl", unpatch_rules)
    edit(HOME / ".config/kitty/kitty.conf", lambda t: t.replace("include themes/angelos.conf", "include themes/noctalia.conf"))
    edit(HOME / ".config/foot/foot.ini", lambda t: t.replace("include=~/.config/foot/themes/angelos", "include=~/.config/foot/themes/noctalia"))
    edit(HOME / ".config/alacritty/alacritty.toml", lambda t: t.replace("themes/angelos.toml", "themes/noctalia.toml"))
    for g in ("gtk-3.0", "gtk-4.0"):
        edit(HOME / f".config/{g}/gtk.css", lambda t: t.replace('@import url("angelos.css");', '@import url("noctalia.css");'))
    MARK.unlink(missing_ok=True)


def to_noctalia(restart=True):
    backups = sorted((STATE / "backups").glob("*-switch*"))
    src = None
    for b in reversed(backups):
        cfg = b / ".config/niri/config.kdl"
        if cfg.exists() and 'include "noctalia.kdl"' in cfg.read_text():
            src = b
            break
    if not src:
        log("бэкапа с Noctalia нет — переписываю обвязку на месте")
        to_noctalia_forward()
        if restart:
            # through bin/angelos: the systemd service would bring a plain `qs kill` back
            subprocess.run([str(SHELL / "bin/angelos"), "stop"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.Popen(["setsid", "-f", "noctalia"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return
    backup("switch-back")
    for rel in json.loads((src / "files.json").read_text()):
        shutil.copy2(src / rel, HOME / rel)
        log("восстановлен", rel)
    MARK.unlink(missing_ok=True)
    if restart:
        subprocess.run([str(SHELL / "bin/angelos"), "stop"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(0.5)
        subprocess.Popen(["setsid", "-f", "noctalia"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        log("Noctalia запущена")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "angelos":
        to_angelos(restart="--no-restart" not in sys.argv, validate="--no-validate" not in sys.argv)
    elif cmd == "noctalia-forward":
        to_noctalia_forward()
    elif cmd == "noctalia":
        to_noctalia(restart="--no-restart" not in sys.argv)
    else:
        print("active:", "angelos" if MARK.exists() else "noctalia/other")
