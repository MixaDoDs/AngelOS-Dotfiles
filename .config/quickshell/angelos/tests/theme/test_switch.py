#!/usr/bin/env python3
"""scripts/switch.py angelos in a throw-away $HOME — the run Settings → Updates makes on every update.

- the theme files come in the user's own palette (~/.cache/angelos/palette.json, ThemeExport's),
  not the stock one: an update that didn't restart the shell left kitty, foot, GTK and niri in the
  stock pink until the theme was changed by hand
- the templates switched off in Settings → Appearance stay off; with app theming off nothing is
  rendered (only a missing angelos.kdl, which niri includes, is written)
- the stock palette still makes a first install's files
- an old autostart that also spawned the Voxtype daemon loses that line once its service is enabled
"""
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SHELL = Path(__file__).resolve().parents[2]
SCRIPT = SHELL / "scripts/switch.py"
STOCK = json.loads((SHELL / "templates/palette-default.json").read_text())
# every template that runs a command: they talk to the real session (gsettings, running apps)
COMMANDS = [e["id"] for e in json.loads((SHELL / "templates/templates.json").read_text()) if e.get("command")]


class Switch(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        # stand-ins for what the renderer would reach outside the fake home
        stubs = self.home / "stubs"
        stubs.mkdir()
        for name in ("pkill", "gsettings", "niri"):
            (stubs / name).write_text("#!/bin/sh\nexit 0\n")
            (stubs / name).chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.home), PATH=f"{stubs}:{os.environ['PATH']}",
                        XDG_CONFIG_HOME=str(self.home / ".config"), XDG_CACHE_HOME=str(self.home / ".cache"),
                        XDG_STATE_HOME=str(self.home / ".local/state"), XDG_DATA_HOME=str(self.home / ".local/share"))
        self.settings({})

    def tearDown(self):
        self.tmp.cleanup()

    def settings(self, appearance):
        f = self.home / ".config/angelos/settings.json"
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(json.dumps({"appearance": dict({"disabledTemplates": COMMANDS}, **appearance)}))

    def palette(self, **over):
        f = self.home / ".cache/angelos/palette.json"
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(json.dumps(dict(STOCK, flavor="wallpaper", mode="dark", **over)))

    def switch(self):
        r = subprocess.run(["python3", str(SCRIPT), "angelos", "--no-restart", "--no-validate"],
                           env=self.env, capture_output=True, text=True, timeout=60)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        return r.stdout

    def read(self, rel):
        return (self.home / rel).read_text()

    def test_user_palette_kept(self):
        self.palette(accent="#636f99", bg="#101418")
        self.switch()
        kitty = self.read(".config/kitty/themes/angelos.conf")
        self.assertRegex(kitty, r"(?m)^cursor\s+#636f99$")
        self.assertIn("angelOS wallpaper / dark", kitty)
        self.assertIn("#636f99", self.read(".config/niri/angelos.kdl"))
        self.assertIn("#101418", self.read(".config/gtk-4.0/angelos.css"))

    def test_disabled_templates_left_alone(self):
        self.palette(accent="#636f99")
        foot = self.home / ".config/foot/themes/angelos"
        foot.parent.mkdir(parents=True)
        foot.write_text("# mine\n")
        self.settings({"disabledTemplates": COMMANDS + ["foot"]})
        self.switch()
        self.assertEqual(foot.read_text(), "# mine\n")
        self.assertIn("#636f99", self.read(".config/kitty/themes/angelos.conf"))

    def test_theming_off(self):
        self.palette(accent="#636f99")
        self.settings({"themeApps": False})
        kdl = self.home / ".config/niri/angelos.kdl"
        self.switch()   # no angelos.kdl yet: niri includes it, so it is written
        self.assertTrue(kdl.exists())
        kdl.write_text("// mine\n")
        kitty = self.home / ".config/kitty/themes/angelos.conf"
        kitty.unlink(missing_ok=True)
        self.switch()
        self.assertEqual(kdl.read_text(), "// mine\n")
        self.assertFalse(kitty.exists())

    def test_first_install_stock(self):
        self.switch()
        self.assertIn(STOCK["accent"], self.read(".config/kitty/themes/angelos.conf"))
        self.assertTrue((self.home / ".config/niri/angelos.kdl").exists())

    def test_broken_palette_falls_back(self):
        f = self.home / ".cache/angelos/palette.json"
        f.parent.mkdir(parents=True)
        f.write_text("{not json")
        self.switch()
        self.assertIn(STOCK["accent"], self.read(".config/kitty/themes/angelos.conf"))

    def test_one_voxtype(self):
        auto = self.home / ".config/niri/cfg/autostart.kdl"
        auto.parent.mkdir(parents=True)
        old = ('    spawn-at-startup "qs" "-c" "angelos" "-n"\n'
               f'    spawn-at-startup "{self.home}/.local/bin/voxtype" "daemon"\n'
               '    spawn-sh-at-startup "systemctl --user start voxtype-indicator.service"\n')
        auto.write_text(old)
        self.switch()   # the service isn't enabled: the spawn is the only one, it stays
        self.assertIn('voxtype" "daemon"', auto.read_text())
        wants = self.home / ".config/systemd/user/graphical-session.target.wants"
        wants.mkdir(parents=True)
        (wants / "voxtype.service").write_text("")
        self.switch()
        text = auto.read_text()
        self.assertNotIn('voxtype" "daemon"', text)
        self.assertIn('spawn-at-startup "angelos" "start"', text)
        self.assertIn("voxtype-indicator.service", text)


if __name__ == "__main__":
    unittest.main(verbosity=2)
