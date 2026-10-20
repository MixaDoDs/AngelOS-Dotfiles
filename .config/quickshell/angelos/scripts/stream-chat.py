#!/usr/bin/env python3
"""The stream's chat for the shell (services/StreamChat): follows the newest session log in DIR —
one JSON object a line, {"event": "chat", "author", "text", "kind", "amount", "owner"}, as a chat
reader writes it while live (the owner's bot: stream-logs/<date>.jsonl) — and prints each new
message as a JSON line. Nothing goes to the network: whoever reads the chat writes the log.

  {"author": "@nick", "text": "…", "amount": "", "regular": false, "count": 1, "place": 0, "newbie": true}

The streamer's own messages and the reader's other events are left out; links are cut (a
viewer's text lands on the stream); regular: the author wrote in at least 5 earlier sessions.
The race of this stream (the cats along the bottom): count = the author's messages in this
session so far, place = 1–3 among this session's writers once they wrote twice (else 0),
newbie = their first message ever (in none of the earlier sessions).

A viewer picks their cat's colour by writing «!pink», «!розовый», «!#ff66cc» (or «!цвет …»,
«!color …»; «!сброс» / «!reset» gives back the one from the nick): kept for good in
$XDG_STATE_HOME/angelos/chat-colors.json, sent as "color" with each of their messages; such a
message does not count in the race. Whenever the race changes, a line for the desktop widget:

  {"race": {"session": "2026-10-20_1006", "writers": 36, "top": [["@nick", 70, "#ff66cc", true], …]}}

A paid message carries "rub": its amount in roubles, roughly (for the mines: from 100 ₽). The
cats blown up on the screen lose part of their count: the shell writes what each lost this
session to STATE/chat-race-hits.json, {"session": …, "minus": {"@nick": 28}}, and the counts here
are less by that from then on.

  stream-chat.py DIR [STATE]        STATE: the shell's state folder (default ~/.local/state/angelos)

DonationAlerts: its donations never reach the YouTube chat. When OBS has DonationAlerts' alert
box among its sources, its own widget token (read from OBS's scene files here and kept nowhere
else) lets this listen the way that box does — socket.io at socket3.donationalerts.com, «add-user»
with the token, «donation» events — and each donation comes out like a paid message:

  {"author": "Name", "text": "…", "amount": "150 RUB", "rub": 150, "donation": "donationalerts", …}

DonateX the same way: its donations box in OBS (donatex.gg/widgets/donations/<id>) gives the id,
the box's own SignalR hub (donatex.gg/api/donations-hub, JoinDonationWidgetGroup) the donations —
"donation": "donatex"; its test donations too (to see it work).

  stream-chat.py DIR --donations-only     only the donations' side (to see it connect)

  stream-chat.py DIR
  stream-chat.py --self-test
"""
import base64
import glob
import json
import os
import re
import socket
import ssl
import struct
import sys
import threading
import time

LINK = re.compile(r"(https?://|www\.)\S+|\b\S+\.(com|ru|net|org|io|gg|tv|me|xyz|link|ly)(/\S*)?\b", re.I)
REGULAR = 5                  # of 493 who wrote in 17 streams, 47 came to 5 or more
TOP = 10                     # the race's table: the first ten
# what a viewer can write after «!»: a name (English or Russian) or #rgb / #rrggbb
COLORS = {
    "#ff7eb6": "pink розовый розовая розовое розовенький pinky",
    "#ff4d4d": "red красный красная красное",
    "#ff9a3c": "orange оранжевый оранжевая рыжий рыжая",
    "#ffe14d": "yellow жёлтый желтый жёлтая желтая",
    "#ffcf3f": "gold золотой золотая",
    "#6ee06e": "green зелёный зеленый зелёная зеленая",
    "#7dffc8": "mint мятный мятная",
    "#5fe0ff": "cyan голубой голубая бирюзовый aqua",
    "#5b8cff": "blue синий синяя",
    "#b07cff": "purple violet фиолетовый фиолетовая сиреневый",
    "#ff6bff": "magenta малиновый пурпурный",
    "#c08850": "brown коричневый коричневая",
    "#f4f4f4": "white белый белая",
    "#9a9aa8": "gray grey серый серая",
    "#3a3a46": "black чёрный черный чёрная черная",
}
NAMES = {n: c for c, names in COLORS.items() for n in names.split()}
RESET = {"reset", "сброс", "default", "обычный"}
COMMAND = re.compile(r"^!\s*(?:(?:color|цвет|colour)\s+)?(#[0-9a-f]{3}|#[0-9a-f]{6}|[a-zа-яё]+)\s*$", re.I)


def color_command(text):
    """«!pink» → "#ff7eb6", «!сброс» → "" (back to the nick's), anything else → None"""
    m = COMMAND.match(text or "")
    if not m:
        return None
    w = m.group(1).lower()
    if w.startswith("#"):
        return "#" + "".join(ch * 2 for ch in w[1:]) if len(w) == 4 else w
    if w in RESET:
        return ""
    return NAMES.get(w)


STATE = [os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "angelos")]


def colors_file():
    return os.path.join(STATE[0], "chat-colors.json")


def hits_file():
    return os.path.join(STATE[0], "chat-race-hits.json")


# roubles for one of each, roughly: a mine wants 100 ₽, not to the kopeck
RATES = [("₽", 1), ("RUB", 1), ("РУБ", 1), ("$", 80), ("USD", 80), ("€", 90), ("EUR", 90), ("£", 105),
         ("GBP", 105), ("₴", 2), ("UAH", 2), ("грн", 2), ("₸", 0.16), ("KZT", 0.16), ("BYN", 25),
         ("Br", 25), ("PLN", 20), ("zł", 20), ("TRY", 2.4), ("₺", 2.4)]


def rub(amount):
    """«RUB 100.00», «₽1 000,00», «$5.00», «100,00 ₽» → roubles (0: unknown or none)"""
    a = (amount or "").upper().replace("\u00a0", " ")
    num = re.search(r"\d[\d\s.,]*", a)
    if not num:
        return 0
    n = re.sub(r"\s", "", num.group(0)).rstrip(".,")
    cents = re.match(r"^(.*?)[.,](\d{1,2})$", n)          # «1.000» is a thousand, «5.50» five and a half
    whole, frac = (cents.group(1), cents.group(2)) if cents else (n, "0")
    v = float(re.sub(r"[.,]", "", whole) or 0) + float("0." + frac)
    for sign, rate in RATES:
        if sign.upper() in a:
            return round(v * rate, 2)
    return 0


def load_colors():
    try:
        with open(colors_file(), encoding="utf-8") as fh:
            d = json.load(fh)
        return {str(k): str(v) for k, v in d.items()} if isinstance(d, dict) else {}
    except (OSError, ValueError):
        return {}


def save_colors(colors):
    path = colors_file()
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path + ".tmp", "w", encoding="utf-8") as fh:
            json.dump(colors, fh, ensure_ascii=False, indent=1)
        os.replace(path + ".tmp", path)
    except OSError:
        pass


def message(line):
    """a log line → what the shell shows (None: not a viewer's message)"""
    try:
        e = json.loads(line)
    except ValueError:
        return None
    if not isinstance(e, dict) or e.get("event") != "chat" or e.get("owner"):
        return None
    author = str(e.get("author") or "").strip()[:32]
    text = re.sub(r"\s+", " ", LINK.sub("…", str(e.get("text") or ""))).strip()
    amount = str(e.get("amount") or "").strip()[:16]
    if not author or not (text or amount):
        return None
    return {"author": author, "text": text[:120], "amount": amount}


def sessions(files):
    """author → in how many of these sessions they wrote"""
    seen = {}
    for f in files:
        names = set()
        try:
            with open(f, encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    m = message(line)
                    if m:
                        names.add(m["author"])
        except OSError:
            continue
        for n in names:
            seen[n] = seen.get(n, 0) + 1
    return seen


class Follower:
    """the newest *.jsonl in a folder, from where it was when first seen (a file that appears
    later is read from its start: a new session)"""

    def __init__(self, folder, out):
        self.folder, self.out = folder, out
        self.path, self.pos, self.seen, self.count, self.started = "", 0, {}, {}, True
        self.colors, self.told = load_colors(), None
        self.minus, self.hits_seen = {}, None

    def newest(self):
        files = glob.glob(os.path.join(self.folder, "*.jsonl"))
        return max(files, key=os.path.getmtime) if files else ""

    def step(self):
        p = self.newest()
        if p and p != self.path:
            self.path = p
            self.pos = 0 if not self.started else os.path.getsize(p)
            older = [f for f in glob.glob(os.path.join(self.folder, "*.jsonl")) if f != p]
            self.seen = sessions(older)
            self.count = self.counted(p, self.pos)
        self.started = False
        if not self.path:
            return
        self.read_hits()
        try:
            with open(self.path, encoding="utf-8", errors="replace") as fh:
                fh.seek(self.pos)
                while True:
                    line = fh.readline()
                    if not line.endswith("\n"):
                        break               # half written: next time
                    self.pos = fh.tell()
                    m = message(line)
                    if m:
                        a = m["author"]
                        pick = color_command(m["text"])
                        if pick is not None:
                            if pick:
                                self.colors[a] = pick
                            else:
                                self.colors.pop(a, None)
                            save_colors(self.colors)
                        raw = self.count[a] = self.count.get(a, 0) + (pick is None)
                        n = max(raw - self.minus.get(a, 0), 1)
                        m["regular"] = self.seen.get(a, 0) >= REGULAR
                        m["count"] = n
                        place = 1 + sum(k > n for k in self.scores().values())
                        m["place"] = place if n >= 2 and place <= 3 else 0
                        m["newbie"] = pick is None and n == 1 and a not in self.seen
                        if a in self.colors:
                            m["color"] = self.colors[a]
                        if m["amount"]:
                            m["rub"] = rub(m["amount"])
                        self.out(json.dumps(m, ensure_ascii=False))
        except OSError:
            self.path = ""
        self.tell_race()

    def scores(self):
        """the race's counts: the messages less what the mines took"""
        return {a: max(0, n - self.minus.get(a, 0)) for a, n in self.count.items()}

    def read_hits(self):
        """what the cats blown up lost this session (the shell writes it)"""
        try:
            st = os.stat(hits_file())
            mark = (st.st_mtime_ns, st.st_size)
        except OSError:
            mark = None
        if mark == self.hits_seen:
            return
        self.hits_seen = mark
        minus = {}
        try:
            with open(hits_file(), encoding="utf-8") as fh:
                d = json.load(fh)
            if isinstance(d, dict) and d.get("session") == os.path.splitext(os.path.basename(self.path))[0]:
                minus = {str(k): int(v) for k, v in (d.get("minus") or {}).items()}
        except (OSError, ValueError, TypeError):
            pass
        self.minus = minus

    def tell_race(self):
        """the race's table, when it changed"""
        if not self.path:
            return
        top = sorted(self.scores().items(), key=lambda x: -x[1])[:TOP]
        race = {"session": os.path.splitext(os.path.basename(self.path))[0], "writers": len(self.count),
                "top": [[a, n, self.colors.get(a, ""), self.seen.get(a, 0) >= REGULAR] for a, n in top]}
        if race != self.told:
            self.told = race
            self.out(json.dumps({"race": race}, ensure_ascii=False))

    @staticmethod
    def counted(path, upto):
        """author → messages in this session before `upto` (the shell came mid-stream)"""
        count = {}
        try:
            with open(path, encoding="utf-8", errors="replace") as fh:
                while fh.tell() < upto:
                    line = fh.readline()
                    if not line:
                        break
                    m = message(line)
                    if m and color_command(m["text"]) is None:
                        count[m["author"]] = count.get(m["author"], 0) + 1
        except OSError:
            pass
        return count


def self_test():
    import tempfile
    d = tempfile.mkdtemp()
    STATE[0] = os.path.join(d, "state")                          # the colours: not the real ones
    old = lambda n, who: open(os.path.join(d, f"2026-10-0{n}.jsonl"), "w").write("".join(
        json.dumps({"event": "chat", "author": w, "text": "hi"}) + "\n" for w in who))
    old(1, ["@reg", "@a"])
    for n in (2, 3, 4):
        old(n, ["@reg"])
    old(5, ["@reg", "@reg", "@a"])
    time.sleep(0.01)
    cur = os.path.join(d, "2026-10-06.jsonl")
    open(cur, "w").write(json.dumps({"event": "chat", "author": "@before", "text": "old"}) + "\n")
    os.utime(cur, None)
    lines, races = [], []
    f = Follower(d, lambda s: (races if s.startswith('{"race"') else lines).append(s))
    f.step()
    assert lines == [], "what was there before is not replayed: " + str(lines)
    with open(cur, "a") as fh:
        for e in ({"event": "chat", "author": "@reg", "text": "go to https://spam.example/x now"},
                  {"event": "chat", "author": "@me", "text": "mine", "owner": True},
                  {"event": "her_chat", "author": "bot", "text": "hello"},
                  {"event": "chat", "author": "@new", "text": "", "amount": "€5.00"}):
            fh.write(json.dumps(e) + "\n")
        fh.write('{"event": "chat", "author": "@half"')      # not finished yet
    f.step()
    got = [json.loads(x) for x in lines]
    race = {"count": 1, "place": 0}
    assert got == [{"author": "@reg", "text": "go to … now", "amount": "", "regular": True, **race, "newbie": False},
                   {"author": "@new", "text": "", "amount": "€5.00", "regular": False, **race, "newbie": True, "rub": 450}], got
    with open(cur, "a") as fh:
        fh.write(', "text": "done"}\n')
        fh.write(json.dumps({"event": "chat", "author": "@before", "text": "again"}) + "\n")
        fh.write(json.dumps({"event": "chat", "author": "@reg", "text": "again"}) + "\n")
        fh.write(json.dumps({"event": "chat", "author": "@before", "text": "third"}) + "\n")
    f.step()
    got = [json.loads(x) for x in lines[2:]]
    assert [(m["author"], m["count"], m["place"], m["newbie"]) for m in got] == [
        ("@half", 1, 0, True), ("@before", 2, 1, False), ("@reg", 2, 1, False), ("@before", 3, 1, False)], \
        "counted from the session's start, the race's places: " + str(got)
    race = json.loads(races[-1])["race"]
    assert race["session"] == "2026-10-06" and race["writers"] == 4 and race["top"][0] == ["@before", 3, "", False], race
    n = len(races)
    f.step()
    assert len(races) == n, "the table only when it changed"
    with open(cur, "a") as fh:
        for t in ("!розовый", "!color #0f0", "!pink please", "!сброс", "!PINK"):
            fh.write(json.dumps({"event": "chat", "author": "@half", "text": t}) + "\n")
    f.step()
    got = [json.loads(x) for x in lines[-5:]]
    assert [m.get("color") for m in got] == ["#ff7eb6", "#00ff00", "#00ff00", None, "#ff7eb6"], got
    assert [m["count"] for m in got] == [1, 1, 2, 2, 2], "a colour command does not count: " + str(got)
    assert load_colors() == {"@half": "#ff7eb6"}, load_colors()
    assert Follower(d, lambda s: None).colors == {"@half": "#ff7eb6"}, "kept for good"
    assert ["@half", 2, "#ff7eb6", False] in json.loads(races[-1])["race"]["top"], races[-1]
    for a, want in (("RUB 100.00", 100), ("₽1 000,00", 1000), ("$5.00", 400), ("100,00 ₽", 100), ("€1.50", 135),
                    ("1.000 ₸", 160), ("¥500", 0), ("", 0)):
        assert rub(a) == want, (a, rub(a), want)
    # the mines took from @before: less from then on, the table again
    with open(hits_file(), "w") as fh:
        json.dump({"session": "2026-10-06", "minus": {"@before": 2}}, fh)
    with open(cur, "a") as fh:
        fh.write(json.dumps({"event": "chat", "author": "@before", "text": "ouch", "amount": "RUB 150.00"}) + "\n")
    f.step()
    m = json.loads(lines[-1])
    assert m["author"] == "@before" and m["count"] == 2 and m["rub"] == 150, m
    assert ["@before", 2, "", False] in json.loads(races[-1])["race"]["top"], races[-1]
    time.sleep(0.01)
    nxt = os.path.join(d, "2026-10-07.jsonl")
    open(nxt, "w").write(json.dumps({"event": "chat", "author": "@a", "text": "new session"}) + "\n")
    f.step()
    assert json.loads(lines[-1]) == {"author": "@a", "text": "new session", "amount": "", "regular": False,
                                     "count": 1, "place": 0, "newbie": False}, "a new session, a new race: " + lines[-1]
    assert message('{"event": "chat", "author": "@x", "text": "see youtube.com/watch?v=1"}')["text"] == "see …"
    d = da_donation('42["donation","' + json.dumps({"id": 1, "alert_type": "1", "username": "Вася", "amount": 150,
                    "currency": "RUB", "amount_main": 150, "message": "на мину https://x.ru/y"}).replace('"', '\\"') + '"]')
    assert d == {"author": "Вася", "text": "на мину …", "amount": "150 RUB", "rub": 150}, d
    assert da_donation('42["donation",{"alert_type": 4, "username": "x"}]') is None, "a subscriber is no donation"
    assert da_donation('42["update-alert_widget","{}"]') is None and da_donation("3") is None
    assert da_donation('42["donation",{"username": "", "amount": "2", "currency": "USD"}]')["rub"] == 160
    d = dx_donation(json.dumps({"type": 1, "target": "ReceiveDonation", "arguments": [{
        "id": "x", "username": "Петя", "amount": 2, "currency": "USD", "amountInRub": 180, "message": "бах"}]}))
    assert d == {"author": "Петя", "text": "бах", "amount": "2 USD", "rub": 180}, d
    assert dx_donation('{"type":1,"target":"UpdateVolume","arguments":[50]}') is None
    assert dx_donation('{"type":6}') is None and dx_donation("{}") is None
    print("stream-chat ok")


# ---- DonationAlerts ----
DA_HOST = "socket3.donationalerts.com"
OBS_SCENES = ["~/.var/app/com.obsproject.Studio/config/obs-studio/basic/scenes/*.json",
              "~/.config/obs-studio/basic/scenes/*.json"]
DA_WIDGET = re.compile(r"donationalerts\.com/widget/alerts\?[^\"\s]*?\btoken=([A-Za-z0-9]+)")


def da_token():
    """the alert box's token from OBS's scenes ("" when there is none)"""
    for pattern in OBS_SCENES:
        for f in sorted(glob.glob(os.path.expanduser(pattern))):
            try:
                with open(f, encoding="utf-8", errors="replace") as fh:
                    m = DA_WIDGET.search(fh.read())
            except OSError:
                continue
            if m:
                return m.group(1)
    return ""


def da_donation(packet):
    """an engine.io packet → the donation in it as {author, text, amount, rub} (None: anything else)"""
    if not packet.startswith("42"):
        return None
    try:
        name, data = json.loads(packet[2:])[:2]
        d = json.loads(data) if isinstance(data, str) else data
    except (ValueError, TypeError):
        return None
    if name != "donation" or not isinstance(d, dict) or str(d.get("alert_type", "1")) != "1":
        return None
    amount = "%s %s" % (str(d.get("amount") or "").strip(), str(d.get("currency") or "").strip())
    try:
        main = float(d.get("amount_main") or 0)
    except (TypeError, ValueError):
        main = 0
    return {"author": str(d.get("username") or "").strip()[:32] or "Аноним",
            "text": re.sub(r"\s+", " ", LINK.sub("…", str(d.get("message") or ""))).strip()[:120],
            "amount": amount.strip()[:16], "rub": round(main, 2) if main else rub(amount)}


class Socket:
    """just enough of a WebSocket client for one socket.io connection (no library around here)"""

    def __init__(self, host, path, origin="https://www.donationalerts.com"):
        raw = socket.create_connection((host, 443), timeout=20)
        self.s = ssl.create_default_context().wrap_socket(raw, server_hostname=host)
        key = base64.b64encode(os.urandom(16)).decode()
        self.s.sendall(("GET %s HTTP/1.1\r\nHost: %s\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
                        "Sec-WebSocket-Key: %s\r\nSec-WebSocket-Version: 13\r\n"
                        "Origin: %s\r\nUser-Agent: Mozilla/5.0\r\n\r\n"
                        % (path, host, key, origin)).encode())
        head = b""
        while b"\r\n\r\n" not in head:
            chunk = self.s.recv(1)
            if not chunk:
                raise OSError("closed during the handshake")
            head += chunk
        if b" 101 " not in head.split(b"\r\n", 1)[0]:
            raise OSError("no upgrade: " + head.split(b"\r\n", 1)[0].decode(errors="replace"))
        self.lock = threading.Lock()
        self.s.settimeout(90)               # pings every 25 s: quiet longer than this = gone

    def exact(self, n):
        b = b""
        while len(b) < n:
            chunk = self.s.recv(n - len(b))
            if not chunk:
                raise OSError("closed")
            b += chunk
        return b

    def send(self, text, op=1):
        data = text.encode() if isinstance(text, str) else text
        mask = os.urandom(4)
        n = len(data)
        head = bytes([0x80 | op]) + (bytes([0x80 | n]) if n < 126 else bytes([0x80 | 126]) + struct.pack(">H", n)
                                     if n < 65536 else bytes([0x80 | 127]) + struct.pack(">Q", n))
        with self.lock:
            self.s.sendall(head + mask + bytes(c ^ mask[i % 4] for i, c in enumerate(data)))

    def recv(self):
        """the next text message"""
        parts = b""
        while True:
            b0, b1 = self.exact(2)
            n = b1 & 0x7F
            if n == 126:
                n = struct.unpack(">H", self.exact(2))[0]
            elif n == 127:
                n = struct.unpack(">Q", self.exact(8))[0]
            mask = self.exact(4) if b1 & 0x80 else None
            data = self.exact(n)
            if mask:
                data = bytes(c ^ mask[i % 4] for i, c in enumerate(data))
            op = b0 & 0x0F
            if op == 8:
                raise OSError("closed by the server")
            if op == 9:
                self.send(data, 10)
                continue
            if op in (0, 1, 2):
                parts += data
                if b0 & 0x80:
                    return parts.decode("utf-8", "replace")

    def close(self):
        try:
            self.s.close()
        except OSError:
            pass


def da_listen(token, give, log=lambda s: print(s, file=sys.stderr, flush=True)):
    """keeps a connection to DonationAlerts, give(donation) for each; never returns"""
    wait = 2
    while True:
        ws = None
        pinging = [True]
        try:
            ws = Socket(DA_HOST, "/socket.io/?EIO=3&transport=websocket")
            every = 25

            def ping():
                while pinging[0]:
                    time.sleep(every)
                    try:
                        ws.send("2")
                    except OSError:
                        return
            while True:
                p = ws.recv()
                if p.startswith("0"):
                    try:
                        every = max(5, json.loads(p[1:]).get("pingInterval", 25000) / 1000)
                    except ValueError:
                        pass
                    threading.Thread(target=ping, daemon=True).start()
                elif p == "40":
                    ws.send('42' + json.dumps(["add-user", {"token": token}]))
                    log("donationalerts: connected")
                    wait = 2
                else:
                    d = da_donation(p)
                    if d:
                        give(d)
        except (OSError, ValueError) as e:
            log("donationalerts: %s; again in %d s" % (e, wait))
        finally:
            pinging[0] = False
            if ws:
                ws.close()
        time.sleep(wait)
        wait = min(40, wait * 2)


# ---- DonateX ----
DX_WIDGET = re.compile(r"donatex\.gg/widgets/donations/([0-9a-fA-F-]{36})")
RS = "\x1e"                                  # SignalR's end of a message


def dx_widget():
    """the DonateX donations box's id from OBS's scenes ("" when there is none)"""
    for pattern in OBS_SCENES:
        for f in sorted(glob.glob(os.path.expanduser(pattern))):
            try:
                with open(f, encoding="utf-8", errors="replace") as fh:
                    m = DX_WIDGET.search(fh.read())
            except OSError:
                continue
            if m:
                return m.group(1)
    return ""


def dx_donation(record):
    """a SignalR message → the donation in it as {author, text, amount, rub} (None: anything else)"""
    try:
        m = json.loads(record)
    except ValueError:
        return None
    if not isinstance(m, dict) or m.get("type") != 1 or str(m.get("target", "")).lower() != "receivedonation":
        return None
    d = (m.get("arguments") or [None])[0]
    if not isinstance(d, dict):
        return None
    amount = "%s %s" % (d.get("amount") if d.get("amount") is not None else "", str(d.get("currency") or "").strip())
    try:
        main = float(d.get("amountInRub") or 0)
    except (TypeError, ValueError):
        main = 0
    return {"author": str(d.get("username") or "").strip()[:32] or "Аноним",
            "text": re.sub(r"\s+", " ", LINK.sub("…", str(d.get("message") or ""))).strip()[:120],
            "amount": amount.strip()[:16], "rub": round(main, 2) if main else rub(amount)}


def dx_listen(widget, give, log=lambda s: print(s, file=sys.stderr, flush=True)):
    """keeps a connection to DonateX's hub for the box, give(donation) for each; never returns"""
    import urllib.request
    from urllib.parse import quote
    wait = 2
    while True:
        ws = None
        pinging = [True]
        try:
            req = urllib.request.Request("https://donatex.gg/api/donations-hub/negotiate?negotiateVersion=1", data=b"",
                                         headers={"Origin": "https://donatex.gg", "User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=20) as r:
                token = json.load(r)["connectionToken"]
            ws = Socket("donatex.gg", "/api/donations-hub?id=" + quote(token), "https://donatex.gg")
            ws.send('{"protocol":"json","version":1}' + RS)

            def ping():
                while pinging[0]:
                    time.sleep(15)
                    try:
                        ws.send('{"type":6}' + RS)
                    except OSError:
                        return
            threading.Thread(target=ping, daemon=True).start()
            joined = False
            while True:
                for rec in ws.recv().split(RS):
                    if not rec:
                        continue
                    if not joined:
                        if json.loads(rec).get("error"):
                            raise OSError("handshake: " + rec)
                        ws.send(json.dumps({"type": 1, "invocationId": "0", "target": "JoinDonationWidgetGroup",
                                            "arguments": [widget]}) + RS)
                        joined = True
                        continue
                    m = json.loads(rec)
                    if m.get("type") == 3 and m.get("invocationId") == "0":
                        if m.get("error"):
                            raise OSError("join: " + str(m["error"]))
                        log("donatex: connected")
                        wait = 2
                    elif m.get("type") == 7:
                        raise OSError("closed by the hub: " + str(m.get("error") or ""))
                    d = dx_donation(rec)
                    if d:
                        give(d)
        except (OSError, ValueError, KeyError) as e:
            log("donatex: %s; again in %d s" % (e, wait))
        finally:
            pinging[0] = False
            if ws:
                ws.close()
        time.sleep(wait)
        wait = min(40, wait * 2)


def main():
    if "--self-test" in sys.argv:
        return self_test()
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    if len(sys.argv) > 2:
        STATE[0] = os.path.expanduser(sys.argv[2])
    lock = threading.Lock()

    def out(line):
        with lock:
            print(line, flush=True)
    f = Follower(os.path.expanduser(sys.argv[1]), out)
    def giver(source):
        def give(d):
            # the donor's cat at their place in the race when the name is a chatter's (no count of its own)
            seen = f.scores()
            n = seen.get(d["author"], seen.get("@" + d["author"], 0))
            out(json.dumps(dict(d, regular=False, count=max(1, n), place=0, newbie=False,
                                donation=source), ensure_ascii=False))
        return give
    token = da_token()
    if token:
        threading.Thread(target=da_listen, args=(token, giver("donationalerts")), daemon=True).start()
    widget = dx_widget()
    if widget:
        threading.Thread(target=dx_listen, args=(widget, giver("donatex")), daemon=True).start()
    if "--donations-only" in sys.argv:
        while True:
            time.sleep(60)
    while True:
        f.step()
        time.sleep(0.5)


if __name__ == "__main__":
    sys.exit(main())
