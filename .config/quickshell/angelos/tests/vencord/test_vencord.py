#!/usr/bin/env python3
"""extras/vencord in a throw-away system root and $HOME: pacman's and Flatpak's Discord patched
(Flatpak's files renamed, never written over — they are hard links into its repository), an
update of Discord patched again with the new original kept, someone else's Vencord left alone,
nothing on another system than CachyOS, the user's Vencord downloaded whole (from a local
folder), the Flatpak let in to it, pacman's removal taking the original along — and the loader
itself under node: Vencord when the user has one, the plain Discord when not.

Nothing here touches the real Discord or Flatpak: `flatpak` is a stand-in on PATH.
"""
import importlib.machinery
import importlib.util
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parents[2] / "extras/vencord"
GUARD = HERE / "angelos-vencord"
SETUP = HERE / "install.sh"
FLATPAK = """#!/bin/sh
echo "$@" >>"$HOME/flatpak.log"
[ "$1" = override ] || exit 0
mkdir -p "$HOME/.local/share/flatpak/overrides"
printf '[Context]\\nfilesystems=xdg-config/Vencord/dist;\\n' >"$HOME/.local/share/flatpak/overrides/$4"
"""


def load():
    loader = importlib.machinery.SourceFileLoader("angelos_vencord", str(GUARD))
    spec = importlib.util.spec_from_loader("angelos_vencord", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


V = load()
ORIGINAL = os.urandom(200_000)


class Guard(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="vencord-test-"))
        self.root = self.tmp / "root"
        self.home = self.tmp / "home"
        self.bin = self.tmp / "bin"
        self.dl = self.tmp / "release"
        for d in (self.root / "etc", self.home, self.bin, self.dl):
            d.mkdir(parents=True)
        (self.root / "etc/os-release").write_text('NAME="CachyOS Linux"\nID=cachyos\n')
        (self.bin / "flatpak").write_text(FLATPAK)
        (self.bin / "flatpak").chmod(0o755)
        for name in V.FILES:
            (self.dl / name).write_text(f"// {name}\n")
        # pacman's Discord
        self.opt = self.root / "opt/discord/resources"
        self.opt.mkdir(parents=True)
        (self.opt / "app.asar").write_bytes(ORIGINAL)
        # Flatpak's: a deploy folder, "active" pointing at it, the asar a hard link into the repo
        stable = self.root / "var/lib/flatpak/app/com.discordapp.Discord/x86_64/stable"
        self.fp = stable / "c0ffee/files/discord/resources"
        self.fp.mkdir(parents=True)
        self.obj = self.root / "var/lib/flatpak/repo/objects/ab.file"
        self.obj.parent.mkdir(parents=True)
        self.obj.write_bytes(ORIGINAL)
        os.link(self.obj, self.fp / "app.asar")
        (stable / "active").symlink_to("c0ffee")

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def run_guard(self, *args, stdin=None):
        env = dict(os.environ, HOME=str(self.home), ANGELOS_SYSROOT=str(self.root),
                   ANGELOS_VENCORD_URL=self.dl.as_uri(), PATH=f"{self.bin}:{os.environ['PATH']}")
        return subprocess.run([str(GUARD), *args], env=env, input=stdin, capture_output=True, text=True)

    def test_asar_layout(self):
        # the layout of Vencord's installer's own app.asar (sizes from a real one)
        raw = V.asar({"index.js": "x" * 54, "package.json": "y" * 43})
        self.assertEqual(raw[:16].hex(), "04000000600000005c00000058000000")
        idx = V.asar({"index.js": V.SHIM, "package.json": V.PACKAGE})
        path = self.tmp / "a.asar"
        path.write_bytes(idx)
        self.assertEqual(V.asar_index(str(path)), V.SHIM)

    def test_patch_all(self):
        r = self.run_guard("patch")
        self.assertEqual(r.returncode, 0, r.stderr)
        for res in (self.opt, self.fp):
            self.assertEqual((res / "_app.asar").read_bytes(), ORIGINAL)
            self.assertIn(V.MARK, V.asar_index(str(res / "app.asar")))
        # Flatpak's repository object is untouched: renamed, not written over
        self.assertEqual(self.obj.read_bytes(), ORIGINAL)
        self.assertEqual(os.stat(self.obj).st_ino, os.stat(self.fp / "_app.asar").st_ino)
        # the user's Vencord, whole, and the Flatpak let in to it
        dist = self.home / ".config/Vencord/dist"
        self.assertEqual(sorted(p.name for p in dist.iterdir()), sorted(V.FILES + ["package.json"]))
        self.assertIn("override --user --filesystem=xdg-config/Vencord/dist com.discordapp.Discord",
                      (self.home / "flatpak.log").read_text())
        st = json.loads(self.run_guard("status").stdout)
        self.assertTrue(st["dist"])
        self.assertEqual({c["state"] for c in st["clients"]}, {"ours"})
        # again: nothing to do, nothing downloaded, Flatpak not asked
        before = (self.opt / "app.asar").stat().st_mtime_ns
        (self.home / "flatpak.log").unlink()
        r = self.run_guard("patch")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout, "")
        self.assertEqual((self.opt / "app.asar").stat().st_mtime_ns, before)
        self.assertFalse((self.home / "flatpak.log").exists())

    def test_update_brings_new_original(self):
        self.run_guard("patch")
        new = os.urandom(150_000)
        (self.opt / "app.asar").write_bytes(new)   # pacman's upgrade writes over our loader
        self.assertEqual(json.loads(self.run_guard("status").stdout)["clients"][0]["state"], "clean")
        self.run_guard("patch")
        self.assertEqual((self.opt / "_app.asar").read_bytes(), new)
        self.assertIn(V.MARK, V.asar_index(str(self.opt / "app.asar")))

    def test_foreign_left_alone(self):
        theirs = V.asar({"index.js": 'require("/home/x/.config/Equicord/dist/patcher.js")', "package.json": "{}"})
        (self.opt / "_app.asar").write_bytes(ORIGINAL)
        (self.opt / "app.asar").write_bytes(theirs)
        self.run_guard("patch")
        self.assertEqual((self.opt / "app.asar").read_bytes(), theirs)
        # a loader without its original: reported, not "fixed"
        (self.opt / "_app.asar").unlink()
        r = self.run_guard("patch")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("_app.asar", r.stderr)
        self.assertEqual((self.opt / "app.asar").read_bytes(), theirs)

    def test_not_cachyos(self):
        (self.root / "etc/os-release").write_text("ID=arch\n")
        r = self.run_guard("patch")
        self.assertEqual(r.returncode, 0)
        self.assertEqual((self.opt / "app.asar").read_bytes(), ORIGINAL)
        self.assertFalse((self.opt / "_app.asar").exists())
        self.assertFalse((self.home / ".config").exists())

    def test_download_failure_keeps_nothing(self):
        (self.dl / "renderer.js").unlink()
        r = self.run_guard("patch")
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(list((self.home / ".config/Vencord").iterdir()), [])
        # Discord is patched anyway: without the user's Vencord the loader starts it plain
        self.assertTrue((self.opt / "_app.asar").exists())

    def test_forget(self):
        self.run_guard("patch")
        self.run_guard("forget", stdin="opt/discord/resources/app.asar\n")
        self.assertFalse((self.opt / "_app.asar").exists())
        self.assertTrue((self.fp / "_app.asar").exists())

    def test_setup_status(self):
        env = dict(os.environ, ANGELOS_SYSROOT=str(self.root), HOME=str(self.home),
                   ANGELOS_VENCORD_URL=self.dl.as_uri(), PATH=f"{self.bin}:{os.environ['PATH']}")
        status = lambda: subprocess.run(["sh", str(SETUP), "--status"], env=env, capture_output=True, text=True).stdout.strip()
        self.assertEqual(status(), "missing")
        r = subprocess.run(["sh", str(SETUP)], env=env, capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(status(), "ok")
        for f in ("usr/local/libexec/angelos-vencord", "etc/pacman.d/hooks/angelos-vencord.hook",
                  "etc/systemd/system/angelos-vencord.path", "etc/systemd/system/angelos-vencord.timer"):
            self.assertTrue((self.root / f).exists(), f)
        self.assertTrue((self.opt / "_app.asar").exists())
        (self.root / "etc/systemd/system/angelos-vencord.timer").write_text("old\n")
        self.assertEqual(status(), "old")
        subprocess.run(["sh", str(SETUP), "--remove"], env=env, capture_output=True)
        self.assertFalse((self.root / "usr/local/libexec/angelos-vencord").exists())
        (self.root / "etc/os-release").write_text("ID=arch\n")
        self.assertEqual(status(), "ok")


@unittest.skipUnless(shutil.which("node"), "no node")
class Loader(unittest.TestCase):
    """the loader as Electron runs it: asar folders as plain folders, a stand-in electron module"""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="vencord-shim-"))
        res = self.tmp / "resources"
        (res / "app.asar").mkdir(parents=True)
        (res / "app.asar/index.js").write_text(V.SHIM)
        (res / "_app.asar").mkdir()
        (res / "_app.asar/package.json").write_text('{"main": "app_bootstrap/index.js"}')
        (res / "_app.asar/app_bootstrap").mkdir()
        (res / "_app.asar/app_bootstrap/index.js").write_text(
            'console.log("discord", require("electron").app.path, require.main.filename.endsWith("_app.asar/app_bootstrap/index.js"))')
        mods = self.tmp / "mods/electron"
        mods.mkdir(parents=True)
        (mods / "index.js").write_text("exports.app = {setAppPath(p) { this.path = require('path').basename(p) }}")
        self.home = self.tmp / "home"
        self.home.mkdir()

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def node(self):
        env = dict(os.environ, HOME=str(self.home), NODE_PATH=str(self.tmp / "mods"))
        return subprocess.run(["node", str(self.tmp / "resources/app.asar/index.js")], env=env,
                              capture_output=True, text=True)

    def test_plain_without_vencord(self):
        r = self.node()
        self.assertEqual(r.stdout.strip(), "discord _app.asar true", r.stderr)

    def test_vencord_of_the_user(self):
        dist = self.home / ".config/Vencord/dist"
        dist.mkdir(parents=True)
        (dist / "patcher.js").write_text('console.log("vencord")')
        r = self.node()
        self.assertEqual(r.stdout.strip(), "vencord", r.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
