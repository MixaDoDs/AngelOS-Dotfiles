"""tests/quickshare/run.sh runs this inside its own network namespace: two quickshare.py
daemons on 53418/53419, each with its own HOME (its own certificate, its own fingerprint)."""
import json
import os
import queue
import shutil
import subprocess
import sys
import tempfile
import threading
import time

DIR = sys.argv[1]
T = tempfile.mkdtemp(prefix="aos-quickshare.")
fails = 0
# a stand-in wl-copy: what would go on the clipboard lands in a log, the real one is never touched
BIN = os.path.join(T, "bin")
CLIP = os.path.join(T, "clip.log")
os.makedirs(BIN)
with open(os.path.join(BIN, "wl-copy"), "w") as f:
    f.write('#!/bin/sh\n{ printf "%%s\\n" "$2"; cat; printf "\\n--end--\\n"; } >> "%s"\n' % CLIP)
os.chmod(os.path.join(BIN, "wl-copy"), 0o755)


def clips():
    """[(type, data)] as the stand-in wl-copy got them."""
    try:
        raw = open(CLIP, "rb").read().decode("utf-8", "replace")
    except OSError:
        return []
    out = []
    for chunk in raw.split("\n--end--\n"):
        if chunk:
            t, _, data = chunk.partition("\n")
            out.append((t, data))
    return out


def check(ok, what):
    global fails
    print(("  ✓ " if ok else "  ✕ ") + what, flush=True)
    fails += not ok


class Daemon:
    def __init__(self, name, port):
        self.home = os.path.join(T, name)
        self.inbox = os.path.join(self.home, "in")
        os.makedirs(self.inbox)
        env = dict(os.environ, HOME=self.home, XDG_DATA_HOME=self.home + "/.local/share",
                   XDG_CONFIG_HOME=self.home + "/.config", PATH=BIN + ":" + os.environ.get("PATH", ""))
        env.pop("WAYLAND_DISPLAY", None)
        self.p = subprocess.Popen(["python3", DIR + "/scripts/quickshare.py", "daemon", "--alias", name,
                                   "--port", str(port), "--dir", self.inbox],
                                  stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, env=env)
        self.q = queue.Queue()
        threading.Thread(target=lambda: [self.q.put(json.loads(l)) for l in self.p.stdout], daemon=True).start()
        self.ready = self.wait(lambda e: e["ev"] == "ready", 30)

    def cmd(self, **c):
        self.p.stdin.write(json.dumps(c) + "\n")
        self.p.stdin.flush()

    def wait(self, pred, timeout=20):
        end = time.time() + timeout
        while time.time() < end:
            try:
                e = self.q.get(timeout=max(0.05, end - time.time()))
            except queue.Empty:
                break
            if pred(e):
                return e
        return None

    def stop(self):
        self.p.kill()   # our own child by its PID
        self.p.wait()


a = b = None
try:
    a, b = Daemon("A", 53418), Daemon("B", 53419)
    check(a.ready and b.ready and a.ready["receive"] and b.ready["receive"]
          and a.ready["fingerprint"] != b.ready["fingerprint"], "both daemons up, each its own fingerprint")
    fp = b.ready["fingerprint"]

    a.cmd(cmd="add", ip="127.0.0.1", port=53419)
    dev = a.wait(lambda e: e["ev"] == "device" and e["fp"] == fp)
    check(dev and dev["port"] == 53419 and dev["alias"] == "B", "add by address finds the other one")

    def sent(job, timeout=30):
        e = a.wait(lambda e: e["ev"] == "send" and e["job"] == job and e["state"] not in ("waiting", "sending"), timeout)
        return e and e["state"]

    a.cmd(cmd="send", job="t", to=fp, text="привет ♡")
    t = b.wait(lambda e: e["ev"] == "text")
    check(t and t["text"] == "привет ♡" and t["from"]["alias"] == "A" and sent("t") == "done", "a text arrives as is")
    check(t and t.get("clip") is False and not any(c[0].startswith("text/plain") for c in clips()), "untrusted text: shown, not on the clipboard")
    b.cmd(cmd="config", trusted=[a.ready["fingerprint"]])
    time.sleep(0.2)
    a.cmd(cmd="send", job="t2", to=fp, text="trusted ♡")
    t = b.wait(lambda e: e["ev"] == "text")
    check(t and t.get("clip") is True and sent("t2") == "done" and ("text/plain;charset=utf-8", "trusted ♡") in clips(), "trusted text: on the clipboard")
    b.cmd(cmd="config", trusted=[])
    time.sleep(0.2)

    src = os.path.join(T, "data.bin")
    blob = os.urandom(700 * 1024 + 13)   # more than two chunks
    open(src, "wb").write(blob)
    folder = os.path.join(T, "folder")
    os.makedirs(folder + "/sub")
    open(folder + "/sub/x.txt", "w").write("x")
    a.cmd(cmd="send", job="f", to=fp, files=[src, folder])
    ask = b.wait(lambda e: e["ev"] == "ask")
    check(ask and sorted(f["name"] for f in ask["files"]) == ["data.bin", "folder/sub/x.txt"]
          and ask["total"] == len(blob) + 1, "the receiver is asked with the names and the size")
    if ask:
        b.cmd(cmd="answer", id=ask["id"], accept=True)
    done = b.wait(lambda e: e["ev"] == "recv" and e.get("state") == "done", 30)
    check(sent("f") == "done" and done is not None, "accepted: the sender and the receiver both say done")
    got = os.path.join(b.inbox, "data.bin")
    check(os.path.isfile(got) and open(got, "rb").read() == blob, "the file came byte for byte")
    x = os.path.join(b.inbox, "folder/sub/x.txt")
    check(os.path.isfile(x) and open(x).read() == "x", "the folder came with its tree")
    want = [os.path.join(b.inbox, "data.bin"), os.path.join(b.inbox, "folder")]
    check(done and done.get("items") == want, "the items: the file and the folder once, not its files")
    check(clips()[-1:] == [("text/uri-list", "".join("file://" + p + "\r\n" for p in want))],
          "the files are on the clipboard as a uri-list (CRLF)")

    a.cmd(cmd="send", job="n", to=fp, files=[src])
    ask = b.wait(lambda e: e["ev"] == "ask")
    if ask:
        b.cmd(cmd="answer", id=ask["id"], accept=False)
    check(ask and sent("n") == "declined" and b.wait(lambda e: e["ev"] == "recv" and e.get("state") == "declined") is not None,
          "a refusal reaches the sender as declined")
    check(sorted(os.listdir(b.inbox)) == ["data.bin", "folder"], "nothing written after the refusal")

    # a trusted device: no question; the same names again get new ones, nothing overwritten
    b.cmd(cmd="config", trusted=[a.ready["fingerprint"]])
    time.sleep(0.2)
    a.cmd(cmd="send", job="tr", to=fp, files=[src, folder])
    done = b.wait(lambda e: e["ev"] in ("ask", "recv") and e.get("state") in (None, "done"), 30)
    check(done and done["ev"] == "recv" and sent("tr") == "done", "a trusted device: received without asking")
    check(open(os.path.join(b.inbox, "data.bin"), "rb").read() == blob
          and open(os.path.join(b.inbox, "data (1).bin"), "rb").read() == blob
          and os.path.isfile(os.path.join(b.inbox, "folder (1)/sub/x.txt")), "the same names again: data (1).bin, folder (1), nothing overwritten")
    png = os.path.join(T, "фото 1.png")
    open(png, "wb").write(b"\x89PNG\r\n\x1a\n" + b"0" * 64)
    a.cmd(cmd="send", job="p", to=fp, files=[png])
    check(sent("p") == "done" and b.wait(lambda e: e["ev"] == "recv" and e.get("state") == "done") is not None
          and clips()[-1][0] == "image/png", "one picture goes on the clipboard as a picture")
    b.cmd(cmd="config", trusted=[])

    # the LocalSend app itself (a phone): it streams each file chunked, with no Content-Length —
    # read as 0 bytes, that once gave empty photos and videos that no app could open
    import http.client
    import ssl as _ssl
    PHONE = "PHONE" + "0" * 59

    def phone(files, bodies, trusted=True):
        b.cmd(cmd="config", trusted=[PHONE] if trusted else [])
        time.sleep(0.2)
        ctx = _ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = _ssl.CERT_NONE
        c = http.client.HTTPSConnection("127.0.0.1", 53419, context=ctx, timeout=20)
        info = {"alias": "Pixel", "version": "2.1", "deviceModel": "Pixel", "deviceType": "mobile",
                "fingerprint": PHONE, "port": 53317, "protocol": "https", "download": False}
        c.request("POST", "/api/localsend/v2/prepare-upload", json.dumps({"info": info, "files": files}),
                  {"Content-Type": "application/json"})
        r = c.getresponse()
        tokens = json.loads(r.read() or b"{}")
        codes = []
        for fid, body in bodies.items():
            q = "sessionId=%s&fileId=%s&token=%s" % (tokens.get("sessionId"), fid, (tokens.get("files") or {}).get(fid))
            # chunked, in pieces of odd sizes, like a stream from the phone's storage
            pieces = [body[i:i + 70001] for i in range(0, len(body), 70001)] or [b""]
            try:
                c.request("POST", "/api/localsend/v2/upload?" + q, iter(pieces), {"Content-Type": "application/octet-stream"},
                          encode_chunked=True)
                rr = c.getresponse()
                rr.read()
                codes.append(rr.status)
            except OSError as e:  # the server hung up mid-file
                codes.append(type(e).__name__)
                c.close()
                c = http.client.HTTPSConnection("127.0.0.1", 53419, context=ctx, timeout=20)
        c.close()
        return r.status, codes

    jpg = b"\xff\xd8\xff\xe0" + os.urandom(900_000) + b"\xff\xd9"
    mp4 = b"\x00\x00\x00\x18ftypmp42" + os.urandom(1_300_000)
    st, codes = phone({"j": {"id": "j", "fileName": "IMG_2026.jpg", "size": len(jpg), "fileType": "image/jpeg"},
                       "v": {"id": "v", "fileName": "VID 2026.mp4", "size": len(mp4), "fileType": "video/mp4"}},
                      {"j": jpg, "v": mp4})
    done = b.wait(lambda e: e["ev"] == "recv" and e.get("state") == "done")
    gj, gv = os.path.join(b.inbox, "IMG_2026.jpg"), os.path.join(b.inbox, "VID 2026.mp4")
    check(st == 200 and codes == [200, 200] and done is not None, "the phone's chunked uploads are taken (no Content-Length)")
    check(os.path.isfile(gj) and open(gj, "rb").read() == jpg and os.path.isfile(gv) and open(gv, "rb").read() == mp4,
          "the photo and the video came whole, byte for byte (not 0 bytes)")
    mimes = subprocess.run(["file", "--brief", "--mime-type", gj, gv], capture_output=True, text=True).stdout.split()
    check(mimes == ["image/jpeg", "video/mp4"], "they are a JPEG and an MP4 again: the default apps take them")
    short = os.urandom(5000)
    st, codes = phone({"s": {"id": "s", "fileName": "short.jpg", "size": 9000, "fileType": "image/jpeg"}}, {"s": short})
    bad = b.wait(lambda e: e["ev"] == "recv" and e.get("state") == "error")
    check(codes == [500] and bad is not None and not os.path.exists(os.path.join(b.inbox, "short.jpg")),
          "a file shorter than announced is an error, not a broken file in the folder")
    # a failed file ends the session: the next sending is not "blocked by another session"
    st, codes = phone({"k": {"id": "k", "fileName": "after.jpg", "size": len(short), "fileType": "image/jpeg"}}, {"k": short})
    check(st == 200 and codes == [200] and b.wait(lambda e: e["ev"] == "recv" and e.get("state") == "done") is not None,
          "after a failed file the next one is taken")
    b.cmd(cmd="config", trusted=[])

    b.cmd(cmd="config", receive="off")
    time.sleep(0.2)
    a.cmd(cmd="send", job="o", to=fp, files=[src])
    check(sent("o") == "declined" and b.wait(lambda e: e["ev"] == "ask", 1) is None, "receive off: refused without asking")
    # LocalSend 2.2 (the phone) wants a certificate from whoever connects: without one the
    # handshake ends ("certificate required") and the phone looked unreachable from here
    import hashlib
    import ssl
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
    seen = {"certs": [], "upload": b""}

    class Phone(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, *x):
            pass

        def do_POST(self):
            seen["certs"].append(hashlib.sha256(self.connection.getpeercert(True)).hexdigest().upper())
            n = int(self.headers.get("Content-Length") or 0)
            data = self.rfile.read(n)
            if "/upload" in self.path:
                seen["upload"] = data
                body = b""
            elif "/prepare-upload" in self.path:
                fid = next(iter(json.loads(data)["files"]))
                body = json.dumps({"sessionId": "s1", "files": {fid: "tok"}}).encode()
            else:
                body = json.dumps({"alias": "Phone 2.2", "version": "2.2", "deviceModel": "Samsung", "deviceType": "mobile",
                                   "fingerprint": "PHONE22", "port": 53420, "protocol": "https", "download": False}).encode()
            self.send_response(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    certs = os.path.join(T, "phone")
    os.makedirs(certs)
    subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1", "-subj", "/CN=LocalSend User",
                    "-keyout", certs + "/key.pem", "-out", certs + "/cert.pem"], check=True, capture_output=True)
    sctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    sctx.load_cert_chain(certs + "/cert.pem", certs + "/key.pem")
    sctx.verify_mode = ssl.CERT_REQUIRED
    sctx.load_verify_locations(a.home + "/.local/share/angelos/quickshare/cert.pem")  # self-signed: trust a's own
    ph = ThreadingHTTPServer(("127.0.0.1", 53420), Phone)
    ph.socket = sctx.wrap_socket(ph.socket, server_side=True)
    threading.Thread(target=ph.serve_forever, daemon=True).start()
    a.cmd(cmd="add", ip="127.0.0.1", port=53420)
    check(a.wait(lambda e: e["ev"] == "device" and e["fp"] == "PHONE22") is not None,
          "a LocalSend 2.2 phone that wants a client certificate is found")
    a.cmd(cmd="send", job="m", to="PHONE22", files=[src])
    check(sent("m") == "done" and seen["upload"] == open(src, "rb").read(), "and it gets the file")
    check(seen["certs"] and set(seen["certs"]) == {a.ready["fingerprint"]},
          "the certificate shown is the one our fingerprint names")
    ph.shutdown()

    # the uri-list itself: spaces and Cyrillic percent-encoded (UTF-8), CRLF after each
    sys.path.insert(0, DIR + "/scripts")
    import quickshare
    heic = os.path.join(T, "photo.heic")
    if shutil.which("magick") and subprocess.run(["magick", "-size", "16x16", "xc:red", heic], capture_output=True).returncode == 0:
        png = quickshare.to_png(heic)
        check(bool(png) and png[:4] == b"\x89PNG", "a HEIC photo goes on the clipboard as a PNG")
    check(quickshare.uri_list(["/tmp/x y/Фото.jpg", "/tmp/a#b"]) == "file:///tmp/x%20y/%D0%A4%D0%BE%D1%82%D0%BE.jpg\r\nfile:///tmp/a%23b\r\n",
          "uri-list: spaces, Cyrillic and # encoded")
finally:
    for d in (a, b):
        if d:
            d.stop()
    shutil.rmtree(T, ignore_errors=True)

print("» quickshare: %s" % ("FAILED" if fails else "all good"))
sys.exit(1 if fails else 0)
