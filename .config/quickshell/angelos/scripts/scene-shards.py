#!/usr/bin/env python3
"""Where the meteor's shards lie in a scene with a night, and how they fit in (an author's tool).

  scene-shards.py SCENE SPRITES [--seed N]  -> SCENE/logical/night/shards/<i>.png and
                                               scene.json → "night" → "debris"

SPRITES: the shards drawn as pixel art, one PNG per shape in its cooling state (dark rock, warm
cracks: ~/Work/AngelOS/assets/meteor-debris, cut from an image model's sheet by its slice.py).
Each shard placed is written as a map, not a picture — the colours come at run time from the
night's fire and the scene's palette (widgets/SceneAftermath, shaders/scene_shard.frag):

  r  the rock's shade, 4 steps (0 its outline … 3 its highlight)
  g  a crack, 3 steps (1 deep red … 3 white-hot), 0 none
  a  the shard or not

Where: never just on top of the picture.
  path   open ground that is not green (the paving), nothing of the scene over it
  grass  ground the scene's own plants cover the lower part of (their blades sway over it in
         the wind), the top left to be seen
  seat   on the bench's seat (in front of the bench, behind the plants), not its back
Sizes go with the depth: the far ones half of the near ones. Per shard, by day and by night, the
colours of what it lies on: its shadow (the surface darker), its scorch (darker and greyer), and
the rock's four shades — the scene's own stone greys (STONE) in its palette (palette.json /
night/palette.json), darker at night as the ground there is, so a cold shard is a stone of the
scene, not a sticker.

  debris  [{"at": [x, y] (art px, the middle of where it touches), "z", "map", "size": [w, h],
            "lands", "cools", "gone" (s after the impact), "lean" (art px: the day's shadow
            leans this way), "day"/"night": {"rock": [4], "shadow", "scorch", "ground"}}]
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

SCENE = Path(sys.argv[1]).expanduser().resolve()
SPRITES = Path(sys.argv[2]).expanduser().resolve()
SEED = int(sys.argv[sys.argv.index("--seed") + 1]) if "--seed" in sys.argv else 2004
LOGICAL = SCENE / "logical"
OUT = LOGICAL / "night" / "shards"
QUOTA = {"path": 4, "grass": 3, "seat": 1}
GAP = 30                                    # art px between shards, at least

scene = json.loads((SCENE / "scene.json").read_text())
rng = np.random.default_rng(SEED)


def rgba(path):
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.float64)


day = rgba(SCENE / scene["neutral_pose"]["reference"])[..., :3]
night = rgba(LOGICAL / "night" / "neutral-656x376.png")[..., :3]
h, w = day.shape[:2]
pal_day = np.array(json.loads((SCENE / scene["palette"]["file"]).read_text())["rgb"], float)
pal_night = np.array(json.loads((LOGICAL / scene["night"]["palette"]).read_text())["rgb"], float)

order = sorted([l for l in scene["layers"] if l.get("visible") is not False], key=lambda l: l["z"])
alpha = {l["id"]: rgba(LOGICAL / l["file"])[..., 3] > 0 for l in order}
top = np.full((h, w), -1)
for i, l in enumerate(order):
    top[alpha[l["id"]]] = i
role = np.array([l.get("role") for l in order] + [None])
zs = np.array([l["z"] for l in order])


def over(z):
    """what of the scene is drawn over something at depth z"""
    m = np.zeros((h, w), bool)
    for l in order:
        if l["z"] > z:
            m |= alpha[l["id"]]
    return m


GROUND_Z = 22
covered = over(GROUND_Z)
background = role[top] == "background"
green = (day[..., 1] > day[..., 0] * 1.04) & (day[..., 1] > day[..., 2] * 1.1)
low = np.broadcast_to(np.arange(h)[:, None] > h * 0.66, (h, w))
bench = alpha.get("bench", np.zeros((h, w), bool))
bench_z = next((l["z"] for l in order if l["id"] == "bench"), GROUND_Z)
# the seat: the bench's lowest band, its back stands above it (this scene: the seat from y≈322)
rows = np.nonzero(bench.any(1))[0]
seat = bench & (np.arange(h)[:, None] > rows.min() + 0.78 * (rows.max() - rows.min())) if len(rows) else bench
seat_covered = over(bench_z + 1)


def lum(c):
    c = np.asarray(c, float) / 255
    return c @ np.array([0.3, 0.59, 0.11])


def sat(c):
    c = np.asarray(c, float)
    mx, mn = c.max(-1), c.min(-1)
    return (mx - mn) / np.maximum(mx, 1)


def nearest(pal, c, grey=1.0):
    """the palette colour nearest to c, a colourful one counting `grey` times further"""
    d = np.abs(pal - np.asarray(c, float)).sum(-1) * (1 + (grey - 1) * sat(pal))
    return pal[int(d.argmin())]


def hexc(c):
    return "#%02x%02x%02x" % tuple(int(round(v)) for v in c)


# ---- the sprites: the cooling state read into shade and cracks ----
def read(path):
    px = rgba(path)
    a = px[..., 3] > 0
    r, g, b = px[..., 0], px[..., 1], px[..., 2]
    warm = a & (r > 120) & (r > b * 1.8) & (r > g * 1.15)
    crack = np.zeros(a.shape, int)
    crack[warm & (g < 70)] = 1
    crack[warm & (g >= 70)] = 2
    crack[warm & (g >= 150)] = 3
    body = a & ~warm
    L = lum(px[..., :3])
    shade = np.zeros(a.shape, int)
    if body.any():
        q = np.quantile(L[body], [0.2, 0.55, 0.93])
        shade[body] = 1 + (L[body] > q[1]).astype(int) + (L[body] > q[2]).astype(int)
        shade[body & (L <= max(q[0], 0.06))] = 0
    shade[warm] = 1
    return a, shade, crack


def shrink(a, shade, crack, f):
    """the map at f of its size: a cell is shard when half of it is, its shade the mean, its
    crack the strongest (a thin crack stays); the outline drawn again on the new edge"""
    H, W = a.shape
    nh, nw = max(3, round(H * f)), max(3, round(W * f))
    ys = np.linspace(0, H, nh + 1)
    xs = np.linspace(0, W, nw + 1)
    A = np.zeros((nh, nw), bool)
    S = np.zeros((nh, nw), int)
    C = np.zeros((nh, nw), int)
    for i in range(nh):
        for j in range(nw):
            y0, y1 = int(ys[i]), max(int(ys[i]) + 1, int(ys[i + 1]))
            x0, x1 = int(xs[j]), max(int(xs[j]) + 1, int(xs[j + 1]))
            m = a[y0:y1, x0:x1]
            if m.mean() >= 0.5:
                A[i, j] = True
                S[i, j] = int(round(shade[y0:y1, x0:x1][m].mean()))
                C[i, j] = int(crack[y0:y1, x0:x1].max()) if (crack[y0:y1, x0:x1] > 0).mean() > 0.2 else 0
    edge = A & ~(np.roll(A, 1, 0) & np.roll(A, -1, 0) & np.roll(A, 1, 1) & np.roll(A, -1, 1))
    edge[0, :] |= A[0, :]
    edge[-1, :] |= A[-1, :]
    edge[:, 0] |= A[:, 0]
    edge[:, -1] |= A[:, -1]
    S[edge] = 0
    C[edge] = 0
    S[A & (S == 0) & ~edge] = 1
    return A, S, C


shapes = [read(p) for p in sorted(SPRITES.glob("*-warm.png"))]
assert shapes, "no *-warm.png in " + str(SPRITES)


def scale_at(y):
    """near the bottom of the picture the drawing's own size, at the horizon a little over half"""
    t = np.clip((y - h * 0.68) / (h * 0.32), 0, 1)
    return 0.55 + 0.45 * t


def fits(kind, x, y, A):
    sh, sw = A.shape
    x0, y0 = x - sw // 2, y - sh + 1
    if x0 < 2 or y0 < 2 or x0 + sw >= w - 2 or y + 3 >= h:
        return False
    ys, xs = np.nonzero(A)
    ys, xs = ys + y0, xs + x0
    base = (slice(y, y + 3), slice(x0, x0 + sw))
    if kind == "path":
        # on open paving: nothing over it, nothing green under its foot or its shadow
        return background[ys, xs].all() and not covered[ys, xs].any() and not covered[base].any() \
            and green[base].mean() < 0.15 and background[base].all() and low[y, x]
    if kind == "grass":
        # the scene's plants over its lower part, its top to be seen
        sh3 = max(1, sh // 3)
        lower = ys >= y0 + sh - sh3
        upper = ys < y0 + sh3 + 1
        cov = covered[ys, xs]
        return low[y, x] and background[ys, xs].mean() > 0.6 and 0.35 <= cov[lower].mean() <= 0.85 \
            and cov[upper].mean() <= 0.15 and green[base].mean() > 0.3
    if kind == "seat":
        return seat[y, x] and seat[ys, xs].mean() > 0.95 and not seat_covered[ys, xs].any() and seat[y + 1, x]
    return False


def surface(img, x, y, sw):
    a = img[y:y + 3, max(0, x - sw // 2):x + sw // 2 + 1].reshape(-1, 3)
    return np.median(a, 0)


# the stone itself, one for every shard (a material, not the colour of the spot it lies on — a
# sunlit spot of this scene is yellow-green, and the stone on it read as moss): this scene's own
# cool violet greys, the ones its paving's shadows are made of
STONE = np.array([[0x0e, 0x10, 0x1e], [0x25, 0x29, 0x3b], [0x3c, 0x3e, 0x54], [0x5b, 0x57, 0x6e]], float)


def rock(pal, dim=1.0):
    """the four stone shades in this palette, darkest first, never the same twice; dim: the
    night's ground against the day's there, the stone darkened alike"""
    out, used = [], set()
    for c in STONE * dim:
        d = np.abs(pal - c).sum(-1) * (1 + sat(pal))
        for i in np.argsort(d):
            if i not in used:
                used.add(i)
                out.append(pal[i])
                break
    return sorted(out, key=lum)


OUT.mkdir(parents=True, exist_ok=True)
for old in OUT.glob("*.png"):
    old.unlink()
masks = {"path": None, "grass": None, "seat": None}
spots = {"path": np.argwhere(background & low & ~covered & ~green),
         "grass": np.argwhere(background & low & green),
         "seat": np.argwhere(seat)}
debris = []
pick = list(rng.permutation(len(shapes)))
for kind, n in QUOTA.items():
    cand = spots[kind]
    got = 0
    for k in rng.permutation(len(cand))[:6000]:
        if got == n:
            break
        y, x = (int(v) for v in cand[k])
        if any(abs(x - d["at"][0]) + abs(y - d["at"][1]) < GAP for d in debris):
            continue
        s = shapes[pick[len(debris) % len(pick)]]
        A, S, C = shrink(*s, scale_at(y) * (0.8 if kind == "seat" else 1.0))
        if rng.random() < 0.5:
            A, S, C = A[:, ::-1], S[:, ::-1], C[:, ::-1]
        if not fits(kind, x, y, A):
            continue
        i = len(debris)
        m = np.zeros(A.shape + (4,), np.uint8)
        m[..., 0] = S * 85
        m[..., 1] = C * 85
        m[..., 3] = A * 255
        Image.fromarray(m, "RGBA").save(OUT / f"{i}.png", optimize=True)
        sw = A.shape[1]
        cols = {}
        dim = np.clip(lum(surface(night, x, y, sw)) / max(lum(surface(day, x, y, sw)), 0.05), 0.25, 1.0)
        for name, img, pal, k in (("day", day, pal_day, 1.0), ("night", night, pal_night, dim)):
            g = surface(img, x, y, sw)
            cols[name] = {"rock": [hexc(c) for c in rock(pal, k)], "ground": hexc(nearest(pal, g)),
                          "shadow": hexc(nearest(pal, g * 0.55, 1.5)),
                          "scorch": hexc(nearest(pal, (g * 0.32 + lum(g) * 255 * 0.32 * 0.6) / 1.6, 3.0))}
        debris.append({"at": [x, y], "z": bench_z + 1 if kind == "seat" else GROUND_Z, "on": kind,
                       "map": f"night/shards/{i}.png", "size": [int(A.shape[1]), int(A.shape[0])],
                       "lands": round(float(rng.uniform(4, 22)), 1), "cools": round(float(rng.uniform(900, 2600))),
                       "gone": round(float(rng.uniform(9000, 57000))), "lean": -1 if kind != "seat" else -1,
                       "day": cols["day"], "night": cols["night"]})
        got += 1
    print(kind, got, "of", n)

scene["night"]["debris"] = debris
(SCENE / "scene.json").write_text(json.dumps(scene, ensure_ascii=False, indent=2) + "\n")
print(len(debris), "shards →", OUT)
