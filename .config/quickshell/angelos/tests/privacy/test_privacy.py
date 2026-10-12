#!/usr/bin/env python3
"""The dotfiles' niri-cast-privacy (privacy on stream) in a throw-away HOME: the mode's rule, the
list of apps and its changes while the mode is on or off, a list broken by hand. ANGELOS_TEST=1:
no niri is asked and nothing is notified, so the real session never hears of it.
Run: python3 tests/privacy/test_privacy.py   (scripts/check.sh runs it)"""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
# the repository keeps the tool next to the shell's folder; a live system in ~/.local/bin
TOOL = next((p for p in (ROOT.parents[2] / ".local/bin/niri-cast-privacy", Path.home() / ".local/bin/niri-cast-privacy")
             if p.is_file()), None)


@unittest.skipUnless(TOOL, "no niri-cast-privacy here")
class Privacy(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        self.rules = self.home / ".config/niri/cfg/privacy-block.kdl"
        self.list = self.home / ".config/angelos/privacy.json"

    def tearDown(self):
        self.tmp.cleanup()

    def run_tool(self, *args, ok=True):
        # no desktop entries but the HOME's own: an app's name must not depend on this machine
        env = {"HOME": str(self.home), "PATH": os.environ["PATH"], "ANGELOS_TEST": "1", "LANG": "C",
               "XDG_DATA_DIRS": str(self.home / "nothing")}
        r = subprocess.run([sys.executable, str(TOOL), *args], capture_output=True, text=True, env=env)
        if ok:
            self.assertEqual(r.returncode, 0, r.stderr)
        return r

    def status(self):
        return json.loads(self.run_tool("status").stdout)

    def hidden(self):
        return [line.split('"')[1] for line in self.rules.read_text().splitlines() if "match app-id" in line]

    def test_toggle_writes_the_default_list(self):
        self.assertFalse(self.status()["on"])
        self.run_tool()
        text = self.rules.read_text()
        self.assertTrue(text.startswith("// privacy block-out on"))
        self.assertIn('block-out-from "screencast"', text)
        self.assertEqual(self.hidden(), [r"^org\.telegram\.desktop$", r"^io\.github\.snowyfluffy\.freshgram$",
                                         "^Bitwarden$", "^helium$", "^discord$"])
        self.assertTrue(self.status()["on"])
        self.run_tool("toggle")
        self.assertEqual(self.rules.read_text(), "// privacy block-out off (Mod+Shift+X)\n")
        self.assertFalse(self.status()["on"])

    def test_on_and_off_are_not_toggles(self):
        self.run_tool("on")
        self.run_tool("on")
        self.assertTrue(self.status()["on"])
        self.run_tool("off")
        self.run_tool("off")
        self.assertFalse(self.status()["on"])

    def test_an_old_rule_without_the_mark_counts_as_on(self):
        self.rules.parent.mkdir(parents=True)
        self.rules.write_text('// privacy block-out on (Mod+Shift+X)\nwindow-rule {\n    match app-id=r#"^helium$"#\n'
                              '    block-out-from "screencast"\n}\n')
        self.assertTrue(self.status()["on"])
        self.run_tool()
        self.assertFalse(self.status()["on"])

    def test_the_list_changes_while_off(self):
        self.run_tool("app", "add", "org.keepassxc.KeePassXC")
        self.run_tool("app", "remove", "helium")
        self.run_tool("app", "forget", "discord")
        apps = {a["id"]: a for a in self.status()["apps"]}
        self.assertTrue(apps["org.keepassxc.KeePassXC"]["on"])
        self.assertEqual(apps["org.keepassxc.KeePassXC"]["name"], "KeePassXC")
        self.assertFalse(apps["helium"]["on"])
        self.assertNotIn("discord", apps)
        self.assertFalse(self.rules.exists())          # the mode was not touched
        self.run_tool("on")
        self.assertEqual(self.hidden(), [r"^org\.telegram\.desktop$", r"^io\.github\.snowyfluffy\.freshgram$",
                                         "^Bitwarden$", r"^org\.keepassxc\.KeePassXC$"])

    def test_the_list_changes_while_on_rewrite_the_rule(self):
        self.run_tool("on")
        self.run_tool("app", "toggle", "helium")
        self.assertNotIn("^helium$", self.hidden())
        self.run_tool("app", "toggle", "helium")
        self.assertIn("^helium$", self.hidden())
        self.run_tool("app", "toggle", "steam")
        self.assertIn("^steam$", self.hidden())
        self.assertTrue(self.status()["on"])

    def test_nothing_ticked_is_still_the_mode_on(self):
        for app in ("org.telegram.desktop", "io.github.snowyfluffy.freshgram", "Bitwarden", "helium", "discord"):
            self.run_tool("app", "forget", app)
        self.run_tool("on")
        self.assertNotIn("window-rule", self.rules.read_text())
        self.assertTrue(self.status()["on"])

    def test_an_app_id_cannot_break_the_rule(self):
        for bad in ('evil"# }', "two\nlines", ""):
            r = self.run_tool("app", "add", bad, ok=False)
            self.assertNotEqual(r.returncode, 0, bad)
        self.run_tool("app", "add", "a+b (c) [d]")
        self.run_tool("on")
        self.assertIn(r"^a\+b \(c\) \[d\]$", self.hidden())

    def test_a_broken_list_falls_back_and_is_cleaned(self):
        self.list.parent.mkdir(parents=True)
        self.list.write_text("{ not json")
        self.assertEqual(len(self.status()["apps"]), 5)
        self.list.write_text(json.dumps({"apps": [{"id": "helium"}, {"id": "helium", "on": False}, {"id": 5}, "x",
                                                  {"id": 'q"q'}, {"id": "foot", "name": "Foot", "on": False}]}))
        self.assertEqual(self.status()["apps"], [{"id": "helium", "name": "Helium", "on": True},
                                                 {"id": "foot", "name": "Foot", "on": False}])

    def test_a_new_app_is_named_by_its_desktop_entry(self):
        apps = self.home / ".local/share/applications"
        apps.mkdir(parents=True)
        (apps / "org.example.Vault.desktop").write_text("[Desktop Entry]\nType=Application\nName=My Vault\n")
        self.run_tool("app", "add", "org.example.Vault")
        self.assertIn({"id": "org.example.Vault", "name": "My Vault", "on": True}, self.status()["apps"])

    def test_the_focused_window_needs_a_window(self):
        r = self.run_tool("app", "toggle", ok=False)       # no niri under test: nothing is focused
        self.assertNotEqual(r.returncode, 0)
        self.assertFalse(self.list.exists())

    def test_unknown_arguments_change_nothing(self):
        for args in (["nope"], ["app", "explode", "helium"], ["on", "extra"]):
            self.assertNotEqual(self.run_tool(*args, ok=False).returncode, 0)
        self.assertFalse(self.rules.exists())


if __name__ == "__main__":
    unittest.main()
