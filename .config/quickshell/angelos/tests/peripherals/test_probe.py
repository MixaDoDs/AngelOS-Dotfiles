#!/usr/bin/env python3
"""scripts/peripherals.py without a device on the desk: which hidraw interface it would talk to
(a made-up /sys), the battery report's bytes both ways, headsetcontrol's JSON, the stands'
devices file. No real device is asked: ANGELOS_SYSFS / ANGELOS_DEVFS point into a temp dir.
Run: python3 tests/peripherals/test_probe.py   (scripts/check.sh runs it)"""
import importlib.util
import json
import os
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/peripherals.py"

# the LAMZU Maya X 8K dongle's three interfaces, as the kernel reports them
MOUSE = bytes.fromhex("05010902a1010901a10005091901290515002501950575018102950175038101050109381581257f75089501810605010930093116018026ff7f751095028106050c0a38021581257f750895018106050c090915002501750895018106c0c0")
KEYS = bytes.fromhex("050c0901a101850119002a3c021500263c02751095018100c005010980a1018502198129831500250195037501810295058101c005010906a1018503050719e029e71500250175019508810295017508810195057501050819012905910295017503910195067508150026ff000507190029df8100c006a0ff0901a10185040902150026ff00950875088102c006ffff0901a10185050901150026ff00950875088102c0")
VENDOR = bytes.fromhex("06ffff0900a10109001500250175089540b102c0")


def load(env=None):
    old = dict(os.environ)
    os.environ.update(env or {})
    try:
        spec = importlib.util.spec_from_file_location("peripherals", SCRIPT)
        m = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(m)
        return m
    finally:
        os.environ.clear()
        os.environ.update(old)


def fake_sys(root, nodes):
    """nodes: [(name, "VVVV:PPPP", HID name, descriptor)]"""
    for name, ids, hid_name, desc in nodes:
        d = Path(root) / "sys/class/hidraw" / name / "device"
        d.mkdir(parents=True)
        v, p = ids.split(":")
        (d / "uevent").write_text("DRIVER=hid-generic\nHID_ID=0003:0000%s:0000%s\nHID_NAME=%s\n" % (v, p, hid_name))
        (d / "report_descriptor").write_bytes(desc)


class Probe(unittest.TestCase):
    def test_vendor_interface_only(self):
        p = load()
        self.assertTrue(p.vendor_feature_interface(VENDOR))
        self.assertFalse(p.vendor_feature_interface(MOUSE), "the mouse's own interface is never written to")
        self.assertFalse(p.vendor_feature_interface(KEYS), "an interface with report ids is another protocol")
        self.assertFalse(p.vendor_feature_interface(b""))
        self.assertFalse(p.vendor_feature_interface(bytes.fromhex("06ffff0900a10109001500250175089520b102c0")), "32 bytes: not this report")

    def test_nodes(self):
        with tempfile.TemporaryDirectory() as t:
            fake_sys(t, [("hidraw0", "19F5:FEE0", "NuPhy NuPhy Air60 HE", VENDOR),
                         ("hidraw3", "373E:001E", "LAMZU LAMZU Maya X 8K Dongle", MOUSE),
                         ("hidraw4", "373E:001E", "LAMZU LAMZU Maya X 8K Dongle", KEYS),
                         ("hidraw5", "373E:001E", "LAMZU LAMZU Maya X 8K Dongle", VENDOR)])
            p = load({"ANGELOS_SYSFS": t + "/sys", "ANGELOS_DEVFS": t + "/dev"})
            self.assertEqual(p.lamzu_nodes(), [(t + "/dev/hidraw5", "LAMZU Maya X")])
            # no such node in the made-up /dev: nothing read, nothing listed
            self.assertEqual(p.vendor_devices(), [])

    def test_closed_node_is_denied_not_silent(self):
        if os.geteuid() == 0:
            self.skipTest("root opens everything")
        with tempfile.TemporaryDirectory() as t:
            fake_sys(t, [("hidraw5", "373E:001E", "LAMZU LAMZU Maya X 8K Dongle", VENDOR)])
            Path(t, "dev").mkdir()
            node = Path(t, "dev/hidraw5")
            node.write_bytes(b"")
            node.chmod(0)
            p = load({"ANGELOS_SYSFS": t + "/sys", "ANGELOS_DEVFS": t + "/dev"})
            self.assertEqual(p.poll(headset=False), {"devices": [], "tools": p.poll(headset=False)["tools"], "denied": 1})
            self.assertFalse(p.SILENT, "a closed door is not a sleeping mouse: no half-minute polling")

    def test_query_and_answer(self):
        p = load()
        q = p.aurora_battery_query()
        self.assertEqual(len(q), 65)
        self.assertEqual(bytes(q[:8]), bytes([0, 0, 0, 2, 2, 0, 0x83, 0]))
        self.assertFalse(any(q[8:]))
        answer = bytes.fromhex("00a100020200830029") + bytes(56)
        self.assertEqual(p.aurora_battery_parse(answer), (41, False, False))
        self.assertEqual(p.aurora_battery_parse(bytes.fromhex("00a100020200830150") + bytes(56)), (80, True, False))
        self.assertEqual(p.aurora_battery_parse(bytes.fromhex("00a100020200830264") + bytes(56)), (100, False, True))
        for bad in (bytes(65), b"", bytes.fromhex("00a100020200830000") + bytes(56), bytes.fromhex("00a1000202008300c8") + bytes(56),
                    bytes.fromhex("00a100020200800029") + bytes(56)):
            self.assertIsNone(p.aurora_battery_parse(bad))

    def test_names(self):
        p = load()
        self.assertEqual(p.clean_name("LAMZU LAMZU Maya X 8K Dongle"), "LAMZU Maya X")
        self.assertEqual(p.clean_name("Logitech USB Receiver"), "Logitech")
        self.assertEqual(p.clean_name(""), "?")

    def test_headsetcontrol(self):
        p = load()
        text = json.dumps({"devices": [
            {"status": "success", "device": "SteelSeries Arctis Nova 7", "id_vendor": "0x1038", "id_product": "0x2202",
             "battery": {"status": "BATTERY_AVAILABLE", "level": 85}},
            {"status": "success", "device": "Corsair Void", "id_vendor": "0x1b1c", "id_product": "0x0a14",
             "battery": {"status": "BATTERY_CHARGING", "level": 100}},
            {"status": "success", "device": "Asleep", "battery": {"status": "BATTERY_UNAVAILABLE", "level": -1}}]})
        got = p.headset_parse(text)
        self.assertEqual([(d["id"], d["percent"], d["charging"], d["full"]) for d in got],
                         [("headset:1038:2202", 85, False, False), ("headset:1b1c:0a14", 100, True, True)])
        self.assertEqual(p.headset_parse("not json"), [])

    def test_fake_file(self):
        with tempfile.TemporaryDirectory() as t:
            f = Path(t) / "devices.json"
            f.write_text(json.dumps({"devices": [{"name": "Mouse", "kind": "mouse", "percent": 150},
                                                 {"name": "Thing", "kind": "toaster", "percent": 7, "charging": True}]}))
            env = dict(os.environ, ANGELOS_PERIPHERALS_FAKE=str(f), ANGELOS_SYSFS=t + "/sys", ANGELOS_DEVFS=t + "/dev")
            out = subprocess.run([sys.executable, str(SCRIPT)], capture_output=True, text=True, env=env, timeout=20).stdout
            devs = json.loads(out)["devices"]
            self.assertEqual([(d["id"], d["kind"], d["percent"], d["charging"]) for d in devs],
                             [("fake:mouse", "mouse", 100, False), ("fake:thing", "other", 7, True)])

    def test_watch_ends_with_stdin(self):
        with tempfile.TemporaryDirectory() as t:
            f = Path(t) / "devices.json"
            f.write_text("[]")
            env = dict(os.environ, ANGELOS_PERIPHERALS_FAKE=str(f))
            p = subprocess.Popen([sys.executable, "-u", str(SCRIPT), "--watch", "600"], stdin=subprocess.PIPE,
                                 stdout=subprocess.PIPE, text=True, env=env)
            self.assertEqual(json.loads(p.stdout.readline())["devices"], [])
            f.write_text(json.dumps([{"name": "Pad", "kind": "gamepad", "percent": 60}]))
            p.stdin.write("poll\n")
            p.stdin.flush()
            self.assertEqual(json.loads(p.stdout.readline())["devices"][0]["kind"], "gamepad")
            p.stdin.close()
            self.assertEqual(p.wait(timeout=10), 0)
            p.stdout.close()


ACCESS = ROOT / "extras/hid-access"


class Access(unittest.TestCase):
    """extras/hid-access: the udev rule that lets the user at the seat ask the dongles."""

    def helper(self, descriptor):
        with tempfile.TemporaryDirectory() as t:
            fake_sys(t, [("hidraw0", "373E:001E", "x", descriptor)])
            return subprocess.run(["sh", str(ACCESS / "angelos-hid-feature-only"), t + "/sys/class/hidraw/hidraw0"]).returncode == 0

    def test_helper_passes_only_the_interface_without_input(self):
        self.assertTrue(self.helper(VENDOR))
        self.assertFalse(self.helper(MOUSE), "the mouse's interface stays root's")
        self.assertFalse(self.helper(KEYS), "the keyboard's interface stays root's")
        self.assertFalse(self.helper(b""))
        self.assertNotEqual(subprocess.run(["sh", str(ACCESS / "angelos-hid-feature-only"), "/nonexistent"]).returncode, 0)
        self.assertNotEqual(subprocess.run(["sh", str(ACCESS / "angelos-hid-feature-only")]).returncode, 0)

    def test_helper_and_script_agree(self):
        """udev's gate and the script's own test are two programs: the same verdict on the real
        descriptors cut, patched and grown, and on noise (a made-up device chooses its bytes)."""
        import random
        rnd = random.Random(373)
        p = load()
        cases = []
        for base in (VENDOR, MOUSE, KEYS):
            cases += [base[:n] for n in range(0, len(base) + 1, 3)]
            for _ in range(40):
                d = bytearray(base)
                for _ in range(rnd.randint(1, 3)):
                    d[rnd.randrange(len(d))] = rnd.choice((0x81, 0x91, 0xB1, 0x85, 0x75, 0x95, 0xFE, 0x06, 0xFF, 0x08, 0x40, rnd.randrange(256)))
                cases.append(bytes(d))
        cases += [VENDOR + bytes([0x81, 0x02]), VENDOR + bytes([0xFE]), VENDOR + bytes([0xFE, 0x02, 0x00, 0x81, 0x02]),
                  bytes.fromhex("06ffff0900a10109001500250175109520b102c0"), bytes.fromhex("06ffff0900a1010900150025017508964000b102c0"),
                  bytes.fromhex("06ffff0900a101090015002501750896400081b102c0")]
        cases += [bytes(rnd.randrange(256) for _ in range(rnd.randint(1, 80))) for _ in range(60)]
        cases += [bytes([0x06, rnd.randrange(256), 0xFF]) + bytes(rnd.randrange(256) for _ in range(rnd.randint(3, 60))) for _ in range(60)]
        yes = 0
        for d in cases:
            want = p.vendor_feature_interface(d)
            yes += want
            self.assertEqual(self.helper(d), want, d.hex())
        self.assertGreater(yes, 3, "the cases must reach the yes branch too")

    def test_rule_opens_no_more_than_it_says(self):
        p = load()
        text = (ACCESS / "70-angelos-peripherals.rules").read_text()
        rules = [line for line in text.splitlines() if line.strip() and not line.startswith("#")]
        vendors = set()
        for r in rules:
            m = re.search(r'ATTRS\{idVendor\}=="([0-9a-f]{4})"', r)
            self.assertTrue(m, r)
            vendors.add(m.group(1).upper())
            self.assertIn('SUBSYSTEM=="hidraw"', r)
            self.assertIn('PROGRAM=="/usr/local/libexec/angelos-hid-feature-only %S%p"', r, "no node without the helper's yes")
            self.assertIn('TAG+="uaccess"', r)
            self.assertLess(r.index("PROGRAM=="), r.index("TAG+="), "the tag only after the checks")
            for wide in ("MODE", "GROUP", "OWNER", "RUN", "udev-acl"):
                self.assertNotIn(wide, r, "only logind's ACL for the user at the seat")
        self.assertEqual(vendors, set(p.LAMZU_VENDORS), "the rule's makers are the script's")
        # 73-seat-late.rules turns the tag into the ACL: the file must sort before it
        self.assertLess(int(re.match(r"\d+", "70-angelos-peripherals.rules").group()), 73)

    def test_installer(self):
        with tempfile.TemporaryDirectory() as t:
            env = dict(os.environ, ANGELOS_SYSROOT=t)
            run = lambda *a: subprocess.run(["sh", str(ACCESS / "install.sh"), *a], capture_output=True, text=True, env=env)
            self.assertEqual(run("--status").stdout.strip(), "missing")
            self.assertEqual(run().returncode, 0)
            helper = Path(t, "usr/local/libexec/angelos-hid-feature-only")
            rule = Path(t, "etc/udev/rules.d/70-angelos-peripherals.rules")
            self.assertTrue(os.access(helper, os.X_OK))
            self.assertEqual(rule.read_bytes(), (ACCESS / "70-angelos-peripherals.rules").read_bytes())
            self.assertEqual(rule.stat().st_mode & 0o777, 0o644)
            self.assertEqual(helper.stat().st_mode & 0o777, 0o755)
            self.assertEqual(run("--status").stdout.strip(), "ok")
            rule.write_text("# an older one\n")
            self.assertEqual(run("--status").stdout.strip(), "old")
            self.assertEqual(run().returncode, 0)
            self.assertEqual(run("--status").stdout.strip(), "ok")
            self.assertEqual(run("--remove").returncode, 0)
            self.assertFalse(helper.exists() or rule.exists())

    @unittest.skipIf(os.geteuid() == 0, "root")
    def test_installer_wants_root_for_the_real_system(self):
        env = {k: v for k, v in os.environ.items() if k != "ANGELOS_SYSROOT"}
        r = subprocess.run(["sh", str(ACCESS / "install.sh")], capture_output=True, text=True, env=env)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("root", r.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
