#!/usr/bin/env python3
"""extras/sddm/angelos/xsetup.py with a stand-in xrandr: the main screen picked in angelOS is
found by its monitor's EDID name (X's output names are not niri's), made X's primary, and the
pointer goes to its middle; with nothing picked, or the screen not there, nothing is done."""
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def edid(name, serial=""):
    e = bytearray(128)
    e[0:8] = b"\x00\xff\xff\xff\xff\xff\xff\x00"
    for at, tag, text in ((54, 0xFC, name), (72, 0xFF, serial)):
        if text:
            e[at:at + 5] = bytes((0, 0, 0, tag, 0))
            e[at + 5:at + 18] = (text.encode() + b"\n" + b" " * 13)[:13]
    return bytes(e).hex()


def verbose(primary_x="HDMI-0"):
    out = ["Screen 0: minimum 8 x 8, current 3000 x 1920, maximum 32767 x 32767"]
    for name, geo, model in (("DP-0", "1920x1080+0+0", "Mi Monitor"), ("HDMI-0", "1080x1920+1920+0", "AF24H1")):
        out.append("%s connected%s %s (0x1b8) normal (normal left inverted right x axis y axis) 527mm x 296mm" % (name, " primary" if name == primary_x else "", geo))
        out.append("\tIdentifier: 0x1b8")
        out.append("\tEDID: ")
        hx = edid(model)
        out += ["\t\t" + hx[i:i + 32] for i in range(0, 256, 32)]
        out.append("\tBorderDimensions: 4")
        out.append("  1920x1080 (0x1c2) 148.500MHz +HSync +VSync *current +preferred")
    out.append("DP-1 disconnected (normal left inverted right x axis y axis)")
    return "\n".join(out) + "\n"


class Xsetup(unittest.TestCase):
    def run_it(self, conf):
        tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmp)
        theme = tmp / "theme"
        (theme / "walls").mkdir(parents=True)
        shutil.copy2(ROOT / "extras/sddm/angelos/xsetup.py", theme / "xsetup.py")
        (theme / "walls/theme.conf.user").write_text("[General]\n" + "".join("%s=%s\n" % kv for kv in conf.items()))
        (tmp / "verbose.txt").write_text(verbose())
        fake = tmp / "xrandr"
        fake.write_text("#!/bin/sh\necho \"$*\" >> %s/calls\ncat %s/verbose.txt\n" % (tmp, tmp))
        fake.chmod(0o755)
        env = dict(os.environ, ANGELOS_XRANDR=str(fake), ANGELOS_XSETUP_TEST="1")
        r = subprocess.run([sys.executable, "-I", str(theme / "xsetup.py")], env=env, capture_output=True, text=True, timeout=20)
        calls = (tmp / "calls").read_text().splitlines() if (tmp / "calls").exists() else []
        return r, calls

    def test_found_by_the_monitors_name(self):
        r, calls = self.run_it({"look": "stream", "primary": "DP-1", "primaryModel": "Mi Monitor"})
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("--output DP-0 --primary", calls)
        self.assertIn("warp 960 540", r.stdout)

    def test_the_portrait_side_screen(self):
        r, calls = self.run_it({"primary": "HDMI-A-1", "primaryModel": "AF24H1"})
        self.assertIn("--output HDMI-0 --primary", calls)
        self.assertIn("warp 2460 960", r.stdout)

    def test_nothing_picked_nothing_done(self):
        r, calls = self.run_it({"look": "stream"})
        self.assertEqual((r.returncode, calls, r.stdout), (0, [], ""))

    def test_a_screen_not_there(self):
        r, calls = self.run_it({"primary": "DP-3", "primaryModel": "Other"})
        self.assertEqual(r.returncode, 0)
        self.assertFalse(any("--primary" in c for c in calls))
        self.assertNotIn("warp", r.stdout)

    def test_words_from_the_users_file_are_never_run(self):
        r, calls = self.run_it({"primary": "$(touch /tmp/aos-pwned);DP-0", "primaryModel": "`id`"})
        self.assertFalse(any("--primary" in c for c in calls))
        self.assertFalse(os.path.exists("/tmp/aos-pwned"))


if __name__ == "__main__":
    unittest.main(verbosity=1)
