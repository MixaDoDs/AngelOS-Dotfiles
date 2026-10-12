#!/usr/bin/env python3
"""Caps Lock on the bar (scripts/caps-watch.py): the LED's state over several keyboards.
Run: python3 tests/caps/test_caps.py   (scripts/check.sh runs it)"""
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("caps_watch", ROOT / "scripts/caps-watch.py")
watch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(watch)


class Led(unittest.TestCase):
    def test_reports_changes_only(self):
        s = watch.State()
        self.assertEqual(s.set("a", 0), "off")
        self.assertIsNone(s.set("a", 0))
        self.assertEqual(s.set("a", 1), "on")
        self.assertIsNone(s.set("b", 1))

    def test_on_while_any_keyboard_shows_it(self):
        s = watch.State()
        s.set("a", 1)
        s.set("b", 1)
        self.assertIsNone(s.set("a", 0))
        self.assertEqual(s.drop("b"), "off")


if __name__ == "__main__":
    unittest.main()
