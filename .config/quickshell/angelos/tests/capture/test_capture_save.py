#!/usr/bin/env python3
"""scripts/capture_save.py against stand-ins: wl-copy, notify-send, xdg-open, gdbus and pw-play
write what they were given into files; the owner's clipboard and notifications stay untouched.
  test_capture_save.py <angelOS dir> [script]   (script: another capture_save.py, to see the test fail)"""
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

import numpy as np
from PIL import Image

DIR = sys.argv[1]
SCRIPT = sys.argv[2] if len(sys.argv) > 2 else DIR + "/scripts/capture_save.py"
T = tempfile.mkdtemp(prefix="capture-test-")
BIN, LOG = os.path.join(T, "bin"), os.path.join(T, "log")
os.makedirs(BIN)
os.makedirs(LOG)
fails = 0


def check(ok, what):
    global fails
    print(("  ✓ " if ok else "  ✕ ") + what, flush=True)
    fails += not ok


def stub(name, body):
    p = os.path.join(BIN, name)
    with open(p, "w") as f:
        f.write("#!/bin/sh\n" + body + "\n")
    os.chmod(p, 0o755)


# wl-copy: the type and the bytes; notify-send: its arguments, the click it "gets" from $CLICK
stub("wl-copy", 'n=$(date +%s%N); printf "%s" "$2" > "' + LOG + '/clip-$n.type"; cat > "' + LOG + '/clip-$n.data"')
# (each log is written aside and renamed in: a check never reads one half written)
put = lambda kind: '> "' + LOG + '/.$$" && mv "' + LOG + '/.$$" "' + LOG + '/' + kind + '-$(date +%s%N)"'
stub("notify-send", 'printf "%s\\n" "$@" ' + put("notify") + '; [ -n "$CLICK" ] && echo "$CLICK"; exit 0')
stub("xdg-open", 'printf "%s" "$1" ' + put("open"))
stub("gdbus", 'printf "%s\\n" "$@" ' + put("gdbus"))
stub("pw-play", 'printf "%s" "$*" ' + put("sound"))


def env(**cfg):
    home = os.path.join(T, "home")
    conf = os.path.join(home, ".config", "angelos")
    os.makedirs(conf, exist_ok=True)
    cfg.setdefault("shotDir", os.path.join(T, "shots"))
    with open(os.path.join(conf, "settings.json"), "w") as f:
        json.dump({"capture": cfg}, f)
    e = dict(os.environ, HOME=home, XDG_CONFIG_HOME=home + "/.config", PATH=BIN + ":" + os.environ["PATH"],
             XDG_RUNTIME_DIR=os.path.join(T, "run"))
    e.pop("WAYLAND_DISPLAY", None)
    e.pop("CLICK", None)
    return e


def run(args, e):
    r = subprocess.run(["python3", SCRIPT] + args, capture_output=True, text=True, env=e, timeout=30)
    try:
        return r.returncode, json.loads(r.stdout.strip().splitlines()[-1])
    except (ValueError, IndexError):
        return r.returncode, {}


def logs(kind, wait=0.0):
    end = time.time() + wait
    while True:
        got = sorted(f for f in os.listdir(LOG) if f.startswith(kind + "-"))
        if got or time.time() >= end:
            return [os.path.join(LOG, f) for f in got]
        time.sleep(0.05)


def clear():
    # a saved shot's notification runs detached: let it land before the next check starts
    time.sleep(0.4)
    for f in os.listdir(LOG):
        os.unlink(os.path.join(LOG, f))


def clips():
    return [(open(t).read(), open(t[:-5] + ".data", "rb").read()) for t in logs("clip") if t.endswith(".type")]


try:
    # a frame like grim's: P6 .ppm, every pixel different (a shift by one shows)
    h, w = 300, 400
    yy, xx = np.mgrid[0:h, 0:w]
    px = np.stack([xx % 256, yy % 256, (xx * 7 + yy * 13) % 256], axis=-1).astype(np.uint8)
    frame = os.path.join(T, "frame.ppm")
    Image.fromarray(px).save(frame)
    with open(frame, "rb") as f:
        check(f.read(2) == b"P6", "the test frame is a P6 .ppm, as grim writes it")

    e = env()
    rc, out = run(["save", frame, "--rect", "37,51,120,90"], e)
    path = out.get("path", "")
    month = time.strftime("%Y-%m")
    check(rc == 0 and os.path.isfile(path), "saved")
    check(os.path.basename(os.path.dirname(path)).startswith(month) and os.path.dirname(os.path.dirname(path)) == os.path.join(T, "shots"),
          "into <shots>/<month folder> (screenshot-sort.py)")
    check(re.fullmatch(r"Screenshot from \d{4}-\d\d-\d\d \d\d-\d\d-\d\d\.png", os.path.basename(path)) is not None,
          "the old name: Screenshot from YYYY-MM-DD HH-MM-SS.png")
    got = np.asarray(Image.open(path).convert("RGB")) if os.path.isfile(path) else None
    check(got is not None and got.shape == (90, 120, 3) and np.array_equal(got, px[51:141, 37:157]),
          "the part is exact, pixel for pixel")
    c = clips()
    check(len(c) == 1 and c[0][0] == "image/png" and c[0][1] == open(path, "rb").read(),
          "on the clipboard: the same PNG (capture.shotCopy is on by default)")
    n = logs("notify", 3)
    args = open(n[0]).read().splitlines() if n else []
    check(args[:2] == ["-a", "Screenshot"] and "Скриншот сохранён" in args and path in args
          and "open=Открыть" in args and "folder=Показать в папке" in args and "--wait" in args,
          "the notification: app Screenshot (the shell's shutter sound and achievement), Open, Show in folder")
    check(not os.path.exists(path + ".part") and not logs("open"), "no half file left, not opened (shotOpen off)")

    clear()
    rc2, out2 = run(["save", frame, "--rect", "37,51,120,90"], e)
    check(out2.get("path") != path and os.path.isfile(out2.get("path", "")), "two shots in one second: two files, none overwritten")

    clear()
    rc, out = run(["save", frame], e)
    whole = np.asarray(Image.open(out["path"]).convert("RGB")) if out.get("path") else None
    check(whole is not None and np.array_equal(whole, px), "no part: the whole frame")

    clear()
    rc, out = run(["save", frame, "--rect", "0,0,50,40", "--no-copy"], e)
    check(os.path.isfile(out.get("path", "")) and not clips() and out.get("copied") is False, "--no-copy: saved, the clipboard left alone")

    clear()
    rc, out = run(["save", frame, "--rect", "0,0,50,40"], env(shotCopy=False))
    check(os.path.isfile(out.get("path", "")) and not clips(), "capture.shotCopy off: not copied")

    clear()
    before = sum(len(fs) for _, _, fs in os.walk(os.path.join(T, "shots")))
    rc, out = run(["save", frame, "--rect", "10,20,30,40", "--no-save"], e)
    after = sum(len(fs) for _, _, fs in os.walk(os.path.join(T, "shots")))
    c = clips()
    cp = np.asarray(Image.open(io.BytesIO(c[0][1])).convert("RGB")) if c else None
    check(after == before and out.get("path") == "" and cp is not None and np.array_equal(cp, px[20:60, 10:40]) and not logs("notify", 0.5),
          "--no-save: only the clipboard, no file, no notification")

    clear()
    rc, out = run(["copy", frame, "--rect", "5,6,7,8"], e)
    c = clips()
    cp = np.asarray(Image.open(io.BytesIO(c[0][1])).convert("RGB")) if c else None
    check(rc == 0 and out.get("copied") and c and c[0][0] == "image/png" and cp is not None and np.array_equal(cp, px[6:14, 5:12]),
          "copy: the part on the clipboard as image/png, exact")

    clear()
    rc, out = run(["save", frame, "--rect", "0,0,40,30"], env(shotFormat="jpg"))
    p = out.get("path", "")
    check(p.endswith(".jpg") and open(p, "rb").read(3) == b"\xff\xd8\xff" and clips() and clips()[0][0] == "image/jpeg",
          "capture.shotFormat jpg: a .jpg, copied as image/jpeg")

    clear()
    rc, out = run(["save", frame, "--rect", "0,0,40,30"], env(shotOpen=True))
    o = logs("open", 3)
    check(o and open(o[0]).read() == out.get("path"), "capture.shotOpen: opened in the viewer")

    # the notification's buttons do what they say
    for click, kind, want in (("open", "open", lambda p, s: s == p), ("folder", "gdbus", lambda p, s: "ShowItems" in s and os.path.basename(p).replace(" ", "%20") in s)):
        clear()
        e2 = env()
        e2["CLICK"] = click
        rc, out = run(["save", frame, "--rect", "0,0,40,30"], e2)
        f = logs(kind, 5)
        check(f and want(out.get("path", ""), open(f[0]).read()), "the notification's «%s» works" % ("Открыть" if click == "open" else "Показать в папке"))

    clear()
    rc, out = run(["save", frame, "--rect", "500,500,10,10"], e)
    check(rc != 0 and "error" in out and not clips(), "a part outside the frame: an error, nothing saved or copied")
finally:
    shutil.rmtree(T, ignore_errors=True)
sys.exit(1 if fails else 0)
