#!/usr/bin/env python3
"""scripts/live-wall.py — the author's hints over what a look finds (<name>.scene.json, written
by the scene editor). A made-up pixel-art picture: a sky over a dark land, no water.

  python3 tests/settings/test_live_wall_paint.py    exit 0 = all good, 77 = skipped (no numpy / Pillow)

  none       no hints: the same mask as with empty hints
  paint      a band painted water becomes water (layer 4), found water: axis on its top row
  still      painted still (0) is nothing there, and its lights are gone
  auto       alpha 0 in the painted PNG leaves the layer as found
  effects    "effects" pass through to the JSON (widgets/LiveWall switches those off)
  points     "eyes" put by hand replace the found places; "lights" add a twinkling point
"""
import base64
import importlib.util
import io
import sys
import tempfile
from pathlib import Path

try:
    import numpy as np
    from PIL import Image
except ImportError:
    print("SKIP: numpy / Pillow are not installed")
    sys.exit(77)

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("live_wall", ROOT / "scripts/live-wall.py")
lw = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lw)

failures = []


def check(name, ok, detail=""):
    print("  %s %s %s" % ("✓" if ok else "✕", name, "" if ok else detail))
    if not ok:
        failures.append(name)


# 240×135 art pixels ×4: a night sky gradient with stars, a dark land below the middle
W, H, K = 240, 135, 4
rng = np.random.default_rng(3)
art = np.zeros((H, W, 3), np.uint8)
for y in range(H):
    art[y, :] = (10 + y // 6, 14 + y // 5, 40 + y // 3) if y < 80 else (30, 24, 20)
for _ in range(60):
    art[rng.integers(0, 70), rng.integers(0, W)] = (240, 240, 255)
tmp = Path(tempfile.mkdtemp())
pic = tmp / "night.png"
Image.fromarray(art).resize((W * K, H * K), Image.NEAREST).save(pic)

m0, i0 = lw.analyze(str(pic), hints={})
m_, i_ = lw.analyze(str(pic))
check("none", np.array_equal(np.asarray(m0), np.asarray(m_)) and i0["painted"] is False, str(i_.get("painted")))
w, h = i0["maskSize"]


def paint(cells):
    a = np.zeros((h, w, 4), np.uint8)
    for (y0, y1, x0, x1), layer in cells:
        a[y0:y1, x0:x1, :3] = lw.PAINT[layer]
        a[y0:y1, x0:x1, 3] = 255
    buf = io.BytesIO()
    Image.fromarray(a, "RGBA").save(buf, "PNG")
    return {"size": [w, h], "png": base64.b64encode(buf.getvalue()).decode()}


band = (int(h * 0.85), h, 0, w // 2)
sky_box = (0, int(h * 0.3), w // 2, w)
hints = {"paint": paint([(band, lw.L_WATER), (sky_box, 0)]), "effects": {"meteors": False, "eye": False},
         "eyes": [[0.25, 0.2]], "lights": [[0.1, 0.1]]}
m1, i1 = lw.analyze(str(pic), hints=hints)
L0 = (np.asarray(m0)[..., 0].astype(int) + 16) // 32
L1 = (np.asarray(m1)[..., 0].astype(int) + 16) // 32
B1 = np.asarray(m1)[..., 2]
y0, y1, x0, x1 = band
check("paint", (L1[y0:y1, x0:x1] == lw.L_WATER).all() and i1["water"]["found"] and abs(i1["water"]["axis"] - y0 / h) < 0.02,
      f"water share {(L1[y0:y1, x0:x1] == lw.L_WATER).mean():.2f}, {i1['water']}")
sy0, sy1, sx0, sx1 = sky_box
check("still", (L1[sy0:sy1, sx0:sx1] == 0).all() and not B1[sy0:sy1, sx0:sx1].any(), f"{np.bincount(L1[sy0:sy1, sx0:sx1].ravel())}")
rest = np.ones((h, w), bool)
rest[y0:y1, x0:x1] = False
rest[sy0:sy1, sx0:sx1] = False
check("auto", (L1[rest] == L0[rest]).mean() > 0.97, f"{(L1[rest] == L0[rest]).mean():.3f}")
check("effects", i1["effects"] == {"meteors": False, "eye": False}, str(i1["effects"]))
check("points", i1["scene"]["eyes"] == [[0.25, 0.2]] and B1[int(0.1 * h), int(0.1 * w)] > 0,
      f"{i1['scene']['eyes']} light {B1[int(0.1 * h), int(0.1 * w)]}")

print("FAILED: " + ", ".join(failures) if failures else "OK")
sys.exit(1 if failures else 0)
