#!/usr/bin/env python3
"""Which settings each settings page shows, read from the pages' QML.

  page-keys.py [pages dir] -> {"pages": {page: ["section.key", …]},
                               "groups": {"page/name": ["section.key", …]},
                               "labels": {"section.key": {"ru", "en", "page"}}}
"groups": per PxGroup (by its name; outside any group "page/(page)") — the pages of the
settings tree are put together from groups, so their keys are their groups' keys.

Every `Config.<section>.<key>` a page touches belongs to it; its label is the
SettingRow (or, outside a row, the PxGroup) it sits in. Used by "Reset this
page" and to name the step behind "Undo" (services/SettingsKeys).
"""
import json
import re
import sys
from pathlib import Path

PAIR = re.compile(r'I18n\.t\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\)')
KEY = re.compile(r"\bConfig\.([a-zA-Z0-9]+)\.([a-zA-Z0-9]+)\b")
OPEN = re.compile(r"^\s*([A-Z][\w.]*)\s*\{")
LABEL = re.compile(r"^\s*(label|title)\s*:\s*(.*)$")
NAME = re.compile(r'^\s*name\s*:\s*"([^"]+)"')
# what "Reset this page" never touches: the pictures, the widgets on the desk,
# the shell's own bookkeeping
KEEP = {"appearance.language", "wallpaper.fallback", "wallpaper.outputs", "wallpaper.workspaces", "wallpaper.dir",
        "desktop.widgets", "desktop.initialized", "setup.complete", "launcher.usage",
        "settingsUi.usage", "settingsUi.expert", "settingsUi.skinChosen", "plugins.data", "updates.lastCheck",
        "updates.available", "y2k.character", "y2k.pleas", "y2k.lastPlea", "y2k.pranks",
        "y2k.nextPrank", "y2k.demonSince", "y2k.seenTips", "y2k.angelSaved", "y2k.returns",
        "y2k.helperGreeted", "stream.dndSet", "lyrics.sourcesVersion", "workspaces.names", "game.enabled"}


def page_id(path):
    name = path.stem[:-4] if path.stem.endswith("Page") else path.stem
    return name[:1].lower() + name[1:]


def unescape(s):
    return re.sub(r"\\(.)", r"\1", s)


def scan(path, pages, labels, groups):
    pid = page_id(path)
    keys = []
    stack = []   # [(component, depth, label)]
    depth = 0
    for line in path.read_text().splitlines():
        m = OPEN.match(line)
        if m:
            stack.append([m.group(1), depth, None])
        nm = NAME.match(line)
        if nm and stack and stack[-1][0] == "PxGroup":
            stack[-1].append(nm.group(1))
        lm = LABEL.match(line)
        if lm and stack and stack[-1][0] in ("SettingRow", "PxGroup"):
            p = PAIR.search(lm.group(2))
            if p:
                stack[-1][2] = {"ru": unescape(p.group(1)), "en": unescape(p.group(2))}
            elif lm.group(2).strip().startswith('"'):
                txt = lm.group(2).strip().strip('"')
                stack[-1][2] = {"ru": txt, "en": txt}
        for sec, key in KEY.findall(line):
            path_ = f"{sec}.{key}"
            if path_ not in keys:
                keys.append(path_)
            grp = next((e[3] for e in reversed(stack) if e[0] == "PxGroup" and len(e) > 3), "(page)")
            gl = groups.setdefault(f"{pid}/{grp}", [])
            if path_ not in gl and path_ not in KEEP:
                gl.append(path_)
            if path_ not in labels:
                lab = next((e[2] for e in reversed(stack) if e[0] == "SettingRow" and e[2]), None) \
                    or next((e[2] for e in reversed(stack) if e[0] == "PxGroup" and e[2]), None)
                if lab:
                    labels[path_] = dict(lab, page=pid)
        depth += line.count("{") - line.count("}")
        while stack and depth <= stack[-1][1]:
            stack.pop()
    pages[pid] = [k for k in keys if k not in KEEP]


def main():
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "modules/settings/pages"
    pages, labels, groups = {}, {}, {}
    for f in sorted(root.glob("*Page.qml")):
        scan(f, pages, labels, groups)
    print(json.dumps({"pages": pages, "groups": groups, "labels": labels}, ensure_ascii=False))


if __name__ == "__main__":
    main()
