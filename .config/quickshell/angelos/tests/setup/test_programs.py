#!/usr/bin/env python3
"""scripts/programs.py offline, a stand-in pacman behind it: launchers gathered per package, what
must stay, a removal planned before it is done (what goes along, what refuses), the removal itself
with its progress lines and one password, the clean-up of orphans and the download cache."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import types
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/programs.py"


class Programs(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="angelos-programs-")
        self.addCleanup(tmp.cleanup)
        self.t = Path(tmp.name)
        env = {"HOME": str(self.t), "XDG_DATA_HOME": str(self.t / "data"), "XDG_DATA_DIRS": str(self.t / "usr/share"), "ANGELOS_LANG": "en"}
        old = {k: os.environ.get(k) for k in env}
        os.environ.update(env)
        self.addCleanup(lambda: [os.environ.pop(k, None) if v is None else os.environ.__setitem__(k, v) for k, v in old.items()])
        spec = importlib.util.spec_from_file_location("programs", SCRIPT)
        m = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(m)
        self.m = m
        sysapps, mine = self.t / "usr/share/applications", self.t / "data/applications"
        sysapps.mkdir(parents=True)
        mine.mkdir(parents=True)
        entry = "[Desktop Entry]\nType=Application\nName={}\nIcon={}\nExec=x\n{}"
        (sysapps / "office-writer.desktop").write_text(entry.format("Writer", "writer", ""))
        (sysapps / "office-calc.desktop").write_text(entry.format("Calc", "calc", ""))
        (sysapps / "niri.desktop").write_text(entry.format("Niri", "niri", ""))
        (sysapps / "hidden.desktop").write_text(entry.format("Hidden", "h", "NoDisplay=true\n"))
        (sysapps / "nobody.desktop").write_text(entry.format("Nobody's", "n", ""))
        (mine / "game.desktop").write_text(entry.format("My game", "game", ""))
        self.game = mine / "game.desktop"
        # the stand-in system: package → (size, required by, reason); what was asked of pacman as root
        self.db = {"office": (5 * 1024 ** 2, [], "explicit"), "office-libs": (1024 ** 2, ["office"], "dependency"),
                   "niri": (1024, [], "explicit"), "toolkit": (2048, ["office", "other"], "explicit"),
                   "leftover": (4096, [], "dependency"), "python": (1, [], "dependency")}
        self.owned = {str(sysapps / "office-writer.desktop"): "office", str(sysapps / "office-calc.desktop"): "office",
                      str(sysapps / "niri.desktop"): "niri"}
        self.root_calls = []
        self.helpers = 0
        m.run = self.fake_run
        test = self

        def start_root():
            test.helpers += 1
            return object(), None

        def root(*cmd):
            test.root_calls.append(list(cmd))
            # -R takes the packages out of the stand-in system; anything else just succeeds
            if cmd[:1] == ("pacman",) and cmd[1].startswith("-R"):
                for name in cmd[2:]:
                    if name == "stubborn":
                        return ["false"]
                    test.db.pop(name, None)
            return ["true"]

        m.installer = lambda: types.SimpleNamespace(start_root=start_root, stop_root=lambda h: None, root=root)
        m.trash = lambda p: Path(p).unlink()

    def fake_run(self, cmd, **kw):
        done = lambda rc, out="", err="": subprocess.CompletedProcess(cmd, rc, out, err)  # noqa: E731
        if cmd[:2] == ["pacman", "-Qo"]:
            return done(0, "".join(f"{f} is owned by {self.owned[f]} 1.0-1\n" for f in cmd[2:] if f in self.owned))
        if cmd[:2] == ["pacman", "-Qi"]:
            out = ""
            for n in cmd[2:]:
                if n in self.db:
                    size, need, why = self.db[n]
                    out += (f"Name            : {n}\nInstalled Size  : {size / 1024:.2f} KiB\nRequired By     : {' '.join(need) or 'None'}\n"
                            f"Install Reason  : {'Installed as a dependency for another package' if why == 'dependency' else 'Explicitly installed'}\n\n")
            return done(0, out)
        if cmd[:2] == ["pacman", "-Q"]:
            return done(0 if cmd[2] in self.db else 1)
        if cmd[:2] == ["pacman", "-Qdtq"]:
            return done(0, "".join(n + "\n" for n, (_, need, why) in self.db.items() if why == "dependency" and not need))
        if cmd[0] == "pacman" and "--print" in cmd:
            names = [c for c in cmd[1:] if not c.startswith("-") and c != "%n %s"]
            broken = [n for n in names if [r for r in self.db.get(n, (0, [], ""))[1] if r not in names]]
            if broken:
                return done(1, f":: removing {broken[0]} breaks dependency '{broken[0]}' required by {self.db[broken[0]][1][0]}\n",
                            "error: failed to prepare transaction (could not satisfy dependencies)\n")
            # -s: what only these needed goes too
            also = [n for n, (_, need, why) in self.db.items() if why == "dependency" and need and set(need) <= set(names)] if any("s" in c for c in cmd if c.startswith("-R")) else []
            return done(0, "".join(f"{n} {self.db[n][0]}\n" for n in names + also))
        return done(127)

    def events(self, fn, *args):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            rc = fn(*args)
        return rc, [json.loads(l[3:]) for l in out.getvalue().splitlines() if l.startswith("EV ")]

    def test_one_row_per_thing_that_can_go(self):
        rows = {r["item"]: r for r in self.m.listing()["apps"]}
        self.assertEqual(sorted(rows), sorted(["pacman:office", "pacman:niri", "local:" + str(self.game)]),
                         "hidden launchers and ones nobody owns are not listed")
        office = rows["pacman:office"]
        self.assertEqual((sorted(office["names"]), office["size"], office["keep"], office["needed"]), (["Calc", "Writer"], 5 * 1024 ** 2, "", []))
        self.assertTrue(rows["pacman:niri"]["keep"], "the compositor stays")
        self.assertEqual(rows["local:" + str(self.game)]["source"], "local")

    def test_a_removal_is_planned_first(self):
        p = self.m.plan(["pacman:office"])
        self.assertEqual(([x["name"] for x in p["remove"]], p["size"], p["refused"]), (["office", "office-libs"], 6 * 1024 ** 2, ""))
        self.assertIn("required by", self.m.plan(["pacman:toolkit"])["refused"], "what something else needs says who")
        self.assertIn("part of the system", self.m.plan(["pacman:niri"])["refused"])
        self.assertIn("angelOS needs it", self.m.plan(["pacman:office"], base={"office"})["refused"])
        for bad in ("rm:-rf", "pacman:", "pacman:a b", "local:/etc/passwd", "local:" + str(self.t / "usr/share/applications/niri.desktop")):
            with self.assertRaises(SystemExit, msg=bad):
                self.m.plan([bad])

    def test_removing_with_progress_and_one_password(self):
        self.db["stubborn"] = (1, [], "explicit")
        rc, evs = self.events(self.m.remove, ["pacman:office", "pacman:stubborn", "local:" + str(self.game)])
        self.assertEqual([e["ev"] for e in evs][:2], ["plan", "auth"])
        self.assertEqual([x["name"] for x in evs[0]["remove"]][:2], ["office", "stubborn"])
        self.assertEqual(self.helpers, 1)
        self.assertEqual(evs[-1]["ok"], ["pacman:office", "local:" + str(self.game)])
        self.assertEqual(evs[-1]["failed"], ["pacman:stubborn"])
        self.assertEqual(rc, 1)
        self.assertIn(["pacman", "-Rs", "--noconfirm", "office"], self.root_calls)
        self.assertFalse(self.game.exists())
        # a launcher alone needs no password
        (self.game).write_text("[Desktop Entry]\nType=Application\nName=g\nExec=x\n")
        rc, evs = self.events(self.m.remove, ["local:" + str(self.game)])
        self.assertEqual((rc, self.helpers, "auth" in [e["ev"] for e in evs]), (0, 1, False))

    def test_what_is_refused_removes_nothing(self):
        rc, evs = self.events(self.m.remove, ["pacman:niri"])
        self.assertEqual((rc, self.helpers, self.root_calls), (1, 0, []))
        self.assertIn("part of the system", evs[-1]["refused"])

    def test_clean_up(self):
        self.m.cache_size = lambda: (123, 4)
        st = self.m.cleanup_status()
        self.assertEqual(([o["name"] for o in st["orphans"]], st["cache"], st["cacheFiles"]), (["leftover"], 123, 4),
                         "python is nobody's dependency here too, but the shell runs on it")
        rc, evs = self.events(self.m.cleanup, ["orphans", "cache", "nonsense"])
        self.assertEqual((rc, evs[-1]["ok"], self.helpers), (0, ["orphans", "cache"], 1))
        self.assertIn(["pacman", "-Rns", "--noconfirm", "leftover"], self.root_calls)
        self.assertIn(["pacman", "-Sc", "--noconfirm"], self.root_calls)
        self.assertNotIn("leftover", self.db)


if __name__ == "__main__":
    unittest.main(verbosity=2)
