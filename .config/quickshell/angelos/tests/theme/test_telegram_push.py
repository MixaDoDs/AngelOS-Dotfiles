#!/usr/bin/env python3
"""Freshgram's theme without "Choose from file": scripts/telegram-theme.py push against a stand-in
of its single-instance socket (an abstract one, the local-control protocol: CTRL:…; → DATA:…;).
Local automation off: the user is asked once, not on every theme change; on: the theme is applied,
and not again while it is the one in use."""
import base64
import importlib.util
import json
import os
from pathlib import Path
import socket
import tempfile
import threading
import unittest

ROOT = Path(__file__).resolve().parents[2]


class FakeApp:
    """the app's end of the socket: answers theme / theme-apply like Freshgram does"""

    def __init__(self, name):
        self.name = name
        self.allowed = False
        self.path = ":/gui/Google Day.tdesktop-theme"
        self.got = []
        self.srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.srv.bind("\0" + name)
        self.srv.listen(4)
        self.srv.settimeout(0.2)
        self.stop = False
        self.t = threading.Thread(target=self.loop, daemon=True)
        self.t.start()

    def answer(self, obj):
        return b"DATA:" + base64.b64encode(json.dumps(obj).encode()) + b";"

    def loop(self):
        while not self.stop:
            try:
                conn, _ = self.srv.accept()
            except OSError:
                continue
            with conn:
                cmd = conn.recv(65536).decode().rstrip(";")
                self.got.append(cmd)
                if not self.allowed:
                    conn.sendall(self.answer({"ok": False, "error": "local automation is disabled"}))
                elif cmd == "CTRL:theme":
                    conn.sendall(self.answer({"ok": True, "path": self.path, "editing": False}))
                elif cmd.startswith("CTRL:theme-apply:"):
                    self.path = base64.b64decode(cmd[len("CTRL:theme-apply:"):]).decode()
                    conn.sendall(self.answer({"ok": True, "path": self.path}))

    def close(self):
        self.stop = True
        self.t.join(timeout=2)
        self.srv.close()


class TelegramPush(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="angelos-tg-")
        self.addCleanup(tmp.cleanup)
        old = os.environ.get("HOME")
        os.environ["HOME"] = tmp.name
        self.addCleanup(lambda: os.environ.__setitem__("HOME", old) if old else None)
        spec = importlib.util.spec_from_file_location("tg", ROOT / "scripts/telegram-theme.py")
        m = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(m)
        m.BASE = Path(tmp.name) / "tg"
        m.THEME = m.BASE / "angelOS.tdesktop-theme"
        m.STATE = m.BASE / "applied.json"
        m.BASE.mkdir()
        m.THEME.write_bytes(b"theme")
        name = "@" + os.urandom(16).hex() + "-freshGram"
        self.app = FakeApp(name[1:])
        self.addCleanup(self.app.close)
        m.sockets = lambda: [name]
        self.m = m

    def test_asks_once_then_applies_and_keeps_quiet(self):
        m, app = self.m, self.app
        self.assertEqual(m.push(), {"freshGram": "asked the user to allow it"})
        n = len(app.got)
        # the next theme changes don't ask again (a day at the most)
        self.assertEqual(m.push(), {"freshGram": "waiting for the user's yes"})
        self.assertEqual(len(app.got), n, "no question on every theme change")
        # the user said yes; Settings' "apply" asks right away
        app.allowed = True
        self.assertEqual(m.push(ask=True), {"freshGram": "applied"})
        self.assertEqual(app.path, str(m.THEME))
        # from now on, every build: nothing to do while it is on our file (it watches it)
        self.assertEqual(m.push(), {"freshGram": "on the theme already"})
        self.assertFalse(any(c.startswith("CTRL:theme-apply") for c in app.got[-1:]))

    def test_a_theme_the_user_picks_there_stays(self):
        m, app = self.m, self.app
        app.allowed = True
        self.assertEqual(m.push(), {"freshGram": "applied"})
        app.path = "/somewhere/else.tdesktop-theme"
        self.assertEqual(m.push(), {"freshGram": "another theme picked there: left alone"})
        self.assertEqual(app.path, "/somewhere/else.tdesktop-theme")
        # Settings → apply brings ours back on purpose
        self.assertEqual(m.push(ask=True), {"freshGram": "applied"})


class OwnHomeOnly(unittest.TestCase):
    """/proc/net/unix lists the whole machine's sockets: only the apps of this home are talked to
    (a test's throw-away home must never reach the user's real Freshgram)"""

    def test_only_this_homes_apps(self):
        import hashlib
        tmp = tempfile.TemporaryDirectory(prefix="angelos-tg-home-")
        self.addCleanup(tmp.cleanup)
        home = Path(tmp.name)
        (home / ".local/share/freshGram").mkdir(parents=True)
        old = os.environ.get("HOME")
        os.environ["HOME"] = str(home)
        self.addCleanup(lambda: os.environ.__setitem__("HOME", old) if old else None)
        spec = importlib.util.spec_from_file_location("tg2", ROOT / "scripts/telegram-theme.py")
        m = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(m)
        mine = hashlib.md5(str((home / ".local/share/freshGram").resolve()).encode()).hexdigest() + "-freshGram"
        other = os.urandom(16).hex() + "-freshGram"
        apps = [FakeApp(mine), FakeApp(other)]
        for a in apps:
            self.addCleanup(a.close)
        self.assertEqual(m.sockets(), ["@" + mine])


if __name__ == "__main__":
    unittest.main(verbosity=2)
