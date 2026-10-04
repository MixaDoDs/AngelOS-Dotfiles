#!/usr/bin/env python3
"""data/appmenu-profiles.json — the Golden Gate menu bar's menus for apps that give none of their
own — has no dead item: every item presses keys wtype knows, types into a field a step before
opened, or runs a command; labels in both languages; shared menus exist; an app id is matched once.

  python3 tests/appmenu/test_profiles.py      exit 0 = all good
"""
import json
import sys
from pathlib import Path

DATA = Path(__file__).resolve().parents[2] / "data" / "appmenu-profiles.json"
MODS = {"ctrl", "shift", "alt", "logo"}
# key names the profiles use: X keysym names wtype -k understands
KEYS = set("abcdefghijklmnopqrstuvwxyz0123456789") | {
    "Return", "Escape", "Delete", "BackSpace", "Tab", "Left", "Right", "Up", "Down", "Home", "End",
    "Prior", "Next", "equal", "plus", "minus", "comma", "period", "question", "grave", "space"} | {"F%d" % i for i in range(1, 13)}

errors = []
data = json.loads(DATA.read_text())


def label_ok(where, label):
    if not (isinstance(label, list) and len(label) == 2 and all(isinstance(x, str) and x.strip() for x in label)):
        errors.append("%s: label must be [ru, en]: %r" % (where, label))


def keys_ok(where, keys):
    if not keys or not isinstance(keys, list):
        errors.append("%s: no keys" % where)
        return
    rest = [k for k in keys if k not in MODS]
    if len(rest) != 1 or rest[0] not in KEYS:
        errors.append("%s: keys %r — one key (a keysym name) after the modifiers" % (where, keys))


def item_ok(where, it):
    if it == "-":
        return
    label_ok(where, it.get("label"))
    acts = [k for k in ("keys", "seq", "run") if k in it]
    if len(acts) != 1:
        errors.append("%s: needs exactly one of keys / seq / run, has %r" % (where, acts))
        return
    if "keys" in it:
        keys_ok(where, it["keys"])
    elif "seq" in it:
        steps = it["seq"]
        if not steps or not steps[0].get("keys"):
            errors.append("%s: a sequence starts with keys (it opens the field it types into)" % where)
        for n, s in enumerate(steps):
            if "keys" in s:
                keys_ok("%s step %d" % (where, n), s["keys"])
            elif not isinstance(s.get("type"), str) or not s["type"]:
                errors.append("%s step %d: keys or text to type" % (where, n))
    elif not (isinstance(it["run"], list) and it["run"] and all(isinstance(a, str) for a in it["run"])):
        errors.append("%s: run is an argv list" % where)


shared = data.get("menus", {})
for name, menu in shared.items():
    label_ok(name, menu.get("title"))
    for n, it in enumerate(menu.get("items", [])):
        item_ok("%s[%d]" % (name, n), it)

seen = {}
for pid, ids in data["match"].items():
    if pid not in data["profiles"]:
        errors.append("match %s: no such profile" % pid)
    for app in ids:
        if app in seen:
            errors.append("app id %s matched by %s and %s" % (app, seen[app], pid))
        seen[app] = pid

count = 0
for pid, prof in data["profiles"].items():
    for n, menu in enumerate(prof.get("menus", [])):
        where = "%s menu %d" % (pid, n)
        if "ref" in menu:
            if menu["ref"] not in shared:
                errors.append("%s: no shared menu %s" % (where, menu["ref"]))
        else:
            label_ok(where, menu.get("title"))
        for m, it in enumerate(menu.get("items", []) + menu.get("extra", [])):
            item_ok("%s item %d" % (where, m), it)
            count += it != "-"
    p = prof.get("prefs")
    if p is not None:
        item_ok(pid + " prefs", dict(p, label=["Настройки…", "Settings…"]))
    for m, it in enumerate(prof.get("help", [])):
        item_ok("%s help %d" % (pid, m), it)

if errors:
    print("\n".join("  ✕ " + e for e in errors))
    print("» appmenu profiles FAILED")
    sys.exit(1)
print("  ✓ %d profiles, %d items, every one runnable" % (len(data["profiles"]), count))
print("» appmenu profiles passed")
