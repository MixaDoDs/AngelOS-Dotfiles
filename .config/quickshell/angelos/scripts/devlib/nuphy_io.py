"""The "nuphy-io" protocol family: NuPhy's Hall-effect keyboards (Air60 HE, Air75 HE,
Halo65 HE, Field75 HE…) as their web configurator drive.nuphy.io talks to them.

Worked out from the configurator's JavaScript (2026-10-12); what was then checked on a real
Air60 HE is marked "checked" in docs/devices.md, the rest is "by the description".

A packet is 64 bytes on the service interface (interrupt OUT to the keyboard, interrupt IN back):

  [0] flag    0x55 a command from the host, 0xAA the keyboard's answer to it;
              anything else is a report the keyboard sends by itself (REPORT_*)
  [1] cmd     CMD_*; the answer repeats it
  [2] key     0, or the byte the answer's data is XORed with
  [3] sum     the low byte of the sum of bytes 4..63
  [4] len     data bytes in this packet (at most 56)
  [5] [6]     address inside the command's memory, little endian
  [7] 0
  [8..]       data

Every "Get…" command reads a region of the keyboard's memory by address and length, every
"Set…" writes one. This module builds and parses packets and turns the regions into plain
dicts; it does no I/O. Nothing here can build a firmware packet: the bootloader's commands
are not in it at all, and guard_write() refuses the one settings byte that enters it.
"""

PACKET = 64
DATA = 8
CHUNK = 56

FLAG_HOST = 0x55
FLAG_ANSWER = 0xAA
REPORT_KEY_STATUS = 0xA0        # one key's travel (while "key status upload" is on) or its calibration
REPORT_STATE = 0xA1             # the Fn layer and the mode changed
REPORT_RESET = 0xA2             # the keyboard was reset to factory settings
REPORT_FUNC = 0xA3              # mode settings changed on the keyboard itself (light, sleep, Win lock)
REPORT_DONGLE = 0xFA

CMD = {
    "QuickCommStart": 1, "QuickCommEnd": 2, "GetInfo": 3, "GetBase": 4, "GetFunc": 5, "SetFunc": 6,
    "GetDefaultKeyMatrix": 7, "GetUseKeyMatrix": 8, "SetUseKeyMatrix": 9, "GetLedDefine": 10,
    "SetLedDefine": 11, "GetMacro": 12, "SetMacro": 13, "GetGamepad": 16, "SetGamepad": 17,
    "GetKeyRTInfo": 160, "SetKeyRTInfo": 161, "GetDKSInfo": 162, "SetDKSInfo": 163,
    "GetMtKeyInfo": 164, "SetMtKeyInfo": 165, "GetTglKeyInfo": 166, "SetTglKeyInfo": 167,
    "StartCalibration": 168, "EndCalibration": 169, "GetCalibrationInfo": 170,
    "LedSyncDownload": 221, "LedSyncUpload": 222, "RestoreFactorySettings": 238,
    "GetAppDefine": 241, "SetAppDefine": 242,
}
CMD_NAME = {v: k for k, v in CMD.items()}

# commands that only read: the only ones a read-only session may send
READS = frozenset(CMD[n] for n in ("GetInfo", "GetBase", "GetFunc", "GetDefaultKeyMatrix", "GetUseKeyMatrix",
                                   "GetLedDefine", "GetMacro", "GetGamepad", "GetKeyRTInfo", "GetDKSInfo",
                                   "GetMtKeyInfo", "GetTglKeyInfo", "GetCalibrationInfo", "GetAppDefine",
                                   "LedSyncUpload"))
# settings writes this driver knows how to make, and to read back
WRITES = frozenset(CMD[n] for n in ("SetFunc", "SetUseKeyMatrix", "SetKeyRTInfo", "SetDKSInfo", "SetMtKeyInfo",
                                    "SetTglKeyInfo", "SetMacro", "SetLedDefine", "SetAppDefine"))
# asked for by an explicit button and a confirmation only, never as a side effect
DANGEROUS = frozenset(CMD[n] for n in ("RestoreFactorySettings", "StartCalibration", "EndCalibration"))

# the memory regions: sizes per mode / per layer
MODES = 3
LAYERS_PER_MODE = 4
LAYERS = MODES * LAYERS_PER_MODE
KEYS = 128                      # matrix slots a layer; a keyboard uses the first ones
FUNC_SIZE = 64                  # one mode's settings block
FUNC_READ = 54                  # what the configurator asks of it
MATRIX_SIZE = 512               # one layer: 128 keys × 3 bytes, then 16 "G" keys from byte 464
RT_SIZE = 1024                  # one mode: 128 keys × 8 bytes
RT_RECORD = 8

# key action types (the first byte of a matrix entry)
ACTION = {0: "none", 16: "keyboard", 32: "mouseKey", 33: "mouseWheel", 34: "mouseMove", 35: "mouseXY",
          48: "consumer", 64: "system", 80: "exe", 96: "web", 112: "macro", 128: "kbWheel",
          144: "dks", 145: "toggle", 146: "modTap", 147: "rappySnappy", 148: "socd", 149: "holdTap",
          224: "gkey", 240: "function", 241: "gamepad", 255: "empty"}

TRIGGER = {0: "normal", 1: "rapid", 2: "continuous"}
TRIGGER_ID = {v: k for k, v in TRIGGER.items()}
# which key of a Snap Tap / SOCD pair wins (the high nibble of an RT record's second byte)
PRIORITY = {0x00: "last", 0x10: "own", 0x20: "bond", 0x30: "neutral"}
RT_STEPS = {0: 0.01, 1: 0.005, 2: 0.001, 3: 0.01}       # mm a unit of Rapid Trigger sensitivity
TRAVEL_STEP = 0.01                                      # mm a unit of travel and of the actuation point

KEY_STATUS = {0: "idle", 255: "calibrated"}             # anything else: calibrating

# bytes of a mode's settings block that may be written: 4..7 rates, sleep, locks, flags;
# 8..16 the key light; 24..31 the side light; 39..41 sleep on newer firmware
FUNC_WRITABLE = frozenset(range(4, 17)) | frozenset(range(24, 32)) | frozenset((39, 40, 41))
BOOT_KEY = (240, 7)             # "reboot into the firmware loader", as a key: never written
LIGHT_ZONES = {"main": (8, 9), "side": (24, 8)}         # zone -> (offset in the block, bytes)


class ProtocolError(ValueError):
    pass


def checksum(packet):
    return sum(packet[4:PACKET]) & 0xFF


def build(cmd, length=0, addr=0, data=b""):
    """A host packet. `length` is what is asked for (a read) or len(data) (a write)."""
    if not 0 <= cmd <= 255:
        raise ProtocolError("command out of range")
    if not 0 <= length <= CHUNK or len(data) > CHUNK:
        raise ProtocolError("at most %d bytes a packet" % CHUNK)
    if not 0 <= addr <= 0xFFFF:
        raise ProtocolError("address out of range")
    p = bytearray(PACKET)
    p[0] = FLAG_HOST
    p[1] = cmd
    p[4] = length
    p[5] = addr & 0xFF
    p[6] = addr >> 8
    p[DATA:DATA + len(data)] = bytes(data)
    p[3] = checksum(p)
    return bytes(p)


def parse(packet):
    """{"flag", "cmd", "key", "sum_ok", "len", "addr", "data"} of a 64-byte packet."""
    if len(packet) != PACKET:
        raise ProtocolError("a packet is %d bytes, got %d" % (PACKET, len(packet)))
    length = min(packet[4], CHUNK)
    data = bytes(packet[DATA:DATA + length])
    key = packet[2]
    if key:
        data = bytes(b ^ key for b in data)
    return {"flag": packet[0], "cmd": packet[1], "key": key, "sum_ok": checksum(packet) == packet[3],
            "len": length, "addr": packet[5] | packet[6] << 8, "data": data}


def read_plan(cmd, addr, size):
    """The packets that read `size` bytes of a region from `addr`: [(packet, offset, length)]."""
    if cmd not in READS:
        raise ProtocolError("%s is not a read" % CMD_NAME.get(cmd, cmd))
    out, off = [], 0
    while off < size:
        n = min(CHUNK, size - off)
        out.append((build(cmd, n, addr + off), off, n))
        off += n
    return out


def guard_write(cmd, addr, data):
    """Raise unless this write is one the driver may make. The rules that keep a keyboard
    alive live here, in one place, and a write goes through no other door."""
    if cmd in DANGEROUS:
        raise ProtocolError("%s is sent only by its own confirmed action" % CMD_NAME[cmd])
    if cmd not in WRITES:
        raise ProtocolError("not a settings write: %s" % CMD_NAME.get(cmd, cmd))
    if cmd == CMD["SetFunc"]:
        # byte 0 of a mode's block switches the keyboard into its firmware loader: never written.
        # Only the bytes the configurator itself sets (FUNC_WRITABLE): rates, sleep, Win lock and
        # flags, the key light, the side light, sleep on newer firmware.
        for i in range(len(data)):
            at = (addr + i) % FUNC_SIZE
            if at not in FUNC_WRITABLE:
                raise ProtocolError("mode settings byte %d is not writable" % at)
        if addr + len(data) > MODES * FUNC_SIZE:
            raise ProtocolError("past the last mode")
    if cmd == CMD["SetUseKeyMatrix"]:
        # whole key entries only, and never the key that reboots the keyboard into its loader
        at = addr % MATRIX_SIZE
        if at < 464:
            if at % 3 or len(data) % 3 or at + len(data) > KEYS * 3:
                raise ProtocolError("a key is written whole: three bytes from a key's own place")
            for i in range(0, len(data), 3):
                if tuple(data[i:i + 2]) == BOOT_KEY:
                    raise ProtocolError("the firmware-loader key is never assigned")
        if addr + len(data) > LAYERS * MATRIX_SIZE:
            raise ProtocolError("past the last layer")


# ---- regions into plain dicts ------------------------------------------------------------

def parse_info(packet):
    """The GetInfo answer (the whole packet, not a region)."""
    d = packet[DATA:]
    text = bytes(d).split(b"\0")[0].decode("ascii", "ignore")
    if len(text) >= 3 and text[:3].isalpha():
        # old firmware answers with text alone
        return {"version": "100", "rf": "", "built": text.strip()}
    version = "%x" % (d[1] << 8 | d[0])
    built = bytes(d[2:]).split(b"\0")[0].decode("ascii", "ignore").strip()
    return {"version": version, "versionNumber": int(version) if version.isdigit() else 0, "built": built}


def base_offset(version, ranges):
    """Where the mode byte sits in GetBase: firmware 100..109 of some models keeps it 8 further."""
    for r in ranges or []:
        if int(r.get("min", 0)) <= version <= int(r.get("max", 10 ** 9)):
            return int(r.get("offset", 0))
    return 0


def parse_base(data, offset=0):
    return {"mode": data[offset], "layersPerMode": data[offset + 1] or LAYERS_PER_MODE}


def parse_func(data):
    """One mode's settings block (its first 54 bytes)."""
    rates, sleep, lock, flags = data[4], data[5], data[6], data[7]
    return {
        "reportRate": rates & 0x0F,
        "tickRate": rates >> 4,
        "sleepMinutes": sleep & 0x7F,
        "sleep": bool(sleep & 0x80),
        "lockWin": bool(lock & 1),
        "lockAltTab": bool(lock & 2),
        "lockAltF4": bool(lock & 4),
        "lockApp": bool(lock & 8),
        "speedMode": bool(flags & 1),
        "gameOptimization": bool(flags & 2),
        "dynamicCalibration": bool(flags & 4),
        # the keyboard reports every key's travel by itself while this is set
        "keyStatusUpload": bool(flags & 8),
        "stabilization": flags >> 4,
    }


def func_bytes(block, values):
    """Bytes 4..7 of a mode's settings block with `values` (parse_func's names) put in; what
    is not named stays as the block has it."""
    rates, sleep, lock, flags = block[4], block[5], block[6], block[7]
    v = values
    if "reportRate" in v:
        rates = rates & 0xF0 | max(1, min(4, int(v["reportRate"])))
    if "tickRate" in v:
        rates = rates & 0x0F | max(0, min(2, int(v["tickRate"]))) << 4
    if "sleepMinutes" in v:
        sleep = sleep & 0x80 | max(1, min(127, int(v["sleepMinutes"])))
    if "sleep" in v:
        sleep = sleep & 0x7F | (0x80 if v["sleep"] else 0)
    for name, bit in (("lockWin", 1), ("lockAltTab", 2), ("lockAltF4", 4), ("lockApp", 8)):
        if name in v:
            lock = lock & ~bit | (bit if v[name] else 0)
    for name, bit in (("speedMode", 1), ("gameOptimization", 2), ("dynamicCalibration", 4), ("keyStatusUpload", 8)):
        if name in v:
            flags = flags & ~bit | (bit if v[name] else 0)
    if "stabilization" in v:
        flags = flags & 0x0F | max(0, min(7, int(v["stabilization"]))) << 4
    return bytes((rates & 0xFF, sleep & 0xFF, lock & 0xFF, flags & 0xFF))


def parse_light(block):
    """The two lights of a mode's settings block. on: brightness above zero (that is how the
    configurator turns a light off); rainbow: the effect's own colours instead of `color`."""
    m = block[8:17]
    sd = block[24:32]
    return {
        "main": {"effect": m[0], "brightness": m[1], "on": m[1] > 0, "speed": max(0, min(4, abs(m[2] - 4))), "direction": m[3],
                 "rainbow": bool(m[4]), "color": "#%02x%02x%02x" % (m[6], m[7], m[8])},
        "side": {"effect": sd[0], "brightness": sd[1], "on": sd[1] > 0, "speed": max(0, min(4, abs(sd[2] - 4))),
                 "rainbow": bool(sd[3]), "color": "#%02x%02x%02x" % (sd[5], sd[6], sd[7])},
    }


def light_bytes(block, zone, values):
    """(offset, bytes) of a light's record with `values` put in (effect, brightness, speed,
    direction, rainbow, color "#rrggbb"); what is not named stays."""
    off, size = LIGHT_ZONES[zone]
    rec = bytearray(block[off:off + size])
    main = zone == "main"
    v = values
    if "effect" in v:
        rec[0] = int(v["effect"]) & 0xFF
    if "brightness" in v:
        rec[1] = max(0, min(100, int(v["brightness"])))
    if "speed" in v:
        rec[2] = max(0, min(4, abs(int(v["speed"]) - 4)))
    if main and "direction" in v:
        rec[3] = 1 if v["direction"] else 0
    if "rainbow" in v:
        rec[4 if main else 3] = 1 if v["rainbow"] else 0
    if "color" in v:
        c = str(v["color"]).lstrip("#")
        if len(c) != 6:
            raise ProtocolError("a colour is #rrggbb")
        try:
            rgb = bytes.fromhex(c)
        except ValueError:
            raise ProtocolError("a colour is #rrggbb") from None
        rec[(6 if main else 5):(9 if main else 8)] = rgb
    return off, bytes(rec)


# the Mod-Tap area: 32 slots of two actions a mode; Snap Tap pairs, Rappy Snappy and Hold-Tap
# keep their two keys' actions there too
MT_SIZE = 256
MT_SLOTS = 32
MT_RECORD = 6
SLOT_TYPES = (146, 147, 148, 149)       # matrix entries (type, slot, …) that own a Mod-Tap slot
SOCD_TYPE = 148
RS_TYPE = 147
MT_TYPE = 146
TGL_TYPE = 145
DKS_TYPE = 144
# Toggle: 32 slots of one action a mode; DKS: 32 slots of 24 bytes a mode
TGL_SIZE = 128
TGL_RECORD = 3
DKS_SIZE = 768
DKS_RECORD = 24
MT_DELAY = (10, 1000)                   # ms; the matrix entry keeps it in tens of ms

# the keyboard's own polling rate: the mode block's report-rate code (drive.nuphy.io's
# "ResponseRate" list). Changing it makes the keyboard come back on USB anew.
REPORT_RATE = {4: 1000, 3: 2000, 2: 4000, 1: 8000}


def units_actuation(mm, step=TRAVEL_STEP):
    return max(0, min(0x1FF, int(round(mm / step)) - 1))


def units_sensitivity(mm, step):
    return max(0, min(0x1FF, int(round(mm / step)) - 1))


def units_dead(mm):
    return 0 if mm < 0.015 else max(1, min(0x7F, int(round(mm / TRAVEL_STEP)) - 1))


def parse_matrix(data):
    """A layer: [(type, code0, code1)] × 128, and its 16 G keys."""
    if len(data) != MATRIX_SIZE:
        raise ProtocolError("a layer is %d bytes" % MATRIX_SIZE)
    keys = [tuple(data[3 * i:3 * i + 3]) for i in range(KEYS)]
    gkeys = [tuple(data[464 + 3 * i:464 + 3 * i + 3]) for i in range(16)]
    return keys, gkeys


def parse_rt(rec):
    """One key's travel settings (8 bytes). Lengths are in the record's own units; mm_*()
    below turn them into millimetres."""
    a = rec[3] << 8 | rec[2]
    press = rec[5] << 8 | rec[4]
    release = rec[7] << 8 | rec[6]
    return {
        "switch": rec[0] & 0x1F,
        # the top three bits: a mark the firmware wants on every record it is given
        # (5 on current firmware, 0 on versions 100..109)
        "check": rec[0] >> 5,
        "trigger": TRIGGER.get(rec[1] & 0x0F, "normal"),
        "priority": PRIORITY.get(rec[1] & 0xF0, "last"),
        "actuation": a & 0x1FF,
        "pressStep": RT_STEPS[(rec[3] >> 1) & 3],
        "releaseStep": RT_STEPS[(rec[3] >> 3) & 3],
        "press": press & 0x1FF,
        "pressDead": press >> 9 & 0x7F,
        "release": release & 0x1FF,
        "releaseDead": release >> 9 & 0x7F,
    }


def build_rt(rt):
    """parse_rt() backwards."""
    steps = {0.01: 0, 0.005: 1, 0.001: 2}
    rec = bytearray(RT_RECORD)
    rec[0] = (rt.get("check", 5) & 7) << 5 | rt["switch"] & 0x1F
    rec[1] = {v: k for k, v in PRIORITY.items()}[rt["priority"]] | TRIGGER_ID[rt["trigger"]]
    a = rt["actuation"] & 0x1FF
    rec[2] = a & 0xFF
    rec[3] = a >> 8 & 1 | steps.get(rt["pressStep"], 0) << 1 | steps.get(rt["releaseStep"], 0) << 3
    press = (rt["pressDead"] & 0x7F) << 9 | rt["press"] & 0x1FF
    rec[4], rec[5] = press & 0xFF, press >> 8
    release = (rt["releaseDead"] & 0x7F) << 9 | rt["release"] & 0x1FF
    rec[6], rec[7] = release & 0xFF, release >> 8
    return bytes(rec)


def mm_actuation(units):
    """The actuation point: the record counts from 0.01 mm, so 149 is 1.50 mm."""
    return round((units + 1) * TRAVEL_STEP, 3)


def mm_sensitivity(units, step):
    return round((units + 1) * step, 3)


def mm_dead(units):
    return 0.0 if units == 0 else round((units + 1) * TRAVEL_STEP, 3)


def rt_mm(rt):
    """An RT record in millimetres, as the configurator shows it."""
    return {
        "switch": rt["switch"], "trigger": rt["trigger"], "priority": rt["priority"],
        "actuation": mm_actuation(rt["actuation"]),
        "press": mm_sensitivity(rt["press"], rt["pressStep"]),
        "release": mm_sensitivity(rt["release"], rt["releaseStep"]),
        "pressDead": mm_dead(rt["pressDead"]),
        "releaseDead": mm_dead(rt["releaseDead"]),
    }


def parse_report(packet):
    """A packet the keyboard sent by itself, None for one this driver does not know.
      {"type": "key", "key": (type, code0, code1), "travel": units of 0.01 mm, "raw": N, "status"}
      {"type": "state", "layer", "mode"} | {"type": "reset"} | {"type": "func", …}"""
    if len(packet) < 11:
        return None
    flag = packet[0]
    if flag == REPORT_KEY_STATUS:
        s = packet[10]
        return {"type": "key", "key": (packet[1], packet[2], packet[3]), "raw": packet[4] << 8 | packet[5],
                "travel": packet[6] << 8 | packet[7], "status": KEY_STATUS.get(s, "calibrating")}
    if flag == REPORT_STATE:
        return {"type": "state", "layer": packet[1], "mode": packet[2]}
    if flag == REPORT_RESET:
        return {"type": "reset"}
    if flag == REPORT_FUNC:
        return {"type": "func", "lockWin": bool(packet[6] & 1), "sleepMinutes": packet[5] & 0x7F,
                "sleep": bool(packet[5] & 0x80)}
    return None


# ---- names for people --------------------------------------------------------------------

_HID = {4: "A", 5: "B", 6: "C", 7: "D", 8: "E", 9: "F", 10: "G", 11: "H", 12: "I", 13: "J", 14: "K", 15: "L",
        16: "M", 17: "N", 18: "O", 19: "P", 20: "Q", 21: "R", 22: "S", 23: "T", 24: "U", 25: "V", 26: "W",
        27: "X", 28: "Y", 29: "Z", 30: "1", 31: "2", 32: "3", 33: "4", 34: "5", 35: "6", 36: "7", 37: "8",
        38: "9", 39: "0", 40: "Enter", 41: "Esc", 42: "Backspace", 43: "Tab", 44: "Space", 45: "-", 46: "=",
        47: "[", 48: "]", 49: "\\", 50: "#", 51: ";", 52: "'", 53: "`", 54: ",", 55: ".", 56: "/",
        57: "Caps Lock", 58: "F1", 59: "F2", 60: "F3", 61: "F4", 62: "F5", 63: "F6", 64: "F7", 65: "F8",
        66: "F9", 67: "F10", 68: "F11", 69: "F12", 70: "Print Screen", 71: "Scroll Lock", 72: "Pause",
        73: "Insert", 74: "Home", 75: "Page Up", 76: "Delete", 77: "End", 78: "Page Down", 79: "Right",
        80: "Left", 81: "Down", 82: "Up", 83: "Num Lock", 100: "\\ (ISO)", 101: "Menu"}
_MODS = ((0x01, "Ctrl"), (0x02, "Shift"), (0x04, "Alt"), (0x08, "Super"),
         (0x10, "Right Ctrl"), (0x20, "Right Shift"), (0x40, "Right Alt"), (0x80, "Right Super"))


_CONSUMER = {(205, 0): "Play/Pause", (181, 0): "Next", (182, 0): "Previous", (183, 0): "Stop", (226, 0): "Mute",
             (233, 0): "Vol +", (234, 0): "Vol −", (111, 0): "Screen +", (112, 0): "Screen −", (146, 1): "Calculator",
             (138, 1): "Mail", (148, 1): "Files", (131, 1): "Player", (35, 2): "Web home", (36, 2): "Web back",
             (37, 2): "Web forward", (39, 2): "Web refresh", (33, 2): "Web search", (159, 2): "Mission Control",
             (160, 2): "Launchpad", (207, 0): "Siri"}
_FUNCTION = {1: "Kbd lock", 2: "Win lock", 4: "Win mode", 5: "Mac mode", 6: "Win/Mac", 8: "Factory reset", 16: "Side +",
             17: "Side −", 18: "Side slower", 19: "Side faster", 21: "Side colour", 22: "Side effect", 46: "Light next",
             47: "Light prev", 48: "Light on/off", 50: "Light +", 51: "Light −", 52: "Light loop", 53: "Light off",
             54: "Faster", 55: "Slower", 57: "Light ←", 58: "Light →", 60: "Colour +", 61: "Colour −", 62: "Colour loop",
             81: "Mac search", 82: "Sleep", 83: "Shot area", 84: "Shot screen", 85: "Mac shot area", 86: "Mac shot",
             250: "Mode 1", 251: "Mode 2", 252: "Mode 3", 254: "Layer switch"}
_MOUSE = {(32, 1, 0): "Mouse L", (32, 2, 0): "Mouse R", (32, 4, 0): "Mouse M", (32, 8, 0): "Mouse back",
          (32, 16, 0): "Mouse fwd", (32, 1, 1): "Double click", (33, 0, 1): "Wheel ↑", (33, 0, 255): "Wheel ↓"}
_HID.update({70: "PrtSc", 71: "ScrLk", 73: "Ins", 74: "Home", 75: "PgUp", 76: "Del", 77: "End", 78: "PgDn", 79: "→", 80: "←",
             81: "↓", 82: "↑", 83: "NumLk", 84: "Num /", 85: "Num *", 86: "Num −", 87: "Num +", 88: "Num Enter", 99: "Num ."})
_HID.update({89 + i: "Num %d" % (i + 1) for i in range(9)})
_HID[98] = "Num 0"
_HID.update({104 + i: "F%d" % (13 + i) for i in range(12)})


def action_name(entry):
    """A matrix entry for a person: "A", "Shift", "Ctrl+C", "Fn", "Vol +", "—"."""
    kind, c0, c1 = entry
    name = ACTION.get(kind, "?")
    if name in ("none", "empty") or (kind == 16 and not c0 and not c1):
        return "—"
    if name == "keyboard":
        parts = [n for bit, n in _MODS if c0 & bit]
        if c1:
            parts.append(_HID.get(c1, "0x%02X" % c1))
        return "+".join(parts)
    if name == "function":
        if c0 == 255:
            return "Fn %d" % (c1 % LAYERS_PER_MODE) if c1 % LAYERS_PER_MODE else "Fn 0"
        return _FUNCTION.get(c0, "Fn %d/%d" % (c0, c1))
    if name == "consumer":
        return _CONSUMER.get((c0, c1), "Media %d/%d" % (c0, c1))
    if tuple(entry) in _MOUSE:
        return _MOUSE[tuple(entry)]
    if name in ("socd", "rappySnappy"):
        return "Snap Tap"
    if name == "macro":
        return "Macro %d" % (c0 + 1)
    return {"dks": "DKS", "toggle": "Toggle", "modTap": "Mod-Tap", "holdTap": "Hold-Tap"}.get(name, "%s %d/%d" % (name, c0, c1))


# ---- what a key can be given: the picker of the settings page ----------------------------

_SAFE_FUNCTIONS = (48, 46, 47, 50, 51, 54, 55, 60, 61, 62, 16, 17, 21, 22, 2, 1, 82, 84, 83)


def catalog(mode=0):
    """[{"id", "ru", "en", "items": [{"label", "action": [t, c0, c1]}]}]: every action the page
    offers, by group. Nothing here is a firmware door: no loader key, no factory reset."""
    def k(hid):
        return {"label": _HID.get(hid, "0x%02X" % hid), "action": [16, 0, hid]}
    letters = [k(h) for h in range(4, 30)] + [k(h) for h in range(30, 40)]
    symbols = [k(h) for h in (41, 43, 57, 44, 40, 42, 76, 73, 45, 46, 47, 48, 49, 51, 52, 53, 54, 55, 56, 100, 101)]
    nav = [k(h) for h in list(range(58, 70)) + list(range(104, 116)) + [82, 81, 80, 79, 74, 77, 75, 78, 70, 71, 72]]
    numpad = [k(h) for h in [83, 84, 85, 86, 87, 88, 99] + list(range(89, 99))]
    mods = [{"label": n, "action": [16, bit, 0]} for bit, n in _MODS]
    media = [{"label": n, "action": [48, c0, c1]} for (c0, c1), n in _CONSUMER.items()]
    mouse = [{"label": n, "action": list(e)} for e, n in _MOUSE.items()]
    layers = [{"label": "Fn %d" % n, "action": [240, 255, mode * LAYERS_PER_MODE + n]} for n in (1, 2, 3)]
    ru = {48: "Свет вкл/выкл", 46: "Эффект →", 47: "Эффект ←", 50: "Ярче", 51: "Тусклее", 54: "Быстрее", 55: "Медленнее",
          60: "Цвет +", 61: "Цвет −", 62: "Цвета по кругу", 16: "Боковой ярче", 17: "Боковой тусклее", 21: "Боковой цвет",
          22: "Боковой эффект", 2: "Блок Win", 1: "Блок клавиатуры", 82: "Сон", 84: "Снимок экрана", 83: "Снимок области"}
    board = [{"label": _FUNCTION[c], "ru": ru.get(c, ""), "action": [240, c, 0]} for c in _SAFE_FUNCTIONS] + \
            [{"label": "Mode %d" % (n + 1), "ru": "Режим %d" % (n + 1), "action": [240, 250 + n, 0]} for n in range(MODES)]
    return [
        {"id": "letters", "ru": "Буквы и цифры", "en": "Letters and digits", "items": letters},
        {"id": "symbols", "ru": "Символы и правка", "en": "Symbols and editing", "items": symbols},
        {"id": "nav", "ru": "F1–F24 и стрелки", "en": "F1–F24 and arrows", "items": nav},
        {"id": "mods", "ru": "Модификаторы", "en": "Modifiers", "items": mods},
        {"id": "media", "ru": "Медиа", "en": "Media", "items": media},
        {"id": "mouse", "ru": "Мышь", "en": "Mouse", "items": mouse},
        {"id": "layers", "ru": "Слои Fn", "en": "Fn layers", "items": layers},
        {"id": "board", "ru": "Клавиатура", "en": "The keyboard", "items": board},
        {"id": "numpad", "ru": "Цифровой блок", "en": "Numpad", "items": numpad},
    ]
