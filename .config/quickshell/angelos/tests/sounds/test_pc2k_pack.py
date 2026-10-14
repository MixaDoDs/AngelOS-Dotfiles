#!/usr/bin/env python3
"""data/sounds/pc2k («Нулевые»): every ordinary event has its file, each one decodes, is heard
and doesn't clip, and every recording in src/ has its source in SOURCES.md."""
import re
import subprocess
import unittest
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / "data/sounds/pc2k"
# the story's sounds and the effects stay Y2K's (services/Sounds.qml: effects, "angel", "demon")
STORY = {"angel", "demon", "crack", "choir", "rocks", "shatter", "voice", "bark", "circle", "circleSoft",
         "circleSin", "harp", "webSnap", "webSwipe", "webClear"}


def events():
    qml = (ROOT / "services/Sounds.qml").read_text()
    return re.findall(r'"(\w+)"', re.search(r"readonly property var events: \[([^\]]*)\]", qml).group(1))


def pcm(path):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(path), "-f", "s16le", "-ac", "1", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype="<i2").astype(float) / 32768


class Pc2kPack(unittest.TestCase):
    def test_every_ordinary_event_has_a_sound(self):
        want = [e for e in events() if e not in STORY] + ["key2", "key3"]
        missing = [e for e in want if not (PACK / (e + ".ogg")).exists()]
        self.assertEqual(missing, [])

    def test_heard_and_not_clipping(self):
        for f in sorted(PACK.glob("*.ogg")):
            x = pcm(f)              # quiet ones (ticks, prizes) are capped by RMS, below -6
            peak = 20 * np.log10(np.max(np.abs(x)) or 1e-9)
            self.assertTrue(-24 < peak < -3, "%s peaks at %.1f dBFS" % (f.name, peak))

    def test_every_recording_has_its_source(self):
        sources = (PACK / "SOURCES.md").read_text()
        for f in (PACK / "src").glob("*.ogg"):
            stem = re.sub(r"-\d$", "", f.stem)
            self.assertTrue(f.name in sources or stem + "-1/2/3.ogg" in sources, f.name)


if __name__ == "__main__":
    unittest.main()
