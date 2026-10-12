#!/usr/bin/env python3
"""Who is in your Discord call, for the desktop widget (services/DiscordVoice, widget «Discord»).
Talks to the Discord app on this machine through its local RPC socket (ws://127.0.0.1:6463…),
as OBS's Discord StreamKit overlay and discover-overlay do: StreamKit's client id, its token
exchange (streamkit.discord.com). No app of your own, no keys; the first time Discord asks you
once to allow it. Prints one JSON line per change:

  {"state": "no-discord" | "auth" | "authorizing" | "idle" | "call",
   "channel": "General", "users": [{"id", "name", "avatar": "/path.png" | "", "speaking",
   "muted", "deaf"}], "error": ""}

stdin: "auth" — ask Discord for the permission (the widget's button), "forget" — drop the token.
The token is kept in ~/.local/state/angelos/discord-rpc.json (0600), the avatars in
~/.cache/angelos/discord-avatars/.

  discord-voice.py
  discord-voice.py --self-test      the protocol against a stand-in Discord (no network)
"""
import base64
import json
import os
import select
import socket
import struct
import sys
import threading
import time
import urllib.request
import uuid
from pathlib import Path

CLIENT_ID = "207646673902501888"            # Discord StreamKit
ORIGIN = "https://streamkit.discord.com"
TOKEN_URL = "https://streamkit.discord.com/overlay/token"
PORTS = range(6463, 6473)
HOME = Path.home()
TOKEN_FILE = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "angelos/discord-rpc.json"
AVATARS = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "angelos/discord-avatars"


# ---- a WebSocket client, just enough for Discord's local RPC (text frames, ping/pong, close) ----
class WS:
    def __init__(self, sock):
        self.sock, self.buf = sock, b""

    @classmethod
    def connect(cls, port, timeout=2):
        s = socket.create_connection(("127.0.0.1", port), timeout=timeout)
        key = base64.b64encode(os.urandom(16)).decode()
        s.sendall((f"GET /?v=1&client_id={CLIENT_ID} HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nUpgrade: websocket\r\n"
                   f"Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\nOrigin: {ORIGIN}\r\n\r\n").encode())
        head = b""
        while b"\r\n\r\n" not in head:
            chunk = s.recv(4096)
            if not chunk:
                raise ConnectionError("closed during the handshake")
            head += chunk
        status = head.split(b"\r\n", 1)[0]
        if b" 101 " not in status + b" ":
            raise ConnectionError(status.decode(errors="replace"))
        ws = cls(s)
        ws.buf = head.split(b"\r\n\r\n", 1)[1]
        s.settimeout(None)
        return ws

    def fileno(self):
        return self.sock.fileno()

    def _frame(self, op, data):
        head = bytes([0x80 | op])
        n = len(data)
        head += bytes([0x80 | n]) if n < 126 else bytes([0x80 | 126]) + struct.pack(">H", n) if n < 65536 else bytes([0x80 | 127]) + struct.pack(">Q", n)
        mask = os.urandom(4)
        self.sock.sendall(head + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))

    def send(self, obj):
        self._frame(1, json.dumps(obj).encode())

    def _need(self, n):
        while len(self.buf) < n:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise ConnectionError("Discord closed the connection")
            self.buf += chunk
        out, self.buf = self.buf[:n], self.buf[n:]
        return out

    def recv(self):
        """the next message as JSON (pings answered on the way)"""
        parts = []
        while True:
            b0, b1 = self._need(2)
            n = b1 & 0x7F
            if n == 126:
                n = struct.unpack(">H", self._need(2))[0]
            elif n == 127:
                n = struct.unpack(">Q", self._need(8))[0]
            mask = self._need(4) if b1 & 0x80 else None
            data = self._need(n)
            if mask:
                data = bytes(b ^ mask[i % 4] for i, b in enumerate(data))
            op = b0 & 0x0F
            if op == 9:
                self._frame(10, data)
                continue
            if op == 8:
                raise ConnectionError("Discord closed the connection: " + data[2:].decode(errors="replace"))
            if op in (0, 1, 2):
                parts.append(data)
                if b0 & 0x80:
                    return json.loads(b"".join(parts))

    def pending(self):
        return bool(self.buf)

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass


# ---- the token ----
def load_token():
    try:
        return json.loads(TOKEN_FILE.read_text()).get("access_token") or ""
    except (OSError, ValueError, AttributeError):
        return ""


def save_token(token):
    TOKEN_FILE.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(TOKEN_FILE, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump({"access_token": token, "saved": int(time.time())}, f)


def exchange(code):
    req = urllib.request.Request(TOKEN_URL, data=json.dumps({"code": code}).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "angelOS-discord-voice/1"})
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.loads(r.read(65536))["access_token"]


# ---- avatars: fetched once, in the background ----
def avatar_url(user):
    if user.get("avatar"):
        return f"https://cdn.discordapp.com/avatars/{user['id']}/{user['avatar']}.png?size=64"
    try:
        n = (int(user["id"]) >> 22) % 6
    except (KeyError, ValueError):
        n = 0
    return f"https://cdn.discordapp.com/embed/avatars/{n}.png"


def avatar_path(user):
    return AVATARS / f"{user.get('id', 'x')}-{user.get('avatar') or 'default'}.png"


class Voice:
    """the call as Discord tells it → the lines the widget reads"""

    def __init__(self, out, fetch=True):
        self.out, self.fetch = out, fetch
        self.state, self.channel, self.channel_id, self.error = "no-discord", "", "", ""
        self.users = {}                 # id → user line
        self.order = []
        self._last = None
        self._fetching = set()
        self.lock = threading.Lock()

    def emit(self):
        with self.lock:
            line = json.dumps({"state": self.state, "channel": self.channel, "error": self.error,
                               "users": [self.users[i] for i in self.order if i in self.users]}, ensure_ascii=False)
            if line != self._last:
                self._last = line
                self.out(line)

    def set(self, state, error=""):
        self.state, self.error = state, error
        if state != "call":
            self.channel, self.channel_id, self.users, self.order = "", "", {}, []
        self.emit()

    def _avatar(self, user):
        p = avatar_path(user)
        if p.is_file():
            return str(p)
        if self.fetch and p not in self._fetching:
            self._fetching.add(p)
            threading.Thread(target=self._download, args=(user, p), daemon=True).start()
        return ""

    def _download(self, user, p):
        try:
            req = urllib.request.Request(avatar_url(user), headers={"User-Agent": "angelOS-discord-voice/1"})
            with urllib.request.urlopen(req, timeout=15) as r:
                data = r.read(2 * 1024 * 1024)
            AVATARS.mkdir(parents=True, exist_ok=True)
            tmp = p.with_suffix(".tmp")
            tmp.write_bytes(data)
            os.replace(tmp, p)
        except OSError:
            return
        with self.lock:
            u = self.users.get(user.get("id"))
            if u is not None:
                u["avatar"] = str(p)
        self.emit()

    def put(self, vs):
        user = vs.get("user") or {}
        uid = user.get("id")
        if not uid:
            return
        st = vs.get("voice_state") or {}
        old = self.users.get(uid, {})
        self.users[uid] = {
            "id": uid,
            "name": vs.get("nick") or user.get("global_name") or user.get("username") or "?",
            "avatar": self._avatar(user),
            "speaking": old.get("speaking", False),
            "muted": bool(st.get("mute") or st.get("self_mute") or st.get("suppress")),
            "deaf": bool(st.get("deaf") or st.get("self_deaf")),
        }
        if uid not in self.order:
            self.order.append(uid)

    def channel_in(self, ch):
        self.users, self.order = {}, []
        if not ch:
            self.set("idle")
            return
        self.channel, self.channel_id = ch.get("name") or "", ch.get("id") or ""
        for vs in ch.get("voice_states") or []:
            self.put(vs)
        self.state, self.error = "call", ""
        self.emit()

    def event(self, evt, data):
        data = data or {}
        if evt in ("VOICE_STATE_CREATE", "VOICE_STATE_UPDATE"):
            self.put(data)
        elif evt == "VOICE_STATE_DELETE":
            uid = (data.get("user") or {}).get("id")
            self.users.pop(uid, None)
            self.order = [i for i in self.order if i != uid]
        elif evt in ("SPEAKING_START", "SPEAKING_STOP"):
            u = self.users.get(data.get("user_id"))
            if u:
                u["speaking"] = evt == "SPEAKING_START"
        else:
            return
        self.emit()


class Session:
    """one connection to Discord: READY → AUTHENTICATE (or AUTHORIZE) → the call, then its events"""

    def __init__(self, ws, voice, stdin=None, token_io=(load_token, save_token), exchange_code=exchange):
        self.ws, self.voice, self.stdin = ws, voice, stdin
        self.load, self.save = token_io
        self.exchange = exchange_code
        self.waiting = {}               # nonce → command
        self.subscribed = []            # (evt, channel_id)
        self.authorized = False

    def cmd(self, cmd, args=None, evt=None):
        nonce = str(uuid.uuid4())
        msg = {"cmd": cmd, "args": args or {}, "nonce": nonce}
        if evt:
            msg["evt"] = evt
        self.waiting[nonce] = cmd
        self.ws.send(msg)
        return nonce

    def authorize(self):
        self.voice.set("authorizing")
        self.cmd("AUTHORIZE", {"client_id": CLIENT_ID, "scopes": ["rpc"], "prompt": "none"})

    def follow(self, channel_id):
        for evt, cid in self.subscribed:
            self.cmd("UNSUBSCRIBE", {"channel_id": cid}, evt)
        self.subscribed = []
        if channel_id:
            for evt in ("VOICE_STATE_CREATE", "VOICE_STATE_UPDATE", "VOICE_STATE_DELETE", "SPEAKING_START", "SPEAKING_STOP"):
                self.cmd("SUBSCRIBE", {"channel_id": channel_id}, evt)
                self.subscribed.append((evt, channel_id))

    def handle(self, msg):
        cmd, evt, data = msg.get("cmd"), msg.get("evt"), msg.get("data") or {}
        asked = self.waiting.pop(msg.get("nonce"), None) if msg.get("nonce") else None
        if cmd == "DISPATCH":
            if evt == "READY":
                token = self.load()
                if token:
                    self.cmd("AUTHENTICATE", {"access_token": token})
                else:
                    self.voice.set("auth")
            elif evt == "VOICE_CHANNEL_SELECT":
                self.follow(data.get("channel_id"))
                if data.get("channel_id"):
                    self.cmd("GET_SELECTED_VOICE_CHANNEL")
                else:
                    self.voice.channel_in(None)
            else:
                self.voice.event(evt, data)
            return
        if evt == "ERROR":
            why = data.get("message") or "error"
            if asked == "AUTHENTICATE":
                # an old token: Discord gives a new one without asking again (prompt none)
                self.save("")
                if self.authorized:
                    self.voice.set("auth", why)
                else:
                    self.authorized = True
                    self.authorize()
            elif asked == "AUTHORIZE":
                self.voice.set("auth", why)
            return
        if asked == "AUTHORIZE":
            try:
                token = self.exchange(data["code"])
            except (OSError, ValueError, KeyError) as exc:
                self.voice.set("auth", "token: " + str(exc))
                return
            self.save(token)
            self.authorized = True
            self.cmd("AUTHENTICATE", {"access_token": token})
        elif asked == "AUTHENTICATE":
            self.authorized = True
            self.cmd("SUBSCRIBE", {}, "VOICE_CHANNEL_SELECT")
            self.cmd("GET_SELECTED_VOICE_CHANNEL")
        elif asked == "GET_SELECTED_VOICE_CHANNEL":
            ch = data if data and data.get("id") else None
            if ch and not any(cid == ch["id"] for _, cid in self.subscribed):
                self.follow(ch["id"])
            self.voice.channel_in(ch)

    def line(self, text):
        word = text.strip()
        if word == "auth" and self.voice.state in ("auth", "authorizing"):
            self.authorize()
        elif word == "forget":
            self.save("")
            self.voice.set("auth")

    def run(self):
        while True:
            if not self.ws.pending():
                fds = [self.ws] + ([self.stdin] if self.stdin else [])
                ready, _, _ = select.select(fds, [], [], 30)
                if self.stdin in ready:
                    text = self.stdin.readline()
                    if not text:
                        return "bye"            # the shell went away
                    self.line(text)
                    if self.ws not in ready:
                        continue
                if not ready:
                    continue
            self.handle(self.ws.recv())


def connect():
    for port in PORTS:
        try:
            return WS.connect(port)
        except (OSError, ConnectionError):
            continue
    return None


def main():
    voice = Voice(out=lambda s: print(s, flush=True))
    voice.emit()
    while True:
        ws = connect()
        if not ws:
            voice.set("no-discord")
            r, _, _ = select.select([sys.stdin], [], [], 10)
            if r and not sys.stdin.readline():
                return 0
            continue
        try:
            if Session(ws, voice, sys.stdin).run() == "bye":
                return 0
        except (OSError, ConnectionError, ValueError) as exc:
            voice.set("no-discord", str(exc))
        finally:
            ws.close()
        time.sleep(3)


# ---- the self-test: a stand-in Discord on a socket pair ----
def self_test():
    import tempfile
    global AVATARS
    AVATARS = Path(tempfile.mkdtemp())

    class Fake:
        """the server side: reads our masked frames, answers like Discord"""
        def __init__(self, sock):
            self.ws = WS(sock)
            self.sent = []

        def push(self, obj):           # server frames are not masked
            data = json.dumps(obj).encode()
            n = len(data)
            head = bytes([0x81]) + (bytes([n]) if n < 126 else bytes([126]) + struct.pack(">H", n))
            self.ws.sock.sendall(head + data)

        def take(self):
            m = self.ws.recv()
            self.sent.append(m)
            return m

    a, b = socket.socketpair()
    client, server = WS(a), Fake(b)
    lines = []
    tokens = {"t": "old"}
    voice = Voice(out=lines.append, fetch=False)
    s = Session(client, voice, token_io=(lambda: tokens["t"], lambda t: tokens.__setitem__("t", t)),
                exchange_code=lambda code: "fresh-" + code)
    state = lambda: json.loads(lines[-1])
    user = lambda i, name, **st: {"nick": "", "user": {"id": i, "username": name, "avatar": None}, "voice_state": st}

    server.push({"cmd": "DISPATCH", "evt": "READY", "data": {"v": 1}})
    s.handle(client.recv())
    m = server.take()
    assert m["cmd"] == "AUTHENTICATE" and m["args"]["access_token"] == "old"
    # an expired token: authorized again by itself, the code exchanged for a new token
    server.push({"cmd": "AUTHENTICATE", "evt": "ERROR", "nonce": m["nonce"], "data": {"message": "Invalid token"}})
    s.handle(client.recv())
    m = server.take()
    assert m["cmd"] == "AUTHORIZE" and m["args"]["client_id"] == CLIENT_ID and state()["state"] == "authorizing"
    server.push({"cmd": "AUTHORIZE", "nonce": m["nonce"], "data": {"code": "abc"}})
    s.handle(client.recv())
    m = server.take()
    assert m["cmd"] == "AUTHENTICATE" and m["args"]["access_token"] == "fresh-abc" and tokens["t"] == "fresh-abc"
    server.push({"cmd": "AUTHENTICATE", "nonce": m["nonce"], "data": {"user": {}}})
    s.handle(client.recv())
    sub, get = server.take(), server.take()
    assert sub["cmd"] == "SUBSCRIBE" and sub["evt"] == "VOICE_CHANNEL_SELECT" and get["cmd"] == "GET_SELECTED_VOICE_CHANNEL"
    # in a call: who is there, then someone speaks, mutes, leaves
    server.push({"cmd": "GET_SELECTED_VOICE_CHANNEL", "nonce": get["nonce"], "data": {"id": "c1", "name": "Болталка",
                 "voice_states": [user("1", "anna"), user("2", "bob", self_mute=True)]}})
    s.handle(client.recv())
    subs = [server.take() for _ in range(5)]
    assert {x["evt"] for x in subs} == {"VOICE_STATE_CREATE", "VOICE_STATE_UPDATE", "VOICE_STATE_DELETE", "SPEAKING_START", "SPEAKING_STOP"}
    st = state()
    assert st["state"] == "call" and st["channel"] == "Болталка" and [u["name"] for u in st["users"]] == ["anna", "bob"]
    assert st["users"][1]["muted"] and not st["users"][0]["muted"]
    for evt, data in [("SPEAKING_START", {"user_id": "1"}), ("VOICE_STATE_CREATE", user("3", "cat", self_deaf=True)),
                      ("VOICE_STATE_DELETE", user("2", "bob"))]:
        server.push({"cmd": "DISPATCH", "evt": evt, "data": data})
        s.handle(client.recv())
    st = state()
    assert [(u["name"], u["speaking"], u["deaf"]) for u in st["users"]] == [("anna", True, False), ("cat", False, True)], st
    # out of the call
    server.push({"cmd": "DISPATCH", "evt": "VOICE_CHANNEL_SELECT", "data": {"channel_id": None}})
    s.handle(client.recv())
    assert state() == {"state": "idle", "channel": "", "error": "", "users": []}
    # a big frame (126+ bytes, 16-bit length) and a ping on the way
    server.ws.sock.sendall(bytes([0x89, 0]))
    server.push({"cmd": "DISPATCH", "evt": "NOTHING", "data": {"x": "y" * 300}})
    assert client.recv()["data"]["x"] == "y" * 300
    assert avatar_url({"id": str(5 << 22), "avatar": None}).endswith("/embed/avatars/5.png")
    print("discord-voice ok")


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        self_test()
    else:
        sys.exit(main())
