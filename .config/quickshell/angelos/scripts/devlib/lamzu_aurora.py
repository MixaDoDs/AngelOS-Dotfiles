"""The "lamzu-aurora" protocol family: LAMZU's mice (Maya X, Inca, Paro, Thorn…) as their web
driver "Aurora" (lamzu.net) talks to them, the newer of its two revisions.

Worked out from the web driver's JavaScript (2026-10-12). A request and its answer are a
64-byte feature report (report id 0) on the mouse's or the dongle's configuration interface:

  request  [2] target: 2 the mouse, 0 the dongle     [3] length     [4] category
           [5] opcode: 0x80 | N reads what N writes   [6] profile    [7..] value
  answer   as hidraw returns it (the report id first): [1] 0xA1 done; below it "not yet",
           above it "ask again"; [6] the opcode again; the value from [8]
           (battery and firmware, which take no profile: from [7])

A mouse behind its dongle answers late or not at all while it sleeps; the dongle then says
0xA0 and zeros. That is "asleep", not an error.

Only the commands of ALLOWED can be built. The web driver also has a firmware loader
(category 0xB0, and category 0 / opcode 0 with 0xB0 or 0xC0 as its value): none of that is
here, and build() refuses anything that is not in the table.
"""

TARGET_MOUSE = 2
DONE = 0xA1

# name -> (category, set opcode or None); the read opcode is the set opcode | 0x80
ALLOWED = {
    "firmware": (0, None, 0x81),
    "battery": (0, None, 0x83),
    "profile": (0, None, 0x85),
    "sleep": (0, 0x07, 0x87),
    "debounce": (0, 0x08, 0x88),
    "pollingRate": (1, 0x00, 0x80),
    "dpiStages": (1, 0x01, 0x81),
    "dpiActive": (1, 0x02, 0x82),
    "angleSnap": (1, 0x04, 0x84),
    "lod": (1, 0x08, 0x88),
    "motionSync": (1, 0x09, 0x89),
    "ripple": (1, 0x0A, 0x8A),
    "hyperMode": (1, 0x0B, 0x8B),
    "dpiMax": (1, None, 0x8C),
    "sensor": (1, None, 0x8F),
}
# request lengths the web driver sends ([3]); kept as it has them
LENGTH = {"firmware": 16, "battery": 2, "profile": 1, "sleep": 3, "debounce": 2, "pollingRate": 2, "dpiStages": 10,
          "dpiActive": 2, "angleSnap": 2, "lod": 2, "motionSync": 2, "ripple": 2, "hyperMode": 2, "dpiMax": 2, "sensor": 1}

RATE_CODE = {125: 8, 250: 4, 500: 2, 1000: 1, 2000: 32, 4000: 64, 8000: 128}
CODE_RATE = {v: k for k, v in RATE_CODE.items()}
CODE_RATE[16] = 1000            # what some firmware reports for 1000 Hz


class ProtocolError(ValueError):
    pass


def build_get(name, profile=0, arg=None):
    if name not in ALLOWED:
        raise ProtocolError("unknown setting " + str(name))
    cat, _, op = ALLOWED[name]
    p = bytearray(64)
    p[2], p[3], p[4], p[5] = TARGET_MOUSE, LENGTH[name], cat, op
    if name not in ("firmware", "battery", "profile", "dpiMax", "sensor"):
        p[6] = profile
    if name == "dpiStages":
        p[7] = 6 if arg is None else arg         # how many stages are asked for
    return bytes(p)


def build_set(name, profile, value):
    """value: the bytes after the profile."""
    if name not in ALLOWED or ALLOWED[name][1] is None:
        raise ProtocolError("%s cannot be written" % name)
    cat, op, _ = ALLOWED[name]
    value = bytes(value)
    if len(value) > 40:
        raise ProtocolError("too long")
    p = bytearray(64)
    p[2], p[4], p[5], p[6] = TARGET_MOUSE, cat, op, profile
    p[3] = 26 if name == "dpiStages" else LENGTH[name]
    p[7:7 + len(value)] = value
    return bytes(p)


def done(answer, name):
    """Is this the finished answer to `name`'s read or write."""
    cat, setop, getop = ALLOWED[name]
    return len(answer) >= 9 and answer[1] == DONE and answer[6] in (getop, setop if setop is not None else getop)


def status(answer):
    """"done" | "wait" (not yet) | "again" (ask again) | "asleep" (the dongle alone answers)."""
    if len(answer) < 2:
        return "wait"
    if answer[1] == DONE:
        return "done"
    if answer[1] == 0xA0 and not any(answer[2:]):
        return "asleep"
    return "again" if answer[1] > DONE else "wait"


def lod_code(mm):
    if mm == int(mm) and mm >= 1:
        return int(mm)
    if mm < 1:
        return int(round(mm * 10)) | 0x80
    return int(mm) << 4 | int(round(mm * 10)) % 10


def lod_mm(code):
    if code >= 0x80:
        return (code - 0x80) / 10
    if code in (1, 2):
        return float(code)
    return ((code >> 4) * 10 + (code & 15)) / 10


def parse(name, a):
    """The value of a finished answer."""
    if name == "firmware":
        return "%d.%d.%d.%d" % tuple(a[7:11])
    if name == "battery":
        return {"charging": a[7] == 1, "full": a[7] == 2, "percent": a[8]}
    if name == "profile":
        return a[7]
    if name == "sleep":
        s = a[8] << 8 | a[9]
        return 0 if s in (0xFFFF, 0xFF00) else s        # seconds; 0: never
    if name == "pollingRate":
        return CODE_RATE.get(a[8], 0)
    if name == "dpiStages":
        n = min(a[8], 8)
        return [{"x": a[9 + 4 * i] << 8 | a[10 + 4 * i], "y": a[11 + 4 * i] << 8 | a[12 + 4 * i]} for i in range(n)]
    if name == "lod":
        return lod_mm(a[8])
    if name in ("angleSnap", "motionSync", "ripple", "hyperMode"):
        return a[8] == 1
    if name == "dpiMax":
        return a[7] << 8 | a[8]
    if name == "sensor":
        return a[7]
    return a[8]                                         # debounce (ms), dpiActive (1-based stage)
