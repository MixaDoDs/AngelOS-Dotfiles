#!/usr/bin/env python3
"""The wizard's app install without a terminal, offline: the admin helper (scripts/apps-root.py,
unprivileged here) behind scripts/apps-sudo, a stand-in pacman that records what it was asked,
and the progress lines the wizard reads (EV …)."""
import contextlib
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
HELPER = ROOT / "scripts/apps-root.py"
SUDO = ROOT / "scripts/apps-sudo"

FAKE_PACMAN = """#!/bin/sh
# records the call; -S/-U "install" their names into the fake database
echo "$*" >> "$PACMAN_LOG"
case "$1" in
  -S|-U)
    shift
    for a in "$@"; do case "$a" in -*) ;; broken-pkg) echo "error: target not found: $a"; exit 1 ;; *) echo "${a##*/}" >> "$PACMAN_DB" ;; esac; done ;;
esac
echo "fake pacman done"
"""


class AppsInstall(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="angelos-apps-")
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name)
        self.log, self.db = self.tmp / "pacman.log", self.tmp / "db"
        self.db.write_text("")
        pac = self.tmp / "pacman"
        pac.write_text(FAKE_PACMAN)
        pac.chmod(0o755)
        env = {"HOME": str(self.tmp), "XDG_STATE_HOME": str(self.tmp / "state"), "XDG_CONFIG_HOME": str(self.tmp / "cfg"),
               "XDG_DATA_HOME": str(self.tmp / "data"), "XDG_DATA_DIRS": str(self.tmp / "share"),
               "ANGELOS_LANG": "en", "PACMAN_LOG": str(self.log), "PACMAN_DB": str(self.db),
               "APPS_ROOT_TEST": "1", "APPS_ROOT_PACMAN": str(pac)}
        old = {k: os.environ.get(k) for k in env}
        os.environ.update(env)
        self.addCleanup(lambda: [os.environ.pop(k, None) if v is None else os.environ.__setitem__(k, v)
                                 for k, v in old.items()])
        spec = importlib.util.spec_from_file_location("apps_install", APPS)
        m = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(m)
        names = lambda: set(self.db.read_text().split())  # noqa: E731
        m.pacman_installed = lambda ns: bool(ns) and set(ns) <= names()
        m.pacman_has = lambda n: n != "nowhere-pkg"
        m.flatpak_installed = lambda i: False
        m.arch_without_repos = lambda: False
        m.aur_missing = lambda ns: []
        m.spicetify = lambda: None
        self.helpers = []

        def start_root():
            # the real helper, unprivileged; pkexec stands aside
            d = tempfile.mkdtemp(dir=self.tmp)
            os.chmod(d, 0o700)
            sock = os.path.join(d, "sock")
            p = subprocess.Popen([sys.executable, str(HELPER), str(os.getuid()), sock],
                                 stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
            self.assertEqual(p.stdout.readline().strip(), "READY")
            os.environ["ANGELOS_ROOT_SOCK"] = sock
            self.helpers.append(p)
            return p, None

        m.start_root = start_root
        self.m = m
        cat = {"apps": [
            {"id": "one", "ru": "Один", "en": "One", "icon": "chat", "pacman": "one-pkg"},
            {"id": "two", "ru": "Два", "en": "Two", "icon": "music", "pacman": "broken-pkg"},
            {"id": "three", "ru": "Три", "en": "Three", "icon": "game", "pacman": "nowhere-pkg"}],
            "groups": [], "browsers": []}
        m.catalog = lambda: cat
        m.apps = lambda: {a["id"]: a for a in cat["apps"]}

    def run_install(self, ids):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            rc = self.m.install(ids, wait=False, events=True)
        evs = [json.loads(ln[3:]) for ln in out.getvalue().splitlines() if ln.startswith("EV ")]
        return rc, evs, out.getvalue()

    def test_one_password_progress_per_app_and_failures_named(self):
        rc, evs, text = self.run_install(["one", "two", "three"])
        kinds = [e["ev"] for e in evs]
        self.assertEqual(kinds[0], "plan")
        self.assertIn("auth", kinds)
        self.assertEqual(len(self.helpers), 1, "one admin helper (one password) for the whole run")
        items = [(e["id"], e["state"]) for e in evs if e["ev"] == "item"]
        self.assertEqual(items, [("one", "start"), ("one", "done"), ("two", "start"), ("two", "fail")])
        done = evs[-1]
        self.assertEqual(done["ev"], "done")
        self.assertEqual(done["ok"], ["one"])
        self.assertEqual(done["failed"], ["two"])
        self.assertEqual(done["skipped"], ["three"], "no source has three: named, never tried")
        self.assertEqual(rc, 1)
        calls = self.log.read_text().splitlines()
        self.assertEqual(calls[0], "-Syu --noconfirm", "the lists and the system first")
        self.assertIn("-S --needed --noconfirm one-pkg", calls)
        self.assertNotIn("ANGELOS_ROOT_SOCK", os.environ, "the helper is let go")
        self.assertIsNotNone(self.helpers[0].wait(timeout=10), "the helper ends with the run")

    def test_cancelled_password_installs_nothing(self):
        self.m.start_root = lambda: (None, "the password was not given")
        rc, evs, _ = self.run_install(["one"])
        self.assertEqual(evs[-1]["ev"], "done")
        self.assertEqual(evs[-1]["auth"], "the password was not given")
        self.assertFalse(self.log.exists() and self.log.read_text().strip())
        self.assertEqual(rc, 2)

    def test_helper_runs_only_pacman(self):
        _, why = self.m.start_root()
        self.assertIsNone(why)
        env = dict(os.environ)
        bad = subprocess.run([str(SUDO), "sh", "-c", "touch /tmp/x"], capture_output=True, text=True, env=env)
        self.assertEqual(bad.returncode, 126)
        self.assertIn("not allowed", bad.stdout)
        ok = subprocess.run([str(SUDO), "pacman", "-Q"], capture_output=True, text=True, env=env)
        self.assertEqual(ok.returncode, 0, ok.stdout + ok.stderr)
        self.assertIn("fake pacman done", ok.stdout)
        self.m.stop_root(self.helpers[0])

    # ---- the author's new apps after an update, in the shell's own window (sync --events) ----
    def run_sync(self, take):
        self.acks = []
        self.m.ack = lambda repo, shown=(), fish_shown=True: self.acks.append(list(shown))
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            rc = self.m.sync_events("", take)
        return rc, [json.loads(ln[3:]) for ln in out.getvalue().splitlines() if ln.startswith("EV ")]

    def test_sync_without_a_terminal_takes_what_was_ticked(self):
        self.m.pending = lambda repo: {"apps": ["one"], "suggest": ["two"], "packages": ["base-pkg", "other-pkg"], "fish": True}
        fish = []
        self.m.make_fish_login = lambda repo: fish.append(repo) or 0
        rc, evs = self.run_sync(["one", "pkg:base-pkg", "fish", "pkg:not-offered", "three"])
        self.assertEqual([i["id"] for i in evs[0]["items"]], ["fish", "pkg:base-pkg", "one"], "only what was offered and ticked")
        self.assertEqual([(e["id"], e["state"]) for e in evs if e["ev"] == "item"],
                         [("fish", "start"), ("fish", "done"), ("pkg:base-pkg", "start"), ("pkg:base-pkg", "done"),
                          ("one", "start"), ("one", "done")])
        self.assertEqual(evs[-1]["ok"], ["fish", "pkg:base-pkg", "one"])
        self.assertEqual(rc, 0)
        self.assertEqual(len(self.helpers), 1, "one password for the packages, fish and the apps")
        self.assertEqual(len(fish), 1)
        calls = self.log.read_text().splitlines()
        self.assertIn("-S --needed --noconfirm base-pkg", calls)
        self.assertFalse([c for c in calls if "other-pkg" in c or "broken-pkg" in c], "what was left unticked stays out")
        self.assertEqual(self.acks, [["one", "two"]], "everything shown counts as seen once it worked")

    def test_sync_failure_is_not_forgotten(self):
        self.m.pending = lambda repo: {"apps": ["two"], "suggest": [], "packages": [], "fish": False}
        rc, evs = self.run_sync(None)
        self.assertEqual(evs[-1]["failed"], ["two"])
        self.assertEqual(rc, 1)
        self.assertEqual(self.acks, [], "a failed one is offered again (the window acks when it is closed)")

    def test_helper_makes_fish_the_asking_users_shell_only(self):
        import pwd
        me = pwd.getpwuid(os.getuid()).pw_name
        chsh, shells, said = self.tmp / "chsh", self.tmp / "shells", self.tmp / "chsh.log"
        chsh.write_text(f'#!/bin/sh\necho "$*" >> "{said}"\n')
        chsh.chmod(0o755)
        shells.write_text("/bin/sh\n/bin/bash")
        os.environ.update(APPS_ROOT_CHSH=str(chsh), APPS_ROOT_SHELLS=str(shells))
        self.addCleanup(lambda: [os.environ.pop(k, None) for k in ("APPS_ROOT_CHSH", "APPS_ROOT_SHELLS")])
        _, why = self.m.start_root()
        self.assertIsNone(why)
        env = dict(os.environ)
        for bad in (["chsh", "-s", "/bin/sh", me], ["chsh", "-s", "/usr/bin/fish", "root" if me != "root" else "nobody"],
                    ["chsh", "-s", "/usr/bin/fish", me, "extra"], ["chsh", "/usr/bin/fish"]):
            r = subprocess.run([str(SUDO), *bad], capture_output=True, text=True, env=env)
            self.assertEqual(r.returncode, 126, bad)
        self.assertFalse(said.exists())
        ok = subprocess.run([str(SUDO), "chsh", "-s", "/usr/bin/fish", me], capture_output=True, text=True, env=env)
        self.assertEqual(ok.returncode, 0, ok.stdout + ok.stderr)
        self.assertEqual(said.read_text().strip(), f"-s /usr/bin/fish {me}")
        self.assertEqual(shells.read_text(), "/bin/sh\n/bin/bash\n/usr/bin/fish\n", "chsh takes only a listed shell")
        self.m.stop_root(self.helpers[0])


if __name__ == "__main__":
    unittest.main(verbosity=2)
