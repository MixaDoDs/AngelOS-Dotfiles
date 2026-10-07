#!/usr/bin/env python3
"""scripts/browser-theme.py in a throw-away $HOME (D1): the profile edits, their undo, and the
gentle restart — against stand-in browsers, never the real ones.

The stand-in "helium" behaves like Chromium where it matters: it keeps its prefs in memory and
writes them over Preferences when it gets SIGTERM, so an edit made before it has exited is lost.
Stand-ins on another profile and on the default one (started without --user-data-dir, as the
person's real browser is) must survive everything untouched.
"""
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/browser-theme.py"

FAKE = r'''#!/usr/bin/python3
import json, signal, sys, time
import os, socket
prof = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--user-data-dir=")), os.environ["HOME"] + "/.config/net.imput.helium")
try:
    os.unlink(prof + "/SingletonLock")
except OSError:
    pass
os.symlink("%s-%d" % (socket.gethostname(), os.getpid()), prof + "/SingletonLock")   # as Chromium does
path = prof + "/Default/Preferences"
prefs = json.load(open(path))            # what Chromium holds in memory
def bye(*_):
    time.sleep(0.6)                        # it takes a moment, then writes everything back
    prefs.setdefault("profile", {})["exit_type"] = "SessionEnded"
    json.dump(prefs, open(path, "w"))
    sys.exit(0)
signal.signal(signal.SIGTERM, bye)
open(prof + "/started", "w").write("1")
while True:
    time.sleep(0.1)
'''

PREFS = {
    "browser": {"theme": {"user_color2": -7558172, "color_variant2": 2, "color_scheme2": 2}},
    "extensions": {"theme": {"id": "user_color_theme_id"}, "settings": {}},
    "profile": {"name": "Person 1"},
}

USERCHROME = '@namespace url("http://www.mozilla.org/keymaster/gatekeeper/there.is.only.xul");\n#TabsToolbar { visibility: collapse; }\n'
USERJS = 'user_pref("browser.startup.page", 3);\n'


class BrowserTheme(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        self.prof = self.home / "helium-test"
        (self.prof / "Default").mkdir(parents=True)
        (self.prof / "Default/Preferences").write_text(json.dumps(PREFS))
        self.other = self.home / "helium-other"
        self.default = self.home / ".config/net.imput.helium"
        for d in (self.other, self.default):
            (d / "Default").mkdir(parents=True)
            (d / "Default/Preferences").write_text(json.dumps(PREFS))
        self.bin = self.home / "bin"
        self.bin.mkdir()
        (self.bin / "helium").write_text(FAKE)
        (self.bin / "helium").chmod(0o755)
        self.procs = []
        self.env = dict(os.environ, HOME=str(self.home), ANGELOS_BROWSER_HELIUM=str(self.prof),
                        ANGELOS_BROWSER_NO_REOPEN="1", XDG_CONFIG_HOME=str(self.home / ".config"))
        self.env.pop("NIRI_SOCKET", None)

    def tearDown(self):
        for p in self.procs:
            if p.poll() is None:
                p.kill()
                p.wait()
        self.tmp.cleanup()

    def run_bt(self, *args, ok=True):
        r = subprocess.run([sys.executable, str(SCRIPT)] + list(args), env=self.env, capture_output=True, text=True, timeout=60)
        if ok:
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        return json.loads(r.stdout) if r.stdout.strip() else {}

    def start(self, prof):
        args = [] if prof == self.default else ["--user-data-dir=" + str(prof)]
        p = subprocess.Popen([str(self.bin / "helium")] + args, env=dict(os.environ, HOME=str(self.home)))
        self.procs.append(p)
        for _ in range(50):
            if (prof / "started").exists():
                return p
            time.sleep(0.1)
        self.fail("stand-in browser didn't start")

    def prefs(self, prof=None):
        return json.loads(((prof or self.prof) / "Default/Preferences").read_text())

    def helium_status(self):
        return next(b for b in self.run_bt("status")["browsers"] if b["id"] == "helium")

    # ── Chromium family ──

    def test_apply_closed_then_revert_restores_exactly(self):
        r = self.run_bt("apply", "helium")
        self.assertTrue(r["done"], r)
        p = self.prefs()
        self.assertEqual(p["extensions"]["theme"], {"system_theme": 1})
        self.assertNotIn("user_color2", p["browser"]["theme"])
        self.assertEqual(p["browser"]["theme"]["color_scheme2"], 0)
        self.assertTrue(Path(r["backup"], "Preferences").exists(), "a full copy before the edit")
        s = self.helium_status()
        self.assertTrue(s["live"] and s["undo"] and not s["running"], s)
        # the person changes something else meanwhile: revert must keep it
        p["profile"]["name"] = "Renamed"
        (self.prof / "Default/Preferences").write_text(json.dumps(p))
        self.run_bt("revert", "helium")
        after = self.prefs()
        self.assertEqual(after["browser"]["theme"], PREFS["browser"]["theme"])
        self.assertEqual(after["extensions"]["theme"], PREFS["extensions"]["theme"])
        self.assertEqual(after["profile"]["name"], "Renamed")
        self.assertFalse(self.helium_status()["undo"])

    def test_apply_twice_keeps_the_first_undo(self):
        self.run_bt("apply", "helium")
        self.run_bt("apply", "helium")
        self.run_bt("revert", "helium")
        self.assertEqual(self.prefs()["extensions"]["theme"], PREFS["extensions"]["theme"])
        self.assertEqual(len(list((self.home / ".local/share/angelos/browsers").glob("backup-helium-*"))), 3,
                         "every edit has a backup folder of its own")

    def test_running_without_a_choice_changes_nothing(self):
        self.start(self.prof)
        r = self.run_bt("apply", "helium")
        self.assertFalse(r["done"])
        self.assertTrue(r["running"])
        self.assertEqual(self.prefs(), PREFS)
        self.assertTrue(self.helium_status()["running"])

    def test_restart_edits_after_the_browser_wrote_its_prefs(self):
        mine = self.start(self.prof)
        other = self.start(self.other)
        default = self.start(self.default)
        r = self.run_bt("apply", "helium", "--restart")
        self.assertTrue(r["done"], r)
        mine.wait(timeout=20)
        p = self.prefs()
        self.assertEqual(p["profile"]["exit_type"], "SessionEnded", "the browser had written its prefs first")
        self.assertEqual(p["extensions"]["theme"], {"system_theme": 1}, "and our edit came after, so it stayed")
        self.assertIsNone(other.poll(), "a browser on another profile is never touched")
        self.assertIsNone(default.poll(), "nor one on the default profile (the person's own, in a test)")
        self.assertEqual(self.prefs(self.other), PREFS)
        self.assertEqual(self.prefs(self.default), PREFS)

    def test_a_stale_lock_is_not_a_running_browser(self):
        # after a crash the lock stays: a dead pid, or a pid reused by something else
        for target in ("%s-%d" % (__import__("socket").gethostname(), 2 ** 22 + 7), "%s-%d" % (__import__("socket").gethostname(), os.getpid())):
            lock = self.prof / "SingletonLock"
            if lock.is_symlink():
                lock.unlink()
            lock.symlink_to(target)
            self.assertFalse(self.helium_status()["running"], target)
        self.assertTrue(self.run_bt("apply", "helium")["done"])

    def test_waiting_edits_once_closed(self):
        mine = self.start(self.prof)
        w = subprocess.Popen([sys.executable, str(SCRIPT), "apply", "helium", "--waiting"], env=self.env,
                             stdout=subprocess.PIPE, text=True)
        time.sleep(2.5)
        self.assertIsNone(w.poll(), "it waits while the browser is open")
        self.assertEqual(self.prefs(), PREFS)
        mine.terminate()
        out, _ = w.communicate(timeout=30)
        self.assertTrue(json.loads(out)["done"])
        self.assertEqual(self.prefs()["extensions"]["theme"], {"system_theme": 1})

    # ── Firefox ──

    def firefox_profile(self, with_files):
        root = self.home / ".config/mozilla/firefox"
        prof = root / "abcd.default-release"
        prof.mkdir(parents=True)
        (root / "profiles.ini").write_text(
            "[Profile1]\nName=default\nIsRelative=1\nPath=zzzz.default\nDefault=1\n\n"
            "[Profile0]\nName=default-release\nIsRelative=1\nPath=abcd.default-release\n\n"
            "[Install4F96D1932A9F858E]\nDefault=abcd.default-release\nLocked=1\n")
        (root / "zzzz.default").mkdir()
        (prof / "prefs.js").write_text('user_pref("extensions.activeThemeID", "default-theme@mozilla.org");\n')
        if with_files:
            (prof / "chrome").mkdir()
            (prof / "chrome/userChrome.css").write_text(USERCHROME)
            (prof / "user.js").write_text(USERJS)
        self.env["ANGELOS_BROWSER_FIREFOX"] = ""      # the real lookup (profiles.ini), in the fake home
        self.run_bt("build", str(self.palette()))
        return prof

    def palette(self):
        f = self.home / "palette.json"
        f.write_text(json.dumps({"mode": "dark", "realm": "heaven", "desk": "#161922", "face": "#1a1e29", "faceAlt": "#1f2433",
                                 "sunken": "#161922", "text": "#fafafa", "textDim": "#b4b5b7", "accent": "#7d8cb3"}))
        return f

    def test_firefox_keeps_the_persons_files(self):
        prof = self.firefox_profile(True)
        r = self.run_bt("apply", "firefox")
        self.assertTrue(r["done"], r)
        css = (prof / "chrome/userChrome.css").read_text()
        self.assertTrue(css.startswith("/* angelOS begin */\n@import"), "the import comes before @namespace")
        self.assertIn(USERCHROME, css)
        self.assertIn("legacyUserProfileCustomizations", (prof / "user.js").read_text())
        self.assertTrue((prof / "chrome/angelos-theme.css").is_symlink())
        st = next(b for b in self.run_bt("status")["browsers"] if b["id"] == "firefox")
        self.assertTrue(st["static"] and st["live"] and st["profileDir"].endswith("abcd.default-release"), st)
        self.run_bt("apply", "firefox")              # twice: still one block
        self.assertEqual((prof / "chrome/userChrome.css").read_text().count("@import"), 1)
        self.run_bt("revert", "firefox")
        self.assertEqual((prof / "chrome/userChrome.css").read_text(), USERCHROME)
        self.assertEqual((prof / "user.js").read_text(), USERJS)
        self.assertFalse((prof / "chrome/angelos-theme.css").exists())

    def test_firefox_from_nothing_leaves_nothing(self):
        prof = self.firefox_profile(False)
        self.run_bt("apply", "firefox")
        self.run_bt("revert", "firefox")
        self.assertFalse((prof / "user.js").exists())
        self.assertFalse((prof / "chrome").exists())

    def test_build_rewrites_only_on_change(self):
        f = self.palette()
        self.assertTrue(self.run_bt("build", str(f))["changed"])
        self.assertFalse(self.run_bt("build", str(f))["changed"])
        d = json.loads(f.read_text())
        d["realm"] = "hell"
        f.write_text(json.dumps(d))
        r = self.run_bt("build", str(f))
        self.assertTrue(r["changed"] and r["realm"] == "hell")
        css = (self.home / ".local/share/angelos/browsers/firefox/angelos-theme.css").read_text()
        self.assertIn("hell", css.splitlines()[0])


if __name__ == "__main__":
    unittest.main(verbosity=2)
