"""Made-up devices that answer like the real ones: for the tests, the UI stand and for working
on a page without the hardware (ANGELOS_DEVICES_FAKE). An emulator is a channel, like
usbfs.Interface: write() a packet, read() what comes back.

NuphyEmu keeps the keyboard's memory regions as the protocol addresses them, built from the
device's description (its keys' factory actions), answers every Get…/Set… and, while "key
status upload" is on in the current mode, reports key travel by a script:

  idle            nothing is pressed
  wave            a press runs across the keyboard, row by row (the default)
  press:3,17      keys 3 and 17 (matrix numbers) held to the bottom
  half:3          key 3 held at half its travel
"""
import math
import queue
import threading
import time

from . import nuphy_io as np


class NuphyEmu:
    def __init__(self, desc, script="wave", version=0x0114, mode=1, upload=True):
        self.desc = desc
        self.script = script or "wave"
        self.keys = sorted(k["m"] for k in desc["layout"]["keys"])
        self.travel_max = int(round(max((s["travel"] for s in desc.get("switches", [])), default=3.3) * 100))
        self.out = queue.Queue()
        self.sent = []                      # every packet the host wrote: what a test looks at
        self._stop = threading.Event()
        self._thread = None
        opts = desc.get("nuphy-io", {})
        default_layer = int(opts.get("defaultLayer", 4))
        switch = (desc.get("switches") or [{"id": 0}])[-1]["id"]

        layer = bytearray([255]) * np.MATRIX_SIZE
        blank = bytearray([255]) * np.MATRIX_SIZE
        for i in range(max(self.keys) + 1 + 3):
            layer[3 * i:3 * i + 3] = bytes(3)
            blank[3 * i:3 * i + 3] = bytes((16, 0, 0))
        for k in desc["layout"]["keys"]:
            layer[3 * k["m"]:3 * k["m"] + 3] = bytes(k.get("default", (16, 0, 0)))
        matrix = bytearray()
        for n in range(np.LAYERS):
            matrix += layer if n % np.LAYERS_PER_MODE == default_layer % np.LAYERS_PER_MODE else blank

        func = bytearray()
        for m in range(np.MODES):
            block = bytearray(np.FUNC_SIZE)
            block[0:4] = bytes((80, 4 * m, 170, 187))
            block[4] = 1                    # report rate 1, no tick rate
            block[5] = 0x80 | 6             # sleep after 6 minutes
            block[7] = 0x03 | (0x08 if upload else 0)
            block[8:17] = bytes((6, 60, 2, 0, 0, 0, 0x30, 0x80, 0xff))     # key light: a wave, blue
            block[24:32] = bytes((2, 60, 2, 0, 0, 0xff, 0x40, 0x00))       # side light: static, orange
            func += block
        info = bytearray(np.PACKET)
        info[0], info[1] = np.FLAG_ANSWER, np.CMD["GetInfo"]
        info[np.DATA] = version & 0xFF
        info[np.DATA + 1] = version >> 8
        built = b"Oct 12 2026,00:00:00"
        info[np.DATA + 2:np.DATA + 2 + len(built)] = built
        info[4] = 2 + len(built)
        info[3] = np.checksum(info)
        self.info = bytes(info)
        base = bytearray([162]) * 256
        base[0:4] = bytes((mode, np.LAYERS_PER_MODE, 170, 187))
        self.mem = {
            np.CMD["GetBase"]: base,
            np.CMD["GetFunc"]: func,
            np.CMD["GetDefaultKeyMatrix"]: bytearray(matrix),
            np.CMD["GetUseKeyMatrix"]: bytearray(matrix),
            np.CMD["GetKeyRTInfo"]: bytearray(bytes((5 << 5 | switch, 0, 149, 0, 0, 0, 0, 0)) * (np.KEYS * np.MODES)),
            np.CMD["GetDKSInfo"]: bytearray(3072),
            np.CMD["GetMtKeyInfo"]: bytearray(768),
            np.CMD["GetTglKeyInfo"]: bytearray(384),
            np.CMD["GetMacro"]: bytearray(6144),
            np.CMD["GetLedDefine"]: bytearray(1536),
            np.CMD["GetCalibrationInfo"]: bytearray(1536),
            np.CMD["GetAppDefine"]: bytearray(1536),
            np.CMD["GetGamepad"]: bytearray(256),
            np.CMD["LedSyncUpload"]: bytearray(512),
        }
        # a Set… writes the region its Get… reads
        self.pair = {np.CMD["SetFunc"]: np.CMD["GetFunc"], np.CMD["SetUseKeyMatrix"]: np.CMD["GetUseKeyMatrix"],
                     np.CMD["SetKeyRTInfo"]: np.CMD["GetKeyRTInfo"], np.CMD["SetDKSInfo"]: np.CMD["GetDKSInfo"],
                     np.CMD["SetMtKeyInfo"]: np.CMD["GetMtKeyInfo"], np.CMD["SetTglKeyInfo"]: np.CMD["GetTglKeyInfo"],
                     np.CMD["SetMacro"]: np.CMD["GetMacro"], np.CMD["SetLedDefine"]: np.CMD["GetLedDefine"],
                     np.CMD["SetAppDefine"]: np.CMD["GetAppDefine"], np.CMD["SetGamepad"]: np.CMD["GetGamepad"]}

    # ---- the channel ----
    def open(self):
        self._stop.clear()
        self._thread = threading.Thread(target=self._play, daemon=True)
        self._thread.start()
        return self

    def close(self):
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=1)
            self._thread = None

    def read(self, size=64, timeout_ms=100):
        try:
            return self.out.get(timeout=timeout_ms / 1000)
        except queue.Empty:
            return b""

    def write(self, data, timeout_ms=1000):
        packet = bytes(data)
        self.sent.append(packet)
        answer = self.answer(packet)
        if answer is not None:
            self.out.put(answer)
        return len(packet)

    # ---- the keyboard ----
    def mode(self):
        return self.mem[np.CMD["GetBase"]][0]

    def uploading(self):
        return bool(self.mem[np.CMD["GetFunc"]][self.mode() * np.FUNC_SIZE + 7] & 8)

    def answer(self, packet):
        p = np.parse(packet)
        if p["flag"] != np.FLAG_HOST or not p["sum_ok"]:
            return None                     # a real keyboard stays silent to a broken packet
        cmd, addr, length = p["cmd"], p["addr"], p["len"]
        if cmd == np.CMD["GetInfo"]:
            return self.info
        out = bytearray(np.PACKET)
        out[0], out[1], out[4], out[5], out[6] = np.FLAG_ANSWER, cmd, length, addr & 0xFF, addr >> 8
        if cmd in self.mem:
            region = self.mem[cmd]
            if addr + length > len(region):
                return None
            out[np.DATA:np.DATA + length] = region[addr:addr + length]
        elif cmd in self.pair:
            region = self.mem[self.pair[cmd]]
            if addr + length > len(region):
                return None
            region[addr:addr + length] = p["data"]
            out[np.DATA:np.DATA + length] = p["data"]
        elif cmd == np.CMD["RestoreFactorySettings"]:
            self.mem[np.CMD["GetUseKeyMatrix"]][:] = self.mem[np.CMD["GetDefaultKeyMatrix"]]
            report = bytearray(np.PACKET)
            report[0] = np.REPORT_RESET
            self.out.put(bytes(out))
            return bytes(report)
        out[3] = np.checksum(out)
        return bytes(out)

    def key_packet(self, m, travel):
        # the key's factory action in the mode the keyboard is in (the modes' layers differ)
        layer = self.mem[np.CMD["GetBase"]][0] * np.LAYERS_PER_MODE
        entry = self.mem[np.CMD["GetDefaultKeyMatrix"]][layer * np.MATRIX_SIZE + 3 * m:][:3]
        p = bytearray(np.PACKET)
        p[0] = np.REPORT_KEY_STATUS
        p[1:4] = entry
        raw = 2600 - travel * 3             # a Hall sensor reads lower as the magnet comes down
        p[4], p[5] = raw >> 8, raw & 0xFF
        p[6], p[7] = travel >> 8, travel & 0xFF
        p[10] = 255
        return bytes(p)

    def depths(self, t):
        """{m: travel in 0.01 mm} of the script at time t."""
        s = self.script
        if s.startswith("press:") or s.startswith("half:"):
            deep = self.travel_max if s.startswith("press:") else self.travel_max // 2
            out = {}
            for part in s.split(":", 1)[1].split(","):
                if part.strip().isdigit():
                    out[int(part)] = deep
            return out
        if s == "wave":
            out = {}
            n = len(self.keys)
            head = (t * 9) % (n + 6)        # nine keys a second
            for i, m in enumerate(self.keys):
                d = head - i
                if 0 <= d < 5:
                    out[m] = int(self.travel_max * math.sin(math.pi * d / 5) ** 2)
            return out
        return {}

    def _play(self):
        last = {}
        start = time.monotonic()
        while not self._stop.wait(0.004):
            if not self.uploading():
                last = {}
                continue
            now = self.depths(time.monotonic() - start)
            for m in set(now) | set(last):
                v = now.get(m, 0)
                if v != last.get(m, 0):
                    self.out.put(self.key_packet(m, v))
            last = now


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
