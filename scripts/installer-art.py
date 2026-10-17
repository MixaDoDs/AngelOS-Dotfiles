#!/usr/bin/env python3
"""Builds the installer's pictures (installer/art/) from angelOS's own sprites — run by hand when
a sprite changes (needs Pillow; the installer itself only reads the results).

  angel.gif, demon.gif          the wings flapping (the Y2K rigs: modules/y2k/sprites/*/rig.json)
  angel-N.ans, demon-N.ans      the same frames as half-block truecolor text (no chafa, a TTY)
  chest-{0,1,2}.ans             the ending: the chest opening (data/chest)
"""
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
A = ROOT / ".config/quickshell/angelos"
OUT = ROOT / "installer/art"
ROWS = 16  # text rows of an .ans picture: 32 pixels high


def rig_frames(name):
    d = A / "modules/y2k/sprites" / name
    rig = json.loads((d / "rig.json").read_text())
    W, H = rig["size"]
    b = rig["body"]
    parts = rig["parts"]
    n = max(p["frames"] * p.get("every", 1) for p in parts.values())
    strips = {k: Image.open(d / f"{k}.png").convert("RGBA") for k in parts}
    top = [Image.open(d / f"{k}.png").convert("RGBA") for k in ("body", "eyes", "mouth")]
    frames = []
    # there and back: 0 1 2 3 4 3 2 1
    for t in list(range(n)) + list(range(n - 2, 0, -1)):
        im = Image.new("RGBA", (W, H))
        for k, p in parts.items():
            f = min(t // p.get("every", 1), p["frames"] - 1)
            im.alpha_composite(strips[k].crop((f * p["w"], 0, (f + 1) * p["w"], p["h"])), (p["x"], p["y"]))
        for layer in top:
            im.alpha_composite(layer, (b["x"], b["y"]))
        frames.append(im)
    return frames


def ans(im, rows=ROWS):
    """▀ with the upper pixel as the colour and the lower as the background; clear stays clear."""
    im = im.convert("RGBA")
    h = rows * 2
    w = max(1, round(im.width * h / im.height))
    im = im.resize((w, h), Image.BOX)
    px = im.load()
    out = []
    for y in range(0, h, 2):
        line = ""
        for x in range(w):
            up, lo = px[x, y], px[x, y + 1]
            u, l = up[3] > 96, lo[3] > 96
            if u and l:
                line += "\x1b[38;2;%d;%d;%dm\x1b[48;2;%d;%d;%dm▀" % (*up[:3], *lo[:3])
            elif u:
                line += "\x1b[49m\x1b[38;2;%d;%d;%dm▀" % up[:3]
            elif l:
                line += "\x1b[49m\x1b[38;2;%d;%d;%dm▄" % lo[:3]
            else:
                line += "\x1b[0m "
        out.append(line.rstrip(" ") + "\x1b[0m")
    return "\n".join(out) + "\n"


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name in ("angel", "demon"):
        frames = rig_frames(name)
        big = [f.resize((f.width * 2, f.height * 2), Image.NEAREST) for f in frames]
        big[0].save(OUT / f"{name}.gif", save_all=True, append_images=big[1:], duration=110, loop=0, disposal=2)
        for i, f in enumerate(frames):
            (OUT / f"{name}-{i}.ans").write_text(ans(f))
    for i, k in enumerate(("closed", "lid", "open")):
        (OUT / f"chest-{i}.ans").write_text(ans(Image.open(A / f"data/chest/chest-{k}.png"), 10))
    # a self-check: every .ans row is as wide as the first one
    for p in OUT.glob("*.ans"):
        lines = p.read_text().splitlines()
        assert lines and all(l.count("▀") + l.count("▄") + l.count(" ") <= len(lines[0]) for l in lines), p
    print(f"{len(list(OUT.iterdir()))} files in {OUT.relative_to(ROOT)}", file=sys.stderr)


if __name__ == "__main__":
    main()
