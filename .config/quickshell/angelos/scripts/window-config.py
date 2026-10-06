#!/usr/bin/env python3
"""Read or update niri window layout preferences (with backup, validation and rollback).

  window-config.py                 -> JSON with the current values
  window-config.py '<json>'        -> apply changes, keys:
      gaps: int 0..64
      center: never | always | on-overflow
      defaultWidth: "proportion 0.5" | "fixed 1200"
      presets: ["proportion 0.33333", "fixed 900", ...]
      apps: {"kitty": "proportion 0.5", "helium": null (= remove rule)}
      taskmgr: {"appIds": ["angelos.taskmgr", …], "width": "fixed 1200",
                "height": "fixed 760", "place": "center" | "corner"} | null (= no rule)
      alttab: true (Alt+Tab / Alt+Shift+Tab → `angelos alttab next|prev`, niri's own
              recent-windows switcher off) | false (niri's switcher, no block) |
              "mac" (Golden Gate's Mac keys: niri's switcher off and no Alt+Tab bind —
              ⌘Tab is the switcher there, Alt+Tab goes to the apps as on a Mac)
      lens:   true (Mod+Alt+= / Mod+Alt+- / Mod+Alt+0 → `angelos lens in|out|close`,
              the lens at the pointer) | false (no block)
      quit:   true (Mod+Ctrl+Shift+Escape → `angelos game off`, out of the game at once,
              services/Game) | false (no block)
      streamAngel: true (Mod+Alt+A → the angel on stream: on the bar ⇄ hidden, and the rule
              that makes her window for OBS see-through on the screens) | false (no block)

Writers take a lock (the Alt+Tab and the lens services may write at the same time).

Per-app rules live in cfg/angelos-windows.kdl, included after rules.kdl so they win.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

home = Path.home()
niri = home / ".config/niri"
layout_path = niri / "cfg/layout.kdl"
apps_path = niri / "cfg/angelos-windows.kdl"
config_path = niri / "config.kdl"
WIDTH = re.compile(r"^(proportion\s+(0?\.\d+|1(\.0+)?)|fixed\s+\d{2,5})$")


def value(text, key, default):
    m = re.search(r"^\s*" + re.escape(key) + r"\s+([^\n/{]+)", text, re.M)
    return m.group(1).strip().strip('"') if m else default


def block(text, name):
    """(start, end) of the body of the first `name { ... }` block."""
    m = re.search(r"^\s*" + re.escape(name) + r"\s*\{", text, re.M)
    if not m:
        return None
    depth, i = 0, m.end() - 1
    while i < len(text):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return m.end(), i
        i += 1
    return None


def width_of(body):
    m = re.search(r"(proportion\s+[\d.]+|fixed\s+\d+)", body or "")
    return re.sub(r"\s+", " ", m.group(1)) if m else ""


TM_BEGIN = "// >>> angelOS task manager (Настройки → System → Диспетчер задач)"
TM_END = "// <<< angelOS task manager"
HEIGHT = re.compile(r"^(proportion\s+(0?\.\d+|1(\.0+)?)|fixed\s+\d{2,5})$")
AT_BEGIN = "// >>> angelOS Alt+Tab (Настройки → Окна → Alt+Tab)"
AT_END = "// <<< angelOS Alt+Tab"
AT_MAC = "// Golden Gate's Mac keys: ⌘Tab is the switcher, Alt+Tab is left to the apps"
ANGELOS = "exec ~/.config/quickshell/angelos/bin/angelos alttab "


def read_alttab(text=None):
    if text is None:
        text = apps_path.read_text() if apps_path.exists() else ""
    if AT_BEGIN not in text:
        return False
    return "mac" if AT_MAC in text else True


def norm_alttab(v):
    return "mac" if v == "mac" else bool(v)


LS_BEGIN = "// >>> angelOS lens (Настройки → Клавиатура и мышь → Лупа)"
LS_END = "// <<< angelOS lens"
LENS = "exec ~/.config/quickshell/angelos/bin/angelos lens "


def read_lens(text=None):
    if text is None:
        text = apps_path.read_text() if apps_path.exists() else ""
    return LS_BEGIN in text


QT_BEGIN = "// >>> angelOS game off (README: «Как выйти из игры»)"
QT_END = "// <<< angelOS game off"
GAME_OFF = "exec ~/.config/quickshell/angelos/bin/angelos game off"


def read_quit(text=None):
    if text is None:
        text = apps_path.read_text() if apps_path.exists() else ""
    return QT_BEGIN in text


def render_keys(alttab, lens, quit=False, stream_angel=False):
    """the Alt+Tab block (niri's switcher off), the lens and game-off markers, then one
    binds node with the keys of all (niri takes a single binds node per file)"""
    if not alttab and not lens and not quit and not stream_angel:
        return ""
    out = []
    if alttab == "mac":
        out += [AT_BEGIN, AT_MAC, "recent-windows {", "    off", "}", AT_END]
    elif alttab:
        out += [AT_BEGIN, "// the angelOS switcher: niri's own is off, the keys go to the shell",
                "recent-windows {", "    off", "}", AT_END]
    if lens:
        out += [LS_BEGIN, "// the lens at the pointer: its keys are in the binds below", LS_END]
    if quit:
        out += [QT_BEGIN, "// out of angelOS's game at once: no angel, demon, novel or hell", QT_END]
    out += ["// angelOS keys (one binds node per file)", "binds {"]
    if alttab and alttab != "mac":
        out += [f'    Alt+Tab repeat=false hotkey-overlay-title="angelOS: Alt+Tab" {{ spawn-sh "{ANGELOS}next"; }}',
                f'    Alt+Shift+Tab repeat=false hotkey-overlay-title="angelOS: Alt+Tab назад" {{ spawn-sh "{ANGELOS}prev"; }}']
    if lens:
        out += [f'    Mod+Alt+Equal hotkey-overlay-title="angelOS: лупа ближе" {{ spawn-sh "{LENS}in"; }}',
                f'    Mod+Alt+Minus hotkey-overlay-title="angelOS: лупа дальше" {{ spawn-sh "{LENS}out"; }}',
                f'    Mod+Alt+0 repeat=false hotkey-overlay-title="angelOS: убрать лупу" {{ spawn-sh "{LENS}close"; }}']
    if stream_angel:
        out += [f'    Mod+Alt+A repeat=false allow-inhibiting=false hotkey-overlay-title="angelOS: ангел на стриме — спрятать/показать" {{ spawn-sh "{STREAM_VIEW}"; }}']
    if quit:
        out += [f'    Mod+Ctrl+Shift+Escape repeat=false allow-inhibiting=false hotkey-overlay-title="angelOS: выйти из игры" {{ spawn-sh "{GAME_OFF}"; }}']
    out += ["}", "// <<< angelOS keys", ""]
    return "\n".join(out)


def strip_block(text, begin, end):
    if begin not in text:
        return text
    tail = text[text.index(end) + len(end):] if end in text else ""
    return text[:text.index(begin)] + tail


def read_taskmgr(text=None):
    """the task manager block of angelos-windows.kdl as a spec (None when absent)"""
    if text is None:
        text = apps_path.read_text() if apps_path.exists() else ""
    if TM_BEGIN not in text:
        return None
    body = text[text.index(TM_BEGIN):text.index(TM_END) if TM_END in text else len(text)]
    ids = [re.sub(r"\\(.)", r"\1", m) for m in re.findall(r'match app-id=r#"\^(.+?)\$"#', body)]
    w = re.search(r"default-column-width \{ ([^;]+); \}", body)
    h = re.search(r"default-window-height \{ ([^;]+); \}", body)
    return {
        "appIds": ids,
        "width": w.group(1).strip() if w else "",
        "height": h.group(1).strip() if h else "",
        "place": "corner" if "default-floating-position" in body else "center",
    }


def render_taskmgr(spec):
    if not spec:
        return ""
    ids = [a for a in spec.get("appIds") or [] if re.match(r"^[\w.+-]{1,120}$", a)]
    if not ids:
        return ""
    out = [TM_BEGIN, "window-rule {"]
    out += [f'    match app-id=r#"^{re.escape(a)}$"#' for a in ids]
    out.append("    open-floating true")
    if spec.get("width"):
        out.append(f"    default-column-width {{ {check_width(spec['width'])}; }}")
    if spec.get("height"):
        hgt = re.sub(r"\s+", " ", str(spec["height"]).strip())
        if not HEIGHT.match(hgt):
            raise ValueError("bad height: " + hgt)
        out.append(f"    default-window-height {{ {hgt}; }}")
    if spec.get("place") == "corner":
        out.append('    default-floating-position x=16 y=16 relative-to="bottom-right"')
    out += ["}", TM_END, ""]
    return "\n".join(out)


def read_apps():
    rules = {}
    if apps_path.exists():
        text = apps_path.read_text()
        # the task manager and Alt+Tab blocks are not per-app widths
        text = strip_block(strip_block(text, TM_BEGIN, TM_END), AT_BEGIN, AT_END)
        for m in re.finditer(r'match app-id=r#"\^(.+?)\$"#\s*\n\s*default-column-width \{ ([^;]+); \}', text):
            rules[re.sub(r"\\(.)", r"\1", m.group(1))] = m.group(2).strip()
    return rules


SA_BEGIN = "// >>> angelOS stream angel (Настройки → Y2K → Ангел на стриме)"
SA_END = "// <<< angelOS stream angel"
STREAM_VIEW = "qs -c angelos ipc call angelos streamer view"


def read_stream_angel(text=None):
    if text is None:
        text = apps_path.read_text() if apps_path.exists() else ""
    return SA_BEGIN in text


def render_stream_angel():
    # her window for OBS (modules/y2k/StreamerCast): unseen on the screens (a window cast takes
    # it as drawn), floating in a corner, never taking the focus as it opens
    return "\n".join([SA_BEGIN,
                      "window-rule {",
                      '    match app-id=r#"^org\\.quickshell$"# title="^angelOS · ангел для OBS$"',
                      "    opacity 0.0",
                      "    open-focused false",
                      "    open-floating true",
                      '    default-floating-position x=0 y=0 relative-to="bottom-left"',
                      "    border { off; }",
                      "    focus-ring { off; }",
                      "    shadow { off; }",
                      "}",
                      SA_END, ""])


def current():
    text = layout_path.read_text()
    presets = []
    b = block(text, "preset-column-widths")
    if b:
        presets = [re.sub(r"\s+", " ", x.strip()) for x in re.findall(r"(proportion\s+[\d.]+|fixed\s+\d+)", text[b[0]:b[1]])]
    d = block(text, "default-column-width")
    return {
        "gaps": float(value(text, "gaps", "16")),
        "center": value(text, "center-focused-column", "never"),
        "defaultWidth": width_of(text[d[0]:d[1]]) if d else "",
        "presets": presets,
        "apps": read_apps(),
        "taskmgr": read_taskmgr(),
        "alttab": read_alttab(),
        "lens": read_lens(),
        "quit": read_quit(),
        "streamAngel": read_stream_angel(),
    }


def check_width(w):
    w = re.sub(r"\s+", " ", str(w).strip())
    if not WIDTH.match(w):
        raise ValueError("bad width: " + w)
    return w


def set_scalar(text, node, result):
    pattern = r"^(\s*)" + node + r'\s+(?:"[^"]*"|[\d.]+)'
    if re.search(pattern, text, re.M):
        return re.sub(pattern, lambda m: m[1] + node + " " + result, text, count=1, flags=re.M)
    new, n = re.subn(r"(\blayout\s*\{)", lambda m: m[1] + "\n        " + node + " " + result, text, count=1)
    if not n:
        raise ValueError("layout block not found")
    return new


def set_block(text, name, lines):
    body = "".join(f"\n            {l}" for l in lines) + "\n        "
    b = block(text, name)
    if b:
        return text[: b[0]] + body + text[b[1]:]
    new, n = re.subn(r"(\blayout\s*\{)", lambda m: m[1] + f"\n        {name} {{{body}}}", text, count=1)
    if not n:
        raise ValueError("layout block not found")
    return new


def render_apps(rules, taskmgr=None, alttab=False, lens=False, quit=False, stream_angel=False):
    out = ["// Managed by angelOS → Настройки → Окна. Per-app default widths.", ""]
    for app, w in sorted(rules.items()):
        out += ["window-rule {", f'    match app-id=r#"^{re.escape(app)}$"#', f"    default-column-width {{ {w}; }}", "}", ""]
    return ("\n".join(out) + render_taskmgr(taskmgr) + (render_stream_angel() if stream_angel else "")
            + render_keys(alttab, lens, quit, stream_angel))


def atomic_write(path, content):
    fd, name = tempfile.mkstemp(prefix=".angelos-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as f:
            f.write(content)
        if path.exists():
            os.chmod(name, path.stat().st_mode & 0o777)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def apply(changes):
    unknown = set(changes) - {"gaps", "center", "defaultWidth", "presets", "apps", "taskmgr", "alttab", "lens", "quit", "streamAngel"}
    if unknown:
        raise ValueError("unknown keys: " + ", ".join(sorted(unknown)))
    layout = layout_path.read_text()
    new_layout = layout
    if "gaps" in changes:
        g = int(changes["gaps"])
        if not 0 <= g <= 64:
            raise ValueError("gap out of range")
        new_layout = set_scalar(new_layout, "gaps", str(g))
    if "center" in changes:
        c = changes["center"]
        if c not in ("never", "always", "on-overflow"):
            raise ValueError("invalid centering")
        new_layout = set_scalar(new_layout, "center-focused-column", json.dumps(c))
    if "defaultWidth" in changes:
        new_layout = set_block(new_layout, "default-column-width", [check_width(changes["defaultWidth"])])
    if "presets" in changes:
        ps = [check_width(p) for p in changes["presets"]]
        if not ps:
            raise ValueError("need at least one preset")
        new_layout = set_block(new_layout, "preset-column-widths", ps)

    files = {layout_path: (layout, new_layout)} if new_layout != layout else {}
    if any(k in changes for k in ("apps", "taskmgr", "alttab", "lens", "quit", "streamAngel")):
        rules = read_apps()
        for app, w in (changes.get("apps") or {}).items():
            if not re.match(r"^[\w.+-]{1,120}$", app):
                raise ValueError("bad app id: " + app)
            if w in (None, "", "default"):
                rules.pop(app, None)
            else:
                rules[app] = check_width(w)
        taskmgr = changes["taskmgr"] if "taskmgr" in changes else read_taskmgr()
        alttab = norm_alttab(changes["alttab"]) if "alttab" in changes else read_alttab()
        lens = bool(changes["lens"]) if "lens" in changes else read_lens()
        quit = bool(changes["quit"]) if "quit" in changes else read_quit()
        stream_angel = bool(changes["streamAngel"]) if "streamAngel" in changes else read_stream_angel()
        old_apps = apps_path.read_text() if apps_path.exists() else None
        files[apps_path] = (old_apps, render_apps(rules, taskmgr, alttab, lens, quit, stream_angel))
        cfg = config_path.read_text()
        if 'include "./cfg/angelos-windows.kdl"' not in cfg:
            anchor = 'include "./cfg/rules.kdl"'
            new_cfg = cfg.replace(anchor, anchor + '\ninclude "./cfg/angelos-windows.kdl"') if anchor in cfg else cfg + '\ninclude "./cfg/angelos-windows.kdl"\n'
            files[config_path] = (cfg, new_cfg)

    files = {p: v for p, v in files.items() if v[0] != v[1]}
    if not files:
        print("No changes")
        return
    # backup into a fresh folder, write, validate, roll back on failure
    backup_root = home / ".local/state/angelos/backups"
    backup_root.mkdir(parents=True, exist_ok=True)
    backup = Path(tempfile.mkdtemp(prefix="window-layout-", dir=backup_root))
    for path, (old, _new) in files.items():
        if old is not None:
            shutil.copy2(path, backup / path.name)
    # write the included file first so niri never sees a dangling include
    order = sorted(files, key=lambda p: p != apps_path)
    for path in order:
        atomic_write(path, files[path][1])
    p = subprocess.run(["niri", "validate"], capture_output=True, text=True)
    (backup / "validate.log").write_text(p.stdout + p.stderr)
    if p.returncode:
        for path in reversed(order):
            old = files[path][0]
            if old is None:
                path.unlink(missing_ok=True)
            else:
                atomic_write(path, old)
        raise RuntimeError("niri validate failed, rolled back: " + p.stderr.strip()[-300:])
    print("Saved · " + str(backup))


if __name__ == "__main__":
    if len(sys.argv) == 1:
        print(json.dumps(current()))
    else:
        import fcntl
        lock_dir = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "angelos"
        lock_dir.mkdir(parents=True, exist_ok=True)
        with open(lock_dir / "window-config.lock", "w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            apply(json.loads(sys.argv[1]))
