#!/usr/bin/env python3
"""Quick Share for angelOS: the LocalSend v2 protocol, no LocalSend app needed
(services/QuickShare, modules/quickshare/ShareSheet).

  quickshare.py daemon [--alias NAME] [--receive ask|trusted|off] [--dir DIR]
                       [--trusted FP,FP] [--pin PIN] [--port 53317] [--kdeconnect 1]

Talks JSON lines: commands on stdin, events on stdout.

  stdin   {"cmd":"scan"}                                   announce, devices answer
          {"cmd":"send","job":"j1","to":"<fp>","files":[...],"text":"..."}
          {"cmd":"answer","id":"<ask id>","accept":true}
          {"cmd":"cancel","job":"j1"}
          {"cmd":"add","ip":"192.168.1.5","port":53317}          a device by its address
          {"cmd":"clip","items":["/path",...]}                    on the clipboard again
          {"cmd":"config","alias":..,"receive":..,"dir":..,"trusted":[..],"pin":..}
  stdout  {"ev":"ready", "receive": true|false, "busy": "...", "fingerprint", "alias", "ip"}
          {"ev":"device", "fp","alias","ip","port","protocol","type","model"}
          {"ev":"ask", "id","from":{..},"files":[{name,size,type}],"total"}
          {"ev":"text", "from":{..},"text":"...","clip":bool}   (clip: on the clipboard already — trusted only)
          {"ev":"recv", "id","state":"receiving|done|cancelled|declined|expired|error","done","total","paths","items"}
              (items: what came, top level — a folder once, not its files; it is also put
              on the clipboard: files as text/uri-list, one picture as itself, a trusted device's message as text;
              expired: nobody answered the question in time)
          {"ev":"send", "job","state":"pairing|waiting|sending|done|declined|busy|pin|error","done","total","msg"}
          {"ev":"kdc", "state":"ok|missing","why"}       KDE Connect's daemon (--kdeconnect 1)
              (its devices come as "device" too: fp "kdc:<id>", protocol "kdeconnect", "paired", "online")

Discovery: multicast 224.0.0.167:53317; the server: HTTPS on 53317 with a self-signed
certificate kept in ~/.local/share/angelos/quickshare/. When the LocalSend app already
holds the port, this still finds devices and sends (receive is then the app's).
With --kdeconnect 1 the KDE Connect daemon's devices are there too (see its section): a phone with
that app gets files while it is locked, one with LocalSend's does not.
"""
import hashlib
import http.client
import json
import os
import re
import secrets
import socket
import ssl
import struct
import subprocess
import sys
import threading
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

GROUP = "224.0.0.167"
PORT = 53317
API = "/api/localsend/v2"
HOME = os.path.expanduser("~")
STATE = os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.join(HOME, ".local/share"), "angelos/quickshare")
CHUNK = 256 * 1024

out_lock = threading.Lock()


def emit(**ev):
    line = json.dumps(ev, ensure_ascii=False)
    with out_lock:
        sys.stdout.write(line + "\n")
        sys.stdout.flush()


# ------------------------------------------------------------------ identity

def certificate():
    os.makedirs(STATE, exist_ok=True)
    cert, key = os.path.join(STATE, "cert.pem"), os.path.join(STATE, "key.pem")
    if not (os.path.exists(cert) and os.path.exists(key)):
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "3650",
                        "-keyout", key, "-out", cert, "-subj", "/CN=angelOS Quick Share"],
                       check=True, capture_output=True)
        os.chmod(key, 0o600)
    der = ssl.PEM_cert_to_DER_cert(open(cert).read())
    return cert, key, hashlib.sha256(der).hexdigest().upper()


def local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("10.255.255.255", 1))
        return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        s.close()


class State:
    def __init__(self, args):
        self.alias = args.get("alias") or "angelOS " + socket.gethostname()
        self.receive = args.get("receive") or "ask"
        self.dir = os.path.expanduser(args.get("dir") or "~/Downloads/LocalSend")
        self.trusted = set(filter(None, (args.get("trusted") or "").split(",")))
        self.pin = args.get("pin") or ""
        self.port = int(args.get("port") or PORT)
        self.type = args.get("type") or "desktop"     # a stand plays a phone with "mobile"
        self.fingerprint = ""
        self.cert = self.key = ""         # ours: the server's, and shown when we connect
        self.serving = False
        self.devices = {}             # fp → info
        self.asks = {}                # id → {"event", "accept"}
        self.session = None           # the one receive at a time
        self.jobs = {}                # job → {"cancel": bool, "conn"}
        self.lock = threading.Lock()

    def info(self, announce=None):
        d = {"alias": self.alias, "version": "2.1", "deviceModel": "angelOS", "deviceType": self.type,
             "fingerprint": self.fingerprint, "port": self.port, "protocol": "https", "download": False}
        if announce is not None:
            d["announce"] = announce
        return d


S = None
K = None      # KDE Connect (Kdc), None when it is off


# ------------------------------------------------------------------ discovery

def device_seen(info, ip):
    fp = info.get("fingerprint")
    if not fp or fp == S.fingerprint:
        return
    d = {"fp": fp, "alias": info.get("alias") or ip, "ip": ip, "port": int(info.get("port") or PORT),
         "protocol": info.get("protocol") or "https", "type": info.get("deviceType") or "desktop",
         "model": info.get("deviceModel") or ""}
    with S.lock:
        S.devices[fp] = d
    emit(ev="device", **d)


def multicast_socket():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    if hasattr(socket, "SO_REUSEPORT"):
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
    s.bind(("", PORT))
    s.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, struct.pack("4s4s", socket.inet_aton(GROUP), socket.inet_aton("0.0.0.0")))
    s.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 1)
    s.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_LOOP, 0)
    return s


def announce(sock, flag=True):
    try:
        sock.sendto(json.dumps(S.info(announce=flag)).encode(), (GROUP, PORT))
    except OSError:
        pass


def listen_multicast(sock):
    while True:
        try:
            data, (ip, _) = sock.recvfrom(65535)
            msg = json.loads(data)
        except (OSError, ValueError):
            continue
        if not isinstance(msg, dict) or msg.get("fingerprint") == S.fingerprint:
            continue
        device_seen(msg, ip)
        if msg.get("announce") or msg.get("announcement"):
            threading.Thread(target=answer_announce, args=(sock, msg, ip), daemon=True).start()


def answer_announce(sock, msg, ip):
    # the spec: answer by HTTP register; when that fails, a multicast answer
    try:
        req(ip, int(msg.get("port") or PORT), msg.get("protocol") or "https", "POST", API + "/register",
            S.info(), timeout=3)
    except Exception:
        announce(sock, False)


def ctx_client():
    c = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    c.check_hostname = False
    c.verify_mode = ssl.CERT_NONE
    # LocalSend 2.2+ asks the one connecting for a certificate (its fingerprint is who we are):
    # without one the phone ends the handshake ("certificate required") and looks unreachable
    if S and S.cert:
        try:
            c.load_cert_chain(S.cert, S.key)
        except (OSError, ssl.SSLError):
            pass
    return c


def connect(ip, port, protocol, timeout):
    if protocol == "https":
        return http.client.HTTPSConnection(ip, port, timeout=timeout, context=ctx_client())
    return http.client.HTTPConnection(ip, port, timeout=timeout)


def req(ip, port, protocol, method, path, body=None, timeout=10):
    c = connect(ip, port, protocol, timeout)
    try:
        data = json.dumps(body).encode() if body is not None else None
        c.request(method, path, body=data, headers={"Content-Type": "application/json"} if data else {})
        r = c.getresponse()
        raw = r.read()
        try:
            return r.status, json.loads(raw) if raw else None
        except ValueError:
            return r.status, None
    finally:
        c.close()


# ------------------------------------------------------------------ receiving

def safe_path(base, name, dirs=None):
    parts = [p for p in re.split(r"[\\/]+", name) if p not in ("", ".", "..")]
    if not parts:
        parts = ["file"]
    # a folder that is already there gets a new name for this session ("Photos (1)"), not a merge
    if dirs is not None and len(parts) > 1:
        top = parts[0]
        if top not in dirs:
            t, n = top, 1
            while os.path.exists(os.path.join(base, t)):
                t, n = "%s (%d)" % (top, n), n + 1
            dirs[top] = t
        parts[0] = dirs[top]
    path = os.path.join(base, *parts)
    root, ext = os.path.splitext(path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    n = 1
    # the name is taken at once (an empty file, the upload replaces it): two uploads of the same
    # name at a time got one name and the second overwrote the first
    while True:
        try:
            os.close(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644))
            return path
        except FileExistsError:
            path = "%s (%d)%s" % (root, n, ext)
            n += 1


def top_items(base, paths):
    """What came, top level and in order: a folder once, not each of its files."""
    items = []
    for p in paths:
        top = os.path.join(base, os.path.relpath(p, base).split(os.sep)[0])
        if top not in items:
            items.append(top)
    return items


def uri_list(paths):
    """text/uri-list (RFC 2483): file:// URIs, UTF-8 percent-encoded, CRLF after each."""
    return "".join("file://" + urllib.parse.quote(os.path.abspath(p)) + "\r\n" for p in paths)


IMAGES = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".webp": "image/webp", ".gif": "image/gif"}
# what chats can't paste as is: given to the clipboard as a PNG made from it
CONVERT = (".heic", ".heif", ".avif", ".bmp", ".tif", ".tiff")


def clip(data, mime):
    try:
        subprocess.run(["wl-copy", "--type", mime], input=data, timeout=10,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except (OSError, subprocess.SubprocessError):
        pass  # no wl-copy, no Wayland: the files are still there


def clip_items(items):
    """One picture as a picture (pastes into a chat as one), anything else as files."""
    one = items[0] if len(items) == 1 else ""
    ext = os.path.splitext(one)[1].lower()
    mime = IMAGES.get(ext) if os.path.isfile(one) else None
    # shortcut: a picture over 32 MB goes as a file, not as image data
    if mime and os.path.getsize(one) <= 32 * 1024 * 1024:
        with open(one, "rb") as f:
            return clip(f.read(), mime)
    if ext in CONVERT and os.path.isfile(one) and os.path.getsize(one) <= 64 * 1024 * 1024:
        png = to_png(one)
        if png:
            return clip(png, "image/png")
    clip(uri_list(items).encode(), "text/uri-list")


def to_png(path):
    for cmd in (["magick", path + "[0]", "png:-"], ["vips", "copy", path, ".png"]):
        try:
            r = subprocess.run(cmd, capture_output=True, timeout=30)
        except (OSError, subprocess.SubprocessError):
            continue
        if r.returncode == 0 and r.stdout[:8] == b"\x89PNG\r\n\x1a\n":
            return r.stdout
    return None


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *a):
        pass

    def reply(self, code, body=None):
        data = json.dumps(body).encode() if body is not None else b""
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        if data:
            self.wfile.write(data)

    def body_json(self):
        n = int(self.headers.get("Content-Length") or 0)
        if n > 4 * 1024 * 1024:
            return None
        try:
            return json.loads(self.rfile.read(n) or b"{}")
        except ValueError:
            return None

    def body_chunks(self):
        """The upload's bytes as they come: with a Content-Length, or chunked — the LocalSend
        app streams its files chunked with no length (read as 0, that made empty files)."""
        if "chunked" in (self.headers.get("Transfer-Encoding") or "").lower():
            while True:
                line = self.rfile.readline(1024)
                if not line:
                    raise OSError("closed")
                size = int(line.split(b";")[0].strip() or b"0", 16)
                if size == 0:
                    while self.rfile.readline(1024) not in (b"\r\n", b"\n", b""):
                        pass  # the trailers
                    return
                while size > 0:
                    buf = self.rfile.read(min(CHUNK, size))
                    if not buf:
                        raise OSError("closed")
                    size -= len(buf)
                    yield buf
                self.rfile.readline(1024)  # the CRLF after a chunk
        left = int(self.headers.get("Content-Length") or 0)
        while left > 0:
            buf = self.rfile.read(min(CHUNK, left))
            if not buf:
                raise OSError("closed")
            left -= len(buf)
            yield buf

    def route(self):
        u = urllib.parse.urlparse(self.path)
        return u.path.rstrip("/"), dict(urllib.parse.parse_qsl(u.query))

    def do_GET(self):
        path, _ = self.route()
        if path == API + "/info":
            return self.reply(200, S.info())
        self.reply(404)

    def do_POST(self):
        path, q = self.route()
        ip = self.client_address[0]
        if path == API + "/register":
            info = self.body_json() or {}
            device_seen(info, ip)
            return self.reply(200, S.info())
        if path == API + "/prepare-upload":
            return self.prepare(q, ip)
        if path == API + "/upload":
            return self.upload(q)
        if path == API + "/cancel":
            with S.lock:
                sess = S.session
                if sess and sess["id"] == q.get("sessionId"):
                    sess["cancelled"] = True
                    S.session = None
            if sess:
                emit(ev="recv", id=sess["id"], state="cancelled")
            return self.reply(200)
        self.reply(404)

    def prepare(self, q, ip):
        body = self.body_json()
        if not isinstance(body, dict) or not isinstance(body.get("files"), dict):
            return self.reply(400, {"message": "bad request"})
        sender = body.get("info") or {}
        device_seen(sender, ip)
        fp = sender.get("fingerprint", "")
        frm = {"alias": sender.get("alias") or ip, "ip": ip, "type": sender.get("deviceType") or "", "fp": fp}
        if S.receive == "off" or (S.receive == "trusted" and fp not in S.trusted):
            return self.reply(403, {"message": "rejected"})
        if S.pin and q.get("pin") != S.pin:
            return self.reply(401, {"message": "pin"})
        files = body["files"]
        # a message: one text file with its words in the preview — shown, nothing to upload
        if len(files) == 1:
            f = next(iter(files.values()))
            if (f.get("fileType") or "").startswith("text/") and f.get("preview"):
                # any device on the LAN can send one: only a trusted one's goes on the clipboard by
                # itself, any other is only shown (its notification has a button for the clipboard)
                trusted = fp in S.trusted
                emit(ev="text", clip=trusted, **{"from": frm, "text": f["preview"]})
                if trusted:
                    clip(f["preview"].encode(), "text/plain;charset=utf-8")
                return self.reply(204)
        with S.lock:
            if S.session:
                return self.reply(409, {"message": "blocked by another session"})
            S.session = {"id": "pending", "cancelled": False}
        listed = [{"name": f.get("fileName") or "file", "size": int(f.get("size") or 0), "type": f.get("fileType") or ""} for f in files.values()]
        total = sum(f["size"] for f in listed)
        sid = secrets.token_hex(8)
        accept = answered = fp in S.trusted
        if not accept:
            ev = threading.Event()
            S.asks[sid] = {"event": ev, "accept": False}
            emit(ev="ask", id=sid, files=listed, total=total, **{"from": frm})
            answered = ev.wait(120)
            accept = S.asks.pop(sid, {}).get("accept", False)
        if not accept:
            with S.lock:
                S.session = None
            # no answer in time: the shell says so (a late Accept would find no question)
            emit(ev="recv", id=sid, state="declined" if answered else "expired", **{"from": frm})
            return self.reply(403, {"message": "declined"})
        tokens = {fid: secrets.token_hex(8) for fid in files}
        with S.lock:
            S.session = {"id": sid, "files": files, "tokens": tokens, "left": set(files), "done": 0,
                         "total": total, "paths": [], "dirs": {}, "cancelled": False, "from": frm, "last": 0}
        emit(ev="recv", id=sid, state="receiving", done=0, total=total, **{"from": frm})
        self.reply(200, {"sessionId": sid, "files": tokens})

    def upload(self, q):
        sess = S.session
        fid = q.get("fileId")
        if not sess or sess.get("id") != q.get("sessionId") or fid not in sess.get("tokens", {}) or sess["tokens"][fid] != q.get("token"):
            return self.reply(403, {"message": "bad session"})
        meta = sess["files"][fid]
        os.makedirs(S.dir, exist_ok=True)
        path = safe_path(S.dir, meta.get("fileName") or fid, sess["dirs"])
        os.makedirs(os.path.dirname(path), exist_ok=True)
        part = path + ".part"
        want = meta.get("size")
        got = 0
        try:
            with open(part, "wb") as f:
                for buf in self.body_chunks():
                    if sess.get("cancelled"):
                        raise OSError("cancelled")
                    f.write(buf)
                    got += len(buf)
                    sess["done"] += len(buf)
                    now = time.time()
                    if now - sess["last"] > 0.25:
                        sess["last"] = now
                        emit(ev="recv", id=sess["id"], state="receiving", done=sess["done"], total=sess["total"])
            # the size the sender announced: a short file is a broken one, not a received one
            if isinstance(want, int) and want >= 0 and got != want:
                raise OSError("got %d of %d bytes" % (got, want))
            os.replace(part, path)
        except (OSError, ValueError) as e:
            # the half file, and the empty one that held its name (safe_path)
            for p in (part, path):
                try:
                    os.unlink(p)
                except OSError:
                    pass
            # the sending is over: a session left open would refuse every next one (409)
            with S.lock:
                if S.session is sess:
                    S.session = None
            emit(ev="recv", id=sess["id"], state="error", msg=str(e))
            return self.reply(500, {"message": str(e)})
        sess["paths"].append(path)
        sess["left"].discard(fid)
        if not sess["left"]:
            with S.lock:
                S.session = None
            items = top_items(S.dir, sess["paths"])
            clip_items(items)
            emit(ev="recv", id=sess["id"], state="done", done=sess["total"], total=sess["total"], paths=sess["paths"], items=items, **{"from": sess["from"]})
        self.reply(200)


def serve():
    try:
        cert, key, S.fingerprint = certificate()
        S.cert, S.key = cert, key
    except (OSError, subprocess.CalledProcessError) as e:
        S.fingerprint = secrets.token_hex(32).upper()
        return "certificate: %s" % e
    if S.receive == "off":
        return "off"
    try:
        httpd = ThreadingHTTPServer(("0.0.0.0", S.port), Handler)
    except OSError as e:
        return "port %d: %s" % (S.port, e.strerror or e)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(cert, key)
    httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)
    httpd.daemon_threads = True
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    S.serving = True
    return ""


# ------------------------------------------------------------------ sending

def walk(paths):
    """files to send: [(path, name)]; a folder goes with its tree (folder/sub/file)."""
    out = []
    for p in paths:
        p = os.path.expanduser(p)
        if os.path.isdir(p):
            base = os.path.dirname(os.path.abspath(p))
            for root, _, names in os.walk(p):
                for n in sorted(names):
                    full = os.path.join(root, n)
                    out.append((full, os.path.relpath(full, base)))
        elif os.path.isfile(p):
            out.append((p, os.path.basename(p)))
    return out


def mime(path):
    import mimetypes
    return mimetypes.guess_type(path)[0] or "application/octet-stream"


def send(job, to, files, text, pin=""):
    S.jobs[job] = {"cancel": False}
    if to.startswith("kdc:"):
        if not K:
            return emit(ev="send", job=job, state="error", msg="kdeconnect off")
        return kdc_send(job, to[4:], files, text)
    with S.lock:
        d = S.devices.get(to)
    if not d:
        return emit(ev="send", job=job, state="error", msg="device")
    entries, meta = {}, {}
    if text:
        data = text.encode()
        fid = secrets.token_hex(6)
        entries[fid] = {"id": fid, "fileName": "message.txt", "size": len(data), "fileType": "text/plain", "preview": text}
        meta[fid] = ("text", data)
    for path, name in walk(files):
        fid = secrets.token_hex(6)
        # gone since it was picked: the job says so (it waited for ever, the thread dead)
        try:
            st = os.stat(path)
        except OSError as e:
            return emit(ev="send", job=job, state="error", msg=str(e)[:200])
        entries[fid] = {"id": fid, "fileName": name, "size": st.st_size, "fileType": mime(path),
                        "metadata": {"modified": time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(st.st_mtime))}}
        meta[fid] = ("file", path)
    if not entries:
        return emit(ev="send", job=job, state="error", msg="nothing")
    total = sum(e["size"] for e in entries.values())
    emit(ev="send", job=job, state="waiting", done=0, total=total)
    try:
        path = API + "/prepare-upload" + ("?pin=" + urllib.parse.quote(pin) if pin else "")
        code, body = req(d["ip"], d["port"], d["protocol"], "POST", path, {"info": S.info(), "files": entries}, timeout=180)
    except Exception as e:
        return emit(ev="send", job=job, state="error", msg=str(e)[:200])
    if code == 204:
        return emit(ev="send", job=job, state="done", done=total, total=total)
    if code != 200 or not isinstance(body, dict):
        state = {403: "declined", 409: "busy", 401: "pin", 429: "busy"}.get(code, "error")
        return emit(ev="send", job=job, state=state, msg=str(code))
    sid, tokens = body.get("sessionId"), body.get("files") or {}
    done = 0
    last = 0
    for fid, token in tokens.items():
        if fid not in meta:
            continue
        kind, src = meta[fid]
        size = entries[fid]["size"]
        q = urllib.parse.urlencode({"sessionId": sid, "fileId": fid, "token": token})
        c = connect(d["ip"], d["port"], d["protocol"], 60)
        S.jobs[job]["conn"] = c
        try:
            c.putrequest("POST", API + "/upload?" + q)
            c.putheader("Content-Type", "application/octet-stream")
            c.putheader("Content-Length", str(size))
            c.endheaders()
            if kind == "text":
                c.send(src)
                done += size
            else:
                with open(src, "rb") as f:
                    while True:
                        if S.jobs[job]["cancel"]:
                            raise OSError("cancelled")
                        buf = f.read(CHUNK)
                        if not buf:
                            break
                        c.send(buf)
                        done += len(buf)
                        now = time.time()
                        if now - last > 0.25:
                            last = now
                            emit(ev="send", job=job, state="sending", done=done, total=total)
            r = c.getresponse()
            r.read()
            if r.status != 200:
                raise OSError("upload %d" % r.status)
        except Exception as e:
            cancelled = S.jobs[job]["cancel"]
            try:
                req(d["ip"], d["port"], d["protocol"], "POST", API + "/cancel?sessionId=" + urllib.parse.quote(sid), timeout=3)
            except Exception:
                pass
            return emit(ev="send", job=job, state="cancelled" if cancelled else "error", msg=str(e)[:200])
        finally:
            c.close()
    emit(ev="send", job=job, state="done", done=total, total=total)


def add_device(ip, port):
    for proto in ("https", "http"):
        try:
            code, body = req(ip, port, proto, "POST", API + "/register", S.info(), timeout=4)
        except Exception:
            continue
        if code == 200 and isinstance(body, dict):
            body.setdefault("protocol", proto)
            body.setdefault("port", port)
            return device_seen(body, ip)
    emit(ev="error", msg="no device at %s:%d" % (ip, port))


# ------------------------------------------------------------------ KDE Connect
#
# The LocalSend app on a phone sleeps once the phone is locked; the KDE Connect app keeps a service
# and a link to the computer, so files get to the phone any time. With KDE Connect's daemon here
# (package kdeconnect; ports 1714–1764 open: `sudo ufw allow "KDE Connect"`) its devices are the
# sheet's too, fp "kdc:<id>": sending goes through it over D-Bus (it takes the files and sends them
# itself, so no progress here), files from a phone land where it puts them (~/Downloads) and are
# handled as LocalSend's (clipboard, notification); a text from a phone it puts on the clipboard itself.

KDC = "org.kde.kdeconnect"
KDC_ROOT = "/modules/kdeconnect"
KDC_SIGNAL = re.compile(r"^(/modules/kdeconnect\S*): \S+\.(\w+) \((.*)\)\s*$")


class Kdc:
    def __init__(self):
        self.state = ""          # ok | missing (no daemon on the bus, not installed)
        self.why = ""
        self.devs = {}           # id → {"name", "ip", "type", "paired", "online"}
        self.batches = {}        # id → {"paths", "timer"}: the files a phone sends, one after another
        self.kick = threading.Event()
        self.lock = threading.Lock()


def kdc_call(path, iface, method, sig="", *args):
    """A method of the KDE Connect daemon (started by the bus if it is not running): its result."""
    r = subprocess.run(["busctl", "--user", "--json=short", "--timeout=15", "call", KDC, path, iface, method]
                       + ([sig] + [str(a) for a in args] if sig else []), capture_output=True, text=True, timeout=20)
    if r.returncode:
        raise OSError(r.stderr.strip() or "busctl %d" % r.returncode)
    out = r.stdout.strip()
    return json.loads(out)["data"] if out else []


def kdc_status(state, why=""):
    if (K.state, K.why) != (state, why):
        K.state, K.why = state, why
        emit(ev="kdc", state=state, why=why)


def kdc_refresh():
    try:
        ids = kdc_call(KDC_ROOT, KDC + ".daemon", "devices", "bb", "false", "false")[0]
    except (OSError, ValueError, IndexError, subprocess.SubprocessError) as e:
        return kdc_status("missing", str(e)[:200])
    seen = {}
    for did in ids:
        try:
            p = kdc_call(KDC_ROOT + "/devices/" + did, "org.freedesktop.DBus.Properties", "GetAll", "s", KDC + ".device")[0]
        except (OSError, ValueError, IndexError, subprocess.SubprocessError):
            continue
        v = {k: x.get("data") for k, x in p.items()}
        seen[did] = {"name": v.get("name") or did, "ip": (v.get("reachableAddresses") or [""])[0],
                     "type": "mobile" if v.get("type") in ("phone", "tablet") else "desktop",
                     "paired": bool(v.get("isPaired")), "online": bool(v.get("isReachable"))}
    with K.lock:
        old, K.devs = K.devs, seen
    for did, d in seen.items():
        if old.get(did) != d:
            kdc_show(did, d)
    for did, d in old.items():
        if did not in seen:
            kdc_show(did, dict(d, online=False))
    kdc_status("ok")


def kdc_show(did, d):
    emit(ev="device", fp="kdc:" + did, alias=d["name"], ip=d["ip"], port=0, protocol="kdeconnect",
         type=d["type"], model="KDE Connect", paired=d["paired"], online=d["online"])


def kdc_keep():
    # the list again on any of its signals, and every half minute anyway
    while True:
        kdc_refresh()
        K.kick.wait(30)
        K.kick.clear()
        time.sleep(0.3)


def die_with_parent():
    # the monitor goes when the daemon does (a restart of the shell must not leave one behind)
    try:
        import ctypes
        ctypes.CDLL("libc.so.6", use_errno=True).prctl(1, 15)   # PR_SET_PDEATHSIG, SIGTERM
    except (OSError, AttributeError):
        pass


def kdc_watch():
    while True:
        try:
            p = subprocess.Popen(["gdbus", "monitor", "--session", "--dest", KDC], stdout=subprocess.PIPE,
                                 stderr=subprocess.DEVNULL, text=True, preexec_fn=die_with_parent)
        except OSError:
            return
        for line in p.stdout:
            m = KDC_SIGNAL.match(line)
            if not m:
                continue
            path, name, args = m.groups()
            if name == "shareReceived":
                kdc_received(path, args)
            elif name in ("reachableChanged", "pairStateChanged", "nameChanged", "deviceAdded", "deviceRemoved",
                          "deviceVisibilityChanged", "deviceListChanged", "linksChanged"):
                K.kick.set()
        p.wait()
        time.sleep(5)


def kdc_received(path, args):
    """shareReceived('file:///…'): one file of what a phone sends; two quiet seconds end the batch."""
    s = args.strip().rstrip(",").strip()
    if len(s) < 2 or s[0] not in "'\"" or s[-1] != s[0]:
        return
    url = s[1:-1].replace("\\" + s[0], s[0]).replace("\\\\", "\\")
    if not url.startswith("file://"):
        return
    path_ = url[7:]
    if not os.path.exists(path_):
        path_ = urllib.parse.unquote(path_)
    if not os.path.isfile(path_):
        return
    did = path.split("/")[4] if path.count("/") >= 4 else ""
    with K.lock:
        b = K.batches.setdefault(did, {"paths": [], "timer": None})
        if path_ not in b["paths"]:
            b["paths"].append(path_)
        if b["timer"]:
            b["timer"].cancel()
        b["timer"] = threading.Timer(2.0, kdc_batch_done, args=(did,))
        b["timer"].daemon = True
        b["timer"].start()


def kdc_batch_done(did):
    with K.lock:
        b = K.batches.pop(did, None)
        d = K.devs.get(did) or {}
    if not b:
        return
    items = [p for p in b["paths"] if os.path.exists(p)]
    if not items:
        return
    clip_items(items)
    total = sum(os.path.getsize(p) for p in items)
    frm = {"alias": d.get("name") or "KDE Connect", "ip": d.get("ip") or "", "type": d.get("type") or "mobile", "fp": "kdc:" + did}
    emit(ev="recv", id="kdc-" + secrets.token_hex(4), state="done", done=total, total=total, paths=items, items=items, **{"from": frm})


def kdc_send(job, did, files, text):
    base = KDC_ROOT + "/devices/" + did
    d = K.devs.get(did)
    try:
        if not d or not d["online"]:
            return emit(ev="send", job=job, state="error", msg="offline")
        if not d["paired"]:
            # not paired yet: asked on the phone, a minute for its yes
            emit(ev="send", job=job, state="pairing")
            kdc_call(base, KDC + ".device", "requestPairing")
            for _ in range(120):
                time.sleep(0.5)
                if S.jobs[job]["cancel"]:
                    return emit(ev="send", job=job, state="cancelled")
                if kdc_call(base, KDC + ".device", "isPaired")[0]:
                    break
            else:
                return emit(ev="send", job=job, state="declined")
            K.kick.set()
        if text:
            kdc_call(base + "/share", KDC + ".device.share", "shareText", "s", text)
            return emit(ev="send", job=job, state="done", done=len(text), total=len(text))
        paths = [p for p, _ in walk(files)]
        if not paths:
            return emit(ev="send", job=job, state="error", msg="nothing")
        total = sum(os.path.getsize(p) for p in paths)
        urls = ["file://" + urllib.parse.quote(os.path.abspath(p)) for p in paths]
        kdc_call(base + "/share", KDC + ".device.share", "shareUrls", "as", len(urls), *urls)
        emit(ev="send", job=job, state="done", done=total, total=total)
    except (OSError, ValueError, IndexError, subprocess.SubprocessError) as e:
        emit(ev="send", job=job, state="error", msg=str(e)[:200])


def kdc_scan():
    # the sheet is open: the daemon announces itself again (a phone back on the Wi-Fi links at once)
    now = time.time()
    if now - getattr(K, "announced", 0) > 60:
        K.announced = now
        try:
            kdc_call(KDC_ROOT, KDC + ".daemon", "forceOnNetworkChange")
        except (OSError, ValueError, subprocess.SubprocessError):
            pass
    K.kick.set()


# ------------------------------------------------------------------ main loop

def main():
    global S, K
    if len(sys.argv) < 2 or sys.argv[1] != "daemon":
        print(__doc__)
        return 2
    args = {}
    it = iter(sys.argv[2:])
    for a in it:
        if a.startswith("--"):
            args[a[2:]] = next(it, "")
    S = State(args)
    why = serve()
    if args.get("kdeconnect") == "1":
        K = Kdc()
        for fn in (kdc_keep, kdc_watch):
            threading.Thread(target=fn, daemon=True).start()
    try:
        sock = multicast_socket()
    except OSError as e:
        emit(ev="ready", receive=S.serving, busy=why or "multicast: %s" % e, fingerprint=S.fingerprint, alias=S.alias, ip=local_ip())
        sock = None
    else:
        threading.Thread(target=listen_multicast, args=(sock,), daemon=True).start()
        emit(ev="ready", receive=S.serving, busy=why, fingerprint=S.fingerprint, alias=S.alias, ip=local_ip())
        announce(sock)
    for line in sys.stdin:
        try:
            c = json.loads(line)
        except ValueError:
            continue
        cmd = c.get("cmd")
        if cmd == "scan":
            if sock:
                announce(sock)
            if K:
                threading.Thread(target=kdc_scan, daemon=True).start()
        elif cmd == "send":
            threading.Thread(target=send, args=(c.get("job") or "j", c.get("to"), c.get("files") or [], c.get("text") or "", c.get("pin") or ""), daemon=True).start()
        elif cmd == "answer":
            a = S.asks.get(c.get("id"))
            if a:
                a["accept"] = bool(c.get("accept"))
                a["event"].set()
        elif cmd == "add":
            threading.Thread(target=add_device, args=(c.get("ip") or "", int(c.get("port") or PORT)), daemon=True).start()
        elif cmd == "clip":
            items = [p for p in (c.get("items") or []) if os.path.exists(p)]
            if items:
                threading.Thread(target=clip_items, args=(items,), daemon=True).start()
        elif cmd == "cancel":
            j = S.jobs.get(c.get("job"))
            if j:
                j["cancel"] = True
        elif cmd == "config":
            if "alias" in c:
                S.alias = c["alias"] or S.alias
            if "receive" in c:
                S.receive = c["receive"]
            if "dir" in c:
                S.dir = os.path.expanduser(c["dir"] or "~/Downloads/LocalSend")
            if "trusted" in c:
                S.trusted = set(c["trusted"] or [])
            if "pin" in c:
                S.pin = c["pin"] or ""
        elif cmd == "quit":
            break
    return 0


if __name__ == "__main__":
    sys.exit(main())
