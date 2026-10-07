#!/usr/bin/env python3
"""Tell angelOS when OBS goes live (obs-websocket 5, no extra Python packages).

  obs-watch.py [--port 4455] [--password PW]

Prints one word per line:
  up      connected to OBS
  down    OBS closed or unreachable (tried again every 10 s, silently)
  live    the stream started (also at connect time if it is already running)
  off     the stream stopped
  rec     the recording started (also at connect time)
  recoff  the recording stopped
  auth    OBS wants a password that is not configured / is wrong

The password is read from OBS's own obs-websocket config (native or Flatpak)
when --password is not given. Only the Outputs event group is subscribed;
nothing is ever sent to OBS except the status request.
"""
import argparse
import base64
import hashlib
import json
import os
import select
import socket
import struct
import sys
import time

CONFIGS = [
    "~/.config/obs-studio/plugin_config/obs-websocket/config.json",
    "~/.var/app/com.obsproject.Studio/config/obs-studio/plugin_config/obs-websocket/config.json",
]
OUTPUTS = 1 << 6


def say(word):
    print(word, flush=True)


def config_password():
    for path in CONFIGS:
        try:
            with open(os.path.expanduser(path)) as f:
                cfg = json.load(f)
        except (OSError, ValueError):
            continue
        if cfg.get("auth_required") and cfg.get("server_password"):
            return cfg["server_password"]
    return ""


class Socket:
    def __init__(self, port):
        self.sock = socket.create_connection(("127.0.0.1", port), timeout=5)
        key = base64.b64encode(os.urandom(16)).decode()
        self.sock.sendall((
            "GET / HTTP/1.1\r\nHost: 127.0.0.1:%d\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
            "Sec-WebSocket-Key: %s\r\nSec-WebSocket-Version: 13\r\n"
            "Sec-WebSocket-Protocol: obswebsocket.json\r\n\r\n" % (port, key)).encode())
        head = b""
        while b"\r\n\r\n" not in head:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise ConnectionError("closed during handshake")
            head += chunk
        head, self.buf = head.split(b"\r\n\r\n", 1)
        if b" 101 " not in head.split(b"\r\n", 1)[0]:
            raise ConnectionError("no websocket upgrade")
        self.sock.settimeout(None)

    def send(self, obj, opcode=1):
        data = json.dumps(obj).encode() if opcode == 1 else obj
        mask = os.urandom(4)
        n = len(data)
        head = bytes([0x80 | opcode])
        if n < 126:
            head += bytes([0x80 | n])
        elif n < 65536:
            head += bytes([0x80 | 126]) + struct.pack(">H", n)
        else:
            head += bytes([0x80 | 127]) + struct.pack(">Q", n)
        body = bytes(b ^ mask[i % 4] for i, b in enumerate(data))
        self.sock.sendall(head + mask + body)

    def _need(self, n):
        while len(self.buf) < n:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise ConnectionError("closed")
            self.buf += chunk
        out, self.buf = self.buf[:n], self.buf[n:]
        return out

    def recv(self):
        """The next text message as JSON (pings answered, fragments joined)."""
        message = b""
        while True:
            b0, b1 = self._need(2)
            opcode, fin = b0 & 0x0F, b0 & 0x80
            n = b1 & 0x7F
            if n == 126:
                n = struct.unpack(">H", self._need(2))[0]
            elif n == 127:
                n = struct.unpack(">Q", self._need(8))[0]
            mask = self._need(4) if b1 & 0x80 else None
            data = self._need(n)
            if mask:
                data = bytes(b ^ mask[i % 4] for i, b in enumerate(data))
            if opcode == 8:
                raise ConnectionError("closed by OBS")
            if opcode == 9:
                self.send(data, opcode=10)
                continue
            if opcode in (0, 1, 2):
                message += data
                if fin:
                    return json.loads(message.decode())

    def pending(self, timeout):
        return bool(self.buf) or bool(select.select([self.sock], [], [], timeout)[0])


def session(port, password, state):
    ws = Socket(port)
    hello = ws.recv()
    ident = {"rpcVersion": 1, "eventSubscriptions": OUTPUTS}
    auth = (hello.get("d") or {}).get("authentication")
    if auth:
        if not password:
            say("auth")
            return False
        secret = base64.b64encode(hashlib.sha256((password + auth["salt"]).encode()).digest())
        ident["authentication"] = base64.b64encode(hashlib.sha256(secret + auth["challenge"].encode()).digest()).decode()
    ws.send({"op": 1, "d": ident})
    state["up"] = True
    say("up")
    ws.send({"op": 6, "d": {"requestType": "GetStreamStatus", "requestId": "angelos-stream"}})
    ws.send({"op": 6, "d": {"requestType": "GetRecordStatus", "requestId": "angelos-record"}})
    while True:
        if not ws.pending(60):
            continue
        msg = ws.recv()
        op, d = msg.get("op"), msg.get("d") or {}
        live = rec = None
        if op == 7 and d.get("requestId") == "angelos-stream":
            live = bool((d.get("responseData") or {}).get("outputActive"))
        elif op == 7 and d.get("requestId") == "angelos-record":
            rec = bool((d.get("responseData") or {}).get("outputActive"))
        elif op == 5 and d.get("eventType") == "StreamStateChanged":
            live = bool((d.get("eventData") or {}).get("outputActive"))
        elif op == 5 and d.get("eventType") == "RecordStateChanged":
            rec = bool((d.get("eventData") or {}).get("outputActive"))
        if live is not None and live != state["live"]:
            state["live"] = live
            say("live" if live else "off")
        if rec is not None and rec != state["rec"]:
            state["rec"] = rec
            say("rec" if rec else "recoff")


def main():
    try:  # go away together with the shell
        import ctypes
        import signal
        ctypes.CDLL(None).prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG
    except (OSError, AttributeError):
        pass
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=4455)
    ap.add_argument("--password", default=None)
    args = ap.parse_args()
    state = {"live": False, "rec": False, "up": None}
    while True:
        password = args.password if args.password is not None else config_password()
        try:
            session(args.port, password, state)
            code = "auth"
        except (OSError, ConnectionError, ValueError):
            code = "down"
        if state["live"]:
            state["live"] = False
            say("off")
        if state["rec"]:
            state["rec"] = False
            say("recoff")
        if code == "down" and state["up"] is not False:
            say("down")
        state["up"] = False
        time.sleep(30 if code == "auth" else 10)


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        pass
