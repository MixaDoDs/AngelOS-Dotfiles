#!/usr/bin/env python3
"""List or edit the niri key bindings of the theme in front (Settings → Shortcuts).

Every theme has a key profile of its own (scripts/keyprofile.py): cfg/keybinds-pixel.kdl
for the pixel theme, cfg/keybinds-macos.kdl for Golden Gate, cfg/keybinds-common.kdl for
both. This edits only the profile in front, so a change in one theme never reaches the
other; the common file is listed read-only (its section says so). A key of the common
file may be bound again here: the profile is read after it and wins, for this theme.

  keybinds.py                   -> JSON {"file", "profile", "binds": [...], "sections": [...]}
      bind: {"id", "line", "key", "action", "title", "props", "section", "editable"}
  keybinds.py '<json ops>'      -> apply a list of operations, then print {"ok"} / {"error"}
      {"op": "set", "id": 12, "key": "Mod+Shift+T"}               change the combination
      {"op": "set", "id": 12, "action": "spawn \\"kitty\\"", "title": "…"}
      {"op": "delete", "id": 12}
      {"op": "add", "key": "Mod+Alt+K", "action": "spawn \\"gtk-launch\\" \\"kitty\\"", "title": "…"}

Only one-line binds (`Key props { action; }`) are editable; anything else is shown
read-only. The binds angelOS writes into the files niri reads after this one are listed
read-only too, as their own sections ({"file": …}): cfg/angelos-windows.kdl (Alt+Tab, the
lens) and angelos.kdl (the Golden Gate skin's Mac keys) — niri would let them replace a bind
here on the same key, so a key they hold can't be given to a bind here either. The file is edited line by line, so comments and alignment stay. A copy
of the niri config with the change must pass `niri validate` first; the old file is
backed up under ~/.local/state/angelos/backups/keybinds-* and restored if the final
validation fails. New binds go to an "angelOS: my shortcuts" section at the end.
"""
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
import keyprofile  # noqa: E402

CONFIG = Path.home() / ".config/niri/config.kdl"
PROFILE = keyprofile.current()          # "pixel" | "macos" | "" (a config from before profiles)
KEYBINDS = keyprofile.path()            # the profile in front
BACKUPS = Path.home() / ".local/state/angelos/backups"
MY_SECTION = "// ─── angelOS: мои хоткеи (Настройки → Горячие клавиши) ───"
THEMES = {"pixel": "пиксельная тема", "macos": "тема macOS (Golden Gate)"}
# other files with binds, read-only here: (path, section, read after the profile?). Files niri
# reads after the profile (config.kdl's include order) replace a key of it — their keys can't be
# given to a bind here; the common file is read before it
EXTRA = ([(CONFIG.parent / "cfg/keybinds-common.kdl", "Общие для обеих тем (cfg/keybinds-common.kdl)", False),
          # a binds block written by hand into the selector: both themes, read after the profile
          (keyprofile.SELECTOR, "Свои, для обеих тем (cfg/keybinds.kdl, правятся в файле)", True)] if PROFILE else []) + [
    (CONFIG.parent / "cfg/angelos-windows.kdl", "angelOS: Alt+Tab, лупа (Настройки → Окна, Клавиатура и мышь)", True),
    (CONFIG.parent / "angelos.kdl", "angelOS: сгенерировано темой", True),
]

BIND = re.compile(
    r'^(?P<indent>[ \t]*)(?P<key>[A-Za-z0-9_+\-]+)(?P<gap>[ \t]+)'
    r'(?P<props>(?:[\w-]+=(?:"(?:[^"\\]|\\.)*"|[^\s{]+)[ \t]+)*)'
    r'\{[ \t]*(?P<action>.*?)[ \t]*;?[ \t]*\}(?P<tail>[ \t]*(?://.*)?)$')
PROP = re.compile(r'([\w-]+)=("(?:[^"\\]|\\.)*"|[^\s{]+)')
SECTION = re.compile(r'^\s*//\s*[─—-]{2,}\s*(.+?)\s*[─—-]{2,}\s*$')
KEY_OK = re.compile(r'^(?:(?:Mod|Super|Win|Ctrl|Control|Shift|Alt|ISO_Level3_Shift|ISO_Level5_Shift)\+)*[A-Za-z0-9_]+$', re.I)
ACTION_OK = re.compile(r'^[a-z][a-z0-9-]*(?:\s+(?:"(?:[^"\\]|\\.)*"|[\w.%+\-]+|[\w-]+=(?:"(?:[^"\\]|\\.)*"|\S+)))*$')
MODS = {"mod": "mod", "super": "mod", "win": "mod", "ctrl": "ctrl", "control": "ctrl",
        "shift": "shift", "alt": "alt", "iso_level3_shift": "l3", "iso_level5_shift": "l5"}


def norm_key(key):
    parts = key.split("+")
    mods = sorted(MODS.get(p.lower(), p.lower()) for p in parts[:-1])
    return "+".join(mods + [parts[-1].lower()])


def unquote(v):
    if len(v) >= 2 and v[0] == '"' and v[-1] == '"':
        return re.sub(r'\\(.)', r'\1', v[1:-1])
    return v


def quote(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def block_range(lines):
    """line indexes (start, end) of the binds { … } block body"""
    start = None
    depth = 0
    for i, l in enumerate(lines):
        code = l.split("//")[0]
        if start is None:
            if re.match(r'^\s*binds\s*\{', code):
                start = i
                depth = code.count("{") - code.count("}")
            continue
        depth += code.count("{") - code.count("}")
        if depth <= 0:
            return start, i
    if start is None:
        raise ValueError("binds block not found")
    return start, len(lines) - 1


def parse(text):
    lines = text.split("\n")
    start, end = block_range(lines)
    binds, sections, section = [], [], ""
    depth = 0
    for i in range(start + 1, end):
        l = lines[i]
        m = SECTION.match(l)
        if m and depth == 0:
            section = m.group(1)
            if section not in sections:
                sections.append(section)
            continue
        stripped = l.strip()
        if not stripped or stripped.startswith("//"):
            continue
        b = BIND.match(l) if depth == 0 else None
        if b:
            props = {k: unquote(v) for k, v in PROP.findall(b.group("props"))}
            binds.append({
                "id": len(binds), "line": i, "key": b.group("key"),
                "action": b.group("action").strip().rstrip(";").strip(),
                "title": props.pop("hotkey-overlay-title", ""),
                "props": props, "section": section, "editable": True,
            })
        elif depth == 0 and re.match(r'^\s*[A-Za-z0-9_+\-]+\s', l):
            key = stripped.split()[0]
            binds.append({"id": len(binds), "line": i, "key": key, "action": stripped[len(key):].strip(),
                          "title": "", "props": {}, "section": section, "editable": False})
        code = l.split("//")[0]
        depth = max(0, depth + code.count("{") - code.count("}"))
    return lines, (start, end), binds, sections


def extra_binds(first_id=0):
    """the binds of EXTRA, read-only, numbered on from first_id"""
    out = []
    for path, section, after in EXTRA:
        try:
            _, _, binds, _ = parse(path.read_text())
        except (OSError, ValueError):
            continue
        for b in binds:
            b.update({"id": first_id + len(out), "section": section, "editable": False, "file": path.name, "after": after})
            out.append(b)
    return out


def render(indent, key, props, title, action, tail="", width=36):
    parts = []
    for k, v in props.items():
        parts.append(f"{k}={v}" if re.match(r'^(true|false|\d+)$', str(v)) else f"{k}={quote(str(v))}")
    if title:
        parts.append("hotkey-overlay-title=" + quote(title))
    lead = key.ljust(width - 1) + " "
    return f"{indent}{lead}{' '.join(parts) + ' ' if parts else ''}{{ {action}; }}{tail}"


def check_key(key):
    if not KEY_OK.match(key or ""):
        raise ValueError("bad key: " + str(key))
    return key


def check_action(action):
    action = (action or "").strip().rstrip(";").strip()
    if not action or not ACTION_OK.match(action) or "{" in action or "}" in action:
        raise ValueError("bad action: " + str(action))
    return action


def apply_ops(text, ops):
    lines, (start, end), binds, _ = parse(text)
    by_id = {b["id"]: b for b in binds}
    delete, added, asked = set(), [], set()
    for op in ops:
        kind = op.get("op")
        if kind in ("set", "delete"):
            b = by_id.get(op.get("id"))
            if not b or not b["editable"]:
                raise ValueError("no editable bind with id " + str(op.get("id")))
            if kind == "delete":
                delete.add(b["line"])
                b["deleted"] = True
                continue
            m = BIND.match(lines[b["line"]])
            key = check_key(op["key"]) if "key" in op else b["key"]
            if "key" in op:
                asked.add(norm_key(key))
            action = check_action(op["action"]) if "action" in op else b["action"]
            title = op["title"] if "title" in op else b["title"]
            props = {k: unquote(v) for k, v in PROP.findall(m.group("props")) if k != "hotkey-overlay-title"}
            width = len(m.group("key")) + len(m.group("gap"))
            lines[b["line"]] = render(m.group("indent"), key, props, title, action, m.group("tail"), max(width, 2))
            b["key"] = key
        elif kind == "add":
            key = check_key(op.get("key"))
            action = check_action(op.get("action"))
            title = str(op.get("title") or "")
            props = {k: v for k, v in (op.get("props") or {}).items() if re.match(r'^[\w-]+$', k)}
            added.append({"key": key, "line": render("    ", key, props, title, action)})
            asked.add(norm_key(key))
        else:
            raise ValueError("unknown op: " + str(kind))
    # one combination, one action
    seen = {}
    for b in binds:
        if b.get("deleted"):
            continue
        k = norm_key(b["key"])
        if k in seen:
            raise ValueError(f"{b['key']} is already used: {seen[k]}")
        seen[k] = b["key"] + " → " + b["action"][:60]
    for a in added:
        k = norm_key(a["key"])
        if k in seen:
            raise ValueError(f"{a['key']} is already used: {seen[k]}")
        seen[k] = a["key"]
    # a key angelOS's own files hold would be taken over by them (only the keys asked for now:
    # an old clash in the file doesn't stop other edits)
    for b in extra_binds():
        k = norm_key(b["key"])
        if k in asked and b["after"]:
            raise ValueError(f"{b['key']} is already used: {b['section']} → {b['title'] or b['action'][:60]}")
    out = [l for i, l in enumerate(lines) if i not in delete]
    if added:
        _, (_, end2), _, _ = parse("\n".join(out))
        has_section = any(l.strip() == MY_SECTION.strip() for l in out)
        insert = ([] if has_section else ["", "    " + MY_SECTION]) + [a["line"] for a in added]
        if has_section:  # after the last line of our section
            idx = max(i for i, l in enumerate(out) if l.strip() == MY_SECTION.strip())
            j = idx + 1
            while j < end2 and BIND.match(out[j]):
                j += 1
            out[j:j] = insert
        else:
            out[end2:end2] = insert
    return "\n".join(out)


def validate(config):
    result = subprocess.run(["niri", "validate", "-c", str(config)], capture_output=True, text=True)
    if result.returncode:
        raise ValueError((result.stderr or result.stdout).strip()[-400:])


def atomic_write(path, content):
    fd, name = tempfile.mkstemp(prefix=".keybinds-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(content)
        os.chmod(name, path.stat().st_mode & 0o777)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def save(ops):
    BACKUPS.mkdir(parents=True, exist_ok=True)
    # workspace-anim.py rewrites workspace binds in the same file
    with (BACKUPS / ".anim.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        old = KEYBINDS.read_text()
        new = apply_ops(old, ops)
        if new == old:
            return "Unchanged"
        with tempfile.TemporaryDirectory(prefix="angelos-keys-") as tmp:
            staged = Path(tmp) / "niri"
            shutil.copytree(CONFIG.parent, staged)
            (staged / KEYBINDS.relative_to(CONFIG.parent)).write_text(new)
            validate(staged / CONFIG.name)
        backup = Path(tempfile.mkdtemp(prefix="keybinds-", dir=BACKUPS))
        shutil.copy2(KEYBINDS, backup / KEYBINDS.name)
        if KEYBINDS.read_text() != old:
            raise RuntimeError(KEYBINDS.name + " changed during validation; try again")
        atomic_write(KEYBINDS, new)
        try:
            validate(CONFIG)
        except Exception:
            if KEYBINDS.read_text() == new:
                atomic_write(KEYBINDS, old)
            raise
        return "Saved · " + str(backup)


def main():
    try:
        if len(sys.argv) == 1:
            _, _, binds, sections = parse(KEYBINDS.read_text())
            extra = extra_binds(len(binds))
            sections += [s for s in dict.fromkeys(b["section"] for b in extra) if s not in sections]
            print(json.dumps({"file": str(KEYBINDS), "profile": PROFILE, "theme": THEMES.get(PROFILE, ""),
                              "binds": binds + extra, "sections": sections}, ensure_ascii=False))
        else:
            ops = json.loads(sys.argv[1])
            print(json.dumps({"ok": save(ops if isinstance(ops, list) else [ops])}, ensure_ascii=False))
    except (OSError, ValueError, RuntimeError, KeyError) as error:
        print(json.dumps({"error": str(error)}, ensure_ascii=False))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
