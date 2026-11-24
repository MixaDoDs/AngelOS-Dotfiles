"""A made-up device that answers like the real one: for the tests, the UI stand and for working
on a page without the hardware (ANGELOS_DEVICES_FAKE). An emulator is a channel, like
hidraw.FeatureChannel: set() a feature report, get() what comes back.
"""


class AuroraEmu:
    """A made-up LAMZU mouse: a feature channel (set / get) that answers lamzu-aurora's
    reads and takes its writes. script "asleep": the dongle alone answers."""

    def __init__(self, desc, script="idle"):
        from . import lamzu_aurora as au
        self.au = au
        self.desc = desc
        self.asleep = script == "asleep"
        self.sent = []
        self.last = bytes(65)
        self.settings = {"profile": 1, "firmware": (0, 0, 0, 19), "battery": (0, 87), "pollingRate": 128 if 8000 in (desc["capabilities"].get("pollingRate") or {}).get("values", []) else 1,
                         "dpiActive": 2, "dpiStages": [(400, 400), (800, 800), (1600, 1600), (3200, 3200)],
                         "lod": 1, "debounce": 2, "motionSync": 1, "angleSnap": 0, "ripple": 0, "sleep": 60}

    def open(self):
        return self

    def close(self):
        pass

    def set(self, payload):
        au = self.au
        p = bytes(payload)[:64].ljust(64, b"\0")
        self.sent.append(p)
        out = bytearray(65)
        out[2:8] = bytes((0, p[2], p[3], p[4], p[5], 0))        # the request back: [3] target … [6] opcode
        out[1] = 0xA0
        if self.asleep:
            self.last = bytes(out)
            return
        cat, op = p[4], p[5]
        name = next((n for n, (c, w, r) in au.ALLOWED.items() if c == cat and op in (w, r)), None)
        if name is None:
            out[1] = 0xA2                                       # the mouse refuses what it does not know
            self.last = bytes(out)
            return
        st = self.settings
        if op < 0x80:                                           # a write
            v = p[7:]
            if name == "dpiStages":
                st[name] = [(v[1 + 4 * i] << 8 | v[2 + 4 * i], v[3 + 4 * i] << 8 | v[4 + 4 * i]) for i in range(min(v[0], 8))]
                st["dpiActive"] = min(st["dpiActive"], len(st[name]))
            elif name == "sleep":
                st[name] = v[0] << 8 | v[1]
            else:
                st[name] = v[0]
        out[1] = 0xA1
        if name == "firmware":
            out[7:11] = bytes(st[name])
        elif name == "battery":
            out[7:9] = bytes(st[name])
        elif name == "profile":
            out[7] = st[name]
        elif name == "sleep":
            out[7], out[8], out[9] = p[6], st[name] >> 8, st[name] & 0xFF
        elif name == "dpiStages":
            out[7], out[8] = p[6], len(st[name])
            for i, (x, y) in enumerate(st[name]):
                out[9 + 4 * i:13 + 4 * i] = bytes((x >> 8, x & 0xFF, y >> 8, y & 0xFF))
        elif name == "dpiMax":
            out[7], out[8] = 30000 >> 8, 30000 & 0xFF
        elif name == "sensor":
            out[7] = 2
        else:
            out[7], out[8] = p[6], st[name]
        self.last = bytes(out)

    def get(self):
        return self.last
