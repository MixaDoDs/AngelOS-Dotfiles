#!/usr/bin/env python3
"""scripts/wall-pixelate.py — any wallpaper redrawn in big pixels, a copy per screen
(services/Wallpapers: pixel). Made-up pictures in a throw-away folder.

  python3 tests/settings/test_wall_pixelate.py    exit 0 = all good, 77 = skipped (no numpy / Pillow)

  screen     the copy is exactly the screen's pixels, every art pixel a whole square of `block`
             (a wide picture on a tall screen is cut to the screen's shape first)
  palette    no more colours than asked for, all of them the picture's own (no new hues)
  dither     0: flat patches — a smooth gradient becomes bands; more: the bands' edges mix,
             a hard edge between two far colours never does
  art        pixel art is left as it is (the answer's file is the picture itself)
  small      a picture with fewer pixels than the art is only enlarged without smoothing
  gif        a GIF that moves is left as it is
  cache      asked again: the same file, not made again; another number: another file; the
             original is never written to; old copies of one picture for one screen are dropped
  broken     a file that is no picture: an error and the file itself, exit 1
"""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

try:
    import numpy as np
    from PIL import Image
except ImportError:
    print("SKIP: numpy / Pillow are not installed")
    sys.exit(77)

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/wall-pixelate.py"
spec = importlib.util.spec_from_file_location("wall_pixelate", SCRIPT)
wp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wp)


def photo(w, h, seed=3):
    """a smooth picture with a hard edge: a sky's gradient over a dark hill, a red sun"""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    a = np.zeros((h, w, 3), np.float32)
    a[..., 0] = 0.20 + 0.35 * yy / h
    a[..., 1] = 0.30 + 0.25 * yy / h
    a[..., 2] = 0.80 - 0.25 * yy / h
    hill = yy > h * (0.72 + 0.08 * np.sin(xx / w * 6.0))
    a[hill] = (0.05, 0.07, 0.06)
    sun = (xx - w * 0.7) ** 2 + (yy - h * 0.3) ** 2 < (h * 0.08) ** 2
    a[sun] = (0.95, 0.25, 0.15)
    rng = np.random.default_rng(seed)
    a += rng.normal(0, 0.004, a.shape).astype(np.float32)
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))


def opened(path):
    with Image.open(path) as im:
        im.load()
        return im.copy()


def blocks(img, block):
    """the copy as its art pixels, or None when a square of `block` is not one colour"""
    a = np.asarray(img.convert("RGB"))
    h, w, _ = a.shape
    if h % block or w % block:
        return None
    b = a.reshape(h // block, block, w // block, block, 3)
    if (b != b[:, :1, :, :1]).any():
        return None
    return b[:, 0, :, 0]


class Pixelate(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.dir = Path(cls.tmp.name)
        cls.cache = cls.dir / "cache"
        cls.pic = cls.dir / "photo.png"
        photo(1600, 900).save(cls.pic)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def run_script(self, pic, *args, cache=None):
        r = subprocess.run([sys.executable, str(SCRIPT), str(pic), "--cache", str(cache or self.cache), *args],
                           capture_output=True, text=True, timeout=120)
        return r.returncode, json.loads(r.stdout.strip().splitlines()[-1])

    def test_screen(self):
        for screen, size, art, block in (("1920x1080", 4, [480, 270], 4), ("1080x1920", 4, [270, 480], 4),
                                         ("2560x1440", 6, [320, 180], 8), ("1366x768", 4, [456, 256], 3)):
            rc, j = self.run_script(self.pic, "--screen", screen, "--size", str(size))
            self.assertEqual(rc, 0, j)
            self.assertEqual((j["art"], j["block"]), (art, block), screen)
            im = opened(j["out"])
            self.assertEqual("%dx%d" % im.size, screen)
            if im.width % block == 0 and im.height % block == 0:
                self.assertIsNotNone(blocks(im, block), f"{screen}: an art pixel is not a whole square")
        # a tall screen shows the middle of a wide picture: the sun (right of the middle) is cut off
        rc, j = self.run_script(self.pic, "--screen", "1080x1920")
        a = np.asarray(opened(j["out"]).convert("RGB")).astype(int)
        self.assertFalse(((a[..., 0] > 200) & (a[..., 2] < 90)).any(), "the picture was squeezed, not cut")

    def test_palette(self):
        src = np.asarray(opened(self.pic).convert("RGB")).astype(int)
        for n in (8, 16, 32):
            rc, j = self.run_script(self.pic, "--colors", str(n))
            a = blocks(opened(j["out"]), j["block"])
            cols = np.unique(a.reshape(-1, 3), axis=0)
            self.assertLessEqual(len(cols), n)
            self.assertEqual(j["colors"], len(cols))
            self.assertGreaterEqual(len(cols), n // 2, "most of the palette is used")
            # every colour is near one the picture has (nothing invented: no green in this picture)
            self.assertFalse(((cols[:, 1] > cols[:, 0] + 40) & (cols[:, 1] > cols[:, 2] + 40)).any())
        self.assertTrue(((src[..., 0] > 200) & (src[..., 2] < 90)).any())
        rc, j = self.run_script(self.pic, "--colors", "16")
        a = blocks(opened(j["out"]), j["block"]).astype(int)
        self.assertTrue(((a[..., 0] > 180) & (a[..., 2] < 110)).any(), "the small red sun kept a colour of its own")

    def test_dither(self):
        def mixes(dither):
            rc, j = self.run_script(self.pic, "--colors", "8", "--dither", str(dither))
            a = blocks(opened(j["out"]), j["block"]).astype(int)
            # a checker: a cell that differs from all four neighbours, which agree with each other
            c = a[1:-1, 1:-1]
            n = (a[:-2, 1:-1], a[2:, 1:-1], a[1:-1, :-2], a[1:-1, 2:])
            lone = np.ones(c.shape[:2], bool)
            for q in n:
                lone &= (q != c).any(2)
            lone &= (n[0] == n[1]).all(2) & (n[2] == n[3]).all(2) & (n[0] == n[2]).all(2)
            # near colours: the dither's checker; far ones: the picture's own lone pixels (a
            # hill's tip against the sky)
            d = np.abs(c - n[0]).max(2)
            return int((lone & (d < 70)).sum()), int((lone & (d >= 70)).sum())
        flat, own = mixes(0)
        some, far = mixes(100)
        self.assertEqual(flat, 0, "no dither asked, a checker drawn")
        self.assertGreater(some, 200, "a smooth sky in 8 colours and no dither")
        # the hill (near black) against the sky, the sun against it: never mixed
        self.assertEqual(far, own, "two far colours were dithered into each other")

    def test_pixel_art(self):
        small = photo(240, 135).quantize(16).convert("RGB")
        art = self.dir / "art.png"
        small.resize((1920, 1080), Image.Resampling.NEAREST).save(art)
        before = art.read_bytes()
        rc, j = self.run_script(art)
        self.assertEqual((rc, j.get("skip"), j["out"]), (0, "art", str(art)))
        self.assertEqual(j["grid"], 8)
        self.assertEqual(art.read_bytes(), before)

    def test_small(self):
        p = self.dir / "small.png"
        photo(320, 180).save(p)
        rc, j = self.run_script(p, "--size", "4")
        self.assertEqual(rc, 0)
        self.assertTrue(j.get("small"))
        im = opened(j["out"])
        self.assertEqual(im.size, (1920, 1080))
        self.assertIsNotNone(blocks(im, 6), "320 → 1920: every pixel a square of 6")

    def test_gif(self):
        p = self.dir / "moves.gif"
        a, b = photo(200, 120, 1), photo(200, 120, 2).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        a.save(p, save_all=True, append_images=[b], duration=100, loop=0)
        rc, j = self.run_script(p)
        self.assertEqual((rc, j.get("skip"), j["out"]), (0, "animated", str(p)))

    def test_cache(self):
        cache = self.dir / "cache2"
        before = self.pic.read_bytes()
        rc, a = self.run_script(self.pic, cache=cache)
        t = os.stat(a["out"]).st_mtime_ns
        rc, b = self.run_script(self.pic, cache=cache)
        self.assertEqual(a["out"], b["out"])
        self.assertEqual(os.stat(b["out"]).st_mtime_ns, t, "made again instead of read from the cache")
        outs = {a["out"]}
        for size in (2, 3, 5, 6, 8):
            rc, c = self.run_script(self.pic, "--size", str(size), cache=cache)
            self.assertNotIn(c["out"], outs)
            outs.add(c["out"])
        left = sorted(cache.glob("*.png"))
        self.assertLessEqual(len(left), 3, "old copies pile up: " + str(len(left)))
        self.assertTrue(os.path.exists(c["out"]), "the newest copy was dropped")
        self.assertEqual(self.pic.read_bytes(), before, "the original was written to")
        # another screen has copies of its own: they are not what is dropped
        rc, d = self.run_script(self.pic, "--screen", "1080x1920", cache=cache)
        self.assertTrue(os.path.exists(c["out"]) and os.path.exists(d["out"]))
        # the picture changed: a new copy
        photo(1600, 900, 9).save(self.dir / "changing.png")
        rc, e = self.run_script(self.dir / "changing.png", cache=cache)
        photo(1600, 900, 10).rotate(180).save(self.dir / "changing.png")
        rc, f = self.run_script(self.dir / "changing.png", cache=cache)
        self.assertNotEqual(e["out"], f["out"])

    def test_broken(self):
        p = self.dir / "not-a-picture.png"
        p.write_text("no")
        rc, j = self.run_script(p)
        self.assertEqual(rc, 1)
        self.assertIn("error", j)
        self.assertEqual(j["out"], str(p))
        rc, j = self.run_script(self.dir / "nothing.png")
        self.assertEqual(rc, 1)
        self.assertIn("error", j)

    def test_plan(self):
        self.assertEqual(wp.plan((1920, 1080), 4), (480, 270, 4))
        self.assertEqual(wp.plan((3840, 2160), 4), (480, 270, 8))
        self.assertEqual(wp.plan((1080, 1920), 12), (90, 160, 12))
        self.assertEqual(wp.plan((1366, 768), 4), (456, 256, 3))


if __name__ == "__main__":
    unittest.main(verbosity=1)
