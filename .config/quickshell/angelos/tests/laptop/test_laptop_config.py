#!/usr/bin/env python3
"""scripts/laptop-config.py in a throw-away HOME: the keys and switches it writes, the include
it adds once, a key you bound yourself left alone, a refused config rolled back.
A stand-in `niri` answers `niri validate` (the real one isn't needed, nor touched).
Run: python3 tests/laptop/test_laptop_config.py   (scripts/check.sh runs it)"""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/laptop-config.py"
FAKE_NIRI = """#!/bin/sh
# stand-in niri: `validate` fails when the config tree holds the word BROKEN
[ "$1" = validate ] || exit 0
grep -rq BROKEN "$(dirname "$3")" && { echo "error: BROKEN" >&2; exit 1; }
exit 0
"""


class LaptopConfig(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        self.niri = self.home / ".config/niri"
        (self.niri / "cfg").mkdir(parents=True)
        (self.niri / "config.kdl").write_text('include "./cfg/keybinds.kdl"\n')
        (self.niri / "cfg/keybinds.kdl").write_text('binds {\n    Mod+T { spawn "kitty"; }\n    // Mod+P { spawn "x"; }\n}\n')
        bin_ = self.home / "bin"
        bin_.mkdir()
        (bin_ / "niri").write_text(FAKE_NIRI)
        (bin_ / "niri").chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / ".config"),
                        PATH=f"{bin_}:/usr/bin:/bin")

    def tearDown(self):
        self.tmp.cleanup()

    def run_(self, *args):
        p = subprocess.run([sys.executable, str(SCRIPT), *args], capture_output=True, text=True, env=self.env, timeout=20)
        return p

    def test_writes_once(self):
        p = self.run_(json.dumps({"keys": True, "switches": True}))
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertTrue(json.loads(p.stdout)["saved"])
        text = (self.niri / "cfg/angelos-laptop.kdl").read_text()
        for key in ("XF86MonBrightnessUp", "XF86TouchpadToggle", "XF86RFKill", "Mod+P", "lid-close", "tablet-mode-on"):
            self.assertIn(key, text)
        self.assertIn('spawn "sh" "-c"', text)          # switch-events take no spawn-sh
        cfg = (self.niri / "config.kdl").read_text()
        self.assertEqual(cfg.count("angelos-laptop.kdl"), 1)
        self.assertTrue(cfg.rstrip().endswith('include "./cfg/angelos-laptop.kdl"'))   # last
        again = self.run_(json.dumps({"keys": True, "switches": True}))
        self.assertFalse(json.loads(again.stdout)["saved"])
        self.assertEqual((self.niri / "config.kdl").read_text(), cfg)

    def test_own_binding_kept(self):
        kb = self.niri / "cfg/keybinds.kdl"
        kb.write_text(kb.read_text().replace("}\n", '    Super+p { spawn "rofi"; }\n    XF86MonBrightnessUp { spawn "x"; }\n}\n'))
        p = self.run_(json.dumps({"keys": True, "switches": False}))
        j = json.loads(p.stdout)
        self.assertEqual(sorted(j["skipped"]), ["Mod+P", "XF86MonBrightnessUp"])
        text = (self.niri / "cfg/angelos-laptop.kdl").read_text()
        self.assertNotIn("Mod+P", text)
        self.assertIn("XF86MonBrightnessDown", text)
        self.assertNotIn("switch-events", text)

    def test_keys_off(self):
        self.run_(json.dumps({"keys": True, "switches": True}))
        self.run_(json.dumps({"keys": False, "switches": True}))
        text = (self.niri / "cfg/angelos-laptop.kdl").read_text()
        self.assertNotIn("binds {", text)
        self.assertIn("switch-events", text)

    def test_rollback(self):
        (self.niri / "cfg/keybinds.kdl").write_text("binds { BROKEN }\n")
        before = (self.niri / "config.kdl").read_text()
        p = self.run_(json.dumps({"keys": True, "switches": True}))
        self.assertNotEqual(p.returncode, 0)
        self.assertEqual((self.niri / "config.kdl").read_text(), before)
        self.assertFalse((self.niri / "cfg/angelos-laptop.kdl").exists())


if __name__ == "__main__":
    unittest.main(verbosity=1)
