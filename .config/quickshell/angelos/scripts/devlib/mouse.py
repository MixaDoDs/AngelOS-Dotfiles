"""A mouse of the "lamzu-aurora" family being talked to: read its settings, change one, read
it back (devlib/lamzu_aurora.py is the protocol; devlib/hidraw.py the channel).

Like a keyboard's session (devlib/session.py), with what a mouse needs instead of keys: no
stream, a question and its answer at a time. A mouse behind its dongle sleeps within a minute
of lying still and the dongle alone answers then: DeviceError("asleep"), which is no fault —
the page says "move the mouse" and asks again.

Writing follows the same rules as for a keyboard: only the settings of lamzu_aurora.ALLOWED
(there is no firmware command to build), a file with everything as it was before the first
write ever, every write read back.
"""
import json
import os
import queue
import time
from pathlib import Path

from . import lamzu_aurora as au
from .session import DeviceError


class AuroraSession:
    family = "lamzu-aurora"
    DELAY = 0.015
    READ = ("pollingRate", "dpiActive", "dpiStages", "lod", "debounce", "motionSync", "angleSnap", "ripple", "sleep")

    def __init__(self, desc, channel, writes=False):
        self.desc = desc
        self.channel = channel
        self.writes = writes
        self.why_readonly = "" if writes else "off"
        self.events = queue.Queue()
        self.state = None
        self.backup_file = ""
        self.profile = 0
        self.stats = {"packets": 0, "retries": 0}

    # ---- the same face as a keyboard's session ----
    def open(self):
        self.channel.open()
        return self

    def close(self):
        self.channel.close()

    def take_depth(self):
        return []

    def all_depth(self):
        return []

    # ---- a question and its answer ----
    def _exchange(self, request, name, tries=5):
        answer = b""
        for attempt in range(tries):
            try:
                self.channel.set(request)
                time.sleep(self.DELAY)
                for _ in range(30):
                    answer = self.channel.get()
                    self.stats["packets"] += 1
                    if len(answer) > 6 and answer[1] == au.DONE and au.done(answer, name):
                        return answer
                    if len(answer) > 1 and answer[1] > au.DONE:
                        break
                    time.sleep(self.DELAY)
            except Exception as e:
                raise DeviceError(getattr(e, "code", "gone"), str(e)) from None
            self.stats["retries"] += 1
        if len(answer) > 1 and answer[1] == 0xA0:
            raise DeviceError("asleep", "the mouse does not answer its dongle")
        raise DeviceError("timeout", "no answer to " + name)

    def get(self, name):
        return au.parse(name, self._exchange(au.build_get(name, self.profile), name))

    def put(self, name, value_bytes, expect):
        """Write a setting and read it back."""
        if not self.writes or self.why_readonly:
            raise DeviceError("readonly", "this session only reads (%s)" % (self.why_readonly or "off"))
        self.ensure_backup()
        try:
            request = au.build_set(name, self.profile, value_bytes)
        except au.ProtocolError as e:
            raise DeviceError("refused", str(e)) from None
        self._exchange(request, name)
        back = self.get(name)
        if back != expect:
            raise DeviceError("verify", "%s: wrote %r, the mouse holds %r" % (name, expect, back))
        return back

    # ---- everything a page shows ----
    def load(self, progress=None):
        names = ("profile", "firmware", "battery") + self.READ
        out = {}
        self.profile = 0
        for n, name in enumerate(names):
            out[name] = self.get(name)
            if name == "profile":
                self.profile = out[name]
            if progress:
                progress(n + 1, len(names))
        self.state = {
            "kind": "mouse", "firmware": {"version": out["firmware"]}, "profile": out["profile"], "battery": out["battery"],
            "pollingRate": out["pollingRate"], "dpiActive": out["dpiActive"], "dpiStages": out["dpiStages"],
            "lod": out["lod"], "debounce": out["debounce"], "motionSync": out["motionSync"],
            "angleSnap": out["angleSnap"], "ripple": out["ripple"], "sleep": out["sleep"],
            "readonly": self.why_readonly, "backup": self.find_backup(),
            # a keyboard's fields, empty: one shape for the shell
            "keys": {}, "actions": {}, "pairs": [], "modes": [], "mismatch": [], "upload": False,
            "mode": 0, "modeName": "", "modeNames": [], "layersPerMode": 0,
        }
        return self.state

    def set_setting(self, name, value):
        """One setting by its name, the value as a person gives it."""
        caps = self.desc.get("capabilities") or {}
        st = self.state

        def limit(cap, field, default):
            c = caps.get(cap)
            return c.get(field, default) if isinstance(c, dict) else default
        if name == "pollingRate":
            hz = int(value)
            if hz not in limit("pollingRate", "values", []) or hz not in au.RATE_CODE:
                raise DeviceError("range", "polling rate: one of %s" % limit("pollingRate", "values", []))
            st[name] = self.put(name, bytes((au.RATE_CODE[hz],)), hz)
        elif name == "lod":
            mm = float(value)
            if mm not in [float(v) for v in limit("lod", "values", [])]:
                raise DeviceError("range", "lift-off distance: one of %s" % limit("lod", "values", []))
            st[name] = self.put(name, bytes((au.lod_code(mm),)), mm)
        elif name == "debounce":
            ms = max(int(limit("debounce", "min", 0)), min(int(limit("debounce", "max", 15)), int(value)))
            st[name] = self.put(name, bytes((ms,)), ms)
        elif name in ("motionSync", "angleSnap", "ripple"):
            st[name] = self.put(name, bytes((1 if value else 0,)), bool(value))
        elif name == "sleep":
            sec = int(value)
            if sec not in limit("sleep", "values", []):
                raise DeviceError("range", "sleep: one of %s seconds" % limit("sleep", "values", []))
            st[name] = self.put(name, bytes((sec >> 8, sec & 0xFF)), sec)
        elif name == "dpiActive":
            n = int(value)
            if not 1 <= n <= len(st["dpiStages"]):
                raise DeviceError("range", "no such DPI stage")
            st[name] = self.put(name, bytes((n,)), n)
        elif name == "dpiStages":
            stages = self._stages(value)
            data = bytearray((len(stages),))
            for s in stages:
                data += bytes((s["x"] >> 8, s["x"] & 0xFF, s["y"] >> 8, s["y"] & 0xFF))
            st[name] = self.put(name, data, stages)
            if st["dpiActive"] > len(stages):
                st["dpiActive"] = self.get("dpiActive")
        else:
            raise DeviceError("range", "unknown setting " + str(name))
        return st[name]

    def _stages(self, value):
        caps = (self.desc.get("capabilities") or {}).get("dpi") or {}
        lo, hi, step, most = int(caps.get("min", 50)), int(caps.get("max", 26000)), int(caps.get("step", 50)), int(caps.get("stages", 5))
        if not isinstance(value, list) or not 1 <= len(value) <= most:
            raise DeviceError("range", "1…%d DPI stages" % most)
        out = []
        for s in value:
            x = s.get("x") if isinstance(s, dict) else s
            y = s.get("y", x) if isinstance(s, dict) else s
            fit = lambda v: max(lo, min(hi, int(round(int(v) / step)) * step))
            out.append({"x": fit(x), "y": fit(y)})
        return out

    # ---- as it was ----
    def state_dir(self):
        return Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "angelos/devices"

    def find_backup(self):
        try:
            files = sorted(self.state_dir().glob("backup-%s-*.json" % self.desc["id"]))
        except OSError:
            files = []
        self.backup_file = str(files[0]) if files else ""
        return self.backup_file

    SAVED = ("pollingRate", "dpiStages", "dpiActive", "lod", "debounce", "motionSync", "angleSnap", "ripple", "sleep")

    def ensure_backup(self, progress=None):
        if self.backup_file or self.find_backup():
            return self.backup_file
        st = self.state or self.load()
        out = {"format": "angelos-device-backup", "version": 1, "device": self.desc["id"], "family": self.family,
               "firmware": st["firmware"], "profile": st["profile"], "taken": time.strftime("%Y-%m-%dT%H:%M:%S"),
               "settings": {k: st[k] for k in self.SAVED}}
        try:
            d = self.state_dir()
            d.mkdir(parents=True, exist_ok=True)
            f = d / ("backup-%s-%s.json" % (self.desc["id"], time.strftime("%Y%m%d-%H%M%S")))
            tmp = f.with_suffix(".tmp")
            tmp.write_text(json.dumps(out, indent=1))
            os.replace(tmp, f)
        except OSError as e:
            raise DeviceError("nobackup", "the backup could not be saved: %s" % e) from None
        self.backup_file = str(f)
        if self.state is not None:
            self.state["backup"] = self.backup_file
        return self.backup_file

    def restore(self, path=None, progress=None):
        path = path or self.backup_file or self.find_backup()
        if not path:
            raise DeviceError("nobackup", "there is no backup of this device")
        try:
            saved = json.loads(Path(path).read_text())
            settings = saved["settings"]
            if saved.get("format") != "angelos-device-backup" or saved.get("device") != self.desc["id"]:
                raise ValueError("not a backup of this device")
        except (OSError, ValueError, KeyError) as e:
            raise DeviceError("nobackup", "the backup cannot be read: %s" % e) from None
        written = 0
        for n, name in enumerate(self.SAVED):
            if name in settings and self.state.get(name) != settings[name]:
                self.set_setting(name, settings[name])
                written += 1
            if progress:
                progress(n + 1, len(self.SAVED))
        return written
