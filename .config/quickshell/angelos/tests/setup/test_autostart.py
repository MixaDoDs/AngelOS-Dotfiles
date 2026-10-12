#!/usr/bin/env python3
"""scripts/autostart.py in throw-away XDG folders: the user's entries over the system's, an app
added from its launcher, a command of one's own, a system entry switched off without touching the
system file, and what this desktop wouldn't start told apart."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/autostart.py"


class Autostart(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="angelos-autostart-")
        self.addCleanup(tmp.cleanup)
        self.t = Path(tmp.name)
        self.user = self.t / "config/autostart"
        self.system = self.t / "etc/autostart"
        self.apps = self.t / "share/applications"
        for d in (self.system, self.apps):
            d.mkdir(parents=True)
        self.env = {"PATH": os.environ["PATH"], "HOME": str(self.t), "XDG_CONFIG_HOME": str(self.t / "config"),
                    "XDG_CONFIG_DIRS": str(self.t / "etc"), "XDG_DATA_HOME": str(self.t / "data"),
                    "XDG_DATA_DIRS": str(self.t / "share"), "XDG_CURRENT_DESKTOP": "niri", "ANGELOS_LANG": "ru",
                    "AUTOSTART_WORKS": "1"}
        (self.system / "keyring.desktop").write_text("[Desktop Entry]\nType=Application\nName=Keyring\nExec=keyring --start\nNoDisplay=true\n")
        (self.system / "gnome-only.desktop").write_text("[Desktop Entry]\nType=Application\nName=Gnome thing\nExec=true\nOnlyShowIn=GNOME;\n")
        (self.apps / "chat.desktop").write_text(
            "[Desktop Entry]\nType=Application\nName=Chat\nName[ru]=Чат\nIcon=chat\nExec=chat --open %U\nCategories=Network;\n"
            "\n[Desktop Action quit]\nName=Quit\nExec=chat --quit\n")

    def run_it(self, *args, ok=True):
        r = subprocess.run([sys.executable, str(SCRIPT), *args], env=self.env, capture_output=True, text=True)
        if ok:
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        return r

    def listed(self):
        out = json.loads(self.run_it("list").stdout)
        self.assertTrue(out["works"])
        return {e["id"]: e for e in out["entries"]}

    def test_an_app_added_switched_and_removed(self):
        self.assertEqual(self.run_it("add", "chat").stdout.strip(), "chat.desktop")
        text = (self.user / "chat.desktop").read_text()
        self.assertIn("Exec=chat --open\n", text, "no file to open at login")
        self.assertNotIn("Desktop Action", text)
        self.assertNotIn("chat --quit", text)
        e = self.listed()["chat.desktop"]
        self.assertEqual((e["name"], e["icon"], e["on"], e["source"], e["system"], e["fits"]), ("Чат", "chat", True, "user", False, True))
        self.run_it("off", "chat.desktop")
        self.assertFalse(self.listed()["chat.desktop"]["on"])
        self.assertIn("Exec=chat --open", (self.user / "chat.desktop").read_text(), "off keeps the entry")
        self.run_it("on", "chat.desktop")
        self.assertTrue(self.listed()["chat.desktop"]["on"])
        self.assertNotIn("Hidden", (self.user / "chat.desktop").read_text())
        self.run_it("remove", "chat.desktop")
        self.assertNotIn("chat.desktop", self.listed())

    def test_a_command_of_ones_own(self):
        fid = self.run_it("add-command", "Мой скрипт", "sh -c 'sleep 5; notify-send hi'").stdout.strip()
        self.assertTrue(fid.startswith("angelos-") and fid.endswith(".desktop"), fid)
        e = self.listed()[fid]
        self.assertEqual((e["name"], e["exec"], e["on"]), ("Мой скрипт", "sh -c 'sleep 5; notify-send hi'", True))
        self.assertEqual(self.run_it("add-command", "two words", "prog", "an arg").stdout.strip(), "angelos-two-words.desktop")
        self.assertIn("Exec=prog 'an arg'", (self.user / "angelos-two-words.desktop").read_text())

    def test_a_system_entry_is_only_ever_switched(self):
        before = (self.system / "keyring.desktop").read_text()
        e = self.listed()["keyring.desktop"]
        self.assertEqual((e["on"], e["source"], e["system"]), (True, "system", True))
        self.run_it("off", "keyring.desktop")
        e = self.listed()["keyring.desktop"]
        self.assertEqual((e["on"], e["source"], e["name"], e["exec"]), (False, "override", "Keyring", "keyring --start"))
        self.run_it("on", "keyring.desktop")
        self.assertFalse((self.user / "keyring.desktop").exists(), "on again = the system's own file, no override left")
        self.run_it("remove", "keyring.desktop")
        self.assertFalse(self.listed()["keyring.desktop"]["on"], "removing a system entry switches it off")
        self.assertEqual((self.system / "keyring.desktop").read_text(), before, "the system file is never touched")

    def test_what_this_desktop_would_not_start(self):
        self.assertFalse(self.listed()["gnome-only.desktop"]["fits"])

    def test_bad_input_is_refused(self):
        for args in (("add", "nope"), ("off", "../../etc/passwd"), ("remove", "nope.desktop"), ("on", "a/b.desktop")):
            r = self.run_it(*args, ok=False)
            self.assertEqual(r.returncode, 1, args)
        self.assertFalse(self.user.exists() and list(self.user.iterdir()))


if __name__ == "__main__":
    unittest.main(verbosity=2)
