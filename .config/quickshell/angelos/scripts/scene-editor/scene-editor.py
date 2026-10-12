#!/usr/bin/env python3
"""angelOS scene editor: which parts of a wallpaper come alive (`angelos scene edit [picture]`).

  scene-editor.py [PICTURE] [--port 0] [--no-open] [--stay]

A small local server on 127.0.0.1 behind the editor. The editor itself is a window of the shell
(SceneEditorWindow.qml, `angelos scene edit`, services/SceneEditor): it starts this server
with --no-open and talks to it. The same thing as a page in a browser window is still here
(`angelos scene web`: Helium/Chromium `--app`, else the default browser). The editor paints the live
wallpaper's layers over the picture (sky, cloud, water …: what moves there), switches effects
off, puts the rare events' places and extra lights, and hands requests to Claude ("Отдать
Claude": a note and the regions). Everything goes through scene_core: <picture>.scene.json,
which scripts/live-wall.py reads; Claude changes the same file over MCP (scene-mcp.py), and
the page picks such a change up by itself. Without --stay the server quits a minute after the
page stopped pinging. Only the standard library, numpy and Pillow (as live-wall.py).
"""
import argparse
import base64
import json
import os
import shutil
import subprocess
import sys
import threading
import time
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, quote, urlparse

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import scene_core as sc  # noqa: E402

last_ping = time.time()
POKES = ["glint", "pebble", "gust", "eye", "rings"]


def b64_grid(arr):
    """(h, w) int (-1 = as found) → base64 of bytes value + 1"""
    return base64.b64encode((arr.astype(np.int16) + 1).clip(0, 255).astype(np.uint8).tobytes()).decode()


def grid_b64(s, w, h):
    raw = np.frombuffer(base64.b64decode(s), dtype=np.uint8)
    if raw.size != w * h:
        raise ValueError(f"слои не того размера: {raw.size} вместо {w}×{h}")
    return raw.reshape(h, w).astype(np.int8) - 1


def rle_grid(arr):
    """(h, w) int (-1 = as found) → [value, count, value, count …] row by row: the window of the
    shell reads this (QML has no binary strings); a layer map is a few hundred runs"""
    a = np.asarray(arr).astype(np.int16).reshape(-1)
    if a.size == 0:
        return []
    cut = np.flatnonzero(np.diff(a)) + 1
    starts = np.concatenate([[0], cut])
    counts = np.diff(np.concatenate([starts, [a.size]]))
    out = np.empty(len(starts) * 2, np.int64)
    out[0::2] = a[starts]
    out[1::2] = counts
    return out.tolist()


def grid_rle(runs, w, h):
    v = np.asarray(runs[0::2], np.int16)
    n = np.asarray(runs[1::2], np.int64)
    if len(v) != len(n) or (n < 0).any() or int(n.sum()) != w * h or (v < -1).any() or (v > 6).any():
        raise ValueError(f"слои не того размера: {int(n.sum()) if len(v) == len(n) else '?'} вместо {w}×{h}")
    return np.repeat(v, n).reshape(h, w).astype(np.int8)


def mask_runs(m):
    """a boolean mask → [[y, x0, x1], …]: the cells of every row, x1 inclusive"""
    out = []
    for y in np.flatnonzero(m.any(1)):
        row = np.concatenate([[0], m[y].astype(np.int8), [0]])
        d = np.diff(row)
        for x0, x1 in zip(np.flatnonzero(d == 1), np.flatnonzero(d == -1)):
            out.append([int(y), int(x0), int(x1) - 1])
    return out


def scene_payload(pic, rle=False):
    d = sc.load(pic)
    lay_auto, info_auto = sc.auto(pic)
    h, w = lay_auto.shape
    _, info = sc.analysis(pic)
    plain = {k: v for k, v in d.items() if k != "paint"}
    enc = rle_grid if rle else b64_grid
    return {
        "picture": str(pic), "grid": [w, h], "scene": plain,
        "paint": enc(sc.paint_get(d, w, h)), "auto": enc(lay_auto.astype(np.int16)),
        "found": {"rims": info_auto["scene"].get("rims", []), "eyes": info_auto["scene"].get("eyes", []),
                  "ponds": info_auto["scene"].get("ponds", [])},
        "info": {"night": info["sky"]["night"], "water": info["water"], "pixelArt": info["pixelArt"],
                 "size": info["size"]},
        "mtime": str(sc.scene_mtime(pic)),      # ns: past what a JS number holds exactly
    }


def show_screens():
    """(the connected outputs by name, the ones the user marked as streamed)"""
    names, streamed = [], []
    try:
        r = subprocess.run(["niri", "msg", "--json", "outputs"], capture_output=True, text=True, timeout=5)
        names = sorted(json.loads(r.stdout)) if r.returncode == 0 else []
    except (OSError, ValueError, subprocess.TimeoutExpired):
        pass
    try:
        conf = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "angelos" / "settings.json"
        streamed = [str(n) for n in (json.loads(conf.read_text()).get("stream") or {}).get("screens") or []]
    except (OSError, ValueError, AttributeError):
        pass
    return names, streamed


def make_handler(first):
    class H(BaseHTTPRequestHandler):
        def log_message(self, fmt, *args):
            pass

        def send(self, code, body, ctype="application/json; charset=utf-8"):
            data = body if isinstance(body, bytes) else body.encode()
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(data)

        def json(self, obj, code=200):
            self.send(code, json.dumps(obj, ensure_ascii=False))

        def body(self):
            raw = self.rfile.read(int(self.headers.get("Content-Length") or 0))
            return json.loads(raw or b"{}")

        def pic(self, q):
            return sc.check_picture((q.get("pic") or [""])[0])

        def do_GET(self):
            global last_ping
            u = urlparse(self.path)
            q = parse_qs(u.query)
            p = u.path
            try:
                if p in ("/", "/index.html"):
                    return self.send(200, (HERE / "index.html").read_bytes(), "text/html; charset=utf-8")
                if p in ("/editor.js", "/editor.css"):
                    ctype = "text/javascript" if p.endswith(".js") else "text/css"
                    return self.send(200, (HERE / p[1:]).read_bytes(), ctype + "; charset=utf-8")
                if p == "/api/ping":
                    last_ping = time.time()
                    return self.json({"ok": True})
                if p == "/api/meta":
                    return self.json({
                        "first": first, "layers": [{"id": i, "key": k, "name": n, "what": wh, "rgb": sc.LW.PAINT[i]} for i, k, n, wh in sc.LAYERS],
                        "effects": [{"key": k, "name": n} for k, n in sc.EFFECTS], "points": sc.POINTS})
                if p == "/api/list":
                    return self.json({"pictures": sc.candidates()})
                if p == "/api/scene":
                    return self.json(scene_payload(self.pic(q), (q.get("fmt") or [""])[0] == "rle"))
                if p == "/api/picture":
                    # w: a smaller one for the list of pictures
                    mw = max(64, min(1600, int((q.get("w") or ["1600"])[0])))
                    return self.send(200, sc.picture_small(self.pic(q), mw), "image/png")
                if p == "/api/flood":
                    # the cells of alike colour touching the one at x, y (0…1): the fill tool
                    pic = self.pic(q)
                    w, h = sc.grid_size(pic)
                    shape = {"flood": [float((q.get("x") or ["0"])[0]), float((q.get("y") or ["0"])[0])],
                             "tolerance": max(0.0, min(1.0, float((q.get("tol") or ["0.08"])[0])))}
                    m = sc.shape_mask(pic, shape, w, h)
                    return self.json({"runs": mask_runs(m), "n": int(m.sum())})
                if p == "/api/render":
                    return self.send(200, sc.render(self.pic(q), (q.get("view") or ["final"])[0]), "image/png")
                if p == "/api/state":
                    # what changed since the page looked: the scene (Claude over MCP?), the requests
                    pic = (q.get("pic") or [""])[0]
                    ch = sc.recent_changes(1)
                    return self.json({"mtime": str(sc.scene_mtime(pic)) if pic else "0", "requests": str(sc.requests_mtime()),
                                      "last": ch[-1] if ch else None})
                if p == "/api/requests":
                    return self.json({"requests": sc.requests()[::-1][:50]})
            except ValueError as e:
                return self.json({"error": str(e)}, 400)
            return self.send(404, b"not found", "text/plain")

        def do_PUT(self):
            u = urlparse(self.path)
            q = parse_qs(u.query)
            if u.path != "/api/scene":
                return self.json({"error": "?"}, 404)
            try:
                pic = self.pic(q)
                b = self.body()
                cur = sc.scene_mtime(pic)
                if not b.get("force") and b.get("base") is not None and str(b["base"]) != str(cur):
                    ch = sc.recent_changes(1)
                    return self.json({"error": "conflict", "who": (ch[-1] if ch else {}).get("who", "?")}, 409)
                w, h = sc.grid_size(pic)
                d = sc.load(pic)
                if "paintRle" in b:
                    b["paint"] = True
                if "paint" in b:
                    grid = grid_rle(b["paintRle"], w, h) if "paintRle" in b else grid_b64(b["paint"], w, h) if b["paint"] else None
                    enc = sc.paint_encode(grid) if grid is not None else None
                    if enc:
                        d["paint"] = enc
                    else:
                        d.pop("paint", None)
                for k in ("effects", "rings", "night", "axis", "mirror", "rims", "eyes", "ponds", "lights", "note"):
                    if k in b:
                        if b[k] is None:
                            d.pop(k, None)
                        else:
                            d[k] = b[k]
                sc.save(pic, d, "editor", b.get("what", "правка в редакторе"))
                return self.json({"ok": True, "mtime": str(sc.scene_mtime(pic))})
            except (ValueError, KeyError) as e:
                return self.json({"error": str(e)}, 400)

        def do_POST(self):
            u = urlparse(self.path)
            q = parse_qs(u.query)
            try:
                if u.path == "/api/undo":
                    pic = self.pic(q)
                    ok = sc.undo(pic, "editor")
                    return self.json({"ok": ok, "mtime": str(sc.scene_mtime(pic))})
                if u.path == "/api/requests":
                    b = self.body()
                    return self.json(sc.add_request(b["pic"], b.get("note", ""), b.get("regions", [])))
                if u.path.startswith("/api/requests/"):
                    b = self.body()
                    return self.json(sc.update_request(u.path.rsplit("/", 1)[1], b.get("status"), b.get("reply")))
                if u.path == "/api/poke":
                    # one of the rare events now, on every screen whose scene has it
                    kind = (q.get("kind") or [""])[0]
                    if kind in POKES:
                        subprocess.Popen(["qs", "-c", "angelos", "ipc", "call", "angelos", "liveWall", kind],
                                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
                    return self.json({"ok": kind in POKES})
                if u.path == "/api/show":
                    # the picture on a screen: the one asked for, else the first that is not
                    # streamed (Settings → Stream mode → screens); never a streamed one
                    pic = self.pic(q)
                    names, streamed = show_screens()
                    out = (q.get("screen") or [next((n for n in names if n not in streamed), "")])[0]
                    if not out:
                        return self.json({"error": "нет экрана, который не идёт в эфир / no screen that is off the stream"}, 400)
                    if out in streamed and len(names) > 1:
                        return self.json({"error": out + " — стримовый экран / a streamed screen"}, 400)
                    r = subprocess.run(["qs", "-c", "angelos", "ipc", "call", "angelos", "wallpaperOn", out, str(pic)],
                                       capture_output=True, text=True, timeout=10)
                    said = (r.stdout + r.stderr).strip()
                    return self.json({"ok": r.returncode == 0 and said == "ok", "screen": out, "out": said})
                if u.path == "/api/open":
                    pic = self.pic(q)
                    subprocess.Popen(["xdg-open", str(pic.parent)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
                    return self.json({"ok": True})
            except (ValueError, KeyError, subprocess.TimeoutExpired) as e:
                return self.json({"error": str(e)}, 400)
            return self.json({"error": "?"}, 404)

    return H


def open_window(url):
    for b in ("helium-browser", "chromium", "google-chrome-stable", "brave"):
        if shutil.which(b):
            subprocess.Popen([b, "--app=" + url, "--new-window"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            return
    webbrowser.open(url)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("picture", nargs="?", default="")
    ap.add_argument("--port", type=int, default=0)
    ap.add_argument("--no-open", action="store_true")
    ap.add_argument("--stay", action="store_true", help="don't quit when the page is closed")
    a = ap.parse_args()
    first = ""
    if a.picture:
        try:
            first = str(sc.check_picture(a.picture))
        except ValueError as e:
            sys.exit(str(e))
    srv = ThreadingHTTPServer(("127.0.0.1", a.port), make_handler(first))
    url = "http://127.0.0.1:%d/" % srv.server_address[1] + (("#" + quote(first)) if first else "")
    print(url, flush=True)
    if not a.no_open:
        open_window(url)
    if not a.stay:
        def watchdog():
            time.sleep(90)
            while time.time() - last_ping < 60:
                time.sleep(5)
            srv.shutdown()
        threading.Thread(target=watchdog, daemon=True).start()
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
