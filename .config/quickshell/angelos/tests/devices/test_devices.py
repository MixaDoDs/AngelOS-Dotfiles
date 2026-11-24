#!/usr/bin/env python3
"""The devices' driver without a device on the desk (scripts/devices.py, scripts/devlib): the
description files' checker, a whole session against the emulated mouse, the helper's JSON
lines, a description dropped into the user's folder while the helper runs. No real device is
asked: the emulator (ANGELOS_DEVICES_FAKE) stands in.
Run: python3 tests/devices/test_devices.py"""
import json
import os
import select
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from devlib import emulator, registry                      # noqa: E402
from devlib.session import DeviceError                     # noqa: E402

MAYA = ROOT / "data/devices/lamzu-aurora/373e-001c.json"


class Descriptions(unittest.TestCase):
    def test_shipped_files_are_good(self):
        files = sorted((ROOT / "data/devices").glob("*/*.json"))
        self.assertTrue(files)
        for f in files:
            d, problems = registry.load_file(f)
            self.assertEqual(problems, [], f)
            self.assertEqual(f.name, "%s-%s.json" % (d["usb"][0]["vid"].lower(), d["usb"][0]["pid"].lower()))
            self.assertEqual(f.parent.name, d["family"])
            # nothing is called checked that the list of checked things does not carry
            if d["support"] == "verified":
                self.assertTrue(d.get("checked"), f)

    def test_schema_file_says_what_the_checker_says(self):
        # data/devices/schema.json is `angelos devices schema`, nothing written by hand
        self.assertEqual(json.loads((ROOT / "data/devices/schema.json").read_text()), registry.schema())

    def problems(self, change):
        d = json.loads(MAYA.read_text())
        change(d)
        return {p["at"] for p in registry.check(d)}

    def test_checker_names_the_place(self):
        self.assertIn("schema", self.problems(lambda d: d.update(schema=2)))
        self.assertIn("family", self.problems(lambda d: d.update(family="no-such")))
        self.assertIn("kind", self.problems(lambda d: d.update(kind="keyboard")))
        self.assertIn("usb[0]", self.problems(lambda d: d["usb"][0].update(vid="373")))
        self.assertIn("channel.via", self.problems(lambda d: d["channel"].update(via="usbfs")))
        self.assertIn("capabilities.pollingRate.values", self.problems(lambda d: d["capabilities"]["pollingRate"].pop("values")))
        self.assertIn("capabilities.teleport", self.problems(lambda d: d["capabilities"].update(teleport=True)))
        self.assertIn("support", self.problems(lambda d: d.update(support="works on my machine")))
        self.assertTrue(registry.check([]))
        for p in registry.check({}):
            self.assertTrue(p["ru"] and p["en"])

    def test_broken_files_do_not_stop_the_good_ones(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "broken.json").write_text("{ this is not json")
            (Path(tmp) / "empty.json").write_text("{}")
            mine = json.loads(MAYA.read_text())
            mine.update(id="my-mouse", name="My Mouse")
            (Path(tmp) / "mine.json").write_text(json.dumps(mine))
            old = os.environ.get("ANGELOS_DEVICES_DIR")
            os.environ["ANGELOS_DEVICES_DIR"] = tmp
            try:
                good, broken = registry.load_all()
            finally:
                if old is None:
                    del os.environ["ANGELOS_DEVICES_DIR"]
                else:
                    os.environ["ANGELOS_DEVICES_DIR"] = old
            self.assertIn("my-mouse", [d["id"] for d in good])
            self.assertIn("lamzu-maya-x", [d["id"] for d in good])
            self.assertEqual(sorted(Path(b["file"]).name for b in broken), ["broken.json", "empty.json"])
            self.assertIn("JSON", broken[0]["problems"][0]["ru"])


class Mouse(unittest.TestCase):
    """The lamzu-aurora family against the emulated mouse."""

    def setUp(self):
        from devlib import lamzu_aurora, mouse
        self.au, self.mouse = lamzu_aurora, mouse
        self.tmp = tempfile.mkdtemp()
        self.old = os.environ.get("XDG_STATE_HOME")
        os.environ["XDG_STATE_HOME"] = self.tmp
        self.desc, problems = registry.load_file(ROOT / "data/devices/lamzu-aurora/373e-001e.json")
        self.assertEqual(problems, [])

    def tearDown(self):
        import shutil
        if self.old is None:
            del os.environ["XDG_STATE_HOME"]
        else:
            os.environ["XDG_STATE_HOME"] = self.old
        shutil.rmtree(self.tmp, ignore_errors=True)

    def open(self, script="idle", writes=True):
        emu = emulator.AuroraEmu(self.desc, script)
        s = self.mouse.AuroraSession(self.desc, emu, writes=writes)
        s.DELAY = 0
        s.open()
        return s, emu

    def test_packets(self):
        au = self.au
        p = au.build_get("pollingRate", 1)
        self.assertEqual((p[2], p[3], p[4], p[5], p[6]), (2, 2, 1, 0x80, 1))
        p = au.build_set("pollingRate", 1, bytes((au.RATE_CODE[8000],)))
        self.assertEqual((p[4], p[5], p[6], p[7]), (1, 0x00, 1, 128))
        p = au.build_get("battery")
        self.assertEqual((p[2], p[3], p[4], p[5], p[6]), (2, 2, 0, 0x83, 0))
        for mm in (0.7, 1, 2):
            self.assertEqual(au.lod_mm(au.lod_code(mm)), mm)
        self.assertEqual(au.lod_code(0.7), 0x87)

    def test_no_firmware_and_no_factory_reset_door(self):
        au = self.au
        # the loader's category, and "category 0, opcode 0" that carries 0xB0 / 0xC0, are not in the table
        for name, (cat, w, r) in au.ALLOWED.items():
            self.assertIn(cat, (0, 1), name)
            self.assertNotEqual((cat, w), (0, 0), name)
            self.assertFalse(w is not None and w >= 0x80, name)
        for name in ("enterBL", "erase", "defaultDevice", "program", "resetProfile"):
            with self.assertRaises(au.ProtocolError):
                au.build_get(name)
            with self.assertRaises(au.ProtocolError):
                au.build_set(name, 1, b"\x01")
        for name in ("firmware", "battery", "profile", "dpiMax", "sensor"):
            with self.assertRaises(au.ProtocolError):
                au.build_set(name, 1, b"\x01")

    def test_read_and_change(self):
        s, emu = self.open()
        st = s.load()
        self.assertEqual((st["pollingRate"], st["dpiActive"], st["lod"], st["debounce"], st["motionSync"], st["sleep"]), (8000, 2, 1.0, 2, True, 60))
        self.assertEqual(st["battery"]["percent"], 87)
        self.assertTrue(all(p[5] >= 0x80 for p in emu.sent))               # loading only reads
        self.assertEqual(s.set_setting("pollingRate", 4000), 4000)
        self.assertEqual(emu.settings["pollingRate"], 64)
        self.assertEqual(s.set_setting("lod", 0.7), 0.7)
        self.assertEqual(s.set_setting("debounce", 99), 15)                # brought into the limits
        self.assertEqual(s.set_setting("motionSync", False), False)
        self.assertEqual(s.set_setting("sleep", 300), 300)
        self.assertEqual(s.set_setting("dpiStages", [400, {"x": 820, "y": 1610}, 99999]), [{"x": 400, "y": 400}, {"x": 800, "y": 1600}, {"x": 30000, "y": 30000}])
        self.assertEqual(s.set_setting("dpiActive", 3), 3)
        for name, value in (("pollingRate", 3000), ("pollingRate", 125), ("lod", 1.5), ("sleep", 7), ("dpiActive", 9), ("dpiStages", []), ("warp", 1)):
            with self.assertRaises(DeviceError) as e:
                s.set_setting(name, value)
            self.assertEqual(e.exception.code, "range", name)
        self.assertEqual(len(list(Path(self.tmp).glob("angelos/devices/backup-lamzu-maya-x-8k-*.json"))), 1)
        self.assertGreater(s.restore(), 0)
        self.assertEqual((s.state["pollingRate"], s.state["dpiStages"][1], s.state["lod"]), (8000, {"x": 800, "y": 800}, 1.0))

    def test_reading_only_and_asleep(self):
        s, emu = self.open(writes=False)
        s.load()
        with self.assertRaises(DeviceError) as e:
            s.set_setting("pollingRate", 4000)
        self.assertEqual(e.exception.code, "readonly")
        self.assertTrue(all(p[5] >= 0x80 for p in emu.sent))
        self.assertEqual(list(Path(self.tmp).glob("angelos/devices/*")), [])
        s, emu = self.open("asleep")
        with self.assertRaises(DeviceError) as e:
            s.load()
        self.assertEqual(e.exception.code, "asleep")


class Helper(unittest.TestCase):
    def setUp(self):
        self.pending = {}

    def start(self, tmp, script="idle"):
        env = dict(os.environ, ANGELOS_DEVICES_FAKE=script, ANGELOS_DEVICES_DIR=tmp, XDG_STATE_HOME=os.path.join(tmp, "state"))
        p = subprocess.Popen([sys.executable, "-u", str(ROOT / "scripts/devices.py"), "serve"], stdin=subprocess.PIPE,
                             stdout=subprocess.PIPE, env=env)
        self.addCleanup(lambda: (p.stdin.close(), p.wait(5), p.stdout.close()))
        return p

    def read(self, p, want, timeout=5.0):
        """The next line of type `want` (the others on the way are returned too). The pipe is
        read by hand: several lines come in one piece, and a buffered readline() would keep
        the rest where select() cannot see it."""
        seen = []
        deadline = time.monotonic() + timeout
        fd = p.stdout.fileno()
        buf = self.pending.setdefault(fd, bytearray())
        while True:
            while b"\n" in buf:
                line, _, rest = bytes(buf).partition(b"\n")
                buf[:] = rest
                ev = json.loads(line)
                seen.append(ev)
                if ev["t"] == want:
                    return ev, seen
            left = deadline - time.monotonic()
            if left <= 0:
                break
            ready, _, _ = select.select([fd], [], [], min(left, 0.2))
            if ready:
                chunk = os.read(fd, 65536)
                if not chunk:
                    break
                buf += chunk
        self.fail("no %s line; got %s" % (want, [e["t"] for e in seen]))

    def say(self, p, **msg):
        p.stdin.write((json.dumps(msg) + "\n").encode())
        p.stdin.flush()

    def test_lines(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = self.start(tmp)
            ev, _ = self.read(p, "devices")
            self.assertEqual(sorted(d["id"] for d in ev["devices"]), ["lamzu-maya-x", "lamzu-maya-x-8k"])
            self.assertEqual({d["access"] for d in ev["devices"]}, {"ok"})
            self.assertEqual(ev["broken"], [])
            self.say(p, cmd="open", id="lamzu-maya-x")
            st, seen = self.read(p, "state")
            self.assertTrue(any(e["t"] == "progress" for e in seen))
            self.assertEqual((st["kind"], st["dpiActive"]), ("mouse", 2))
            self.say(p, cmd="open", id="no-such-device")
            err, _ = self.read(p, "error")
            self.assertEqual(err["code"], "unknown")
            self.assertTrue(err["ru"] and err["en"])
            # a file put into the user's folder turns up by itself; a broken one is told, not fatal
            mine = json.loads(MAYA.read_text())
            mine.update(id="my-mouse", name="My Mouse", usb=[{"vid": "ffff", "pid": "0001"}])
            (Path(tmp) / "mine.json").write_text(json.dumps(mine))
            (Path(tmp) / "bad.json").write_text("[1, 2")
            # (the folder may be looked at between the two files being written: wait for both)
            deadline = time.monotonic() + 10
            while True:
                ev, _ = self.read(p, "devices", timeout=max(0.1, deadline - time.monotonic()))
                if "my-mouse" in [k["id"] for k in ev["known"]] and ev["broken"]:
                    break
            self.assertEqual([Path(b["file"]).name for b in ev["broken"]], ["bad.json"])

    def test_writes_through_the_lines(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = self.start(tmp)
            self.read(p, "devices")
            self.say(p, cmd="open", id="lamzu-maya-x-8k")
            st, _ = self.read(p, "state")
            self.assertEqual(st["readonly"], "")
            self.assertTrue(st["backup"].startswith(os.path.join(tmp, "state")))
            self.say(p, cmd="set", what="mouse", name="dpiActive", value=3)
            st, _ = self.read(p, "state")
            self.assertEqual(st["dpiActive"], 3)
            self.assertEqual(self.read(p, "done")[0]["what"], "mouse")
            self.say(p, cmd="set", what="mouse", name="pollingRate", value=3000)
            bad, _ = self.read(p, "failed")
            self.assertEqual((bad["what"], bad["code"]), ("mouse", "range"))
            self.say(p, cmd="restore")
            st, _ = self.read(p, "state")
            self.assertEqual(st["dpiActive"], 2)

    def test_stdin_closing_ends_it(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = self.start(tmp)
            self.read(p, "devices")
            self.say(p, cmd="open", id="lamzu-maya-x")
            self.read(p, "state")
            p.stdin.close()
            self.assertEqual(p.wait(5), 0)
            p.stdin = open(os.devnull, "wb")

    def test_check_command(self):
        with tempfile.TemporaryDirectory() as tmp:
            bad = Path(tmp) / "bad.json"
            d = json.loads(MAYA.read_text())
            d["capabilities"]["teleport"] = True
            bad.write_text(json.dumps(d))
            r = subprocess.run([sys.executable, str(ROOT / "scripts/devices.py"), "check", str(MAYA), str(bad)], capture_output=True, text=True)
            self.assertEqual(r.returncode, 1)
            self.assertIn("в порядке", r.stdout)
            self.assertIn("capabilities.teleport", r.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
