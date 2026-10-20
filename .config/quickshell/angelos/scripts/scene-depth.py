#!/usr/bin/env python3
"""Which layer of a layered scene is the nearest at each spot (widgets/SceneWall: the desktop
widgets stand between the layers like the depth text). For every art pixel of the canvas the
highest z of the visible layers that have a pixel there, at rest (a layer's first frame): a
widget put at some depth is covered wherever that z is nearer than its own.

A JSON file: {"w", "h", "z": [the scene's distinct z, nearest last], "near": a string of one
character per art pixel, row by row — "0" + 1 + the index into "z" of the nearest layer there,
"0" for nothing (a string QML reads with charCodeAt, nothing to decode)}.
Cached per scene and its files' times; prints the file's path.

    scene-depth.py <scene dir> <cache dir>
"""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

scene_dir, cache = Path(sys.argv[1]), Path(sys.argv[2])
scene = json.loads((scene_dir / "scene.json").read_text())
visible = sorted((l for l in scene["layers"] if l.get("visible", True)), key=lambda l: l["z"])
files = [scene_dir / "logical" / ((l.get("animation") or {}).get("frames") or [l["file"]])[0] for l in visible]
key = hashlib.md5("|".join(f"{f}:{f.stat().st_mtime_ns}" for f in [scene_dir / "scene.json", Path(__file__)] + files).encode()).hexdigest()
out = cache / f"{key}.json"

if not out.exists():
    w, h = scene["logical_canvas"]["width"], scene["logical_canvas"]["height"]
    zs = sorted({l["z"] for l in visible})
    near = np.zeros((h, w), np.int32)
    for l, f in zip(visible, files):
        a = np.asarray(Image.open(f).convert("RGBA"))[..., 3] > 0
        near[a[:h, :w]] = zs.index(l["z"]) + 1
    cache.mkdir(parents=True, exist_ok=True)
    tmp = out.with_suffix(".tmp")
    tmp.write_text(json.dumps({"w": w, "h": h, "z": zs, "near": "".join(chr(48 + v) for v in near.ravel().tolist())}))
    tmp.replace(out)
print(out)
