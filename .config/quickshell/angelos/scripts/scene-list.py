#!/usr/bin/env python3
"""The layered scenes in wallpaper folders (widgets/SceneWall): every <scene>/scene.json of
schema angelos.layered-scene.* / angelos.editable-scene.* one to three folders down, printed as "<scene dir>\t<its neutral
reference picture>\t<its night's neutral picture, or nothing>". The picture stands for the scene wherever a
still is shown (thumbnails, the lock and login screens); the desktop draws the scene itself, and at
night (scripts/scene-night.py) its night's still before the scene takes over.

    scene-list.py <dir>...      (the wallpaper folder, the releases' Pictures/AngelOS)
"""
import json
import sys
from pathlib import Path

found = {q.resolve(): q for d in sys.argv[1:] for g in ("*/", "*/*/", "*/*/*/") for q in Path(d).glob(g + "scene.json")}
for p in sorted(found.values()):
    try:
        s = json.loads(p.read_text())
        ref = p.parent / s["neutral_pose"]["reference"]
    except (OSError, ValueError, KeyError, TypeError):
        continue
    schema = str(s.get("schema", ""))
    if schema.startswith(("angelos.layered-scene.", "angelos.editable-scene.")) and ref.is_file():
        night = p.parent / s["night"]["neutral"] if isinstance(s.get("night"), dict) and s["night"].get("neutral") else None
        print(f"{p.parent}\t{ref}\t{night if night and night.is_file() else ''}")
