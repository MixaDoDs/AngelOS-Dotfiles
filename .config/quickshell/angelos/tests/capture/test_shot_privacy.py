"""Verify that detection passes only geometry and that copying flattens it into the PNG."""
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from PIL import Image, ImageDraw, ImageFont

SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "shot_privacy.py"


class ShotPrivacyTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="shot-privacy-test-")
        self.addCleanup(temp.cleanup)
        self.dir = Path(temp.name)
        self.shot = self.dir / "shot.png"
        self.clip = self.dir / "clipboard.png"
        binder = self.dir / "wl-copy"
        binder.write_text('#!/bin/sh\n[ "$1" = --type ] && [ "$2" = image/png ] && cat > "$SHOT_TEST_CLIP"\n')
        binder.chmod(0o700)
        self.env = dict(os.environ, PATH=f'{self.dir}:{os.environ["PATH"]}', SHOT_TEST_CLIP=str(self.clip))

    def invoke(self, *args):
        return subprocess.run([sys.executable, str(SCRIPT), *args], env=self.env,
                              capture_output=True, check=False, timeout=20)

    @unittest.skipUnless(shutil.which("tesseract"), "Tesseract missing")
    def test_scans_real_text_and_returns_only_regions(self):
        page = Image.new("RGB", (960, 360), "#1b1b20")
        draw = ImageDraw.Draw(page)
        font = ImageFont.truetype("DejaVuSansMono.ttf", 32)
        draw.text((25, 25), "hello@example.test", "white", font=font)
        draw.text((25, 95), "+1 (202) 555-0147", "white", font=font)
        # split: the publish check (owner/checks.sh) must not see a token in the source
        draw.text((25, 165), "ghp_" + "1234567890ABCDE1234567890ABCDE123456", "white", font=font)
        draw.text((25, 235), "4111 1111 1111 1111", "white", font=font)
        draw.text((25, 305), "Build 2026-11-20", "white", font=font)
        page.save(self.shot)

        result = self.invoke("scan", str(self.shot))
        self.assertEqual(result.returncode, 0, result.stderr)
        found = json.loads(result.stdout)
        self.assertEqual((found["width"], found["height"]), (960, 360))
        self.assertEqual(len(found["boxes"]), 4, found)
        boxes = sorted(found["boxes"], key=lambda b: b["y"])
        for box, line_y in zip(boxes, (42, 112, 182, 252)):
            self.assertEqual(set(box), {"x", "y", "w", "h"})
            self.assertLessEqual(box["y"], line_y)
            self.assertGreater(box["y"] + box["h"], line_y)
        self.assertFalse(self.clip.exists())

    @unittest.skipUnless(shutil.which("tesseract"), "Tesseract missing")
    def test_masks_truncated_email_and_leaves_standalone_mentions(self):
        page = Image.new("RGB", (672, 265), "white")
        draw = ImageDraw.Draw(page)
        font = ImageFont.truetype("DejaVuSans.ttf", 22)
        draw.text((44, 36), "preview.account@gmail…", "#333333", font=font)
        draw.text((44, 106), "second.account@outlook", "#333333", font=font)
        draw.text((44, 176), "Ping @handle", "#333333", font=font)
        page.save(self.shot)

        result = self.invoke("scan", str(self.shot))
        self.assertEqual(result.returncode, 0, result.stderr)
        boxes = sorted(json.loads(result.stdout)["boxes"], key=lambda b: b["y"])
        self.assertEqual(len(boxes), 2, boxes)
        for box, line_y in zip(boxes, (47, 117)):
            self.assertLessEqual(box["x"], 46)
            self.assertGreater(box["x"] + box["w"], 270)
            self.assertLessEqual(box["y"], line_y)
            self.assertGreater(box["y"] + box["h"], line_y)

    def test_copies_opaque_pixels_and_keeps_the_source(self):
        source = Image.new("RGBA", (20, 14), (220, 100, 40, 80))
        source.save(self.shot)
        original = self.shot.read_bytes()
        boxes = [{"x": 3, "y": 4, "w": 8, "h": 5}, {"x": 17, "y": 12, "w": 10, "h": 5}]

        result = self.invoke("copy", str(self.shot), json.dumps(boxes))
        self.assertEqual(result.returncode, 0, result.stderr)
        with Image.open(io.BytesIO(self.clip.read_bytes())) as masked:
            masked = masked.convert("RGBA")
        self.assertEqual(masked.getpixel((3, 4)), (17, 17, 17, 255))
        self.assertEqual(masked.getpixel((10, 8)), (17, 17, 17, 255))
        self.assertEqual(masked.getpixel((19, 13)), (17, 17, 17, 255))
        self.assertEqual(masked.getpixel((11, 9)), (220, 100, 40, 80))
        self.assertEqual(self.shot.read_bytes(), original)

    def test_empty_and_invalid_masks_never_copy_the_source(self):
        Image.new("RGB", (20, 14), "white").save(self.shot)
        for boxes in ([], [{"x": 50, "y": 50, "w": 2, "h": 2}],
                      [{"x": 3, "y": 3, "w": 3, "h": 3}, {"x": 8, "y": 3, "w": -3, "h": 3}]):
            with self.subTest(boxes=boxes):
                result = self.invoke("copy", str(self.shot), json.dumps(boxes))
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.clip.exists())


if __name__ == "__main__":
    unittest.main()
