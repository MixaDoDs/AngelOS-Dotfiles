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
  2002       release 2002's hints: painted outdoors (layer 7), bulbs and screens in R's low bits
             (the layer, G and B as without them), snow / fireworks / smoke / blink in "extras";
             bad values dropped
  same       LIVE_WALL_BASE=<an older live-wall.py>: on the shipped wallpapers (~/Pictures/AngelOS)
             the mask and the JSON are what the older script makes (skipped without it)
"""
import base64
import importlib.util
import io
import json
import os
import subprocess
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

# ---- 2002 ----
plain = {"paint": paint([(band, lw.L_OUT)])}
m2p, i2p = lw.analyze(str(pic), hints=plain)
P = np.asarray(m2p)
check("2002 out", ((P[y0:y1, x0:x1, 0].astype(int) + 16) // 32 == lw.L_OUT).all() and not (P[..., 0] % 32).any()
      and "extras" not in i2p, f"{np.unique(P[y0:y1, x0:x1, 0])}")
extra = dict(plain, snow=0.6, fireworks=[[0.1, 0.05, 0.4, 0.3], [0.6, 0.0, 0.9, 0.2], [0, 0, 1, 1]],
             bulbs=[[0.5, 0.5, 2, 1], [0.2, 0.9, 1, 2], ["x"], [0.8, 0.2]],
             screens=[[0.7, 0.6, 0.8, 0.7], [0.05, 0.4, 0.15, 0.5]], smoke=[0.3, 0.7, 25], blink=[0.25, 0.2, 0.03, 0.04])
m2, i2 = lw.analyze(str(pic), hints=extra)
Q = np.asarray(m2)
code = Q[..., 0].astype(int) % 32
check("2002 layer", np.array_equal((Q[..., 0].astype(int) + 16) // 32, (P[..., 0].astype(int) + 16) // 32)
      and np.array_equal(Q[..., 1:], P[..., 1:]), "a hint changed the layer, G or B")
cy, cx = int(0.5 * h), int(0.5 * w)
check("2002 bulb", code[cy, cx] == 2 and code[cy + 2, cx] == 2 and code[cy + 3, cx] == 0 and code[cy + 2, cx + 2] == 0
      and code[int(0.9 * h), int(0.2 * w)] == 3, f"{code[cy - 3:cy + 4, cx - 3:cx + 4]}")
check("2002 screens", (code[int(0.6 * h):int(0.7 * h), int(0.7 * w):int(0.8 * w)] == 4).all()
      and (code[int(0.4 * h):int(0.5 * h), int(0.05 * w):int(0.15 * w)] == 5).all()
      and (code > 0).sum() == 13 + 5 + sum((round(r[3] * h) - round(r[1] * h)) * (round(r[2] * w) - round(r[0] * w)) for r in extra["screens"]),
      f"{np.bincount(code.ravel())}")
check("2002 extras", i2.get("extras") == {"snow": 0.6, "fireworks": [[0.1, 0.05, 0.4, 0.3], [0.6, 0.0, 0.9, 0.2]], "screens": 2,
                                          "bulbs": 2, "smoke": [0.3, 0.7, 25], "blink": [0.25, 0.2, 0.03, 0.04]}, str(i2.get("extras")))
_, i3 = lw.analyze(str(pic), hints={"fireworks": [0.2, 0.1, 0.3, 0.05], "snow": "lots", "smoke": [1, 2], "blink": [0.5, 0.5, 0, 0.1]})
check("2002 odd", i3.get("extras") == {"fireworks": [[0.2, 0.05, 0.3, 0.1]]}, str(i3.get("extras")))

# ---- the shipped wallpapers: what an older script made, unchanged ----
base = os.environ.get("LIVE_WALL_BASE")
pics = sorted((Path.home() / "Pictures/AngelOS").glob("0*/*.png"))
if not base or not pics:
    print("  - same: skipped (LIVE_WALL_BASE=<older live-wall.py> and ~/Pictures/AngelOS/0*/*.png)")
else:
    def run(script, p, cache):
        out = subprocess.run([sys.executable, script, str(p), "--cache", cache, "--force"], capture_output=True, text=True, check=True).stdout
        j = json.loads(out.strip().splitlines()[-1])
        return np.asarray(Image.open(j.pop("mask"))), {k: v for k, v in j.items() if k != "version"}
    bad = []
    for p in pics:
        ma, ja = run(base, p, str(tmp / "old"))
        mb, jb = run(str(ROOT / "scripts/live-wall.py"), p, str(tmp / "new"))
        if not np.array_equal(ma, mb) or ja != jb:
            bad.append(p.name)
    check("same (%d wallpapers, %d with a scene)" % (len(pics), sum(p.with_name(p.stem + ".scene.json").exists() for p in pics)),
          not bad, ", ".join(bad))

print("FAILED: " + ", ".join(failures) if failures else "OK")
sys.exit(1 if failures else 0)
