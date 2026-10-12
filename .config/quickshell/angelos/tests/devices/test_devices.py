#!/usr/bin/env python3
"""The devices' driver without a device on the desk (scripts/devices.py, scripts/devlib):
the nuphy-io packets both ways, the guard on writes, the description files' checker, a whole
session against the emulated keyboard, the helper's JSON lines, a description dropped into the
user's folder while the helper runs. No real device is asked: the emulator
(ANGELOS_DEVICES_FAKE) and a made-up /sys (ANGELOS_SYSFS) stand in. No bytes here were
captured from anybody's keyboard: every vector is built by hand from the protocol's rules.
Run: python3 tests/devices/test_devices.py"""
import json
import os
import random
import select
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from devlib import emulator, registry, usbfs               # noqa: E402
from devlib import nuphy_io as np                          # noqa: E402
from devlib.session import DeviceError, NuphySession       # noqa: E402

AIR60 = ROOT / "data/devices/nuphy-io/19f5-fee0.json"


def air60():
    d, problems = registry.load_file(AIR60)
    assert d is not None, problems
    return d


class Packets(unittest.TestCase):
    def test_build_header_and_sum(self):
        p = np.build(np.CMD["GetKeyRTInfo"], 56, 1024 + 56)
        self.assertEqual(len(p), 64)
        self.assertEqual(p[0], 0x55)
        self.assertEqual(p[1], 160)
        self.assertEqual(p[2], 0)
        self.assertEqual(p[4], 56)
        self.assertEqual(p[5] | p[6] << 8, 1080)
        self.assertEqual(p[3], (56 + (1080 & 0xFF) + (1080 >> 8)) & 0xFF)
        self.assertEqual(np.build(np.CMD["GetInfo"])[:8].hex(), "5503000000000000")

    def test_parse_and_xor_key(self):
        p = bytearray(np.build(np.CMD["SetKeyRTInfo"], 8, 16, bytes(range(1, 9))))
        got = np.parse(bytes(p))
        self.assertTrue(got["sum_ok"])
        self.assertEqual(got["data"], bytes(range(1, 9)))
        self.assertEqual(got["addr"], 16)
        # an answer whose data is XORed with the key byte
        p[2] = 0x5A
        for i in range(8, 16):
            p[i] ^= 0x5A
        self.assertEqual(np.parse(bytes(p))["data"], bytes(range(1, 9)))
        p[20] ^= 1
        self.assertFalse(np.parse(bytes(p))["sum_ok"])
        with self.assertRaises(np.ProtocolError):
            np.parse(b"\0" * 63)

    def test_read_plan_chunks(self):
        plan = np.read_plan(np.CMD["GetUseKeyMatrix"], 512, 512)
        self.assertEqual([n for _, _, n in plan], [56] * 9 + [8])
        self.assertEqual(plan[1][0][5] | plan[1][0][6] << 8, 512 + 56)
        with self.assertRaises(np.ProtocolError):
            np.read_plan(np.CMD["SetFunc"], 0, 4)

    def test_limits(self):
        for bad in (dict(cmd=3, length=57), dict(cmd=3, addr=70000), dict(cmd=300)):
            with self.assertRaises(np.ProtocolError):
                np.build(**bad)


class Guard(unittest.TestCase):
    def test_no_firmware_door(self):
        # the firmware loader's commands (128..132) do not exist in this driver
        self.assertFalse(set(range(128, 133)) & set(np.CMD.values()))
        for name in np.CMD:
            self.assertNotIn("iap", name.lower())
        # …and the settings byte that enters the loader is never written, in any mode
        for mode in range(np.MODES):
            for off in range(0, 4):
                with self.assertRaises(np.ProtocolError):
                    np.guard_write(np.CMD["SetFunc"], mode * 64 + off, b"\x01")
        with self.assertRaises(np.ProtocolError):
            np.guard_write(np.CMD["SetFunc"], 3, bytes(4))          # 3..6 touches byte 3

    def test_what_may_be_written(self):
        np.guard_write(np.CMD["SetFunc"], 64 + 4, bytes(4))
        np.guard_write(np.CMD["SetFunc"], 39, bytes(3))
        np.guard_write(np.CMD["SetKeyRTInfo"], 8, bytes(8))
        for cmd in ("RestoreFactorySettings", "StartCalibration", "EndCalibration", "QuickCommStart", "GetInfo"):
            with self.assertRaises(np.ProtocolError):
                np.guard_write(np.CMD[cmd], 0, b"")
        with self.assertRaises(np.ProtocolError):
            np.guard_write(0xEE, 0, b"")
        with self.assertRaises(np.ProtocolError):
            np.guard_write(np.CMD["SetFunc"], 3 * 64 + 4, bytes(4))  # past the last mode


class Regions(unittest.TestCase):
    def test_rt_both_ways(self):
        rnd = random.Random(7)
        for _ in range(500):
            rec = bytearray(rnd.randrange(256) for _ in range(8))
            rec[1] = rnd.choice((0, 1, 2)) | rnd.choice((0x00, 0x10, 0x20, 0x30))
            rec[3] &= 0x1F
            if (rec[3] >> 1) & 3 == 3:
                rec[3] &= ~0x06
            if (rec[3] >> 3) & 3 == 3:
                rec[3] &= ~0x18
            self.assertEqual(np.build_rt(np.parse_rt(bytes(rec))), bytes(rec))

    def test_rt_millimetres(self):
        # a low-profile key at its factory settings: switch 2, check mark 5, actuation 1.50 mm
        rt = np.parse_rt(bytes((5 << 5 | 2, 0, 149, 0, 0, 0, 0, 0)))
        self.assertEqual((rt["switch"], rt["check"], rt["trigger"]), (2, 5, "normal"))
        self.assertEqual(np.rt_mm(rt)["actuation"], 1.5)
        # Rapid Trigger, continuous, 0.10 down / 0.20 up, dead zones 0.10 / 0.20, this key wins
        press, release = 9 | 9 << 9, 19 | 19 << 9
        rt = np.parse_rt(bytes((0xA2, 0x12, 49, 0, press & 0xFF, press >> 8, release & 0xFF, release >> 8)))
        mm = np.rt_mm(rt)
        self.assertEqual((mm["trigger"], mm["priority"]), ("continuous", "own"))
        self.assertEqual((mm["actuation"], mm["press"], mm["release"], mm["pressDead"], mm["releaseDead"]), (0.5, 0.1, 0.2, 0.1, 0.2))
        self.assertEqual(np.mm_dead(0), 0.0)

    def test_func(self):
        block = bytearray(54)
        block[4] = 2 << 4 | 3
        block[5] = 0x80 | 10
        block[6] = 0b0101
        block[7] = 7 << 4 | 0b1010
        f = np.parse_func(bytes(block))
        self.assertEqual((f["reportRate"], f["tickRate"], f["sleep"], f["sleepMinutes"]), (3, 2, True, 10))
        self.assertEqual((f["lockWin"], f["lockAltTab"], f["lockAltF4"]), (True, False, True))
        self.assertEqual((f["speedMode"], f["gameOptimization"], f["keyStatusUpload"], f["stabilization"]), (False, True, True, 7))

    def test_info_and_base(self):
        p = bytearray(64)
        p[0], p[1] = 0xAA, 3
        p[8], p[9] = 0x14, 0x01
        p[10:30] = b"Jan 01 2026,00:00:00"
        self.assertEqual(np.parse_info(bytes(p)), {"version": "114", "versionNumber": 114, "built": "Jan 01 2026,00:00:00"})
        self.assertEqual(np.base_offset(105, [{"min": 100, "max": 109, "offset": 8}]), 8)
        self.assertEqual(np.base_offset(114, [{"min": 100, "max": 109, "offset": 8}]), 0)
        self.assertEqual(np.parse_base(bytes((2, 0)) + bytes(14)), {"mode": 2, "layersPerMode": 4})

    def test_reports(self):
        p = bytearray(64)
        p[0:4] = bytes((0xA0, 16, 0, 4))
        p[4:8] = (2400).to_bytes(2, "big") + (187).to_bytes(2, "big")
        p[10] = 255
        r = np.parse_report(bytes(p))
        self.assertEqual((r["type"], r["key"], r["travel"], r["raw"], r["status"]), ("key", (16, 0, 4), 187, 2400, "calibrated"))
        p[0], p[1], p[2] = 0xA1, 1, 2
        self.assertEqual(np.parse_report(bytes(p)), {"type": "state", "layer": 1, "mode": 2})
        p[0] = 0x77
        self.assertIsNone(np.parse_report(bytes(p)))

    def test_names(self):
        self.assertEqual(np.action_name((16, 0, 41)), "Esc")
        self.assertEqual(np.action_name((16, 0x02, 0)), "Shift")
        self.assertEqual(np.action_name((16, 0x01, 6)), "Ctrl+C")
        self.assertEqual(np.action_name((240, 255, 5)), "Fn 1")
        self.assertEqual(np.action_name((0, 0, 0)), "—")


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

    def test_air60_layout(self):
        d = air60()
        keys = d["layout"]["keys"]
        self.assertEqual(len(keys), 61)
        self.assertEqual(sorted(k["m"] for k in keys), list(range(61)))
        for y in range(5):
            self.assertAlmostEqual(sum(k.get("w", 1) for k in keys if k["y"] == y), 15)

    def problems(self, change):
        d = json.loads(AIR60.read_text())
        change(d)
        return {p["at"] for p in registry.check(d)}

    def test_checker_names_the_place(self):
        self.assertIn("schema", self.problems(lambda d: d.update(schema=2)))
        self.assertIn("family", self.problems(lambda d: d.update(family="no-such")))
        self.assertIn("usb[0]", self.problems(lambda d: d["usb"][0].update(vid="19f")))
        self.assertIn("channel.in", self.problems(lambda d: d["channel"].update({"in": "0x02"})))
        self.assertIn("channel.out", self.problems(lambda d: d["channel"].update({"out": "0x82"})))
        self.assertIn("capabilities.actuation.max", self.problems(lambda d: d["capabilities"]["actuation"].pop("max")))
        self.assertIn("capabilities.teleport", self.problems(lambda d: d["capabilities"].update(teleport=True)))
        self.assertIn("layout.keys[1].m", self.problems(lambda d: d["layout"]["keys"][1].update(m=0)))
        self.assertIn("layout.keys[2].x", self.problems(lambda d: d["layout"]["keys"][2].update(x="left")))
        self.assertIn("support", self.problems(lambda d: d.update(support="works on my machine")))
        self.assertTrue(registry.check([]))
        for p in registry.check({}):
            self.assertTrue(p["ru"] and p["en"])

    def test_broken_files_do_not_stop_the_good_ones(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "broken.json").write_text("{ this is not json")
            (Path(tmp) / "empty.json").write_text("{}")
            mine = json.loads(AIR60.read_text())
            mine.update(id="my-board", name="My Board")
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
            self.assertIn("my-board", [d["id"] for d in good])
            self.assertIn("nuphy-air60-he", [d["id"] for d in good])
            self.assertEqual(sorted(Path(b["file"]).name for b in broken), ["broken.json", "empty.json"])
            self.assertIn("JSON", broken[0]["problems"][0]["ru"])


class Session(unittest.TestCase):
    def open(self, script="idle", **kw):
        emu = emulator.NuphyEmu(air60(), script, **kw)
        s = NuphySession(air60(), emu)
        s.open()
        self.addCleanup(s.close)
        return s, emu

    def test_load_reads_and_only_reads(self):
        s, emu = self.open()
        st = s.load()
        self.assertEqual(st["firmware"]["version"], "114")
        self.assertEqual((st["mode"], st["modeName"]), (1, "Windows"))
        self.assertEqual(st["mismatch"], [])
        self.assertEqual(len(st["keys"]), 61)
        self.assertEqual(st["keys"][0]["actuation"], 1.5)
        self.assertTrue(st["upload"])
        self.assertTrue(emu.sent)
        for p in emu.sent:
            self.assertEqual(p[0], 0x55)
            self.assertIn(p[1], np.READS)
            self.assertEqual(np.checksum(p), p[3])
        snap = s.snapshot()
        self.assertEqual(len(bytes.fromhex(snap["rt"])), 3 * 1024)
        self.assertEqual(len(bytes.fromhex(snap["matrix"])), 12 * 512)
        for p in emu.sent:
            self.assertIn(p[1], np.READS)

    def test_a_reading_session_cannot_write(self):
        s, emu = self.open()
        n = len(emu.sent)
        for cmd in ("SetFunc", "SetKeyRTInfo", "RestoreFactorySettings", "StartCalibration", "QuickCommStart"):
            with self.assertRaises(DeviceError) as e:
                s.request(np.CMD[cmd], 4, 4, bytes(4))
            self.assertEqual(e.exception.code, "readonly")
        self.assertEqual(len(emu.sent), n)

    def test_travel_of_held_keys(self):
        s, _ = self.open("press:3,17")
        s.load()
        deadline = time.monotonic() + 2
        got = {}
        while time.monotonic() < deadline and len(got) < 2:
            k = s.take_depth()
            got.update(zip(k[0::2], k[1::2]))
            time.sleep(0.01)
        self.assertEqual(got, {3: 3.3, 17: 3.3})
        self.assertEqual(s.take_depth(), [])
        self.assertEqual(s.all_depth(), [3, 3.3, 17, 3.3])

    def test_no_travel_when_upload_is_off(self):
        s, _ = self.open("press:3", upload=False)
        st = s.load()
        self.assertFalse(st["upload"])
        time.sleep(0.15)
        self.assertEqual(s.take_depth(), [])

    def test_layout_that_does_not_match_is_told(self):
        d = air60()
        d["layout"]["keys"][5]["default"] = [16, 0, 99]
        emu = emulator.NuphyEmu(air60(), "idle")
        s = NuphySession(d, emu)
        s.open()
        self.addCleanup(s.close)
        st = s.load()
        self.assertEqual([x["m"] for x in st["mismatch"]], [5])

    def test_a_silent_device_times_out(self):
        s, emu = self.open()
        emu.answer = lambda packet: None
        s.TIMEOUT = 0.02
        with self.assertRaises(DeviceError) as e:
            s.load()
        self.assertEqual(e.exception.code, "timeout")


class Writing(unittest.TestCase):
    """Settings written to the emulated keyboard: every write guarded, backed up first, read back."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.old = os.environ.get("XDG_STATE_HOME")
        os.environ["XDG_STATE_HOME"] = self.tmp

    def tearDown(self):
        import shutil
        if self.old is None:
            del os.environ["XDG_STATE_HOME"]
        else:
            os.environ["XDG_STATE_HOME"] = self.old
        shutil.rmtree(self.tmp, ignore_errors=True)

    def open(self, script="idle", desc=None, **kw):
        emu = emulator.NuphyEmu(air60(), script, **kw)
        s = NuphySession(desc or air60(), emu, writes=True)
        s.open()
        self.addCleanup(s.close)
        s.load()
        return s, emu

    def writes(self, emu):
        return [p for p in emu.sent if p[1] not in np.READS]

    def test_backup_before_the_first_write_and_only_once(self):
        s, emu = self.open()
        self.assertEqual(s.state["readonly"], "")
        self.assertEqual(s.state["backup"], "")
        s.set_rt([4], {"actuation": 0.8})
        files = sorted(Path(self.tmp).glob("angelos/devices/backup-nuphy-air60-he-*.json"))
        self.assertEqual(len(files), 1)
        saved = json.loads(files[0].read_text())
        # the file holds the keyboard as it was before the write
        rt = bytes.fromhex(saved["regions"]["rt"])
        self.assertEqual(np.rt_mm(np.parse_rt(rt[1024 + 4 * 8:1024 + 5 * 8]))["actuation"], 1.5)
        self.assertEqual(s.state["backup"], str(files[0]))
        s.set_rt([5], {"actuation": 0.9})
        self.assertEqual(len(list(Path(self.tmp).glob("angelos/devices/backup-*.json"))), 1)

    def test_travel_settings(self):
        s, emu = self.open()
        changed = s.set_rt([29, 30, 31, 7], {"actuation": 0.5, "trigger": "continuous", "press": 0.1, "release": 0.15, "pressDead": 0.2, "releaseDead": 0})
        self.assertEqual(changed, [7, 29, 30, 31])
        k = s.state["keys"][30]
        self.assertEqual((k["actuation"], k["trigger"], k["press"], k["release"], k["pressDead"], k["releaseDead"]), (0.5, "continuous", 0.1, 0.15, 0.2, 0.0))
        self.assertEqual(s.state["keys"][28]["actuation"], 1.5)            # a neighbour untouched
        self.assertEqual(s.state["keys"][30]["switch"], 2)                 # the switch type stays
        # the three neighbours went as one write, the far key as another; the record keeps its mark
        w = [p for p in self.writes(emu) if p[1] == np.CMD["SetKeyRTInfo"]]
        self.assertEqual(sorted((p[5] | p[6] << 8, p[4]) for p in w), [(1024 + 7 * 8, 8), (1024 + 29 * 8, 24)])
        self.assertTrue(all(p[8] >> 5 == 5 for p in w))
        # out of the device's limits: brought into them, never written raw
        s.set_rt([0], {"actuation": 9.0, "pressDead": 5.0})
        self.assertEqual((s.state["keys"][0]["actuation"], s.state["keys"][0]["pressDead"]), (3.3, 1.28))
        s.set_rt([0], {"actuation": 0.0})
        self.assertEqual(s.state["keys"][0]["actuation"], 0.1)
        with self.assertRaises(DeviceError):
            s.set_rt([0], {"trigger": "warp"})
        with self.assertRaises(DeviceError):
            s.set_rt([200], {"actuation": 1})
        # nothing to change: nothing written
        n = len(self.writes(emu))
        self.assertEqual(s.set_rt([0], {"actuation": 0.1}), [])
        self.assertEqual(len(self.writes(emu)), n)

    def test_mode_settings_and_travel_reports(self):
        s, emu = self.open()
        self.assertTrue(s.state["upload"])
        s.set_upload(False)
        self.assertFalse(s.state["upload"])
        self.assertFalse(any(m["keyStatusUpload"] for m in s.state["modes"]))
        s.set_func(1, {"tickRate": 2, "stabilization": 3, "lockWin": True, "sleepMinutes": 30})
        m = s.state["modes"][1]
        self.assertEqual((m["tickRate"], m["stabilization"], m["lockWin"], m["sleepMinutes"], m["speedMode"]), (2, 3, True, 30, True))
        for p in self.writes(emu):
            self.assertEqual(p[1], np.CMD["SetFunc"])
            self.assertEqual(((p[5] | p[6] << 8) % 64, p[4]), (4, 4))       # bytes 4..7 of a mode, nothing else
        self.assertFalse(s.set_func(1, {"tickRate": 2}))
        with self.assertRaises(DeviceError):
            s.set_func(5, {"tickRate": 1})

    def test_reports_are_off_when_the_session_ends(self):
        emu = emulator.NuphyEmu(air60(), "idle")
        s = NuphySession(air60(), emu, writes=True)
        s.open()
        s.load()
        self.assertTrue(emu.uploading())
        s.close()
        self.assertFalse(emu.uploading())
        # a session that only reads leaves the keyboard as it found it
        emu = emulator.NuphyEmu(air60(), "idle")
        s = NuphySession(air60(), emu)
        s.open()
        s.load()
        s.close()
        self.assertTrue(emu.uploading())
        self.assertEqual(self.writes(emu), [])

    def test_snap_tap_pair(self):
        s, emu = self.open()
        a, d = 29, 31                                   # A and D
        s.set_pair(a, d, "last")
        self.assertEqual([(p["a"], p["b"], p["kind"], p["whole"]) for p in s.state["pairs"]], [(a, d, "socd", True)])
        matrix = emu.mem[np.CMD["GetUseKeyMatrix"]][4 * 512:5 * 512]
        self.assertEqual((tuple(matrix[3 * a:3 * a + 3]), tuple(matrix[3 * d:3 * d + 3])), ((148, 0, d), (148, 1, a)))
        mt = emu.mem[np.CMD["GetMtKeyInfo"]][256:512]
        self.assertEqual((bytes(mt[0:6]), bytes(mt[6:12])), (bytes((16, 0, 4, 16, 0, 7)), bytes((16, 0, 7, 16, 0, 4))))
        self.assertEqual((s.state["keys"][a]["priority"], s.state["keys"][d]["priority"]), ("last", "last"))
        # the rule changed: the same slots, only the keys' places in the pair
        s.set_pair(a, d, "a")
        self.assertEqual((s.state["keys"][a]["priority"], s.state["keys"][d]["priority"]), ("own", "bond"))
        self.assertEqual(tuple(emu.mem[np.CMD["GetUseKeyMatrix"]][4 * 512 + 3 * a:][:3]), (148, 0, d))
        s.set_pair(a, d, "neutral")
        self.assertEqual(s.state["keys"][a]["priority"], "neutral")
        # a second pair takes the next slots; a key moved to a new partner leaves the old one whole
        s.set_pair(17, 30, "last")                      # W and S
        self.assertEqual(len(s.state["pairs"]), 2)
        s.set_pair(a, 30, "last")                       # A with S: both old pairs are undone
        self.assertEqual([(p["a"], p["b"]) for p in s.state["pairs"]], [(a, 30)])
        self.assertEqual(tuple(emu.mem[np.CMD["GetUseKeyMatrix"]][4 * 512 + 3 * d:][:3]), (16, 0, 7))
        s.clear_pair(30)
        self.assertEqual(s.state["pairs"], [])
        self.assertEqual(bytes(emu.mem[np.CMD["GetUseKeyMatrix"]]), bytes(emu.mem[np.CMD["GetDefaultKeyMatrix"]]))
        self.assertFalse(any(emu.mem[np.CMD["GetMtKeyInfo"]]))
        self.assertEqual(s.state["keys"][a]["priority"], "last")
        with self.assertRaises(DeviceError):
            s.set_pair(a, a)
        with self.assertRaises(DeviceError):
            s.set_pair(a, 99)

    def test_restore_puts_it_back(self):
        s, emu = self.open()
        before = {k: bytes(v) for k, v in emu.mem.items()}
        s.set_rt(list(range(61)), {"actuation": 0.3, "trigger": "rapid", "press": 0.05})
        s.set_pair(29, 31, "b")
        s.set_func(1, {"stabilization": 7, "tickRate": 1})
        self.assertNotEqual(bytes(emu.mem[np.CMD["GetKeyRTInfo"]]), before[np.CMD["GetKeyRTInfo"]])
        written = s.restore()
        self.assertGreater(written, 0)
        for cmd in ("GetKeyRTInfo", "GetUseKeyMatrix", "GetMtKeyInfo"):
            self.assertEqual(bytes(emu.mem[np.CMD[cmd]]), before[np.CMD[cmd]], cmd)
        func, was = emu.mem[np.CMD["GetFunc"]], before[np.CMD["GetFunc"]]
        self.assertEqual(bytes(func[64:72]), was[64:72])
        self.assertEqual(s.state["keys"][0]["actuation"], 1.5)
        self.assertEqual(s.restore(), 0)                # nothing differs: nothing written

    def test_unknown_firmware_and_a_wrong_layout_only_read(self):
        emu = emulator.NuphyEmu(air60(), "idle", version=0x0250)
        s = NuphySession(air60(), emu, writes=True)
        s.open()
        self.addCleanup(s.close)
        self.assertEqual(s.load()["readonly"], "firmware")
        with self.assertRaises(DeviceError) as e:
            s.set_rt([0], {"actuation": 1})
        self.assertEqual(e.exception.code, "readonly")
        d = air60()
        d["layout"]["keys"][5]["default"] = [16, 0, 99]
        s2, emu2 = self.open(desc=d)
        self.assertEqual(s2.state["readonly"], "mismatch")
        with self.assertRaises(DeviceError):
            s2.set_upload(False)
        self.assertEqual(self.writes(emu) + self.writes(emu2), [])
        self.assertEqual(list(Path(self.tmp).glob("angelos/devices/*")), [])

    def test_remap_and_layers(self):
        s, emu = self.open()
        layer = lambda n: emu.mem[np.CMD["GetUseKeyMatrix"]][(4 + n) * 512:(5 + n) * 512]
        self.assertEqual(s.set_keys([29], [16, 0x01, 6]), [29])           # A -> Ctrl+C
        self.assertEqual(tuple(layer(0)[3 * 29:3 * 29 + 3]), (16, 1, 6))
        self.assertEqual(s.state["labels"][29], "Ctrl+C")
        self.assertIn(29, s.state["changed"])
        s.set_keys([29], "factory")
        self.assertEqual(tuple(layer(0)[3 * 29:3 * 29 + 3]), (16, 0, 4))
        # a layer of Fn: what is set there stays there
        s.set_layer(1)
        s.set_keys([1, 2], [48, 233, 0])                                 # 1, 2 -> Vol +
        self.assertEqual(s.state["layer"], 1)
        self.assertEqual(tuple(layer(1)[3:6]), (48, 233, 0))
        self.assertEqual(tuple(layer(0)[3:6]), (16, 0, 30))
        s.set_keys([3], "off")
        self.assertEqual(s.state["labels"][3], "—")
        with self.assertRaises(DeviceError):
            s.set_keys([4], [240, 7, 0])                                 # the loader key: never
        with self.assertRaises(DeviceError):
            s.set_layer(4)

    def test_mod_tap_and_toggle(self):
        s, emu = self.open()
        mt = lambda: emu.mem[np.CMD["GetMtKeyInfo"]][256:512]
        s.set_modtap(57, [16, 0, 41], [16, 0x01, 0], 250)                # Caps: tap Esc, hold Ctrl
        self.assertEqual(tuple(emu.mem[np.CMD["GetUseKeyMatrix"]][4 * 512 + 3 * 57:][:3]), (146, 0, 25))
        self.assertEqual(bytes(mt()[0:6]), bytes((16, 0, 41, 16, 1, 0)))
        sp = s.state["special"][57]
        self.assertEqual((sp["kind"], sp["tapName"], sp["holdName"], sp["delay"]), ("modTap", "Esc", "Ctrl", 250))
        # the same key again: the same slot; a Snap Tap pair takes the next free one
        s.set_modtap(57, [16, 0, 41], [16, 0x02, 0], 9999)
        self.assertEqual(tuple(emu.mem[np.CMD["GetUseKeyMatrix"]][4 * 512 + 3 * 57:][:3]), (146, 0, 100))
        s.set_pair(29, 31)
        self.assertEqual([p["slot"] for p in s.state["pairs"]], [1])
        # Toggle has slots of its own; a key that becomes one gives its Mod-Tap slot back
        s.set_toggle(57, [16, 0, 4])
        self.assertEqual(tuple(emu.mem[np.CMD["GetUseKeyMatrix"]][4 * 512 + 3 * 57:][:3]), (145, 0, 0))
        self.assertEqual(bytes(mt()[0:6]), bytes(6))
        self.assertEqual(s.state["special"][57]["actionName"], "A")
        s.set_keys([57], "factory")
        self.assertFalse(any(emu.mem[np.CMD["GetTglKeyInfo"]][128:256]))
        for bad in ([146, 0, 0], [112, 0, 0], [240, 7, 0], [1, 2]):
            with self.assertRaises(DeviceError):
                s.set_modtap(57, bad, [16, 1, 0])

    def test_lights_and_profiles(self):
        s, emu = self.open()
        s.set_light(1, "main", {"effect": 6, "brightness": 40, "color": "#ff0080"})
        light = s.state["modes"][1]["light"]["main"]
        self.assertEqual((light["effect"], light["brightness"], light["color"]), (6, 40, "#ff0080"))
        s.set_light(1, "main", {"on": False})
        self.assertFalse(s.state["modes"][1]["light"]["main"]["on"])
        s.set_light(1, "main", {"on": True})
        self.assertEqual(s.state["modes"][1]["light"]["main"]["brightness"], 40)
        f = s.save_profile("Игры / CS")
        self.assertEqual([p["name"] for p in s.state["profiles"]], [Path(f).stem])
        self.assertNotIn("/", Path(f).stem)
        s.set_rt([0], {"actuation": 0.4})
        s.restore(f)
        self.assertEqual(s.state["keys"][0]["actuation"], 1.5)
        with self.assertRaises(DeviceError):
            s.delete_profile("/etc/passwd")
        s.delete_profile(f)
        self.assertEqual(s.state["profiles"], [])

    def test_a_write_the_keyboard_did_not_take_is_told(self):
        s, emu = self.open()
        real = emu.answer

        def deaf_to_sets(packet):
            if packet[1] == np.CMD["SetKeyRTInfo"]:
                p = np.parse(packet)                    # answers, and keeps what it had
                out = bytearray(64)
                out[0], out[1], out[4] = np.FLAG_ANSWER, packet[1], p["len"]
                out[3] = np.checksum(out)
                return bytes(out)
            return real(packet)
        emu.answer = deaf_to_sets
        with self.assertRaises(DeviceError) as e:
            s.set_rt([3], {"actuation": 2.0})
        self.assertEqual(e.exception.code, "verify")


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


class Sysfs(unittest.TestCase):
    def test_find_reads_sysfs_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp) / "sys/bus/usb/devices/3-4"
            for n, driver in ((0, "usbhid"), (1, ""), (2, "usbhid")):
                i = d / ("3-4:1.%d" % n)
                i.mkdir(parents=True)
                (i / "bInterfaceNumber").write_text("%02x\n" % n)
                if driver:
                    (i / "driver").symlink_to("../../../../drivers/" + driver)
            for name, text in (("idVendor", "19f5"), ("idProduct", "fee0"), ("busnum", "3"), ("devnum", "6"),
                               ("manufacturer", "NuPhy"), ("product", "NuPhy Air60 HE"), ("bcdDevice", "0120")):
                (d / name).write_text(text + "\n")
            old = usbfs.SYSFS, usbfs.DEVFS
            usbfs.SYSFS, usbfs.DEVFS = Path(tmp) / "sys", Path(tmp) / "dev"
            try:
                found = usbfs.find("19F5", "FEE0")
                self.assertEqual(usbfs.find("19f5", "0001"), [])
            finally:
                usbfs.SYSFS, usbfs.DEVFS = old
            self.assertEqual(len(found), 1)
            self.assertEqual(found[0]["node"], str(Path(tmp) / "dev/bus/usb/003/006"))
            self.assertEqual(found[0]["interfaces"], {0: "usbhid", 1: "", 2: "usbhid"})
            self.assertEqual(usbfs.access(found[0]["node"]), "gone")

    def test_never_detaches_a_kernel_driver(self):
        # the ioctls that push a kernel driver off an interface, reset the device or set a
        # configuration are not in the module at all
        src = (ROOT / "scripts/devlib/usbfs.py").read_text()
        code = "\n".join(l for l in src.splitlines() if not l.strip().startswith(("#", '"""')) and "USBDEVFS_DISCONNECT /" not in l)
        for word in ("USBDEVFS_DISCONNECT", "USBDEVFS_RESET", "USBDEVFS_SETCONFIGURATION", "USBDEVFS_IOCTL", "USBDEVFS_CONNECT"):
            self.assertNotIn(word + " =", code)


class Helper(unittest.TestCase):
    def setUp(self):
        self.pending = {}

    def start(self, tmp, script="press:3"):
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
            self.assertEqual([d["id"] for d in ev["devices"]], ["nuphy-air60-he", "lamzu-maya-x", "lamzu-maya-x-8k"])
            self.assertEqual(ev["devices"][0]["access"], "ok")
            self.assertEqual(len(ev["devices"][0]["layout"]["keys"]), 61)
            self.assertEqual(ev["broken"], [])
            self.say(p, cmd="open", id="nuphy-air60-he")
            st, seen = self.read(p, "state")
            self.assertTrue(any(e["t"] == "progress" for e in seen))
            self.assertEqual(st["firmware"]["version"], "114")
            self.assertEqual(st["keys"]["3"]["actuation"], 1.5)
            # the emulator came up reporting travel: off at once, on again for the watcher
            self.assertFalse(st["upload"])
            time.sleep(0.05)                # (the emulator's player looks at the flag every 4 ms)
            self.say(p, cmd="stream", on=True)
            deadline = time.monotonic() + 5
            while True:
                d, _ = self.read(p, "d", timeout=max(0.1, deadline - time.monotonic()))
                if d["k"] == [3, 3.3]:
                    break
            self.say(p, cmd="open", id="no-such-device")
            err, _ = self.read(p, "error")
            self.assertEqual(err["code"], "unknown")
            self.assertTrue(err["ru"] and err["en"])
            # a file put into the user's folder turns up by itself; a broken one is told, not fatal
            mine = json.loads(AIR60.read_text())
            mine.update(id="my-board", name="My Board", usb=[{"vid": "ffff", "pid": "0001"}])
            (Path(tmp) / "mine.json").write_text(json.dumps(mine))
            (Path(tmp) / "bad.json").write_text("[1, 2")
            # (the folder may be looked at between the two files being written: wait for both)
            deadline = time.monotonic() + 10
            while True:
                ev, _ = self.read(p, "devices", timeout=max(0.1, deadline - time.monotonic()))
                if "my-board" in [k["id"] for k in ev["known"]] and ev["broken"]:
                    break
            self.assertEqual([Path(b["file"]).name for b in ev["broken"]], ["bad.json"])
            self.say(p, cmd="open", id="nuphy-air60-he")
            self.read(p, "state")

    def test_writes_through_the_lines(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = self.start(tmp, "idle")
            self.read(p, "devices")
            self.say(p, cmd="open", id="nuphy-air60-he")
            st, seen = self.read(p, "state")
            self.assertEqual(st["readonly"], "")
            self.assertTrue(st["backup"].startswith(os.path.join(tmp, "state")))
            self.assertTrue(any(e.get("what") == "backup" for e in seen))
            self.say(p, cmd="set", what="rt", keys=[29, 31], values={"actuation": 0.6, "trigger": "rapid"})
            st, _ = self.read(p, "state")
            self.assertEqual((st["keys"]["29"]["actuation"], st["keys"]["31"]["trigger"]), (0.6, "rapid"))
            self.assertEqual(self.read(p, "done")[0]["what"], "rt")
            self.say(p, cmd="pair", a=29, b=31, rule="last")
            st, _ = self.read(p, "state")
            self.assertEqual(len(st["pairs"]), 1)
            self.say(p, cmd="set", what="mode", mode=1, values={"tickRate": 2, "keyStatusUpload": True})
            st, _ = self.read(p, "state")
            self.assertEqual(st["modes"][1]["tickRate"], 2)
            self.say(p, cmd="set", what="rt", keys=[999], values={"actuation": 1})
            bad, _ = self.read(p, "failed")
            self.assertEqual((bad["what"], bad["code"]), ("rt", "range"))
            # travel reports follow the watcher: off until asked, off again after
            self.assertFalse(st["upload"])
            self.say(p, cmd="stream", on=True)
            st, _ = self.read(p, "state")
            self.assertTrue(st["upload"])
            self.say(p, cmd="restore")
            st, _ = self.read(p, "state")
            self.assertEqual((st["keys"]["29"]["actuation"], st["pairs"]), (1.5, []))

    def test_stdin_closing_ends_it(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = self.start(tmp, "idle")
            self.read(p, "devices")
            self.say(p, cmd="open", id="nuphy-air60-he")
            self.read(p, "state")
            p.stdin.close()
            self.assertEqual(p.wait(5), 0)
            p.stdin = open(os.devnull, "wb")

    def test_check_command(self):
        with tempfile.TemporaryDirectory() as tmp:
            bad = Path(tmp) / "bad.json"
            d = json.loads(AIR60.read_text())
            d["layout"]["keys"][1]["m"] = 0
            bad.write_text(json.dumps(d))
            r = subprocess.run([sys.executable, str(ROOT / "scripts/devices.py"), "check", str(AIR60), str(bad)], capture_output=True, text=True)
            self.assertEqual(r.returncode, 1)
            self.assertIn("в порядке", r.stdout)
            self.assertIn("layout.keys[1].m", r.stdout)


class Bridge(unittest.TestCase):
    """extras/usb-bridge: the service that stands between the user and the keyboard's USB node."""

    @classmethod
    def setUpClass(cls):
        import importlib.util
        spec = importlib.util.spec_from_file_location("usb_bridge", ROOT / "extras/usb-bridge/bridge.py")
        cls.b = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.b)
        from devlib import bridge as client
        cls.client = client

    def listen(self, uids=None, allow=None):
        """A bridge on a socket of our own, with the emulated keyboard behind it."""
        import socket
        import threading
        tmp = tempfile.mkdtemp()
        path = os.path.join(tmp, "b.sock")
        srv = socket.socket(socket.AF_UNIX, socket.SOCK_SEQPACKET)
        srv.bind(path)
        srv.listen(4)
        srv.settimeout(5)
        emu = emulator.NuphyEmu(air60(), "idle")
        allow = allow if allow is not None else {"19f5:fee0": {"interface": 1, "in": 0x82, "out": 0x02, "family": "nuphy-io"}}
        uids = uids if uids is not None else (lambda: {os.getuid()})

        def run():
            while True:
                try:
                    conn, _ = srv.accept()
                except OSError:
                    return
                self.b.serve(conn, allow, opener=lambda key, entry: emu.open(), uids=uids)
                conn.close()
        t = threading.Thread(target=run, daemon=True)
        t.start()
        self.addCleanup(lambda: (srv.close(), os.remove(path), os.rmdir(tmp)))
        return path, emu

    def test_a_session_through_the_bridge(self):
        path, emu = self.listen()
        s = NuphySession(air60(), self.client.BridgeChannel("19f5", "fee0", path))
        s.open()
        self.addCleanup(s.close)
        st = s.load()
        self.assertEqual(st["firmware"]["version"], "114")
        self.assertEqual(len(st["keys"]), 61)
        self.assertTrue(all(p[1] in np.READS for p in emu.sent))

    def raw(self, path):
        import socket
        c = socket.socket(socket.AF_UNIX, socket.SOCK_SEQPACKET)
        c.settimeout(3)
        c.connect(path)
        self.addCleanup(c.close)
        return c

    def test_the_filter_stands_whatever_the_client_sends(self):
        path, emu = self.listen()
        c = self.raw(path)
        c.send(b'J{"open": "19F5:FEE0"}')
        self.assertTrue(json.loads(c.recv(4096)[1:])["ok"])
        loader = bytearray(64)                      # what a firmware loader's packet looks like
        loader[0], loader[1] = 0x80, 7
        bad_sum = bytearray(np.build(np.CMD["GetInfo"]))
        bad_sum[3] ^= 1
        for packet in (np.build(np.CMD["SetFunc"], 1, 0, b"\x01"),      # the byte that enters the loader
                       np.build(np.CMD["SetFunc"], 4, 64 + 1, bytes(4)),
                       np.build(0x80, 7), np.build(0xEF), bytes(loader), bytes(bad_sum), b"\x55" * 10):
            c.send(b"P" + packet)
            note = json.loads(c.recv(4096)[1:])
            self.assertIn("refused", note, packet[:8].hex())
        self.assertEqual(emu.sent, [])
        # and what a settings page needs does pass
        c.send(b"P" + np.build(np.CMD["GetInfo"]))
        answer = c.recv(4096)
        self.assertEqual(answer[:3], b"P\xaa\x03")
        c.send(b"P" + np.build(np.CMD["SetFunc"], 4, 64 + 4, bytes((1, 0x86, 0, 3))))
        self.assertEqual(c.recv(4096)[:3], b"P\xaa\x06")
        self.assertEqual(len(emu.sent), 2)

    def test_only_the_list_and_only_the_seat(self):
        path, emu = self.listen()
        c = self.raw(path)
        c.send(b'J{"open": "046d:c52b"}')
        self.assertEqual(json.loads(c.recv(4096)[1:])["error"], "unknown")
        path, emu = self.listen(uids=lambda: {os.getuid() + 1})
        c = self.raw(path)
        c.send(b'J{"open": "19f5:fee0"}')
        self.assertEqual(json.loads(c.recv(4096)[1:])["error"], "denied")
        with self.assertRaises(usbfs.UsbError) as e:
            self.client.BridgeChannel("19f5", "fee0", path).open()
        self.assertEqual(e.exception.code, "denied")
        self.assertEqual(emu.sent, [])

    def test_the_service_holds_the_device_all_the_time(self):
        import socket
        import threading
        entry = {"interface": 1, "in": 0x82, "out": 0x02, "family": "nuphy-io"}
        emu = emulator.NuphyEmu(air60(), "press:3")         # reporting by itself, nobody asking
        plugged = {"in": True}

        def opener(key, e):
            if not plugged["in"]:
                raise usbfs.UsbError("gone", "unplugged")
            return emu.open()
        keeper = self.b.Keeper("19f5:fee0", entry, opener=opener).start()
        self.addCleanup(keeper.close)
        # no client: the keyboard's packets are read and dropped, its endpoint never fills
        deadline = time.monotonic() + 3
        while emu.out.qsize() or not keeper.channel:
            self.assertLess(time.monotonic(), deadline)
            time.sleep(0.05)
        time.sleep(0.3)
        self.assertEqual(emu.out.qsize(), 0)
        tmp = tempfile.mkdtemp()
        path = os.path.join(tmp, "b.sock")
        srv = socket.socket(socket.AF_UNIX, socket.SOCK_SEQPACKET)
        srv.bind(path)
        srv.listen(4)
        self.addCleanup(lambda: (srv.close(), os.remove(path), os.rmdir(tmp)))
        keepers = {"19f5:fee0": keeper}

        def run():
            while True:
                try:
                    conn, _ = srv.accept()
                except OSError:
                    return
                threading.Thread(target=lambda c=conn: (self.b.serve(c, {"19f5:fee0": entry}, uids=lambda: {os.getuid()}, keepers=keepers), c.close()), daemon=True).start()
        threading.Thread(target=run, daemon=True).start()
        s = NuphySession(air60(), self.client.BridgeChannel("19f5", "fee0", path))
        s.open()
        self.assertEqual(s.load()["firmware"]["version"], "114")
        # one client at a time; the second is told so
        with self.assertRaises(usbfs.UsbError) as e:
            self.client.BridgeChannel("19f5", "fee0", path).open()
        self.assertEqual(e.exception.code, "busy")
        s.close()
        time.sleep(0.2)
        # unplugged: the client goes, the keeper takes the device again once it is back
        plugged["in"] = False
        emu.close()
        keeper.channel.read = lambda *a: (_ for _ in ()).throw(usbfs.UsbError("gone", "unplugged"))
        time.sleep(0.8)
        self.assertIsNone(keeper.channel)
        with self.assertRaises(usbfs.UsbError) as e:
            self.client.BridgeChannel("19f5", "fee0", path).open()
        self.assertEqual(e.exception.code, "gone")
        del emu.read                                    # (the patch above: a fresh plug reads again)
        plugged["in"] = True
        deadline = time.monotonic() + 3
        while keeper.channel is None:
            self.assertLess(time.monotonic(), deadline)
            time.sleep(0.05)
        s = NuphySession(air60(), self.client.BridgeChannel("19f5", "fee0", path))
        s.open()
        self.addCleanup(s.close)
        self.assertEqual(s.load()["firmware"]["version"], "114")

    def test_who_sits_at_the_seat(self):
        with tempfile.TemporaryDirectory() as tmp:
            for name, text in (("1", "UID=1000\nACTIVE=1\nREMOTE=0\nCLASS=manager\n"),
                               ("3", "UID=1000\nACTIVE=1\nREMOTE=0\nCLASS=user\nSEAT=seat0\n"),
                               ("5", "UID=1001\nACTIVE=0\nREMOTE=0\nCLASS=user\nSEAT=seat0\n"),
                               ("7", "UID=1002\nACTIVE=1\nREMOTE=1\nCLASS=user\n"),
                               ("9", "UID=1003\nACTIVE=1\nREMOTE=1\nCLASS=user\nSEAT=seat0\n"),
                               ("c1", "UID=1004\nACTIVE=1\nREMOTE=0\nCLASS=user\nSEAT=seat0\n")):
                (Path(tmp) / name).write_text(text)
            self.assertEqual(self.b.seated_uids(tmp), {1000})
        self.assertEqual(self.b.seated_uids("/nonexistent"), set())

    def test_the_list_is_roots_and_whole(self):
        good = {"vid": "19f5", "pid": "FEE0", "interface": 1, "in": 130, "out": 2, "family": "nuphy-io"}
        junk = [dict(good, family="no-such"), dict(good, **{"in": 2}), dict(good, out=130), dict(good, interface=99), {"vid": "zz"}, 7]
        self.assertEqual(list(self.b.parse_allow({"devices": [good] + junk})), ["19f5:fee0"])
        with tempfile.NamedTemporaryFile("w", suffix=".json") as f:
            json.dump({"devices": [good]}, f)
            f.flush()
            # a list that is not root's own file is not believed
            self.assertEqual(self.b.load_allow(f.name), {} if os.getuid() else self.b.load_allow(f.name))

    def test_install_into_a_made_up_root(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = dict(os.environ, ANGELOS_SYSROOT=tmp)
            sh = str(ROOT / "extras/usb-bridge/install.sh")
            run = lambda *a: subprocess.run(["sh", sh, *a], env=env, capture_output=True, text=True)
            self.assertEqual(run("--status").stdout.strip(), "missing")
            r = run()
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertEqual(run("--status").stdout.strip(), "ok")
            allow = json.loads((Path(tmp) / "etc/angelos/usb-bridge.json").read_text())
            self.assertEqual(self.b.parse_allow(allow), {"19f5:fee0": {"interface": 1, "in": 0x82, "out": 0x02, "family": "nuphy-io"}})
            rule = (Path(tmp) / "etc/udev/rules.d/70-angelos-usb-bridge.rules").read_text()
            self.assertIn('ATTR{idVendor}=="19f5", ATTR{idProduct}=="fee0", GROUP="angelos-usb"', rule)
            for word in ("0666", "uaccess", 'MODE='):
                self.assertNotIn(word, rule)
            # what the bridge runs from is a copy of the very modules the tests above test
            for name in ("usbfs.py", "nuphy_io.py"):
                self.assertEqual((Path(tmp) / "usr/local/libexec/angelos-usb/devlib" / name).read_bytes(), (ROOT / "scripts/devlib" / name).read_bytes())
            (Path(tmp) / "usr/local/libexec/angelos-usb/bridge.py").write_text("# old\n")
            self.assertEqual(run("--status").stdout.strip(), "old")
            run("--remove")
            self.assertEqual(run("--status").stdout.strip(), "missing")


if __name__ == "__main__":
    unittest.main(verbosity=1)
