#!/usr/bin/env python3
"""The screenshot keys in the shipped key templates (templates/keybinds): Mod+Shift+T is bound
nowhere (its Circle went into the screenshot), Mod+Shift+S and Print open `angelos capture`
with the old region tool as the way out when no shell answers, and every file still parses
bind by bind (the profile merge, scripts/keyprofile.py, needs that). No hotkey-overlay title,
no line of docs/KEYBINDS.md or scripts/keyprofile.py speaks of Mod+Shift+T or Circle any more;
the IPC has capture/captureOn (circle/circleOn stay as old names); Settings search finds the
classic region tool under "capture".
  test_capture_keys.py <angelOS dir> [templates dir]     exit 0 = all good"""
import importlib.util
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
tpl = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else root / "templates/keybinds"
spec = importlib.util.spec_from_file_location("kb", root / "scripts/keybinds.py")
kb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(kb)
bad = []
binds = {}
for name in ("keybinds-common.kdl", "keybinds-pixel.kdl", "keybinds-macos.kdl"):
    try:
        _, _, bs, _ = kb.parse((tpl / name).read_text())
    except (OSError, ValueError) as e:
        bad.append("%s: %s" % (name, e))
        continue
    binds[name] = {kb.norm_key(b["key"]): b for b in bs}
    if any(not b["editable"] for b in bs if b["key"] in ("Mod+Shift+S", "Print")):
        bad.append(name + ": a screenshot key is not a one-line bind")
for name, d in binds.items():
    for k in d:
        if k.lower() == kb.norm_key("Mod+Shift+T").lower():
            bad.append(name + ": Mod+Shift+T is still bound (" + d[k]["action"][:60] + ")")
common = binds.get("keybinds-common.kdl", {})
for key in ("Mod+Shift+S", "Print"):
    b = common.get(kb.norm_key(key))
    a = b["action"] if b else ""
    if "angelos capture" not in a:
        bad.append(key + " does not open `angelos capture`: " + (a[:70] or "not bound"))
    elif "niri-screenshot-region" not in a:
        bad.append(key + " has no way out to niri-screenshot-region when the shell does not answer")
    for name in ("keybinds-pixel.kdl", "keybinds-macos.kdl"):  # a profile's own would win over common
        o = binds.get(name, {}).get(kb.norm_key(key))
        if o and "angelos capture" not in o["action"]:
            bad.append(name + ": " + key + " is taken by " + o["action"][:60])
import re  # noqa: E402

old_words = re.compile(r"Mod\+Shift\+T\b|circle to search|обвести и найти", re.I)
for name, d in binds.items():
    for k, b in d.items():
        if old_words.search(b.get("title") or ""):
            bad.append("%s: %s's hotkey-overlay title is the old one: %s" % (name, k, b["title"]))
        if re.search(r"angelos (circle|ocr)\b|niri-ocr", b["action"]):
            bad.append("%s: %s still opens the old Circle/OCR: %s" % (name, k, b["action"][:60]))
for rel in ("docs/KEYBINDS.md", "scripts/keyprofile.py"):
    try:
        lines = (root / rel).read_text().splitlines()
    except OSError as e:
        bad.append("%s: %s" % (rel, e))
        continue
    for i, line in enumerate(lines, 1):
        if re.search(r"Mod\+Shift\+T\b", line):
            bad.append("%s:%d still has Mod+Shift+T: %s" % (rel, i, line.strip()[:70]))
ipc = (root / "modules/Ipc.qml").read_text()
for fn in ("function capture()", "function captureOn(screen: string)", "function circle()", "function circleOn(screen: string)"):
    if fn not in ipc:
        bad.append("modules/Ipc.qml: no " + fn)
m = re.search(r'"capture":\s*\[([^\]]*)\]', (root / "services/SettingsSearch.qml").read_text())
words = m.group(1) if m else ""
for w in ("классический выбор", "старый скриншот", "classic region", "скриншот", "print screen"):
    if '"%s"' % w not in words:
        bad.append('services/SettingsSearch.qml: "capture" does not know "%s"' % w)
for b in bad:
    print("  ✕ " + b)
if not bad:
    print("  ✓ screenshot keys: Mod+Shift+S and Print → capture, Mod+Shift+T bound nowhere")
sys.exit(1 if bad else 0)
