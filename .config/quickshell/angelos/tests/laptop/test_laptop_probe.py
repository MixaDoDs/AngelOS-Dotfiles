#!/usr/bin/env python3
"""scripts/laptop.py against fake laptops (tests/laptop/fakesys.py): what it finds, what it
leaves out (a mouse's battery, a touchscreen as a touchpad), the charge limit's writes.
Run: python3 tests/laptop/test_laptop_probe.py   (scripts/check.sh runs it)"""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).parent))
import fakesys  # noqa: E402

SCRIPT = ROOT / "scripts/laptop.py"


def run(root, *args, env=None):
    e = dict(os.environ, ANGELOS_SYSFS=root + "/sys", ANGELOS_PROC=root + "/proc",
             ANGELOS_CHARGE_HELPER=root + "/no-helper", PATH="/usr/bin:/bin")
    e.update(env or {})
    p = subprocess.run([sys.executable, str(SCRIPT), *args], capture_output=True, text=True, env=e, timeout=20)
    return p.stdout.strip()


class Probe(unittest.TestCase):
    def test_thinkpad(self):
        with tempfile.TemporaryDirectory() as d:
            fakesys.build(d)
            j = json.loads(run(d, "probe"))
            self.assertTrue(j["laptop"])
            self.assertEqual(j["chassis"], "notebook")
            self.assertEqual([b["name"] for b in j["batteries"]], ["BAT0"])   # not the mouse's
            b = j["batteries"][0]
            self.assertEqual((b["cycles"], b["health"], b["limit"]), (312, 87, 100))
            self.assertEqual(j["backlights"][0]["name"], "intel_backlight")
            self.assertEqual(j["kbd"][0]["max"], 2)
            self.assertEqual(j["touchpad"], ["SynPS/2 Synaptics TouchPad"])
            self.assertEqual(j["touchscreen"], [])
            self.assertTrue(j["lid"])
            self.assertFalse(j["tabletSwitch"])
            self.assertFalse(j["rfkill"]["airplane"])

    def test_convertible(self):
        with tempfile.TemporaryDirectory() as d:
            fakesys.build(d, convertible=True)
            j = json.loads(run(d, "probe"))
            self.assertEqual(j["chassis"], "convertible")
            self.assertTrue(j["tabletSwitch"] and j["accel"])
            self.assertEqual(len(j["touchscreen"]), 1)
            self.assertEqual(len(j["touchpad"]), 1)          # the touchscreen is no touchpad

    def test_desktop(self):
        with tempfile.TemporaryDirectory() as d:
            fakesys.build(d, desktop=True)
            j = json.loads(run(d, "probe"))
            self.assertFalse(j["laptop"])
            self.assertEqual((j["batteries"], j["backlights"], j["touchpad"], j["lid"]), ([], [], [], False))

    def test_limit(self):
        with tempfile.TemporaryDirectory() as d:
            fakesys.build(d)
            self.assertEqual(run(d, "limit", "80"), "ok 80")
            self.assertEqual(Path(d, "sys/class/power_supply/BAT0/charge_control_end_threshold").read_text().strip(), "80")
            self.assertEqual(run(d, "limit", "20"), "ok 50")              # never below 50
            os.chmod(Path(d, "sys/class/power_supply/BAT0/charge_control_end_threshold"), 0o444)
            if os.geteuid() != 0:
                self.assertEqual(run(d, "limit", "80"), "nohelper")      # root-owned in real life
        with tempfile.TemporaryDirectory() as d:
            fakesys.build(d, limit=False)
            self.assertTrue(run(d, "limit", "80").startswith("error"))

    def test_rfkill(self):
        with tempfile.TemporaryDirectory() as d:
            fakesys.build(d)
            for i in (0, 1):
                Path(d, f"sys/class/rfkill/rfkill{i}/soft").write_text("1\n")
            self.assertTrue(json.loads(run(d, "rfkill"))["airplane"])


if __name__ == "__main__":
    unittest.main(verbosity=1)
