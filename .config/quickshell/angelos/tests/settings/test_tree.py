#!/usr/bin/env python3
"""The settings tree (modules/settings/tree.json) against the pages it is put together from.

- every group of every page file is on exactly one page of the tree (or the page file is
  there whole); every block names a file and a group that exist
- no setting got lost: every configuration key the interface could change before the
  rebuild (ui-keys-before.txt, from scripts/settings-inventory.py --keys) is on a page of
  the tree
- every page id the code opens directly (openSettings("…"), settingsPage = "…": the wizard,
  the tour, the helper, Start, `angelos settings …`) leads somewhere: a page of the tree, an
  old id in "legacy", a plugin page or a view's own home
- two levels: category › page; ids unique; every name in both languages
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


def tree_pages():
    yield dict(TREE["account"], id=TREE["account"]["page"])
    for c in TREE["categories"]:
        yield from c["pages"]


def blocks():
    for p in tree_pages():
        for b in p["blocks"]:
            yield p["id"], b


class Tree(unittest.TestCase):
    def test_every_group_once(self):
        groups = {(g["page"], g["name"]) for g in INV if g["name"] != "(page)" and g["page"] not in SKIN_HOMES}
        files = {g["page"] for g in INV if g["page"] not in SKIN_HOMES}
        seen = {}
        for pid, b in blocks():
            if b.startswith("@owner/"):
                continue
            src, _, name = b.partition("/")
            self.assertIn(src, files, f"{pid}: no page file {src!r}")
            covered = [(s, n) for s, n in groups if s == src and (not name or n == name)]
            self.assertTrue(covered or not name, f"{pid}: no group {b!r}")
            for g in covered:
                self.assertNotIn(g, seen, f"group {g[0]}/{g[1]} is on {seen.get(g)} and on {pid}")
                seen[g] = pid
        missing = sorted(f"{s}/{n}" for s, n in groups - set(seen))
        self.assertEqual(missing, [], "groups on no page of the tree")

    def test_no_setting_lost(self):
        before = set((ROOT / "tests/settings/ui-keys-before.txt").read_text().split())
        reached = set()
        by_group = {(g["page"], g["name"]): g for g in INV}
        for _, b in blocks():
            if b.startswith("@owner/"):
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
        known = ids | set(legacy) | {"home", "more", ""}
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
                for o in p.get("open", []):
                    self.assertIn(o, p["blocks"], f"{p['id']} opens {o!r}, not a group of it")
                # two levels only: a page holds groups, never pages
                self.assertNotIn("pages", p, f"{p['id']} has pages of its own")


if __name__ == "__main__":
    unittest.main(verbosity=2)
