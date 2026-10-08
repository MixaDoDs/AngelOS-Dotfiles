#!/usr/bin/env python3
"""Search index of the settings pages, read straight from their QML.

  settings-index.py [pages dir …]  -> JSON list of entries:
      {"page": "appearance", "kind": "page|group|row", "ru": …, "en": …, "name": "theme",
       "group": {"ru","en"} (rows), "hint": {"ru","en"}, "words": {"ru","en"}}
"page" is the page file, "name" the group's name (PxGroup.name, a row: its group's): the
settings tree (modules/settings/tree.json, services/SettingsTree) says which page shows it.

Every I18n.t("…", "…") pair is picked up: page headings and subtitles, PxGroup
titles, SettingRow labels and hints, and the texts inside a row or group
(options, buttons) as extra words. New settings become searchable by themselves.
A group or row shown only in developer mode (`shown:`/`visible: Config.developer.enabled`)
is marked "developer": true, its rows too — the search leaves them out while the mode is off.
One shown only to the author (`shown: GameDebug.allowed`, the game's debug panel from
owner/debug) is marked "owner": true — the search leaves it out for everyone else.

The result is kept in $XDG_CACHE_HOME/angelos/settings-index.json with the size and time of
every page file (and of this script): Settings opening asks again each time, and while no page
changed the answer comes from there instead of reading ~50 QML files anew.
"""
import hashlib
import json
import os
import re
import sys
from pathlib import Path

PAIR = re.compile(r'I18n\.t\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\)')
LIT = re.compile(r'^"((?:[^"\\]|\\.)+)"\s*;?\s*(//.*)?$')
CHECKED = re.compile(r'^\s*checked:\s*Config\.(\w+\.\w+)\s*$')
SETS = re.compile(r'onToggled:\s*(\w+)\s*=>\s*Config\.(\w+\.\w+)\s*=\s*\1\s*;?\s*$')
PROP = re.compile(r'^\s*"?(heading|subtitle|title|label|hint|text|placeholder)"?\s*:\s*(.*)$')
OPEN = re.compile(r"^\s*([A-Z][\w.]*)\s*\{")
DEV = re.compile(r"^\s*(shown|visible)\s*:\s*Config\.developer\.enabled\s*$")
OWNER = re.compile(r"^\s*(shown|visible)\s*:\s*GameDebug\.allowed\s*$")
NAME = re.compile(r'^\s*name\s*:\s*"([^"]+)"')


def unescape(s):
    return re.sub(r"\\(.)", r"\1", s)


def page_id(path):
    name = path.stem[:-4] if path.stem.endswith("Page") else path.stem
    return name[:1].lower() + name[1:]


def index_page(path):
    pid = page_id(path)
    out = []
    stack = []  # [(component, depth, entry or None)]
    depth = 0
    page = {"page": pid, "kind": "page", "ru": "", "en": "", "hint": {"ru": "", "en": ""}, "words": {"ru": [], "en": []}}
    out.append(page)

    def owner():
        for comp, _, entry in reversed(stack):
            if entry is not None:
                return entry
        return page

    for line in path.read_text().splitlines():
        code = line.split("//")[0] if "//" in line and '"' not in line.split("//")[0] else line
        m = OPEN.match(code)
        if m:
            comp = m.group(1)
            entry = None
            if comp == "PxGroup":
                entry = {"page": pid, "kind": "group", "ru": "", "en": "", "name": "", "hint": {"ru": "", "en": ""}, "words": {"ru": [], "en": []}}
            elif comp == "SettingRow":
                grp = next((e for c, _, e in reversed(stack) if c == "PxGroup" and e), None)
                entry = {"page": pid, "kind": "row", "ru": "", "en": "", "name": grp["name"] if grp else "", "hint": {"ru": "", "en": ""}, "words": {"ru": [], "en": []},
                         "group": {"ru": grp["ru"], "en": grp["en"]} if grp else {"ru": "", "en": ""}}
                for gate in ("developer", "owner"):
                    if grp and grp.get(gate):
                        entry[gate] = True
            if entry is not None:
                out.append(entry)
            stack.append((comp, depth, entry))
        if DEV.match(code) and stack and stack[-1][2] is not None and stack[-1][0] in ("PxGroup", "SettingRow"):
            stack[-1][2]["developer"] = True
        if OWNER.match(code) and stack and stack[-1][2] is not None and stack[-1][0] in ("PxGroup", "SettingRow"):
            stack[-1][2]["owner"] = True
        # a row that is one plain switch (checked: Config.a.b, set back the same way): the
        # search shows the switch right in its results
        row = next((e for c, _, e in reversed(stack) if c == "SettingRow" and e), None)
        if row is not None:
            ck = CHECKED.match(code)
            if ck:
                row["_checks"] = row.get("_checks", []) + [ck.group(1)]
            st = SETS.search(code)
            if st:
                row["_sets"] = row.get("_sets", []) + [st.group(2)]
        nm = NAME.match(code)
        if nm and stack and stack[-1][0] == "PxGroup" and stack[-1][2] is not None:
            stack[-1][2]["name"] = nm.group(1)
        p = PROP.match(code)
        pairs = [(unescape(a), unescape(b)) for a, b in PAIR.findall(code)]
        # a name that is the same in both languages ("fastfetch", "Bluetooth"): a plain string
        if p and not pairs and p.group(1) in ("title", "label"):
            lit = LIT.match(p.group(2))
            if lit:
                pairs = [(unescape(lit.group(1)), unescape(lit.group(1)))]
        if p and pairs:
            prop = p.group(1)
            e = owner()
            cur = stack[-1][0] if stack else ""
            if prop == "heading" and e is page:
                page["ru"], page["en"] = pairs[0]
            elif prop == "subtitle" and e is page:
                page["hint"] = {"ru": pairs[0][0], "en": pairs[0][1]}
            elif prop == "title" and cur == "PxGroup" and e and e["kind"] == "group" and not e["ru"]:
                e["ru"], e["en"] = pairs[0]
            elif prop == "label" and cur == "SettingRow" and e and e["kind"] == "row" and not e["ru"]:
                e["ru"], e["en"] = pairs[0]
            elif prop == "hint" and cur == "SettingRow" and e and e["kind"] == "row":
                if len(pairs) == 1 and not e["hint"]["ru"]:
                    e["hint"] = {"ru": pairs[0][0], "en": pairs[0][1]}
                else:
                    for ru, en in pairs:
                        e["words"]["ru"].append(ru)
                        e["words"]["en"].append(en)
            else:
                for ru, en in pairs:
                    e["words"]["ru"].append(ru)
                    e["words"]["en"].append(en)
        elif pairs:
            e = owner()
            for ru, en in pairs:
                e["words"]["ru"].append(ru)
                e["words"]["en"].append(en)
        depth += code.count("{") - code.count("}")
        while stack and depth <= stack[-1][1]:
            stack.pop()
    for e in out:
        checks, sets = e.pop("_checks", []), e.pop("_sets", [])
        if len(checks) == 1 and sets == checks:
            e["toggle"] = checks[0]
    # rows without a literal label (built from a model) are not reachable by name
    return [e for e in out if e["ru"] or e["kind"] == "page"]


def signature(files):
    h = hashlib.sha1()
    for f in [Path(__file__).resolve()] + files:
        try:
            st = f.stat()
            h.update(("%s %d %d\n" % (f, st.st_mtime_ns, st.st_size)).encode())
        except OSError:
            h.update(("%s -\n" % f).encode())
    return h.hexdigest()


def main():
    here = Path(__file__).resolve().parent.parent
    dirs = [Path(a) for a in sys.argv[1:]] or [here / "modules/settings/pages"]
    files = []
    for d in dirs:
        files += [d] if d.is_file() else sorted(f for f in d.glob("*Page.qml") if f.name != "PluginSettingsPage.qml")
    cache = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "angelos" / "settings-index.json"
    sig = signature(files)
    try:
        kept = json.loads(cache.read_text())
        if kept.get("sig") == sig:
            print(kept["text"])
            return
    except (OSError, ValueError, KeyError, AttributeError):
        pass
    entries = []
    for f in files:
        try:
            entries += index_page(f)
        except OSError:
            pass
    for e in entries:  # keep the extra words short and unique
        for lang in ("ru", "en"):
            seen, words = set(), []
            for w in e["words"][lang]:
                w = w.strip()
                if w and w not in seen and len(w) < 160:
                    seen.add(w)
                    words.append(w)
            e["words"][lang] = words[:40]
    text = json.dumps(entries, ensure_ascii=False)
    print(text)
    try:
        cache.parent.mkdir(parents=True, exist_ok=True)
        tmp = cache.with_suffix(".tmp%d" % os.getpid())
        tmp.write_text(json.dumps({"sig": sig, "text": text}, ensure_ascii=False))
        os.replace(tmp, cache)
    except OSError:
        pass


if __name__ == "__main__":
    main()
