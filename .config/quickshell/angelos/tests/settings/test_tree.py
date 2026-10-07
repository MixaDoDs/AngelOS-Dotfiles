#!/usr/bin/env python3
"""The settings tree (modules/settings/tree.json) against the pages it is put together from.

- every group of every page file is on exactly one page of the tree (or the page file is
  there whole); every block names a file and a group that exist. The Golden Gate skin's own
  tree ("mac"): its page file (MacPage.qml) is all on it, each group once, and its blocks from
  the other files exist; the pixel files' groups it borrows stay on the pixel tree too
- no setting got lost: every configuration key the interface could change before the
  rebuild (ui-keys-before.txt, from scripts/settings-inventory.py --keys) is on a page of
  the tree
- every page id the code opens directly (openSettings("…"), settingsPage = "…": the wizard,
  the tour, the helper, Start, `angelos settings …`) leads somewhere: a page of the tree, an
  old id in "legacy", a plugin page or a view's own home
- two levels: category › page; ids unique; every name in both languages
- the setup wizard's questions that show groups from Settings (SetupFlow.qml, "blocks")
  name groups that are on a page of the tree
Run: python3 tests/settings/test_tree.py   (scripts/check.sh runs it)
"""
import importlib.util
import json
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TREE = json.loads((ROOT / "modules/settings/tree.json").read_text())
spec = importlib.util.spec_from_file_location("inventory", ROOT / "scripts/settings-inventory.py")
inventory = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inventory)
INV = inventory.inventory(ROOT / "modules/settings/pages")
SKIN_HOMES = set(TREE.get("skinHomes", []))


MAC_FILES = {"mac"}                      # page files only the Golden Gate tree shows


def tree_pages(tree=None):
    yield dict(TREE["account"], id=TREE["account"]["page"])
    for c in (tree or TREE)["categories"]:
        yield from c["pages"]


def blocks(tree=None):
    # a page's groups: shown at once ("blocks") and folded under «Ещё…» ("more")
    for p in tree_pages(tree):
        for b in p["blocks"] + p.get("more", []):
            yield p["id"], b


class Tree(unittest.TestCase):
    def test_every_group_once(self):
        groups = {(g["page"], g["name"]) for g in INV if g["name"] != "(page)" and g["page"] not in SKIN_HOMES and g["page"] not in MAC_FILES}
        files = {g["page"] for g in INV if g["page"] not in SKIN_HOMES and g["page"] not in MAC_FILES}
        seen = {}
        for pid, b in blocks():
            if b.startswith("@owner/"):
                continue
            src, _, name = b.partition("/")
            self.assertIn(src, files, f"{pid}: no page file {src!r}")
            if name == "@":          # what sits outside src's groups, no group of its own
                continue
            covered = [(s, n) for s, n in groups if s == src and (not name or n == name)]
            self.assertTrue(covered or not name, f"{pid}: no group {b!r}")
            for g in covered:
                self.assertNotIn(g, seen, f"group {g[0]}/{g[1]} is on {seen.get(g)} and on {pid}")
                seen[g] = pid
        missing = sorted(f"{s}/{n}" for s, n in groups - set(seen))
        self.assertEqual(missing, [], "groups on no page of the tree")

    def test_mac_tree(self):
        mac = TREE["mac"]
        groups = {(g["page"], g["name"]) for g in INV if g["name"] != "(page)"}
        files = {g["page"] for g in INV}
        own = {(s, n) for s, n in groups if s in MAC_FILES}
        seen = {}
        for pid, b in blocks(mac):
            if b.startswith("@owner/"):
                continue
            src, _, name = b.partition("/")
            self.assertIn(src, files, f"mac {pid}: no page file {src!r}")
            self.assertNotIn(src, SKIN_HOMES, f"mac {pid}: {src!r} is a view's home")
            self.assertTrue(not name or name == "@" or (src, name) in groups, f"mac {pid}: no group {b!r}")
            if (src, name) in own:
                self.assertNotIn((src, name), seen, f"group {b} is on {seen.get((src, name))} and on {pid}")
                seen[(src, name)] = pid
        self.assertEqual(sorted(f"{s}/{n}" for s, n in own - set(seen)), [], "MacPage groups on no page of the mac tree")
        ids = {p["id"] for p in tree_pages(mac)}
        self.assertIn(mac["fallback"], ids)
        for old, to in mac.get("legacy", {}).items():
            self.assertIn(to["page"], ids, f"mac legacy {old!r} leads to no page")
        # the pixel skins' own groups (the Win98 taskbar, desk hearts, flavours, bar layouts, decorations) stay out
        for b in ("bar/style", "bar/layout", "workspaces/desk-sprite-animation", "appearance/theme", "windows/window-decorations", "windows/alt-tab"):
            self.assertNotIn(b, {x for _, x in blocks(mac)}, f"{b} is on the Golden Gate tree")

    def test_no_setting_lost(self):
        before = set((ROOT / "tests/settings/ui-keys-before.txt").read_text().split())
        reached = set()
        by_group = {(g["page"], g["name"]): g for g in INV}
        for _, b in list(blocks()) + list(blocks(TREE["mac"])):
            if b.startswith("@owner/") or b.endswith("/@"):
                continue
            src, _, name = b.partition("/")
            for (s, n), g in by_group.items():
                # the page file's own code (functions the groups call) comes with any group of it
                if s == src and (not name or n == name or n == "(page)"):
                    reached.update(g["keys"])
        self.assertEqual(sorted(before - reached), [], "settings the interface could change before and can't now")

    def test_direct_links_lead_somewhere(self):
        ids = {p["id"] for p in tree_pages()}
        legacy = TREE.get("legacy", {})
        for old, to in legacy.items():
            self.assertIn(to["page"], ids, f"legacy {old!r} leads to no page")
        known = ids | set(legacy) | {"home", "more", ""} | {p["id"] for p in tree_pages(TREE["mac"])}
        pattern = re.compile(r'(?:openSettings\(\s*"([\w-]*)"|settingsPage\s*=\s*"([\w-]*)"|"page":\s*"([\w-]+)")')
        bad = []
        files = list(ROOT.glob("**/*.qml")) + list(ROOT.glob("**/*.js"))
        for f in files:
            if "/tests/" in str(f) or "/owner/" in str(f):
                continue
            for m in pattern.finditer(f.read_text(errors="ignore")):
                pid = next(x for x in m.groups() if x is not None)
                if m.group(3) is not None and f.name not in ("Angel.qml", "AngelLines.js", "Intents.js"):
                    continue          # "page": … elsewhere is not a settings page
                if pid not in known and not pid.startswith("plugin"):
                    bad.append(f"{f.relative_to(ROOT)}: {pid}")
        self.assertEqual(bad, [], "links to settings pages that are nowhere")

    def test_wizard_blocks_in_tree(self):
        text = (ROOT / "modules/settings/SetupFlow.qml").read_text()
        wanted = [b for m in re.finditer(r'"blocks":\s*\[([^\]]*)\]', text) for b in re.findall(r'"([^"]+)"', m.group(1))]
        self.assertTrue(wanted, "the wizard shows no group from Settings")
        on = {b for _, b in blocks()}
        for b in wanted:
            src = b.split("/")[0]
            self.assertTrue(b in on or src in on, f"the wizard's {b!r} is on no page of the tree")

    def test_shape(self):
        seen = set()
        for c in TREE["categories"]:
            self.assertTrue(c.get("ru") and c.get("en"), c["id"])
            self.assertTrue(c["pages"], f"empty category {c['id']}")
            for p in c["pages"]:
                self.assertNotIn(p["id"], seen, f"page id twice: {p['id']}")
                seen.add(p["id"])
                self.assertTrue(p.get("ru") and p.get("en"), p["id"])
                self.assertTrue(p["blocks"], f"empty page {p['id']}")
                self.assertFalse(set(p["blocks"]) & set(p.get("more", [])), f"{p['id']}: a group both at once and under «Ещё…»")
                for o in p.get("open", []):
                    self.assertIn(o, p["blocks"], f"{p['id']} opens {o!r}, not a group of it")
                # links lead to pages of the tree
                all_ids = {q["id"] for cc in TREE["categories"] for q in cc["pages"]}
                for l in p.get("links", []):
                    self.assertIn(l.split(":")[0], all_ids, f"{p['id']} links to no page: {l!r}")
                # two levels only: a page holds groups, never pages
                self.assertNotIn("pages", p, f"{p['id']} has pages of its own")


if __name__ == "__main__":
    unittest.main(verbosity=2)
