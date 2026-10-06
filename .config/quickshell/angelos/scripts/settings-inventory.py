#!/usr/bin/env python3
"""Every setting the Settings window offers, read from the pages' QML.

  settings-inventory.py [--json] [--keys] [pages dir]

For every page (modules/settings/pages/*Page.qml) and every PxGroup on it: the group's
name (`name:`, the key the settings tree uses), its title (ru/en), whether it is a
sub-page (`advanced: true`) or only for developers/the owner, its rows (SettingRow labels)
and the configuration keys it changes — `Config.section.key = …` inside the group, and
inside the settings' own components it uses (StartTuner, BarLayoutEditor…) — plus the
other ways it saves things (StartPrefs.set, Outputs.set…) and the pages it links to.
Whatever sits on a page outside any group is listed as the pseudo-group "(page)".

  --keys   one configuration key per line, sorted: what the interface can change
           (tests/settings compares it with the list from before the rebuild)
  --json   the whole inventory as JSON (default: a Markdown table)
"""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
PAIR = re.compile(r'I18n\.t\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\)')
WRITE = re.compile(r'Config\.([a-z][A-Za-z0-9]*)\.([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)')
READ = re.compile(r'Config\.([a-z][A-Za-z0-9]*)\.([A-Za-z_][A-Za-z0-9_]*)')
SAVERS = re.compile(r'\b([A-Z][A-Za-z0-9]+)\.(set[A-Z]?\w*|save\w*|apply\w*|pick\w*|toggle\w*|write\w*|put|remove\w*|add\w*)\(')
LINK = re.compile(r'(?:(?:openSettings\(|settingsGo\(\s*\w+\s*,)\s*"([\w:-]+)"|settingsPage\s*=\s*"([\w:-]+)")')
TYPE = re.compile(r'^\s*([A-Z][A-Za-z0-9]*)\s*\{')
# components of the settings themselves whose own writes belong to the group using them
COMPONENT_DIRS = [HERE / "modules/settings", HERE / "widgets"]


def unescape(s):
    return re.sub(r"\\(.)", r"\1", s)


def page_id(path):
    name = path.stem[:-4] if path.stem.endswith("Page") else path.stem
    return name[:1].lower() + name[1:]


def strip_comments(text):
    out = []
    for line in text.splitlines():
        # a // outside a string ends the code on the line
        code, q = [], False
        i = 0
        while i < len(line):
            c = line[i]
            if c == '"' and (i == 0 or line[i - 1] != "\\"):
                q = not q
            if not q and line.startswith("//", i):
                break
            code.append(c)
            i += 1
        out.append("".join(code))
    return "\n".join(out)


def blocks(text, typename):
    """[(start, end)] of every `typename {…}` block at any depth"""
    found = []
    for m in re.finditer(r"(?m)^\s*" + typename + r"\s*\{", text):
        i = text.index("{", m.start())
        depth = 0
        for j in range(i, len(text)):
            if text[j] == "{":
                depth += 1
            elif text[j] == "}":
                depth -= 1
                if depth == 0:
                    found.append((m.start(), j + 1))
                    break
    return found


_components = {}


def component_writes(name):
    """the config keys a settings component (StartTuner…) writes itself"""
    if name in _components:
        return _components[name]
    _components[name] = set()
    for d in COMPONENT_DIRS:
        for f in d.rglob(name + ".qml"):
            text = strip_comments(f.read_text())
            keys = {f"{a}.{b}" for a, b in WRITE.findall(text)}
            for t in set(TYPE.findall(text)):
                if t != name:
                    keys |= component_writes(t)
            _components[name] = keys
            return keys
    return set()


def own_props(block):
    """the block's own lines, children blocks cut out (title:/name:/advanced: of this group)"""
    i = block.index("{")
    depth, out = 0, []
    for c in block[i:]:
        if c == "{":
            depth += 1
            if depth > 1:
                continue
        elif c == "}":
            depth -= 1
            continue
        if depth == 1:
            out.append(c)
    return "".join(out)


def describe(pid, text, title_hint=None):
    props = own_props(text)
    name = re.search(r'^\s*name\s*:\s*"([^"]+)"', props, re.M)
    title = re.search(r'^\s*title\s*:\s*(.+)$', props, re.M)
    tr = PAIR.search(title.group(1)) if title else None
    rows = []
    for s, e in blocks(text, "SettingRow"):
        lab = re.search(r'^\s*label\s*:\s*(.+)$', own_props(text[s:e]), re.M)
        p = PAIR.search(lab.group(1)) if lab else None
        rows.append(unescape(p.group(1)) if p else (lab.group(1).strip() if lab else "?"))
    writes = {f"{a}.{b}" for a, b in WRITE.findall(text)}
    for t in set(TYPE.findall(text)):
        if t not in ("PxGroup", "SettingRow", "PxPage", "Column", "Row", "Item", "Repeater", "Flow"):
            writes |= component_writes(t)
    reads = {f"{a}.{b}" for a, b in READ.findall(text)} - writes
    cond = re.search(r'^\s*(?:shown|visible)\s*:\s*(.+)$', props, re.M)
    return {
        "page": pid,
        "name": name.group(1) if name else "",
        "title": {"ru": unescape(tr.group(1)), "en": unescape(tr.group(2))} if tr else {"ru": title_hint or (title.group(1).strip() if title else ""), "en": title_hint or ""},
        "advanced": bool(re.search(r'^\s*advanced\s*:\s*true', props, re.M)),
        "developer": bool(cond and "developer" in cond.group(1)),
        "owner": bool(cond and "Owner" in cond.group(1)),
        "rows": rows,
        "keys": sorted(writes),
        "reads": sorted(reads),
        "savers": sorted({f"{a}.{b}" for a, b in SAVERS.findall(text)} - {"Config.undo"}),
        "links": sorted({a or b for a, b in LINK.findall(text)}),
    }


def inventory(pages_dir):
    out = []
    for f in sorted(Path(pages_dir).glob("*Page.qml")):
        pid = page_id(f)
        text = strip_comments(f.read_text())
        groups = blocks(text, "PxGroup")
        rest, last = [], 0
        for s, e in groups:
            rest.append(text[last:s])
            last = e
        rest.append(text[last:])
        out.extend(describe(pid, text[s:e]) for s, e in groups)
        page_rest = describe(pid, "PxPage {" + "".join(rest) + "}", "(page)")
        page_rest["name"] = "(page)"
        page_rest["title"] = {"ru": "(страница)", "en": "(page)"}
        if page_rest["rows"] or page_rest["keys"] or page_rest["savers"] or page_rest["links"]:
            out.append(page_rest)
    return out


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    inv = inventory(args[0] if args else HERE / "modules/settings/pages")
    if "--keys" in argv:
        print("\n".join(sorted({k for g in inv for k in g["keys"]})))
    elif "--json" in argv:
        print(json.dumps(inv, ensure_ascii=False, indent=1))
    else:
        print("| page | group | name | sub | rows | keys |")
        print("|---|---|---|---|---|---|")
        for g in inv:
            print(f"| {g['page']} | {g['title']['ru']} | {g['name']} | {'›' if g['advanced'] else ''}{' dev' if g['developer'] else ''} | {'; '.join(g['rows'])} | {', '.join(g['keys'])} |")


if __name__ == "__main__":
    main(sys.argv[1:])
