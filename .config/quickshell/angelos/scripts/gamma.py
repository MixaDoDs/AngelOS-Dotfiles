#!/usr/bin/env python3
"""Screen brightness and night light through the compositor's gamma tables
(wlr-gamma-control-unstable-v1, niri has it) — services/ScreenTune, Settings → Monitor.

usage: gamma.py            reads JSON lines on stdin, keeps the tables while it runs
       gamma.py --probe    prints the outputs and whether gamma control is there, exits

stdin, one JSON object a line (each one replaces the last):
  {"outputs": {"DP-1": {"brightness": 0.8}, …},          0.3–1.0, missing = 1.0; also
                                                         gamma 0.5–2, contrast 0.5–1.5,
                                                         red/green/blue 0.5–1 (CURVE)
   "night": null | {"day": 6600, "night": 3900,           kelvin
                    "sunrise": "07:00", "sunset": "20:00", fixed times, or
                    "location": [55.75, 37.62],            the sun's own (lat, lon)
                    "fade": 1800}}                         s, sunset → full night
stdout, JSON lines: {"outputs": {name: "ok" | "neutral" | "failed" | "waiting"},
                     "kelvin": 6600, "error": "…"} whenever something changes.

One process for both, because a gamma table has one owner: wlsunset next to this
would get "failed" (and so would this next to it). An output with nothing to change
lets its table go (the compositor puts the original back), so do the tables when
this exits. Pure Python: the Wayland wire protocol is small enough to speak directly
(no pywayland); the ramp goes over as a memfd.
"""
import array
import datetime as dt
import json
import math
import os
import select
import socket
import struct
import sys
import time

MIN_BRIGHTNESS = 0.3
NEUTRAL_K = 6600          # at and above this the night light changes nothing
# the rest of an output's curve: key -> (as at boot, min, max), as in services/ScreenTune
CURVE = {"gamma": (1.0, 0.5, 2.0), "contrast": (1.0, 0.5, 1.5),
         "red": (1.0, 0.5, 1.0), "green": (1.0, 0.5, 1.0), "blue": (1.0, 0.5, 1.0)}


def num(t, key, default, lo, hi):
    try:
        return max(lo, min(hi, float(t.get(key, default))))
    except (TypeError, ValueError):
        return default


# ---------------------------------------------------------------- wire protocol
class Wayland:
    def __init__(self):
        name = os.environ.get("WAYLAND_DISPLAY", "wayland-0")
        path = name if name.startswith("/") else os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), name)
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.connect(path)
        self.next_id = 2
        self.inbox = b""
        self.handlers = {}          # object id -> fn(opcode, payload)
        self.handlers[1] = self._display_event

    def new_id(self):
        i = self.next_id
        self.next_id += 1
        return i

    @staticmethod
    def string(s):
        b = s.encode() + b"\0"
        return struct.pack("=I", len(b)) + b + b"\0" * (-len(b) % 4)

    def send(self, obj, opcode, payload=b"", fds=()):
        msg = struct.pack("=II", obj, ((8 + len(payload)) << 16) | opcode) + payload
        if fds:
            self.sock.sendmsg([msg], [(socket.SOL_SOCKET, socket.SCM_RIGHTS, array.array("i", fds))])
        else:
            self.sock.sendall(msg)

    def _display_event(self, op, p):
        if op == 0:                 # error(object, code, message)
            obj, code = struct.unpack_from("=II", p)
            raise RuntimeError("wayland error on object %d code %d: %s" % (obj, code, read_string(p, 8)[0]))
        if op == 1:                 # delete_id
            self.handlers.pop(struct.unpack_from("=I", p)[0], None)

    def dispatch(self):
        data = self.sock.recv(65536)
        if not data:
            raise ConnectionError("the compositor went away")
        self.inbox += data
        while len(self.inbox) >= 8:
            obj, word = struct.unpack_from("=II", self.inbox)
            size, op = word >> 16, word & 0xFFFF
            if len(self.inbox) < size:
                break
            payload, self.inbox = self.inbox[8:size], self.inbox[size:]
            h = self.handlers.get(obj)
            if h:
                h(op, payload)

    def roundtrip(self):
        done = []
        cb = self.new_id()
        self.handlers[cb] = lambda op, p: done.append(1)
        self.send(1, 0, struct.pack("=I", cb))          # wl_display.sync
        while not done:
            self.dispatch()


def read_string(p, off):
    n = struct.unpack_from("=I", p, off)[0]
    s = p[off + 4:off + 4 + max(0, n - 1)].decode("utf-8", "replace")
    return s, off + 4 + n + (-n % 4)


# ---------------------------------------------------------------- outputs and tables
class Output:
    def __init__(self, wl, global_name, oid):
        self.wl, self.global_name, self.id = wl, global_name, oid
        self.name = ""
        self.control = 0            # zwlr_gamma_control_v1 id, 0 = none
        self.size = 0
        self.state = "neutral"
        self.applied = None
        wl.handlers[oid] = self.event

    def event(self, op, p):
        if op == 4:                 # name (wl_output v4)
            self.name = read_string(p, 0)[0]

    def control_event(self, op, p):
        if op == 0:                 # gamma_size
            self.size = struct.unpack_from("=I", p)[0]
            self.state = "waiting"
            self.applied = None
        elif op == 1:               # failed: someone else holds it, or the output left
            self.release(destroy=True)
            self.state = "failed"

    def ensure_control(self, manager):
        if self.control or self.state == "failed":
            return
        self.control = self.wl.new_id()
        self.wl.handlers[self.control] = self.control_event
        self.wl.send(manager, 0, struct.pack("=II", self.control, self.id))
        self.state = "waiting"

    def release(self, destroy=True):
        if self.control:
            if destroy:
                self.wl.send(self.control, 1)
            self.wl.handlers.pop(self.control, None)
        self.control, self.size, self.applied = 0, 0, None

    def apply(self, brightness, white, gamma=1.0, contrast=1.0):
        if not self.control or not self.size:
            return
        key = (round(brightness, 4), tuple(round(c, 4) for c in white), round(gamma, 4), round(contrast, 4))
        if key == self.applied:
            return
        n = self.size
        # the curve is the same for each channel: gamma (above 1 lifts the mid-tones), then
        # contrast round the middle grey; brightness and the channel's own gain scale it
        curve = [min(1.0, max(0.0, ((i / (n - 1)) ** (1.0 / gamma) - 0.5) * contrast + 0.5)) for i in range(n)]
        ramp = array.array("H")
        for c in white:
            k = brightness * c * 65535.0
            ramp.extend(min(65535, int(v * k + 0.5)) for v in curve)
        fd = os.memfd_create("angelos-gamma", os.MFD_CLOEXEC)
        try:
            os.write(fd, ramp.tobytes())
            os.lseek(fd, 0, os.SEEK_SET)
            self.wl.send(self.control, 0, b"", fds=(fd,))
        finally:
            os.close(fd)
        self.applied = key
        self.state = "ok"


# ---------------------------------------------------------------- night light
def kelvin_white(k):
    """the white point of a black body at k kelvin as RGB multipliers, 1.0 at 6600 K
    (Tanner Helland's fit; wlsunset's tint is within a few percent of it)"""
    t = max(1000.0, min(25000.0, float(k))) / 100.0
    r = 1.0 if t <= 66 else min(1.0, 329.698727446 * (t - 60) ** -0.1332047592 / 255)
    g = (99.4708025861 * math.log(t) - 161.1195681661) / 255 if t <= 66 else 288.1221695283 * (t - 60) ** -0.0755148492 / 255
    b = 1.0 if t >= 66 else (0.0 if t <= 19 else (138.5177312231 * math.log(t - 10) - 305.0447927307) / 255)
    return tuple(max(0.0, min(1.0, c)) for c in (r, g, b))


def sun_times(day, lat, lon, elevation):
    """local datetimes when the sun crosses `elevation` degrees going up and going down
    (NOAA's simplified equations); None for a polar day / night"""
    n = day.timetuple().tm_yday
    g = 2 * math.pi / 365 * (n - 1)
    eqt = 229.18 * (0.000075 + 0.001868 * math.cos(g) - 0.032077 * math.sin(g) - 0.014615 * math.cos(2 * g) - 0.040849 * math.sin(2 * g))
    decl = 0.006918 - 0.399912 * math.cos(g) + 0.070257 * math.sin(g) - 0.006758 * math.cos(2 * g) + 0.000907 * math.sin(2 * g) - 0.002697 * math.cos(3 * g) + 0.00148 * math.sin(3 * g)
    la = math.radians(lat)
    cos_h = (math.sin(math.radians(elevation)) - math.sin(la) * math.sin(decl)) / (math.cos(la) * math.cos(decl))
    if abs(cos_h) > 1:
        return None
    h = math.degrees(math.acos(cos_h))
    noon = 720 - 4 * lon - eqt                      # minutes after UTC midnight
    base = dt.datetime(day.year, day.month, day.day, tzinfo=dt.timezone.utc)
    up = base + dt.timedelta(minutes=noon - 4 * h)
    down = base + dt.timedelta(minutes=noon + 4 * h)
    return up.astimezone(), down.astimezone()


def hhmm(day, s, tz):
    h, _, m = str(s).partition(":")
    return dt.datetime(day.year, day.month, day.day, int(h) % 24, int(m or 0) % 60, tzinfo=tz)


def night_kelvin(night, now=None):
    """the temperature now, and the seconds until it next needs looking at"""
    if not night:
        return NEUTRAL_K, 3600
    now = now or dt.datetime.now().astimezone()
    day_k, night_k = float(night.get("day", 6600)), float(night.get("night", 3900))
    fade = max(60.0, float(night.get("fade", 1800)))
    loc = night.get("location")
    times = None
    if loc:
        up = sun_times(now.date(), float(loc[0]), float(loc[1]), -0.833)
        civil = sun_times(now.date(), float(loc[0]), float(loc[1]), -6.0)
        if up and civil:
            times = (civil[0], up[0], up[1], civil[1])   # dawn, sunrise, sunset, dusk
        elif up is None:
            # polar: the sun is up all day, or never
            g = 2 * math.pi / 365 * (now.timetuple().tm_yday - 1)
            decl = 0.006918 - 0.399912 * math.cos(g) + 0.070257 * math.sin(g)
            polar_day = (float(loc[0]) > 0) == (decl > 0)
            return (day_k if polar_day else night_k), 600
    if not times:
        rise = hhmm(now.date(), night.get("sunrise", "07:00"), now.tzinfo)
        sset = hhmm(now.date(), night.get("sunset", "20:00"), now.tzinfo)
        times = (rise - dt.timedelta(seconds=fade), rise, sset, sset + dt.timedelta(seconds=fade))
    dawn, rise, sset, dusk = times

    def lerp(a, b, x):
        return a + (b - a) * max(0.0, min(1.0, x))

    if now < dawn or now >= dusk:
        k, nxt = night_k, ((dawn - now) if now < dawn else (dawn + dt.timedelta(days=1) - now)).total_seconds()
    elif now < rise:
        k, nxt = lerp(night_k, day_k, (now - dawn) / (rise - dawn)), 15
    elif now < sset:
        k, nxt = day_k, (sset - now).total_seconds()
    else:
        k, nxt = lerp(day_k, night_k, (now - sset) / (dusk - sset)), 15
    return k, max(5.0, min(600.0, nxt))


# ---------------------------------------------------------------- the loop
def connect():
    wl = Wayland()
    reg = wl.new_id()
    outputs, globals_ = {}, {}
    manager = [0]

    def registry(op, p):
        if op == 0:                 # global(name, interface, version)
            gname = struct.unpack_from("=I", p)[0]
            iface, off = read_string(p, 4)
            version = struct.unpack_from("=I", p, off)[0]
            if iface == "wl_output":
                oid = wl.new_id()
                v = min(version, 4)
                wl.send(reg, 0, struct.pack("=I", gname) + Wayland.string(iface) + struct.pack("=II", v, oid))
                outputs[gname] = Output(wl, gname, oid)
                outputs[gname].version = v
            elif iface == "zwlr_gamma_control_manager_v1":
                mid = wl.new_id()
                wl.send(reg, 0, struct.pack("=I", gname) + Wayland.string(iface) + struct.pack("=II", 1, mid))
                manager[0] = mid
            globals_[gname] = iface
        elif op == 1:               # global_remove
            gname = struct.unpack_from("=I", p)[0]
            o = outputs.pop(gname, None)
            if o:
                o.release(destroy=True)
                wl.handlers.pop(o.id, None)
                if getattr(o, "version", 1) >= 3:
                    wl.send(o.id, 0)        # wl_output.release

    wl.handlers[reg] = registry
    wl.send(1, 1, struct.pack("=I", reg))   # wl_display.get_registry
    wl.roundtrip()
    wl.roundtrip()                          # the outputs' names
    return wl, outputs, manager


def main():
    try:
        wl, outputs, manager = connect()
    except Exception as e:
        print(json.dumps({"error": "wayland: %s" % e}), flush=True)
        return 1
    if "--probe" in sys.argv:
        print(json.dumps({"gamma": bool(manager[0]), "outputs": sorted(o.name for o in outputs.values())}), flush=True)
        return 0
    if not manager[0]:
        print(json.dumps({"error": "the compositor has no gamma control (wlr-gamma-control)"}), flush=True)
        return 2

    want = {"outputs": {}, "night": None}
    last_report = None
    stdin_buf = b""
    next_night = 0.0
    kelvin = NEUTRAL_K
    while True:
        now = time.monotonic()
        if now >= next_night:
            kelvin, wait = night_kelvin(want.get("night"))
            next_night = now + wait
        white = kelvin_white(kelvin) if kelvin < NEUTRAL_K else (1.0, 1.0, 1.0)
        for o in list(outputs.values()):
            if not o.name:
                continue
            t = want["outputs"].get(o.name) or {}
            b = num(t, "brightness", 1.0, MIN_BRIGHTNESS, 1.0)
            c = {k: num(t, k, *CURVE[k]) for k in CURVE}
            rgb = (white[0] * c["red"], white[1] * c["green"], white[2] * c["blue"])
            if b >= 0.999 and rgb == (1.0, 1.0, 1.0) and c["gamma"] == 1.0 and c["contrast"] == 1.0:
                if o.control:
                    o.release(destroy=True)
                if o.state != "failed":
                    o.state = "neutral"
                continue
            o.ensure_control(manager[0])
            o.apply(b, rgb, c["gamma"], c["contrast"])
        report = {"outputs": {o.name: o.state for o in outputs.values() if o.name}, "kelvin": round(kelvin)}
        if report != last_report:
            print(json.dumps(report), flush=True)
            last_report = report
        timeout = max(0.5, next_night - time.monotonic())
        r, _, _ = select.select([wl.sock, sys.stdin.fileno()], [], [], timeout)
        if wl.sock in r:
            wl.dispatch()
        if sys.stdin.fileno() in r:
            chunk = os.read(sys.stdin.fileno(), 65536)
            if not chunk:
                return 0            # the shell went away: so do the tables
            stdin_buf += chunk
            *lines, stdin_buf = stdin_buf.split(b"\n")
            for line in lines:
                line = line.strip()
                if not line:
                    continue
                try:
                    msg = json.loads(line)
                except ValueError:
                    continue
                if msg.get("retry"):
                    # someone else let go of the tables (wlsunset quit): ask again
                    for o in outputs.values():
                        if o.state == "failed":
                            o.state = "neutral"
                want = {"outputs": msg.get("outputs") or {}, "night": msg.get("night")}
                next_night = 0.0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (KeyboardInterrupt, BrokenPipeError):
        pass
    except Exception as e:
        print(json.dumps({"error": str(e)}), flush=True)
        sys.exit(1)
