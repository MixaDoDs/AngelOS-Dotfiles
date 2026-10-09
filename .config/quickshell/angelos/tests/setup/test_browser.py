#!/usr/bin/env python3
"""The wizard's «Which browser?» and the apps from a GitHub release, offline: a temporary HOME
with stand-in .desktop files, no pacman, flatpak or network."""
import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
APPS = ROOT / "scripts/apps-install.py"
DEFAULTS = ROOT / "scripts/default-apps.py"

DESKTOP = "[Desktop Entry]\nType=Application\nName={name}\nExec=true %u\nMimeType={mimes}\nCategories={cats}\n"


class Browser(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="angelos-browser-")
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        home = self.root / "home"
        self.apps_dir = self.root / "share/applications"
        self.apps_dir.mkdir(parents=True)
        (home / ".config").mkdir(parents=True)
        # the dotfiles' mimeapps.list names the author's Helium, which isn't installed here
        (home / ".config/mimeapps.list").write_text(
            "[Default Applications]\nx-scheme-handler/http=helium.desktop\nx-scheme-handler/https=helium.desktop\n"
            "text/html=helium.desktop\n")
        self.desktop("firefox.desktop", "Firefox", "text/html;x-scheme-handler/http;x-scheme-handler/https;",
                     "Network;WebBrowser;")
        # takes links but is no browser
        self.desktop("chatgpt.desktop", "ChatGPT", "x-scheme-handler/http;x-scheme-handler/https;", "Utility;")
        env = {"HOME": str(home), "XDG_CONFIG_HOME": str(home / ".config"), "XDG_DATA_HOME": str(home / ".local/share"),
               "XDG_DATA_DIRS": str(self.root / "share"), "XDG_CONFIG_DIRS": str(self.root / "etc"),
               "XDG_STATE_HOME": str(home / ".local/state"), "ANGELOS_LANG": "en"}
        old = {k: os.environ.get(k) for k in env}
        os.environ.update(env)
        self.addCleanup(lambda: [os.environ.pop(k, None) if v is None else os.environ.__setitem__(k, v)
                                 for k, v in old.items()])
        self.home = home
        self.m = self.load(APPS, "apps_install")
        # nothing is installed through pacman or flatpak here
        self.m.pacman_installed = lambda names: False
        self.m.flatpak_installed = lambda app_id: False
        self.m.pacman_has = lambda name: False
        self.m.arch_without_repos = lambda: False

    def load(self, path, name):
        spec = importlib.util.spec_from_file_location(name, path)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        return mod

    def desktop(self, did, name, mimes, cats):
        (self.apps_dir / did).write_text(DESKTOP.format(name=name, mimes=mimes, cats=cats))

    def default(self):
        text = (self.home / ".config/mimeapps.list").read_text()
        return next((ln.split("=", 1)[1] for ln in text.splitlines() if ln.startswith("x-scheme-handler/https=")), "")

    def test_list_holds_real_browsers_and_the_missing_default_is_none(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.m.browsers()
        d = json.loads(out.getvalue())
        ids = [b["id"] for b in d["list"]]
        self.assertIn("helium", ids)
        self.assertIn("desktop:firefox.desktop", ids)
        self.assertNotIn("desktop:chatgpt.desktop", ids, "an app that only takes links is no browser")
        self.assertEqual(d["current"], "", "Helium is named but not installed: no current browser")

    def test_picked_browser_becomes_the_default(self):
        self.assertTrue(self.m.set_browser("desktop:firefox.desktop"))
        self.assertTrue(self.default().startswith("firefox.desktop"), self.default())
        state = json.loads((self.home / ".local/state/angelos/apps.json").read_text())
        self.assertEqual(state["browser"], "desktop:firefox.desktop")

    def test_browser_that_did_not_install_keeps_the_default(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertFalse(self.m.set_browser("brave"))
        self.assertTrue(self.default().startswith("helium.desktop"))

    def test_missing_default_gives_way_to_a_real_browser(self):
        r = subprocess.run([sys.executable, str(DEFAULTS), "browser"], capture_output=True, text=True, check=True)
        self.assertEqual(r.stdout.strip(), "firefox.desktop", "not ChatGPT, not the missing Helium")
        self.assertTrue(self.default().startswith("firefox.desktop"))

    def test_github_release_is_checked_before_pacman(self):
        payload = b"a package"
        good = hashlib.sha256(payload).hexdigest()
        calls = []

        class Resp(io.BytesIO):
            def __enter__(self):
                return self

            def __exit__(self, *a):
                return False

        def serve(sums):
            def urlopen(url, timeout=0):
                return Resp(sums.encode() if url.endswith("SHA256SUMS") else payload)
            return urlopen

        real_run = subprocess.run

        def run(cmd, *a, **k):
            if cmd[:2] == ["sudo", "pacman"]:
                calls.append(cmd)
                return subprocess.CompletedProcess(cmd, 0)
            return real_run(cmd, *a, **k)

        self.m.subprocess.run = run
        self.m.shutil.which = lambda name: None  # no curl: urllib downloads
        app = self.m.apps()["freshgram"]
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.m.urllib.request.urlopen = serve(f"{'0' * 64}  freshGram.pacman\n")
            self.assertFalse(self.m.github_install(app))
            self.assertEqual(calls, [], "a wrong checksum never reaches pacman")
            self.m.urllib.request.urlopen = serve(f"{good}  freshGram.pacman\n")
            self.assertTrue(self.m.github_install(app))
        self.assertEqual(calls[0][:4], ["sudo", "pacman", "-U", "--needed"])
        self.assertTrue(calls[0][-1].endswith("freshGram.pacman"))

    def test_catalog_browsers_and_freshgram(self):
        cat = json.loads((ROOT / "data/apps-catalog.json").read_text())
        by = {a["id"]: a for a in cat["apps"]}
        for b in cat["browsers"]:
            self.assertIn(b, by, b)
            self.assertTrue(any(by[b].get(k) for k in ("pacman", "aur", "flatpak", "github")), b)
        self.assertIn("freshgram", next(g for g in cat["groups"] if g["id"] == "chat")["apps"])
        self.assertEqual(by["freshgram"]["github"]["package"], "freshgram")


if __name__ == "__main__":
    unittest.main(verbosity=2)
