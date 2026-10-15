#!/usr/bin/env python3
"""Quick Look for angelOS (services/QuickLook, modules/quicklook/QuickLook).

  quicklook.py serve
      owns org.gnome.NautilusPreviewer (interface NautilusPreviewer2), the name Nautilus
      asks when Space is pressed on a file (GNOME's sushi has it otherwise). JSON lines:
        stdout {"ev":"show","path":"/…","toggle":true}    Nautilus: show this (toggle: Space again)
               {"ev":"close"}                              Nautilus: close
               {"ev":"ready"} / {"ev":"taken"}             the name is ours / someone else has it
        stdin  {"cmd":"visible","v":false}                 the window opened / closed
               {"cmd":"select","dir":"left|right|up|down"} the arrow keys: Nautilus moves on
  quicklook.py info <path>
      what the window needs, one JSON object: kind (image|video|audio|text|pdf|folder|
      archive|font|other), mime, size, modified, and per kind: "picture" (a frame, a page,
      a cover — a PNG made in the runtime dir), "text", "list", "count", "tags", "duration".
"""
import json
import mimetypes
import os
import subprocess
import sys
import threading
import time
import urllib.parse

RUNTIME = os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/tmp", "angelos", "quicklook")
TEXT_MAX = 120_000
LIST_MAX = 400


_out_lock = threading.Lock()  # the bus filter writes from GDBus's thread


def out(obj):
    with _out_lock:
        sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
        sys.stdout.flush()


# ------------------------------------------------------------------ info

TEXT_EXT = {".txt", ".md", ".py", ".js", ".ts", ".qml", ".json", ".kdl", ".toml", ".yaml", ".yml", ".ini", ".conf",
            ".cfg", ".sh", ".fish", ".bash", ".zsh", ".c", ".h", ".cpp", ".hpp", ".rs", ".go", ".java", ".kt", ".lua",
            ".css", ".scss", ".html", ".xml", ".svg", ".csv", ".log", ".desktop", ".service", ".srt", ".ass", ".vtt",
            ".diff", ".patch", ".sql", ".rb", ".php", ".pl", ".tex", ".nix", ".frag", ".vert", ".glsl"}
ARCHIVE_EXT = (".zip", ".tar", ".tar.gz", ".tgz", ".tar.xz", ".txz", ".tar.zst", ".tar.bz2", ".7z", ".rar", ".iso", ".cab", ".jar", ".apk", ".deb", ".rpm", ".pkg.tar.zst")
FONT_EXT = {".ttf", ".otf", ".woff", ".woff2", ".ttc"}


def mime_of(path):
    try:
        r = subprocess.run(["file", "-b", "--mime-type", "-L", path], capture_output=True, text=True, timeout=5)
        m = r.stdout.strip()
        if m:
            return m
    except (OSError, subprocess.SubprocessError):
        pass
    return mimetypes.guess_type(path)[0] or "application/octet-stream"


def picture_path(path, tag):
    os.makedirs(RUNTIME, exist_ok=True)
    st = os.stat(path)
    import hashlib
    key = hashlib.md5(("%s|%d|%d" % (path, int(st.st_mtime), st.st_size)).encode()).hexdigest()[:20]
    # the runtime dir is memory: keep the last couple of hundred pictures
    try:
        olds = sorted((os.path.join(RUNTIME, n) for n in os.listdir(RUNTIME)), key=os.path.getmtime)
        for n in olds[:-200]:
            os.unlink(n)
    except OSError:
        pass
    return os.path.join(RUNTIME, "%s-%s.png" % (key, tag))


def run(cmd, timeout=15):
    try:
        return subprocess.run(cmd, capture_output=True, timeout=timeout)
    except (OSError, subprocess.SubprocessError):
        return None


def info(path):
    path = os.path.abspath(os.path.expanduser(path))
    if not os.path.exists(path):
        return {"error": "missing", "path": path}
    st = os.stat(path)
    d = {"path": path, "name": os.path.basename(path) or path, "modified": int(st.st_mtime)}
    low = path.lower()
    ext = os.path.splitext(low)[1]
    if os.path.isdir(path):
        d["kind"] = "folder"
        try:
            names = sorted(os.listdir(path), key=str.lower)
        except OSError:
            names = []
        d["count"] = len(names)
        d["list"] = [n + ("/" if os.path.isdir(os.path.join(path, n)) else "") for n in names[:LIST_MAX]]
        r = run(["du", "-sb", path], timeout=4)
        d["size"] = int(r.stdout.split()[0]) if r and r.returncode == 0 and r.stdout.split() else -1
        return d
    d["size"] = st.st_size
    mime = mime_of(path)
    d["mime"] = mime
    if mime.startswith("image/") and ext != ".svg" or ext in {".webp", ".avif", ".heic", ".jxl"}:
        d["kind"] = "image"
        d["animated"] = ext in {".gif"} or mime in {"image/gif"}
    elif ext == ".svg":
        d["kind"] = "image"
        d["animated"] = False
    elif mime.startswith("video/"):
        d["kind"] = "video"
        pic = picture_path(path, "frame")
        if not os.path.exists(pic):
            run(["ffmpegthumbnailer", "-i", path, "-o", pic, "-s", "1280", "-t", "15%"], timeout=20)
        if os.path.exists(pic):
            d["picture"] = pic
        d.update(probe(path))
    elif mime.startswith("audio/"):
        d["kind"] = "audio"
        pic = picture_path(path, "cover")
        if not os.path.exists(pic):
            run(["ffmpeg", "-v", "quiet", "-y", "-i", path, "-an", "-frames:v", "1", pic], timeout=10)
        if os.path.exists(pic) and os.path.getsize(pic) > 0:
            d["picture"] = pic
        d.update(probe(path))
    elif mime == "application/pdf":
        d["kind"] = "pdf"
        pic = picture_path(path, "page")
        if not os.path.exists(pic):
            base = pic[:-4]
            run(["pdftoppm", "-png", "-r", "110", "-f", "1", "-l", "1", "-singlefile", path, base], timeout=20)
        if os.path.exists(pic):
            d["picture"] = pic
        r = run(["pdfinfo", path], timeout=5)
        if r and r.returncode == 0:
            for line in r.stdout.decode(errors="replace").splitlines():
                if line.startswith("Pages:"):
                    d["pages"] = int(line.split()[1])
    elif ext in FONT_EXT or mime.startswith("font/") or "font" in mime:
        d["kind"] = "font"
    elif low.endswith(ARCHIVE_EXT) or mime in {"application/zip", "application/x-tar", "application/x-7z-compressed",
                                               "application/vnd.rar", "application/x-rar", "application/gzip",
                                               "application/x-xz", "application/zstd", "application/x-iso9660-image"}:
        d["kind"] = "archive"
        r = run(["bsdtar", "-tf", path], timeout=10)
        names = r.stdout.decode(errors="replace").splitlines() if r and r.returncode == 0 else []
        d["count"] = len(names)
        d["list"] = names[:LIST_MAX]
    elif mime.startswith("text/") or ext in TEXT_EXT or mime in {"application/json", "application/xml", "application/x-shellscript", "application/javascript"}:
        d["kind"] = "text"
        try:
            with open(path, "rb") as f:
                raw = f.read(TEXT_MAX + 1)
            d["text"] = raw[:TEXT_MAX].decode("utf-8", errors="replace")
            d["cut"] = len(raw) > TEXT_MAX
        except OSError as e:
            d["text"] = str(e)
    else:
        d["kind"] = "other"
    return d


def probe(path):
    r = run(["ffprobe", "-v", "quiet", "-print_format", "json", "-show_format", "-show_streams", path], timeout=10)
    if not r or r.returncode != 0:
        return {}
    try:
        j = json.loads(r.stdout)
    except ValueError:
        return {}
    fmt = j.get("format") or {}
    tags = {k.lower(): v for k, v in (fmt.get("tags") or {}).items()}
    d = {"duration": float(fmt.get("duration") or 0)}
    keep = {k: tags[k] for k in ("title", "artist", "album", "date", "genre") if k in tags}
    if keep:
        d["tags"] = keep
    for s in j.get("streams") or []:
        if s.get("codec_type") == "video" and s.get("width") and not (s.get("disposition") or {}).get("attached_pic"):
            d["width"], d["height"] = s["width"], s["height"]
            d["codec"] = s.get("codec_name")
            break
    return d


# ------------------------------------------------------------------ the D-Bus side

XML = """<node>
  <interface name="org.gnome.NautilusPreviewer2">
    <method name="ShowFile">
      <arg type="s" name="uri" direction="in"/>
      <arg type="s" name="window_handle" direction="in"/>
      <arg type="b" name="close_if_already_visible" direction="in"/>
      <arg type="s" name="activation_token" direction="in"/>
    </method>
    <method name="Close"/>
    <property name="Visible" type="b" access="read"/>
    <signal name="SelectionEvent">
      <arg type="u" name="direction"/>
    </signal>
  </interface>
  <interface name="org.gnome.NautilusPreviewer">
    <method name="ShowFile">
      <arg type="s" name="uri" direction="in"/>
      <arg type="i" name="xid" direction="in"/>
      <arg type="b" name="close_if_already_visible" direction="in"/>
    </method>
    <method name="Close"/>
  </interface>
</node>"""

# GtkDirectionType
DIRS = {"left": 4, "right": 5, "up": 2, "down": 3}


SERVICE = os.path.expanduser("~/.local/share/dbus-1/services/org.gnome.NautilusPreviewer.service")


def ensure_activatable(conn):
    """Nautilus (51) offers Space only for a previewer among the bus's *activatable* names,
    so an owned name is not enough: it needs a .service file. Ours only stands in while the
    shell runs (Exec=true: no shell, no preview); with sushi installed, sushi's own file wins."""
    if os.path.exists("/usr/share/dbus-1/services/org.gnome.NautilusPreviewer.service"):
        return
    text = "[D-BUS Service]\nName=org.gnome.NautilusPreviewer\nExec=/usr/bin/true\n"
    try:
        with open(SERVICE) as f:
            if f.read() == text:
                return
    except OSError:
        pass
    os.makedirs(os.path.dirname(SERVICE), exist_ok=True)
    with open(SERVICE, "w") as f:
        f.write(text)
    # the bus reads its service folders again (Nautilus asks it at its start)
    conn.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "ReloadConfig",
                   None, None, 0, -1, None)


def serve():
    import gi
    gi.require_version("Gio", "2.0")
    from gi.repository import Gio, GLib

    state = {"visible": False, "conn": None}
    node = Gio.DBusNodeInfo.new_for_xml(XML)

    def path_of(uri):
        if uri.startswith("file://"):
            return urllib.parse.unquote(urllib.parse.urlparse(uri).path)
        return uri

    def call(conn, sender, obj, iface, method, params, inv):
        if method == "ShowFile":
            uri, _, toggle = params.unpack()
            out({"ev": "show", "path": path_of(uri), "toggle": bool(toggle)})
            inv.return_value(None)
        elif method == "Close":
            out({"ev": "close"})
            inv.return_value(None)
        else:
            inv.return_dbus_error("org.freedesktop.DBus.Error.UnknownMethod", method)

    def get_prop(conn, sender, obj, iface, name):
        if name == "Visible":
            return GLib.Variant("b", state["visible"])
        return None

    def acquired(conn, name):
        try:
            ensure_activatable(conn)
        except Exception as e:  # Space in Nautilus only: the rest works without it
            out({"ev": "warn", "text": "service file: %s" % e})
        out({"ev": "ready"})

    def lost(conn, name):
        out({"ev": "taken"})
        loop.quit()

    # ShowFile's arguments differ by Nautilus (51 adds an activation token; older ones send
    # three), and GDBus refuses a call whose types differ from the XML before our handler
    # sees it — so ShowFile is taken off the bus here, whatever it carries
    def show_filter(conn, msg, incoming):
        if not (incoming and msg.get_message_type() == Gio.DBusMessageType.METHOD_CALL
                and msg.get_path() == "/org/gnome/NautilusPreviewer" and msg.get_member() == "ShowFile"):
            return msg
        body = msg.get_body()
        args = body.unpack() if body is not None else ()
        if args and isinstance(args[0], str):
            out({"ev": "show", "path": path_of(args[0]), "toggle": bool(args[2]) if len(args) > 2 else False})
        conn.send_message(Gio.DBusMessage.new_method_reply(msg), Gio.DBusSendMessageFlags.NONE)
        return None

    def bus(conn, name):
        state["conn"] = conn
        conn.add_filter(show_filter)
        for iface in node.interfaces:
            conn.register_object("/org/gnome/NautilusPreviewer", iface, call, get_prop, None)

    loop = GLib.MainLoop()
    Gio.bus_own_name(Gio.BusType.SESSION, "org.gnome.NautilusPreviewer", Gio.BusNameOwnerFlags.DO_NOT_QUEUE,
                     bus, acquired, lost)

    def stdin_reader():
        for line in sys.stdin:
            try:
                c = json.loads(line)
            except ValueError:
                continue
            if c.get("cmd") == "visible":
                state["visible"] = bool(c.get("v"))
                if state["conn"]:
                    changed = GLib.Variant("(sa{sv}as)", ("org.gnome.NautilusPreviewer2", {"Visible": GLib.Variant("b", state["visible"])}, []))
                    GLib.idle_add(lambda v=changed: state["conn"].emit_signal(None, "/org/gnome/NautilusPreviewer", "org.freedesktop.DBus.Properties", "PropertiesChanged", v) and False)
            elif c.get("cmd") == "select" and c.get("dir") in DIRS and state["conn"]:
                v = GLib.Variant("(u)", (DIRS[c["dir"]],))
                GLib.idle_add(lambda v=v: state["conn"].emit_signal(None, "/org/gnome/NautilusPreviewer", "org.gnome.NautilusPreviewer2", "SelectionEvent", v) and False)
        GLib.idle_add(loop.quit)

    threading.Thread(target=stdin_reader, daemon=True).start()
    loop.run()


def main():
    if len(sys.argv) >= 2 and sys.argv[1] == "serve":
        serve()
        return 0
    if len(sys.argv) >= 3 and sys.argv[1] == "info":
        out(info(sys.argv[2]))
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
