#!/usr/bin/env python3
"""The live wallpaper's scene, as the scene editor and its MCP server see it.

A picture's scene is <name>.scene.json next to it (scripts/live-wall.py reads it: the layers
painted by hand, which effects are off, where the rare events happen, rings). Both the editor
window (scene-editor.py) and Claude's MCP server (scene-mcp.py) change it only through here:
every save keeps the old one in $XDG_STATE_HOME/angelos/scene-history/, is written to the
change log (who: "editor" | "claude") and tells the running shell to look at the picture again.

Requests to Claude ("Отдать Claude" in the editor: a note and the regions it is about) live in
$XDG_STATE_HOME/angelos/scene-requests.json; Claude reads them over MCP and answers there.
"""
import base64
import hashlib
import importlib.util
import io
import json
import os
import subprocess
import threading
import time
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

Image.MAX_IMAGE_PIXELS = None
HERE = Path(__file__).resolve().parent
SHELL = HERE.parents[1]
STATE = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "angelos"
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "angelos/scene-editor"
HISTORY = STATE / "scene-history"
LOG = STATE / "scene-log.jsonl"
REQUESTS = STATE / "scene-requests.json"
PICTURE_EXT = (".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif")

_spec = importlib.util.spec_from_file_location("live_wall", SHELL / "scripts/live-wall.py")
LW = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(LW)

# the layers, as live-wall.py knows them: id, key, the editor's name, what moves there
LAYERS = [
    (0, "still", "Неподвижно", "ничего не двигается, огоньки гаснут"),
    (LW.L_SKY, "sky", "Небо", "ночью звёзды мерцают и падают"),
    (LW.L_CLOUD, "cloud", "Облако", "плывёт; в нём может открыться глаз"),
    (LW.L_THING, "thing", "Предмет в небе", "по нему пробегает блик (кольцо, луна)"),
    (LW.L_WATER, "water", "Вода", "рябь, блики, отражение, круги"),
    (LW.L_FALL, "fall", "Водопад", "струи бегут вниз"),
    (LW.L_LAND, "land", "Земля", "по ней идут тени облаков"),
]
LAYER_BY_KEY = {k: i for i, k, *_ in LAYERS}
LAYER_KEY = {i: k for i, k, *_ in LAYERS}
EFFECTS = [
    ("stars", "Звёзды мерцают"), ("meteors", "Падающие звёзды"), ("lights", "Огоньки картинки"),
    ("water", "Вода: рябь и отражение"), ("glint", "Блик по кольцу"), ("pebble", "Камешек с обрыва"),
    ("gust", "Ветер по воде"), ("eye", "Глаз в облаке"), ("rings", "Круги по воде"),
]
POINTS = {"rims": "камешек срывается", "eyes": "глаз открывается", "ponds": "круги расходятся",
          "lights": "огонёк мерцает"}

_lock = threading.RLock()
_memo = {}


# ---- pictures ----

USER_SCENES = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share") / "angelos/scenes"


def user_scene_file(pic):
    """The user's own scene of a picture they can't (or shouldn't) write next to: the ones angelOS
    ships inside the shell (an update would take the file away), a folder that isn't theirs."""
    pic = Path(pic)
    tag = hashlib.sha1(str(pic.resolve()).encode()).hexdigest()[:10]
    return USER_SCENES / f"{pic.stem}.{tag}.scene.json"


def _next_to_ok(pic):
    pic = Path(pic).resolve()
    inside_shell = SHELL in pic.parents
    # the author edits the shipped pictures' scenes in place: they are published with them
    if inside_shell and not (SHELL / "owner").is_dir():
        return False
    return os.access(pic.parent, os.W_OK)


def scene_file(pic):
    """Where the picture's scene is: the user's own (USER_SCENES) when there is one, else next to
    the picture when that can be written, else where the user's own would go."""
    pic = Path(pic)
    own = user_scene_file(pic)
    if own.is_file():
        return own
    near = pic.with_name(pic.stem + ".scene.json")
    if _next_to_ok(pic):
        return near
    return own


def shipped_scene_file(pic):
    """The scene that came with the picture (next to it), a start for the user's own copy."""
    pic = Path(pic)
    return pic.with_name(pic.stem + ".scene.json")


def check_picture(pic):
    p = Path(os.path.expanduser(str(pic))).resolve()
    if p.suffix.lower() not in PICTURE_EXT or not p.is_file():
        raise ValueError(f"нет такой картинки: {pic}")
    return p


def _settings():
    try:
        return json.loads((Path.home() / ".config/angelos/settings.json").read_text())
    except (OSError, ValueError):
        return {}


def candidates(limit=400):
    """Pictures worth offering: on the screens now, the release's, the wallpaper folder's."""
    out, seen = [], set()

    def add(p, where):
        try:
            p = str(Path(os.path.expanduser(p)).resolve())
        except (OSError, RuntimeError):
            return
        if p in seen or not p.lower().endswith(PICTURE_EXT) or not os.path.isfile(p) or p.endswith(".scene.png"):
            return
        seen.add(p)
        out.append({"path": p, "where": where, "scene": scene_file(p).is_file()})

    w = _settings().get("wallpaper", {})
    for p in [w.get("fallback")] + list((w.get("outputs") or {}).values()) + \
            [v for ws in (w.get("workspaces") or {}).values() for v in (ws.values() if isinstance(ws, dict) else [ws])]:
        if isinstance(p, str) and p:
            add(p, "на экране")
    try:
        rel = json.loads((SHELL / "owner/release-walls.json").read_text())   # the author's
    except (OSError, ValueError):
        rel = {}
    for wall in rel.get("walls", []):
        for f in [wall.get("day"), wall.get("night")] + [v.get("file") for v in wall.get("variants", [])]:
            if f:
                add(f, f"релиз {rel.get('number', '')} «{wall.get('name') or 'без имени'}»")
    for h in reversed(rel.get("history", [])):
        for wall in h.get("walls", []):
            for f in [wall.get("day"), wall.get("night")] + [v.get("file") for v in wall.get("variants", [])]:
                if f:
                    add(f, f"релиз {h.get('number')} «{h.get('codename', '')}»")
    for d in [os.path.expanduser(w.get("dir") or "~/Pictures"), str(Path.home() / "Pictures/AngelOS")]:
        for root, dirs, files in os.walk(d):
            dirs[:] = [x for x in dirs if not x.startswith(".") and x != "Screenshots"]
            if root.count(os.sep) - d.count(os.sep) > 3:
                dirs[:] = []
            for f in sorted(files):
                if len(out) >= limit:
                    return out
                add(os.path.join(root, f), "папка обоев")
    return out


# ---- the scene file ----

def load(pic):
    """The scene: the user's own, else the one that came with the picture."""
    for f in (scene_file(pic), shipped_scene_file(pic)):
        try:
            d = json.loads(f.read_text())
            return d if isinstance(d, dict) else {}
        except (OSError, ValueError):
            continue
    return {}


def scene_mtime(pic):
    for f in (scene_file(pic), shipped_scene_file(pic)):
        try:
            return f.stat().st_mtime_ns
        except OSError:
            continue
    return 0


def save(pic, d, who="editor", what=""):
    """Write the scene (an empty one removes the file), keep the old one, tell the shell."""
    pic = check_picture(pic)
    f = scene_file(pic)
    d = {k: v for k, v in d.items() if v not in (None, [], {}) or k in ("rims", "eyes", "ponds")}
    text = json.dumps(d, ensure_ascii=False, indent=1) + "\n" if d else ""
    with _lock:
        f.parent.mkdir(parents=True, exist_ok=True)
        old = f.read_text() if f.is_file() else ""
        if old == text:
            return False
        if old:
            h = HISTORY / hashlib.md5(str(pic).encode()).hexdigest()[:12]
            h.mkdir(parents=True, exist_ok=True)
            (h / f"{time.strftime('%Y%m%d-%H%M%S')}-{int(time.time() * 1000) % 1000:03d}-{who}.json").write_text(old)
            (h / "picture.txt").write_text(str(pic) + "\n")
            for o in sorted(h.glob("*.json"))[:-60]:
                o.unlink()
        if text:
            tmp = f.with_name(f.name + ".tmp")
            tmp.write_text(text)
            os.replace(tmp, f)
        elif f.exists():
            f.unlink()
        STATE.mkdir(parents=True, exist_ok=True)
        with LOG.open("a") as lf:
            lf.write(json.dumps({"t": time.time(), "picture": str(pic), "who": who, "what": what}, ensure_ascii=False) + "\n")
    reload_shell(pic)
    return True


def undo(pic, who="editor"):
    """Back to the scene before the last save (that save itself kept in history too)."""
    pic = check_picture(pic)
    h = HISTORY / hashlib.md5(str(pic).encode()).hexdigest()[:12]
    olds = sorted(h.glob("*.json")) if h.is_dir() else []
    if not olds:
        return False
    prev = json.loads(olds[-1].read_text())
    olds[-1].unlink()
    save(pic, prev, who, "откат")
    # the save just kept the undone one: that is no step to go back to
    newest = sorted(h.glob("*.json"))
    if newest:
        newest[-1].unlink()
    return True


def recent_changes(n=20):
    try:
        lines = LOG.read_text().splitlines()[-n:]
    except OSError:
        return []
    return [json.loads(l) for l in lines if l.strip()]


def reload_shell(pic):
    """The running shell looks at the picture again (if it shows it): qs IPC, in the background."""
    try:
        subprocess.Popen(["qs", "-c", "angelos", "ipc", "call", "angelos", "liveWall", "reload " + str(pic)],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError:
        pass


# ---- what live-wall.py finds ----

def analysis(pic, hints=None):
    """(layers (h, w) uint8, info) — hints None: the scene file as it is."""
    pic = check_picture(pic)
    if hints is None:
        hints = load(pic)
    st = pic.stat()
    key = (str(pic), st.st_mtime_ns, st.st_size, json.dumps(hints, sort_keys=True))
    with _lock:
        if key in _memo:
            return _memo[key]
    mask, info = LW.analyze(str(pic), hints=hints)
    layers = (np.asarray(mask)[..., 0].astype(np.int32) + 16) // 32
    out = (layers.astype(np.uint8), info)
    with _lock:
        if len(_memo) > 24:
            _memo.clear()
        _memo[key] = out
    return out


def auto(pic):
    """What a look finds without the hand-painted layers (the rings still count)."""
    d = {k: v for k, v in load(pic).items() if k not in ("paint",)}
    return analysis(pic, d)


def grid_size(pic):
    _, info = auto(pic)
    return tuple(info["maskSize"])


# ---- the painted layers ----

def paint_get(d, w, h):
    return LW.paint_of(d, w, h)


def paint_encode(arr):
    """(h, w) int8, -1 = as found → the hints' {"size", "png"}, or None when nothing is painted."""
    if not (arr >= 0).any():
        return None
    h, w = arr.shape
    rgba = np.zeros((h, w, 4), np.uint8)
    for i, rgb in LW.PAINT.items():
        m = arr == i
        rgba[m, :3] = rgb
        rgba[m, 3] = 255
    buf = io.BytesIO()
    Image.fromarray(rgba, "RGBA").save(buf, "PNG", optimize=True)
    return {"size": [w, h], "png": base64.b64encode(buf.getvalue()).decode()}


def set_paint(pic, arr, who="editor", what="слои"):
    d = load(pic)
    enc = paint_encode(arr)
    if enc:
        d["paint"] = enc
    else:
        d.pop("paint", None)
    return save(pic, d, who, what)


def picture_grid(pic):
    """The picture at the mask's size (one value per art pixel), RGB float 0…1."""
    w, h = grid_size(pic)
    im, _, _ = LW.load(str(check_picture(pic)))
    return np.asarray(im.resize((w, h), Image.BOX)).astype(np.float32) / 255


def shape_mask(pic, shape, w, h):
    """One shape in the picture's 0…1 → a boolean mask on the grid.
    {"rect": [x0, y0, x1, y1]} | {"ellipse": [cx, cy, rx, ry]} | {"polygon": [[x, y], …]} |
    {"brush": [[x, y], …], "radius": r} | {"flood": [x, y], "tolerance": 0.08} (alike colour,
    touching) | {"found": "<layer key>"} (what a look found as that layer) | {"all": true}"""
    if shape.get("all"):
        return np.ones((h, w), bool)
    if "found" in shape:
        lay, _ = auto(pic)
        return lay == LAYER_BY_KEY[shape["found"]]
    im = Image.new("L", (w, h), 0)
    dr = ImageDraw.Draw(im)
    X = lambda x: float(x) * w
    Y = lambda y: float(y) * h
    if "rect" in shape:
        x0, y0, x1, y1 = shape["rect"]
        dr.rectangle([X(min(x0, x1)), Y(min(y0, y1)), X(max(x0, x1)) - 1, Y(max(y0, y1)) - 1], fill=255)
    elif "ellipse" in shape:
        cx, cy, rx, ry = shape["ellipse"]
        dr.ellipse([X(cx - rx), Y(cy - ry), X(cx + rx), Y(cy + ry)], fill=255)
    elif "polygon" in shape:
        pts = [(X(x), Y(y)) for x, y in shape["polygon"]]
        if len(pts) >= 3:
            dr.polygon(pts, fill=255)
    elif "brush" in shape:
        r = max(0.5, float(shape.get("radius", 0.01)) * w)
        pts = [(X(x), Y(y)) for x, y in shape["brush"]]
        if len(pts) > 1:
            dr.line(pts, fill=255, width=max(1, int(round(2 * r))))
        for x, y in pts:
            dr.ellipse([x - r, y - r, x + r, y + r], fill=255)
    elif "flood" in shape:
        A = picture_grid(pic)
        sx, sy = shape["flood"]
        px, py = min(w - 1, int(float(sx) * w)), min(h - 1, int(float(sy) * h))
        tol = float(shape.get("tolerance", 0.08))
        alike = np.abs(A - A[py, px]).max(2) <= tol
        for ys, xs in LW.components(alike):
            if ((ys == py) & (xs == px)).any():
                m = np.zeros((h, w), bool)
                m[ys, xs] = True
                return m
        return np.zeros((h, w), bool)
    else:
        raise ValueError(f"не знаю такой фигуры: {sorted(shape)}")
    return np.asarray(im) > 127


def paint_shapes(pic, layer, shapes, who="claude"):
    """Paint shapes with a layer key (or "auto": back to what was found)."""
    pic = check_picture(pic)
    val = -1 if layer == "auto" else LAYER_BY_KEY[layer]
    w, h = grid_size(pic)
    arr = paint_get(load(pic), w, h).copy()
    n = 0
    for s in shapes:
        m = shape_mask(pic, s, w, h)
        arr[m] = val
        n += int(m.sum())
    set_paint(pic, arr, who, f"{layer}: {len(shapes)} фигур(ы), {n} клеток")
    return n


# ---- a picture of the scene (for Claude, and the editor's check) ----

def picture_small(pic, max_w=1600):
    """The picture scaled down for the editor (cached): PNG bytes."""
    pic = check_picture(pic)
    st = pic.stat()
    key = hashlib.md5(f"{pic}|{st.st_mtime_ns}|{st.st_size}|{max_w}".encode()).hexdigest()
    f = CACHE / (key + ".png")
    if f.is_file():
        return f.read_bytes()
    im, _, _ = LW.load(str(pic))
    if im.width > max_w:
        im = im.resize((max_w, max(1, round(im.height * max_w / im.width))), Image.LANCZOS)
    CACHE.mkdir(parents=True, exist_ok=True)
    buf = io.BytesIO()
    im.save(buf, "PNG")
    f.write_bytes(buf.getvalue())
    return buf.getvalue()


def render(pic, view="final", max_w=1280, regions=None):
    """PNG: the picture with the layers over it (view: final | found | paint | picture), the
    event places and lights marked, a request's regions outlined; a legend strip below."""
    pic = check_picture(pic)
    d = load(pic)
    w, h = grid_size(pic)
    if view == "found":
        lay, info = auto(pic)
        show = np.ones((h, w), bool)
    elif view == "paint":
        lay = paint_get(d, w, h)
        show = lay >= 0
        lay = np.where(show, lay, 0)
        _, info = analysis(pic)
    else:
        lay, info = analysis(pic)
        show = np.ones((h, w), bool) if view == "final" else np.zeros((h, w), bool)
    k = max(1, min(max_w // w, 8)) if w <= max_w else 1
    W, H = (w * k, h * k) if w * k <= max_w else (max_w, round(h * max_w / w))
    base = Image.open(io.BytesIO(picture_small(pic, max(W, 1600)))).convert("RGB").resize((W, H), Image.LANCZOS)
    tint = np.zeros((h, w, 4), np.uint8)
    for i, rgb in LW.PAINT.items():
        m = show & (lay == i)
        tint[m, :3] = rgb
        tint[m, 3] = 110 if i else 150
    over = Image.fromarray(tint, "RGBA").resize((W, H), Image.NEAREST)
    img = Image.alpha_composite(base.convert("RGBA"), over)
    dr = ImageDraw.Draw(img)
    sc = info.get("scene", {})
    marks = {"rims": ((255, 255, 255), sc.get("rims", [])), "eyes": ((255, 80, 80), sc.get("eyes", [])),
             "ponds": ((80, 255, 255), sc.get("ponds", [])), "lights": ((255, 255, 120), d.get("lights", []))}
    for key, (col, pts) in marks.items():
        for x, y in pts:
            cx, cy = x * W, y * H
            dr.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], outline=col, width=2)
    for r in d.get("rings", []):
        cx, cy, rx, ry = (float(v) for v in r[:4])
        dr.ellipse([(cx - rx) * W, (cy - ry) * H, (cx + rx) * W, (cy + ry) * H], outline=(255, 210, 74), width=2)
    for n, rg in enumerate(regions or []):
        x0, y0, x1, y1 = rg["rect"] if "rect" in rg else (0, 0, 0, 0)
        dr.rectangle([x0 * W, y0 * H, x1 * W, y1 * H], outline=(255, 143, 184), width=3)
        dr.text((x0 * W + 4, y0 * H + 2), str(n + 1), fill=(255, 143, 184))
    # the legend
    leg = Image.new("RGBA", (W, 22), (23, 18, 26, 255))
    ld = ImageDraw.Draw(leg)
    x = 6
    for i, key, name, _ in LAYERS:
        ld.rectangle([x, 6, x + 10, 16], fill=LW.PAINT[i])
        ld.text((x + 14, 5), key, fill=(246, 233, 240))
        x += 14 + 7 * len(key) + 14
    out = Image.new("RGBA", (W, H + 22))
    out.paste(img, (0, 0))
    out.paste(leg, (0, H))
    buf = io.BytesIO()
    out.convert("RGB").save(buf, "PNG")
    return buf.getvalue()


def summary(pic):
    """What the scene is, in words and numbers (for Claude)."""
    pic = check_picture(pic)
    d = load(pic)
    lay, info = analysis(pic)
    w, h = lay.shape[1], lay.shape[0]
    painted = paint_get(d, w, h)
    share = {LAYER_KEY[i]: round(float((lay == i).mean()), 3) for i, *_ in LAYERS}
    pshare = {LAYER_KEY[i]: round(float((painted == i).mean()), 3) for i, *_ in LAYERS if (painted == i).any()}
    return {
        "picture": str(pic), "scene_file": str(scene_file(pic)), "grid": [w, h],
        "layers": share, "painted": pshare,
        "effects_off": [k for k, v in (d.get("effects") or {}).items() if v is False],
        "points": {k: d.get(k) for k in POINTS if d.get(k) is not None},
        "rings": d.get("rings", []), "night": info["sky"]["night"], "water": info["water"],
        "found_events": {k: len(info["scene"].get(k, [])) for k in ("rims", "eyes", "ponds")},
        "pixel_art": info["pixelArt"],
    }


# ---- requests to Claude ----

def _requests():
    try:
        r = json.loads(REQUESTS.read_text())
        return r if isinstance(r, list) else []
    except (OSError, ValueError):
        return []


def _save_requests(r):
    STATE.mkdir(parents=True, exist_ok=True)
    tmp = REQUESTS.with_name(REQUESTS.name + ".tmp")
    tmp.write_text(json.dumps(r, ensure_ascii=False, indent=1) + "\n")
    os.replace(tmp, REQUESTS)


def requests(status=None):
    return [q for q in _requests() if status in (None, q.get("status"))]


def add_request(pic, note, regions):
    with _lock:
        r = _requests()
        q = {"id": f"r{int(time.time() * 1000)}", "picture": str(check_picture(pic)), "note": note.strip(),
             "regions": regions or [], "status": "new", "created": time.strftime("%Y-%m-%d %H:%M:%S"), "reply": ""}
        r.append(q)
        _save_requests(r[-200:])
    return q


def update_request(rid, status=None, reply=None):
    with _lock:
        r = _requests()
        for q in r:
            if q["id"] == rid:
                if status:
                    q["status"] = status
                if reply is not None:
                    q["reply"] = reply
                q["updated"] = time.strftime("%Y-%m-%d %H:%M:%S")
                _save_requests(r)
                return q
    raise ValueError(f"нет запроса {rid}")


def requests_mtime():
    try:
        return REQUESTS.stat().st_mtime_ns
    except OSError:
        return 0
