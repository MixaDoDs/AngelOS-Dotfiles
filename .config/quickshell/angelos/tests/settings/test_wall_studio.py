#!/usr/bin/env python3
"""scripts/wall-studio.py: a picture → a scene scripts/scene-list.py finds.

  python3 tests/settings/test_wall_studio.py    exit 0 = all good, 77 = skipped (no numpy / Pillow)
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
try:
    import numpy as np
    from PIL import Image
except ImportError:
    sys.exit(77)


def run(*args):
    return subprocess.run([sys.executable, str(ROOT / "scripts/wall-studio.py"), *args], capture_output=True, text=True)


with tempfile.TemporaryDirectory() as d:
    d = Path(d)
    rng = np.random.default_rng(1)
    art = rng.integers(0, 6, (120, 200, 1), dtype=np.uint8) * 40
    art = np.repeat(art, 3, axis=2)
    Image.fromarray(art).resize((800, 480), Image.NEAREST).save(d / "art x4.png")
    Image.fromarray(art).save(d / "native.png")
    photo = rng.integers(0, 255, (720, 1280, 3), dtype=np.uint8)
    Image.fromarray(photo).save(d / "photo.png")
    (d / "broken.png").write_text("no picture")

    info = json.loads(run("inspect", str(d / "art x4.png")).stdout)
    assert info["scale"] == 4 and info["art"] == [200, 120], info
    assert json.loads(run("inspect", str(d / "native.png")).stdout)["art"] == [200, 120]
    assert json.loads(run("inspect", str(d / "photo.png")).stdout)["art"] is None
    assert run("inspect", str(d / "broken.png")).returncode == 2

    out = d / "out"
    made = Path(run("new", str(d / "art x4.png"), str(out), "--mode", "art").stdout.strip())
    assert Image.open(made / "logical/background.png").size == (200, 120)
    assert np.array_equal(np.asarray(Image.open(made / "logical/background.png").convert("RGB")), art)
    pix = Path(run("new", str(d / "photo.png"), str(out), "--mode", "pixel").stdout.strip())
    assert Image.open(pix / "logical/background.png").size == (656, 376)
    assert len(Image.open(pix / "logical/background.png").convert("RGB").getcolors(4096)) <= 64
    keep = Path(run("new", str(d / "photo.png"), str(out), "--mode", "keep", "--screen", "1280x720").stdout.strip())
    assert Image.open(keep / "logical/background.png").size == (1296, 736)
    assert keep.name == "photo-2", keep
    assert run("new", str(d / "photo.png"), str(out), "--mode", "pixel").stdout.strip() == str(pix)  # taken twice: the same one

    scene = json.loads((keep / "scene.json").read_text())
    assert scene["builtin"] is False and scene["modifiers"] == []
    listed = subprocess.run([sys.executable, str(ROOT / "scripts/scene-list.py"), str(out)], capture_output=True, text=True).stdout
    assert all(str(p) in listed for p in (made, pix, keep)), listed
print("ok")
