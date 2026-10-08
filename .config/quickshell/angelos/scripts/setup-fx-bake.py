#!/usr/bin/env python3
"""Bake the setup wizard's step transitions into pictures (modules/settings/SetupFx.qml).

The wizard's question breaks into big blocks of its own ground and comes back out of them:
six frames, each a tiny picture with one pixel per block, shown scaled up without smoothing.
Baked once per screen size and theme while the first question is read, so a transition only
swaps a picture: nothing is worked out while it plays.

  setup-fx-bake.py OUT W H CELL DESK END ACCENT

W×H: the wizard's stage in its own pixels; CELL: a block's size in them; DESK → END: the ground's
gradient top to bottom; ACCENT: the few lit blocks. Writes OUT/<style>-<frame>.png for the styles
blocks (random order), sweep+ and sweep- (along the step's way), then OUT/done.
"""
import os
import random
import sys

from PIL import Image

FRAMES = 6  # 0-2 the blocks come, the step changes under them, 3-5 they go


def rgb(h):
    h = h.lstrip("#")
    if len(h) == 8:  # #aarrggbb (QML's colours with alpha)
        h = h[2:]
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def bake(out, w, h, cell, desk, end, accent):
    cols, rows = -(-w // cell), -(-h // cell)
    rnd = random.Random(1108)
    styles = {}
    for style in ("blocks", "sweep+", "sweep-"):
        come, go, lit = [], [], []
        for r in range(rows):
            for c in range(cols):
                if style == "blocks":
                    a, b = rnd.randrange(3), rnd.randrange(3)
                else:
                    k = c / max(1, cols - 1)
                    if style == "sweep-":
                        k = 1 - k
                    a = min(2, max(0, int(k * 3 + rnd.uniform(-0.6, 0.6))))
                    b = a
                come.append(a)
                go.append(b)
                lit.append(rnd.random() < 0.12)
        styles[style] = (come, go, lit)
    ground = [mix(desk, end, (r + 0.5) * cell / h) for r in range(rows)]
    glow = [mix(g, accent, 0.22) for g in ground]
    for style, (come, go, lit) in styles.items():
        for f in range(FRAMES):
            im = Image.new("RGBA", (cols, rows), (0, 0, 0, 0))
            px = im.load()
            for r in range(rows):
                for c in range(cols):
                    i = r * cols + c
                    on = come[i] <= f if f < 3 else go[i] > f - 3
                    if not on:
                        continue
                    # the lit ones only while the blocks are on the move (frames 1 and 4)
                    col = glow[r] if lit[i] and f in (1, 4) else ground[r]
                    px[c, r] = col + (255,)
            im.save(os.path.join(out, f"{style}-{f}.png"))
    with open(os.path.join(out, "done"), "w") as fh:
        fh.write(f"{cols}x{rows}\n")


def main():
    if len(sys.argv) != 8:
        sys.exit(__doc__)
    out, w, h, cell = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
    desk, end, accent = rgb(sys.argv[5]), rgb(sys.argv[6]), rgb(sys.argv[7])
    if os.path.exists(os.path.join(out, "done")):
        return
    os.makedirs(out, exist_ok=True)
    bake(out, max(1, w), max(1, h), max(1, cell), desk, end, accent)


if __name__ == "__main__":
    main()
