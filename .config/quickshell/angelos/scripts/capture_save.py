#!/usr/bin/env python3
"""A shot from the screenshot overlay (services/Capture.saveShot / copyShot): the frozen frame
(grim's .ppm, or any picture Pillow reads), cut to the picked part, kept like the old region
tool (~/.local/bin/niri-screenshot-region) kept it:

  capture_save.py save <frame> [--rect x,y,w,h] [--copy|--no-copy] [--no-save] [--open] [--quiet] [--private]
      <shots>/<month>/Screenshot from %Y-%m-%d %H-%M-%S.png (jpg q92 with capture.shotFormat jpg;
      the month folder by screenshot-sort.py), on the clipboard (capture.shotCopy, default on),
      opened (capture.shotOpen), the notification (it brings the shutter sound) "Скриншот сохранён" from app
      "Screenshot" (angelOS plays its shutter sound and counts the achievement from that name)
      with Open / Show in folder (/ Edit when satty or swappy is there).
      prints {"path": "...", "copied": bool}
  capture_save.py copy <frame> [--rect x,y,w,h] [--out <png>]
      only the picture on the clipboard (image/png), nothing kept in the folders; --out: the PNG
      also there (the corner's thumbnail and its editor, services/ShotEdit);
      prints {"copied": bool, "path": <png or "">}
"""
import io
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))


def settings():
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    try:
        with open(os.path.join(base, "angelos/settings.json")) as f:
            return json.load(f).get("capture") or {}
    except (OSError, ValueError):
        return {}


def cut(frame, rect):
    from PIL import Image
    im = Image.open(frame)
    im.load()
    if rect:
        x, y, w, h = rect
        x, y = max(0, x), max(0, y)
        w, h = min(w, im.width - x), min(h, im.height - y)
        if w < 1 or h < 1:
            raise ValueError("the part is outside the frame")
        im = im.crop((x, y, x + w, y + h))
    return im.convert("RGB")


def encode(im, jpg):
    b = io.BytesIO()
    if jpg:
        im.save(b, "JPEG", quality=92)
    else:
        im.save(b, "PNG", compress_level=3)  # 1080×1920 in ~0.1 s, a little bigger than level 6
    return b.getvalue()


def month_dir():
    """<shots>/<2026-10 Октябрь> as screenshot-sort.py makes them, else <shots>."""
    try:
        out = subprocess.run(["python3", os.path.join(HERE, "screenshot-sort.py"), "dir"],
                             capture_output=True, text=True, timeout=3).stdout.strip()
        if out and os.path.isdir(out):
            return out
    except (OSError, subprocess.SubprocessError):
        pass
    d = os.path.expanduser(settings().get("shotDir") or "~/Pictures/Screenshots")
    os.makedirs(d, exist_ok=True)
    return d


def free_name(d, stamp, ext):
    """The old tool's name; a second shot in the same second gets " (2)". The name is taken at
    once (an empty file, the picture replaces it): two saves in one second took one name and
    the second overwrote the first."""
    path = os.path.join(d, f"Screenshot from {stamp}.{ext}")
    n = 2
    while True:
        try:
            os.close(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644))
            return path
        except FileExistsError:
            path = os.path.join(d, f"Screenshot from {stamp} ({n}).{ext}")
            n += 1


def copy(data, mime):
    try:
        return subprocess.run(["wl-copy", "--type", mime], input=data, timeout=5).returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def editor():
    return next((e for e in ("satty", "swappy") if shutil.which(e)), "")


def notify_and_wait(path, private=False):
    """The notification with its buttons; runs on its own (detached), acts on the click.
    private: a camera icon, not the picture (privacy on stream hides apps it may show)."""
    # `timeout`: the shell's restart takes this python away but left notify-send waiting for
    # hours (6 of them, the oldest 14 h, 16.10); now it gives up on its own as well
    args = ["timeout", "900", "notify-send", "-a", "Screenshot", "-i", "camera-photo" if private else path, "-A", "open=Открыть", "-A", "folder=Показать в папке"]
    ed = editor()
    if ed:
        args += ["-A", "edit=Править"]
    args += ["--wait", "Скриншот сохранён", path]
    try:
        # angelOS's popup only hides at its timeout (the notification stays open), so --wait
        # never ended: the buttons give up after 15 minutes
        act = subprocess.run(args, capture_output=True, text=True, timeout=905).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return
    if act == "open":
        subprocess.Popen(["xdg-open", path], start_new_session=True)
    elif act == "folder":
        uri = "file://" + urllib.parse.quote(path)
        r = subprocess.run(["gdbus", "call", "--session", "--dest", "org.freedesktop.FileManager1",
                            "--object-path", "/org/freedesktop/FileManager1", "--method",
                            "org.freedesktop.FileManager1.ShowItems", "['%s']" % uri.replace("'", "%27"), ""],
                           capture_output=True)
        if r.returncode != 0:
            subprocess.Popen(["xdg-open", os.path.dirname(path)], start_new_session=True)
    elif act == "edit" and ed:
        cmd = ["satty", "--filename", path, "--output-filename", path] if ed == "satty" else ["swappy", "-f", path, "-o", path]
        subprocess.Popen(cmd, start_new_session=True)


def parse(argv):
    o = {"rect": None, "copy": None, "save": True, "open": None, "quiet": False, "private": False, "out": ""}
    it = iter(argv)
    for a in it:
        if a == "--rect":
            o["rect"] = [int(round(float(v))) for v in next(it).split(",")]
        elif a in ("--copy", "--no-copy"):
            o["copy"] = a == "--copy"
        elif a == "--no-save":
            o["save"] = False
        elif a == "--open":
            o["open"] = True
        elif a == "--quiet":
            o["quiet"] = True
        elif a == "--private":
            o["private"] = True
        elif a == "--out":
            o["out"] = next(it)
    return o


def main(argv):
    if len(argv) < 2 or argv[0] not in ("save", "copy", "notify"):
        print(__doc__)
        return 2
    cmd, frame, o = argv[0], argv[1], parse(argv[2:])
    if cmd == "notify":  # the detached half of "save"
        notify_and_wait(frame, o["private"])
        return 0
    cfg = settings()
    jpg = cfg.get("shotFormat") == "jpg" and cmd == "save" and o["save"]
    try:
        im = cut(frame, o["rect"])
    except (OSError, ValueError) as e:
        if cmd == "save":
            subprocess.run(["notify-send", "-a", "Screenshot", "Ошибка скриншота", str(e)])
        print(json.dumps({"error": str(e)}))
        return 1
    if cmd == "copy":
        data = encode(im, False)
        path = ""
        if o["out"]:
            try:
                os.makedirs(os.path.dirname(o["out"]), exist_ok=True)
                with open(o["out"] + ".part", "wb") as f:
                    f.write(data)
                os.replace(o["out"] + ".part", o["out"])
                path = o["out"]
            except OSError:
                pass
        print(json.dumps({"copied": copy(data, "image/png"), "path": path}))
        return 0
    data = encode(im, jpg)
    want_copy = cfg.get("shotCopy", True) if o["copy"] is None else o["copy"]
    path = ""
    if o["save"]:
        # a full disk, a folder gone: said like a bad frame (an empty answer told the shell nothing)
        try:
            path = free_name(month_dir(), time.strftime("%Y-%m-%d %H-%M-%S"), "jpg" if jpg else "png")
            with open(path + ".part", "wb") as f:
                f.write(data)
            os.replace(path + ".part", path)
        except OSError as e:
            for p in (path + ".part", path) if path else ():
                try:
                    os.unlink(p)
                except OSError:
                    pass
            subprocess.run(["notify-send", "-a", "Screenshot", "Ошибка скриншота", str(e)])
            print(json.dumps({"error": str(e)}))
            return 1
    copied = copy(data, "image/jpeg" if jpg else "image/png") if want_copy or not o["save"] else False
    # no pling here: the notification brings the "screenshot" sound (services/Notifs → Sounds),
    # at the shell's volume and quiet with its quiet hours and stream mode; this one was a second,
    # louder sound past all of them
    if path and not o["quiet"]:
        if cfg.get("shotOpen") if o["open"] is None else o["open"]:
            subprocess.Popen(["xdg-open", path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        subprocess.Popen([sys.executable, os.path.abspath(__file__), "notify", path] + (["--private"] if o["private"] else []),
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    print(json.dumps({"path": path, "copied": copied}))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
