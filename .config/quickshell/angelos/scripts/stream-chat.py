#!/usr/bin/env python3
"""The stream's chat for the shell (services/StreamChat): follows the newest session log in DIR —
one JSON object a line, {"event": "chat", "author", "text", "kind", "amount", "owner"}, as a chat
reader writes it while live (the owner's bot: stream-logs/<date>.jsonl) — and prints each new
message as a JSON line. Nothing goes to the network: whoever reads the chat writes the log.

  {"author": "@nick", "text": "…", "amount": "", "regular": false}

The streamer's own messages and the reader's other events are left out; links are cut (a
viewer's text lands on the stream); regular: the author wrote in at least 5 earlier sessions.

  stream-chat.py DIR
  stream-chat.py --self-test
"""
import glob
import json
import os
import re
import sys
import time

LINK = re.compile(r"(https?://|www\.)\S+|\b\S+\.(com|ru|net|org|io|gg|tv|me|xyz|link|ly)(/\S*)?\b", re.I)
REGULAR = 5                  # of 493 who wrote in 17 streams, 47 came to 5 or more


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


def regulars(files):
    """authors seen in at least REGULAR of these sessions"""
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
    return {n for n, k in seen.items() if k >= REGULAR}


class Follower:
    """the newest *.jsonl in a folder, from where it was when first seen (a file that appears
    later is read from its start: a new session)"""

    def __init__(self, folder, out):
        self.folder, self.out = folder, out
        self.path, self.pos, self.known, self.started = "", 0, set(), True

    def newest(self):
        files = glob.glob(os.path.join(self.folder, "*.jsonl"))
        return max(files, key=os.path.getmtime) if files else ""

    def step(self):
        p = self.newest()
        if p and p != self.path:
            self.path = p
            self.pos = 0 if not self.started else os.path.getsize(p)
            older = [f for f in glob.glob(os.path.join(self.folder, "*.jsonl")) if f != p]
            self.known = regulars(older)
        self.started = False
        if not self.path:
            return
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
                        m["regular"] = m["author"] in self.known
                        self.out(json.dumps(m, ensure_ascii=False))
        except OSError:
            self.path = ""


def self_test():
    import tempfile
    d = tempfile.mkdtemp()
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
    lines = []
    f = Follower(d, lines.append)
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
    assert got == [{"author": "@reg", "text": "go to … now", "amount": "", "regular": True},
                   {"author": "@new", "text": "", "amount": "€5.00", "regular": False}], got
    with open(cur, "a") as fh:
        fh.write(', "text": "done"}\n')
    f.step()
    assert json.loads(lines[-1])["author"] == "@half", lines
    time.sleep(0.01)
    nxt = os.path.join(d, "2026-10-07.jsonl")
    open(nxt, "w").write(json.dumps({"event": "chat", "author": "@a", "text": "new session"}) + "\n")
    f.step()
    assert json.loads(lines[-1]) == {"author": "@a", "text": "new session", "amount": "", "regular": False}, lines
    assert message('{"event": "chat", "author": "@x", "text": "see youtube.com/watch?v=1"}')["text"] == "see …"
    print("stream-chat ok")


def main():
    if "--self-test" in sys.argv:
        return self_test()
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    f = Follower(os.path.expanduser(sys.argv[1]), lambda s: print(s, flush=True))
    while True:
        f.step()
        time.sleep(0.5)


if __name__ == "__main__":
    sys.exit(main())
