#!/usr/bin/env python3
"""niri's `output` blocks as niri itself reads them, and saving Settings → Monitor.

niri takes the `output` blocks of the config and its includes in order and uses
the FIRST one whose name matches a monitor: its connector ("DP-1") or
"Make Model Serial". Without a matching block, without `mode`, or with a mode
that is not in the monitor's list to the millihertz, it picks the monitor's
preferred mode — usually 60 Hz. So a saved refresh rate only survives a reboot
if monitor.kdl is included, before anything else that names the same monitor,
and its mode is the exact one niri lists (143.981, not 144).

  niri_outputs.py status          -> JSON: per connected output, the block niri uses at login
  niri_outputs.py save '<draft>'  -> JSON {"ok": true, "backup", "notes"} | {"error": …}
      draft: {"outputs": {connector: {mode, scale, transform, x, y, vrr, off}}, "primary": connector | ""}

Save writes monitor.kdl (blocks named "Make Model Serial", so a connector that is
renamed after a reboot still matches), moves `include "monitor.kdl"` to the top
of config.kdl when its blocks would not win, checks a staged copy with
`niri validate` and with niri's own matching, and backs the old files up into
~/.local/state/angelos/backups/<stamp>-monitor first.

ANGELOS_NIRI_DIR and ANGELOS_NIRI_OUTPUTS (a JSON file in the format of
`niri msg --json outputs`) stand in for ~/.config/niri and niri (tests).
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

HOME = Path.home()
NIRI = Path(os.environ.get("ANGELOS_NIRI_DIR") or HOME / ".config/niri")
BACKUPS = HOME / ".local/state/angelos/backups"
MANAGED = {"mode", "scale", "transform", "position", "variable-refresh-rate", "off", "focus-at-startup"}


class Fail(Exception):
    pass


# ── a small KDL reader: enough for top-level nodes, their arguments and children ──

def _tokens(text):
    """(kind, start, end, value): word, string, end (newline or ;), lbrace, rbrace, slashdash."""
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c in " \t\r﻿":
            i += 1
        elif c == "\\":                      # line continuation
            i += 1
            while i < n and text[i] in " \t\r":
                i += 1
            if text.startswith("//", i):
                i = text.find("\n", i)
                i = n if i < 0 else i
            if i < n and text[i] == "\n":
                i += 1
        elif c in "\n;":
            yield "end", i, i + 1, None
            i += 1
        elif text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j < 0 else j
        elif text.startswith("/*", i):
            depth, i = 1, i + 2
            while i < n and depth:
                if text.startswith("/*", i):
                    depth, i = depth + 1, i + 2
                elif text.startswith("*/", i):
                    depth, i = depth - 1, i + 2
                else:
                    i += 1
        elif text.startswith("/-", i):
            yield "slashdash", i, i + 2, None
            i += 2
        elif c == "{":
            yield "lbrace", i, i + 1, None
            i += 1
        elif c == "}":
            yield "rbrace", i, i + 1, None
            i += 1
        elif c == '"':
            j, out = i + 1, []
            while j < n and text[j] != '"':
                if text[j] == "\\" and j + 1 < n:
                    out.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\"}.get(text[j + 1], text[j + 1]))
                    j += 2
                else:
                    out.append(text[j])
                    j += 1
            yield "string", i, min(j + 1, n), "".join(out)
            i = j + 1
        elif c == "r" and text.startswith(('r"', 'r#'), i):   # raw string r#"…"#
            j = i + 1
            while j < n and text[j] == "#":
                j += 1
            close = '"' + "#" * (j - i - 1)
            k = text.find(close, j + 1)
            k = n if k < 0 else k
            yield "string", i, min(k + len(close), n), text[j + 1:k]
            i = k + len(close)
        else:
            j = i
            while j < n and text[j] not in ' \t\r\n;{}"\\' and not text.startswith(("//", "/*"), j):
                j += 1
            yield "word", i, j, text[i:j]
            i = j


class Node:
    __slots__ = ("name", "args", "start", "lead", "end", "disabled", "children", "body")

    def __init__(self, name, start, lead, disabled):
        self.name, self.args, self.start, self.lead, self.end = name, [], start, lead, start + len(name)
        self.disabled, self.children, self.body = disabled, None, None

    def child(self, name):
        return next((c for c in self.children or [] if c.name == name and not c.disabled), None)


def _nodes(toks, i, nested):
    out, slash = [], None
    while i < len(toks):
        kind, a, b, val = toks[i]
        if kind == "end":
            i += 1
        elif kind == "rbrace":
            if nested:
                return out, i
            i += 1
        elif kind == "slashdash":
            slash, i = a, i + 1
        elif kind == "lbrace":                   # a block without a node: skip it
            _, i = _nodes(toks, i + 1, True)
            i += 1
        else:
            node = Node(val, a, slash if slash is not None else a, slash is not None)
            slash, i = None, i + 1
            while i < len(toks):
                k, a2, b2, v2 = toks[i]
                if k == "end":
                    i += 1
                    break
                if k == "rbrace":
                    break
                if k == "slashdash":             # a commented-out argument or children block
                    i += 1
                    if i < len(toks) and toks[i][0] == "lbrace":
                        _, i = _nodes(toks, i + 1, True)
                    i += 1
                    continue
                if k == "lbrace":
                    kids, j = _nodes(toks, i + 1, True)
                    node.children = kids
                    node.body = (b2, toks[j][1] if j < len(toks) else toks[-1][2])
                    node.end = toks[j][2] if j < len(toks) else node.body[1]
                    i = j + 1
                    continue
                node.args.append(v2)
                node.end = b2
                i += 1
            out.append(node)
    return out, i


def parse(text):
    return _nodes(list(_tokens(text)), 0, False)[0]


# ── niri's view ──

def outputs():
    """{connector: output} from niri (or ANGELOS_NIRI_OUTPUTS); {} when niri is not there."""
    fake = os.environ.get("ANGELOS_NIRI_OUTPUTS")
    try:
        if fake:
            return json.loads(Path(fake).read_text())
        raw = subprocess.run(["niri", "msg", "--json", "outputs"], capture_output=True, text=True, timeout=5)
        return json.loads(raw.stdout) if raw.returncode == 0 else {}
    except (OSError, ValueError, subprocess.SubprocessError):
        return {}


def _known(v):
    return v if v and v != "Unknown" else None


def mms(out):
    """"Make Model Serial" as niri matches it, or None when niri has nothing but the connector."""
    make, model, serial = _known(out.get("make")), _known(out.get("model")), _known(out.get("serial"))
    if not (make or model or serial):
        return None
    return " ".join(x or "Unknown" for x in (make, model, serial))


def matches(name, out):
    """niri's OutputName::matches: the connector or "Make Model Serial", ASCII case-insensitive."""
    low = name.encode().lower()
    if low == out.get("name", "").encode().lower():
        return True
    m = mms(out)
    return m is not None and low == m.encode().lower()


def ident(conn, outs):
    """The name to write: "Make Model Serial" unless another connected monitor has the same one."""
    m = mms(outs.get(conn, {}))
    if m and not any(c != conn and (mms(o) or "").lower() == m.lower() for c, o in outs.items()):
        return m
    return conn


def config_path():
    env = None if os.environ.get("ANGELOS_NIRI_DIR") else os.environ.get("NIRI_CONFIG")
    return Path(env) if env else NIRI / "config.kdl"


def _resolve(arg, base, root):
    p = Path(os.path.expanduser(arg))
    p = p if p.is_absolute() else base / p
    if root is not None and root != NIRI:        # a staged copy: includes into ~/.config/niri land in it too
        try:
            p = root / p.relative_to(NIRI)
        except ValueError:
            pass
    return Path(os.path.normpath(p))


def blocks(config, texts=None, root=None, files=None):
    """[(file, text, node)] for every enabled top-level output block, in niri's order.
    `texts` stands in for files on disk; `files` collects every file niri reads."""
    texts = texts or {}
    found = []
    files = [] if files is None else files

    def walk(path, stack):
        try:
            text = texts[path] if path in texts else path.read_text()
        except OSError:
            return
        files.append(path)
        for node in parse(text):
            if node.disabled or not node.args or not isinstance(node.args[0], str):
                continue
            if node.name == "include":
                p = _resolve(node.args[0], path.parent, root)
                if p not in stack:
                    walk(p, stack + (p,))
            elif node.name == "output":
                found.append((path, text, node))

    config = Path(os.path.normpath(config))
    walk(config, (config,))
    return found


def winner(found, out):
    """The block niri uses for `out` and the later ones it ignores."""
    hits = [b for b in found if matches(b[2].args[0], out)]
    return (hits[0] if hits else None), hits[1:]


def mode_of(node):
    m = node.child("mode")
    return m.args[0] if m and m.args and isinstance(m.args[0], str) else None


def parse_mode(s):
    try:
        size, _, rate = s.partition("@")
        w, h = (int(x) for x in size.lower().split("x"))
        return w, h, (float(rate) if rate else None)
    except ValueError:
        return None


def exact_mode(s, out):
    """The draft mode as niri lists it: (string, None) or (None, why)."""
    p = parse_mode(s)
    if not p:
        return None, f"bad mode {s!r}"
    w, h, rate = p
    same = [m for m in out.get("modes", []) if (m["width"], m["height"]) == (w, h)]
    if not same:
        return None, f"{w}x{h} is not a mode of {out.get('name')}"
    if rate is None:
        return s, None
    want = round(rate * 1000)
    best = min(same, key=lambda m: abs(m["refresh_rate"] - want))
    if abs(best["refresh_rate"] - want) > 500:
        return None, f"{s} is not a mode of {out.get('name')}"
    return f"{w}x{h}@{best['refresh_rate'] / 1000:.3f}", None


def same_mode(a, b):
    pa, pb = parse_mode(a or ""), parse_mode(b or "")
    return bool(pa and pb) and pa[:2] == pb[:2] and (pa[2] is None or pb[2] is None
                                                     or round(pa[2] * 1000) == round(pb[2] * 1000))


def focused(found, outs):
    """The monitor niri focuses at login: the first block with focus-at-startup (shadowed or not)
    that names a connected monitor."""
    for _, _, node in found:
        if node.child("focus-at-startup"):
            hit = next((c for c, o in sorted(outs.items()) if matches(node.args[0], o)), None)
            if hit:
                return hit
    return None


def mode_ok(s, out):
    """Does niri find this configured mode (exact refresh) instead of falling back?"""
    p = parse_mode(s or "")
    if not p:
        return False
    w, h, rate = p
    return any((m["width"], m["height"]) == (w, h) and (rate is None or m["refresh_rate"] == round(rate * 1000))
               for m in out.get("modes", []))


def _rel(p, root=None):
    try:
        return str(Path(p).relative_to(root or NIRI))
    except ValueError:
        return str(p)


def status():
    outs = outputs()
    config = config_path()
    files = []
    found = blocks(config, files=files)
    monitor = Path(os.path.normpath(NIRI / "monitor.kdl"))
    rows = []
    focus = focused(found, outs)
    for conn, out in sorted(outs.items()):
        win, rest = winner(found, out)
        cur = out["modes"][out["current_mode"]] if out.get("current_mode") is not None else None
        current = f"{cur['width']}x{cur['height']}@{cur['refresh_rate'] / 1000:.3f}" if cur else None
        row = {"output": conn, "id": mms(out), "current": current,
               "file": _rel(win[0]) if win else None, "block": win[2].args[0] if win else None,
               "mode": mode_of(win[2]) if win else None,
               "focus": conn == focus,
               "ignored": [_rel(f) for f, _, _ in rest]}
        if not win:
            row["issue"] = "no output block: the preferred mode at login"
        elif win[2].child("off"):
            row["issue"] = None
        elif not row["mode"]:
            row["issue"] = "the block has no mode: the preferred mode at login"
        elif not mode_ok(row["mode"], out):
            row["issue"] = f"mode {row['mode']} is not in the list to the millihertz: the preferred mode at login"
        elif current and not same_mode(row["mode"], current):
            row["issue"] = f"running {current}, config says {row['mode']} (not saved?)"
        else:
            row["issue"] = None
        rows.append(row)
    return {"config": str(config), "monitorIncluded": monitor in files, "outputs": rows}


# ── saving ──

def _line_span(text, start, end):
    """The whole lines from start to end, with the newline after."""
    ls = text.rfind("\n", 0, start) + 1
    le = text.find("\n", end)
    return ls, (len(text) if le < 0 else le + 1)


def _fmt_scale(v):
    s = f"{float(v):.2f}"
    return s[:-1] if s.endswith("0") else s


def _q(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def render_block(name, d, old, focus):
    """An output block from the draft, keeping the old block's other settings (layout, colours…)."""
    lines = [f"output {_q(name)} {{"]
    if d.get("off"):
        lines.append("    off")
    else:
        if d.get("mode"):
            lines.append(f"    mode {_q(d['mode'])}")
        lines.append(f"    scale {_fmt_scale(d.get('scale', 1))}")
        lines.append(f"    transform {_q(d.get('transform') or 'normal')}")
        lines.append(f"    position x={round(float(d.get('x', 0)))} y={round(float(d.get('y', 0)))}")
        if d.get("vrr"):
            vrr = old[2].child("variable-refresh-rate") if old else None
            lines.append("    " + (old[1][vrr.start:vrr.end] if vrr else "variable-refresh-rate"))
    if focus:
        lines.append("    focus-at-startup")
    if old:
        for c in old[2].children or []:
            if c.disabled or c.name not in MANAGED:
                lines.append("    " + old[1][c.lead:c.end])
    return "\n".join(lines) + "\n}\n"


def monitor_text(draft, primary, outs, found, old_text):
    head = ("// Generated by angelOS on " + time.strftime("%Y-%m-%d %H:%M:%S") + ".\n"
            "// Edit through angelOS → Настройки → Экран. Monitors are named \"Make Model Serial\"\n"
            "// (`niri msg outputs`), so a connector renamed after a reboot still matches.\n"
            "// config.kdl must include this file before anything else that names these monitors:\n"
            "// niri uses the first matching block.\n")
    parts = []
    focus = primary or focused(found, outs)       # "" = automatic: niri keeps the one it had
    for conn in sorted(draft):
        old, _ = winner(found, outs.get(conn, {"name": conn}))
        parts.append(render_block(ident(conn, outs), draft[conn], old, conn == focus and not draft[conn].get("off")))
    # monitors that are not connected now, and anything else that was there: kept as is
    for node in parse(old_text):
        if node.name == "output" and not node.disabled and node.args and any(
                matches(node.args[0], o) for c, o in outs.items() if c in draft):
            continue
        parts.append(old_text[node.lead:node.end].rstrip() + "\n")
    return head + "\n" + "\n".join(parts)


def include_first(text, monitor, config_dir):
    """config.kdl with `include "monitor.kdl"` before every other include and output block."""
    nodes = parse(text)
    cut = []
    for n in nodes:
        if (n.name == "include" and not n.disabled and n.args and isinstance(n.args[0], str)
                and _resolve(n.args[0], config_dir, None) == monitor):
            cut.append(_line_span(text, n.lead, n.end))
    for a, b in reversed(cut):
        text = text[:a] + text[b:]
    first = next((n for n in parse(text) if not n.disabled and n.name in ("include", "output")), None)
    at = _line_span(text, first.lead, first.end)[0] if first else len(text)
    line = ('// angelOS: first, so Settings → Monitor wins (niri uses the first output block that matches)\n'
            'include "monitor.kdl"\n')
    if first is None and text and not text.endswith("\n"):
        line = "\n" + line
    return text[:at] + line + ("\n" if first else "") + text[at:]


def check_staged(staged_config, draft, outs, staged_monitor, root):
    """Every saved monitor's block is the one niri will use; else why not."""
    found = blocks(staged_config, root=root)
    bad = []
    for conn in draft:
        win, _ = winner(found, outs.get(conn, {"name": conn}))
        if not win or Path(win[0]) != staged_monitor:
            bad.append((conn, win))
    return bad, found


def validate(config):
    if not shutil.which("niri"):
        return
    r = subprocess.run(["niri", "validate", "-c", str(config)], capture_output=True, text=True)
    if r.returncode:
        raise Fail("niri validate: " + (r.stderr or r.stdout).strip()[-400:])


def _write(path, text):
    path = Path(path)
    fd, tmp = tempfile.mkstemp(prefix=".angelos-", dir=path.parent)
    with os.fdopen(fd, "w") as f:
        f.write(text)
    if path.exists():
        os.chmod(tmp, path.stat().st_mode & 0o777)
    os.replace(tmp, path)


def save(draft_json):
    try:
        req = json.loads(draft_json)
    except ValueError as e:
        raise Fail(f"bad draft: {e}")
    draft = req.get("outputs") or {}
    primary = req.get("primary") or ""
    if not draft:
        raise Fail("nothing to save: niri reported no monitors")
    outs = outputs()
    config = config_path()
    monitor = NIRI / "monitor.kdl"
    if not config.is_file():
        raise Fail(f"{config} not found")
    for f in (config, monitor):
        if f.is_symlink():
            raise Fail(f"{f} is a symlink (a dotfiles manager?): edit it there")
    if config.parent != NIRI:
        raise Fail(f"niri runs with {config}, not {NIRI}/config.kdl")
    notes = []
    draft = {c: dict(d) for c, d in draft.items()}
    for conn, d in draft.items():
        if d.get("mode") and conn in outs:
            exact, why = exact_mode(d["mode"], outs[conn])
            if not exact:
                raise Fail(why)
            if exact != d["mode"]:
                notes.append({"code": "mode", "output": conn, "from": d["mode"], "to": exact})
                d["mode"] = exact
    old_monitor = monitor.read_text() if monitor.is_file() else ""
    found = blocks(config)
    new_monitor = monitor_text(draft, primary, outs, found, old_monitor)
    new_config = None
    with tempfile.TemporaryDirectory(prefix="angelos-monitor-") as tmp:
        root = Path(tmp) / "niri"
        shutil.copytree(NIRI, root, symlinks=False, ignore=shutil.ignore_patterns("*.bak*"))
        s_config, s_monitor = root / "config.kdl", root / "monitor.kdl"
        s_monitor.write_text(new_monitor)
        bad, s_found = check_staged(s_config, draft, outs, s_monitor, root)
        if bad:
            new_config = include_first(config.read_text(), Path(os.path.normpath(monitor)), config.parent)
            s_config.write_text(new_config)
            bad, s_found = check_staged(s_config, draft, outs, s_monitor, root)
            notes.append({"code": "include"})
        if bad:
            conn, win = bad[0]
            where = _rel(win[0], root) if win else "nothing"
            raise Fail(f"{conn}: niri would still use the block in {where}")
        validate(s_config)
        for conn in sorted(draft):
            _, rest = winner(s_found, outs.get(conn, {"name": conn}))
            if rest:
                notes.append({"code": "ignored", "output": conn, "files": sorted({_rel(f, root) for f, _, _ in rest})})
    backup = BACKUPS / (time.strftime("%Y%m%d-%H%M%S") + "-monitor")
    while backup.exists():
        backup = backup.with_name(backup.name + "-1")
    backup.mkdir(parents=True)
    if monitor.is_file():
        shutil.copy2(monitor, backup / "monitor.kdl")
    if new_config is not None:
        shutil.copy2(config, backup / "config.kdl")
    _write(monitor, new_monitor)
    if new_config is not None:
        _write(config, new_config)
    return {"ok": True, "backup": str(backup), "notes": notes}


def main():
    args = sys.argv[1:]
    try:
        if not args or args[0] == "status":
            print(json.dumps(status(), ensure_ascii=False))
        elif args[0] == "save" and len(args) == 2:
            print(json.dumps(save(args[1]), ensure_ascii=False))
        else:
            raise Fail("usage: niri_outputs.py status | save '<draft json>'")
    except (Fail, OSError) as e:
        print(json.dumps({"error": str(e)}, ensure_ascii=False))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
