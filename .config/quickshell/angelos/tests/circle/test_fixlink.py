#!/usr/bin/env python3
"""circle.py fixlink without the network: a stand-in YouTube that knows one video."""
import importlib.util
import sys

spec = importlib.util.spec_from_file_location("circle", sys.argv[1] + "/scripts/circle.py")
c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(c)
REAL = "dQw4w9WgXcQ"
asked = []


def exists(vid):
    asked.append(vid)
    return vid == REAL


bad = 0


def check(name, ok):
    global bad
    print(("  ✓ " if ok else "  ✕ ") + name)
    bad += not ok


check("one look-alike (O for Q) found", c.fix_youtube("https://youtu.be/dQw4w9WgXcO", exists) == ("https://youtu.be/" + REAL, True))
check("two (w, 0) found, the rest of the link kept", c.fix_youtube("https://www.youtube.com/watch?v=dQw4w9wgXc0&t=42", exists) == ("https://www.youtube.com/watch?v=" + REAL + "&t=42", True))
asked.clear()
check("a real one asked once and left", c.fix_youtube("https://youtu.be/" + REAL, exists) == ("https://youtu.be/" + REAL, False) and asked == [REAL])
check("not YouTube: untouched, nothing asked", c.fix_youtube("https://example.com/watch?v=abc", lambda v: 1 / 0) == ("https://example.com/watch?v=abc", False))
check("no network: as read", c.fix_youtube("https://youtu.be/dQw4w9WgXcO", lambda v: None) == ("https://youtu.be/dQw4w9WgXcO", False))
r = c.variants("aI0b")
check("fewest changes first", all(sum(x != y for x, y in zip(v, "aI0b")) == 1 for v in r[0]) and all(sum(x != y for x, y in zip(v, "aI0b")) == 2 for v in r[1]))
sys.exit(1 if bad else 0)
