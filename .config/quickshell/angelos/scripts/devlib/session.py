"""A device being talked to: a channel (usbfs.Interface or an emulator) and the driver of its
protocol family on top of it.

A session reads the channel all the time it is open, on its own thread: the answers to its
own commands go to whoever asked, everything the device sends by itself (key travel, a mode
switch) goes to the driver. Reading never stops while the interface is held: a keyboard that
is reporting travel must not be left with a full endpoint.

Writing. A session opened with writes=True may change settings, each time the same way:
  * the firmware must be one the description allows writes for, and the description's layout
    must match the keyboard's own factory matrix — otherwise the session only reads;
  * before the first write ever to a device, every settings region is saved to a file
    (~/.local/state/angelos/devices/backup-ID-TIME.json): what «вернуть как было» puts back;
  * a write goes through nuphy_io.guard_write and is read back and compared;
  * no firmware command exists here.
"""
import json
import os
import queue
import threading
import time
from pathlib import Path

from . import nuphy_io as np


class DeviceError(Exception):
    """code: denied | busy | gone | timeout | deaf | protocol | readonly | refused | verify | range | full | nobackup"""

    def __init__(self, code, message=""):
        super().__init__(message or code)
        self.code = code


class NuphySession:
    family = "nuphy-io"
    TIMEOUT = 0.3
    RETRIES = 3

    def __init__(self, desc, channel, writes=False):
        self.desc = desc
        self.opts = desc.get("nuphy-io", {})
        self.channel = channel
        self.writes = writes
        self.step = float(self.opts.get("travelStep", np.TRAVEL_STEP))
        self.answers = queue.Queue()
        self.lock = threading.Lock()            # one command at a time
        self.depth_lock = threading.Lock()
        self.depth = {}                         # matrix number -> travel in mm, the newest
        self.dirty = set()
        self.events = queue.Queue()             # {"type": "state" | "reset" | "func" | "gone", …}
        self.by_action = {}                     # a key's factory action -> its matrix number
        self.stats = {"packets": 0, "reports": 0, "unknown": 0, "badSum": 0, "retries": 0, "ioErrors": 0}
        self.raw_tap = None                     # every incoming packet, for `sniff`
        self.deaf = False                       # the IN endpoint answers with bus errors only
        self._stop = threading.Event()
        self._thread = None
        self.state = None
        self.why_readonly = "" if writes else "off"     # "" | off | firmware | mismatch
        self.func_raw = []                      # each mode's settings block as read
        self.managed_upload = False             # this session turned "key status upload" on
        self.layer = 0                          # the layer of the current mode the page looks at (0 base, 1..3 Fn)
        self.backup_file = ""
        self.lit = {}                           # (mode, zone) -> the brightness a light had before it was turned off
        self._base_changed = []                 # the base layer's keys that are not the factory's

    # ---- the channel ----
    def open(self):
        self.channel.open()
        self._stop.clear()
        self._thread = threading.Thread(target=self._pump, name="device-reader", daemon=True)
        self._thread.start()
        return self

    def close(self):
        # travel reports this session turned on are turned off again: a keyboard left
        # reporting with nobody reading its channel is a keyboard whose channel dies
        uploading = any(len(b) > 7 and b[7] & 8 for b in self.func_raw)
        if (self.managed_upload or uploading) and self.writes and not self.why_readonly and self._thread and self._thread.is_alive() and not self.deaf:
            try:
                self.set_upload(False)
            except Exception:
                pass
        self._stop.set()
        if self._thread and self._thread is not threading.current_thread():
            self._thread.join(timeout=1.5)
        self._thread = None
        self.channel.close()

    def _pump(self):
        bad = 0
        while not self._stop.is_set():
            try:
                packet = self.channel.read(np.PACKET, 100)
            except Exception as e:
                # A garbled transfer is counted and read past: this is where the kernel's own
                # driver would reset the keyboard, and here nothing is ever reset. An endpoint
                # that gives nothing but errors is "deaf": the device takes commands and says
                # nothing back until it is plugged in again. It is asked less often then, and
                # request() says so instead of waiting for answers that cannot come.
                bad += 1
                self.stats["ioErrors"] += 1
                if getattr(e, "code", "gone") != "io":
                    self.events.put({"type": "gone", "code": getattr(e, "code", "gone"), "message": str(e)})
                    return
                if bad >= 20:
                    self.deaf = True
                self._stop.wait(0.25 if self.deaf else 0.005)
                continue
            if self.deaf:
                self.deaf = False
            bad = 0
            if not packet:
                continue
            self.stats["packets"] += 1
            tap = self.raw_tap
            if tap:
                tap(packet)
            if len(packet) != np.PACKET:
                self.stats["unknown"] += 1
                continue
            if packet[0] == np.FLAG_ANSWER:
                self.answers.put(packet)
                continue
            self.stats["reports"] += 1
            r = np.parse_report(packet)
            if not r:
                self.stats["unknown"] += 1
            elif r["type"] == "key":
                m = self.by_action.get(r["key"])
                if m is not None:
                    v = round(r["travel"] * self.step, 3)
                    with self.depth_lock:
                        if self.depth.get(m) != v:
                            self.depth[m] = v
                            self.dirty.add(m)
            else:
                self.events.put(r)

    def take_depth(self):
        """[m, mm, m, mm, …] of the keys that moved since the last call."""
        with self.depth_lock:
            if not self.dirty:
                return []
            out = []
            for m in sorted(self.dirty):
                out += [m, self.depth[m]]
            self.dirty.clear()
            return out

    def all_depth(self):
        """[m, mm, …] of every key seen so far: where the picture starts from."""
        with self.depth_lock:
            self.dirty.clear()
            out = []
            for m in sorted(self.depth):
                out += [m, self.depth[m]]
            return out

    # ---- commands ----
    def request(self, cmd, length=0, addr=0, data=b""):
        """Send one command and return its answer packet."""
        if cmd not in np.READS:
            if not self.writes or self.why_readonly:
                raise DeviceError("readonly", "%s: this session only reads (%s)" % (np.CMD_NAME.get(cmd, cmd), self.why_readonly or "off"))
            try:
                np.guard_write(cmd, addr, data)
            except np.ProtocolError as e:
                raise DeviceError("refused", str(e)) from None
        packet = np.build(cmd, length, addr, data)
        with self.lock:
            for attempt in range(self.RETRIES + 1):
                while True:                     # an answer nobody waited for any more
                    try:
                        self.answers.get_nowait()
                    except queue.Empty:
                        break
                try:
                    self.channel.write(packet)
                except Exception as e:
                    raise DeviceError(getattr(e, "code", "gone"), str(e)) from None
                deadline = time.monotonic() + self.TIMEOUT
                while True:
                    left = deadline - time.monotonic()
                    if left <= 0:
                        break
                    try:
                        answer = self.answers.get(timeout=left)
                    except queue.Empty:
                        break
                    if answer[1] != cmd:
                        continue
                    if np.checksum(answer) != answer[3]:
                        self.stats["badSum"] += 1
                    return answer
                if self._thread is None or not self._thread.is_alive():
                    raise DeviceError("gone", "the device stopped answering")
                refused = getattr(self.channel, "refused", "")
                if refused:
                    raise DeviceError("refused", "the USB bridge did not pass the packet on: %s" % refused)
                if self.deaf or (self.stats["ioErrors"] and not self.stats["packets"]):
                    raise DeviceError("deaf", "bus errors on the IN endpoint, %d so far" % self.stats["ioErrors"])
                self.stats["retries"] += 1
            raise DeviceError("timeout", "no answer to %s" % np.CMD_NAME.get(cmd, cmd))

    def read_region(self, cmd, addr, size):
        out = bytearray()
        for packet, off, n in np.read_plan(cmd, addr, size):
            answer = np.parse(self.request(cmd, n, addr + off))
            if len(answer["data"]) < n:
                raise DeviceError("protocol", "%s answered %d bytes of %d" % (np.CMD_NAME[cmd], len(answer["data"]), n))
            out += answer["data"][:n]
        return bytes(out)

    # ---- everything a page shows, read once ----
    def load(self, progress=None):
        """Read the keyboard: firmware, mode, each mode's settings, the factory key matrix, the
        current mode's travel settings. Only Get… commands."""
        def step(n, of):
            if progress:
                progress(n, of)
        total = 4 + np.MODES
        info = np.parse_info(self.request(np.CMD["GetInfo"]))
        step(1, total)
        version = info.get("versionNumber", 0)
        base = np.parse_base(self.read_region(np.CMD["GetBase"], 0, 16), np.base_offset(version, self.opts.get("baseOffset")))
        step(2, total)
        modes, self.func_raw = [], []
        for m in range(np.MODES):
            block = self.read_region(np.CMD["GetFunc"], m * np.FUNC_SIZE, np.FUNC_READ)
            self.func_raw.append(bytearray(block))
            modes.append(dict(np.parse_func(block), light=np.parse_light(block)))
            step(3 + m, total)
        layer = int(self.opts.get("defaultLayer", 4))
        factory, _ = np.parse_matrix(self.read_region(np.CMD["GetDefaultKeyMatrix"], layer * np.MATRIX_SIZE, np.MATRIX_SIZE))
        step(3 + np.MODES, total)
        # which slot of the matrix reports as which key: by the key's factory action
        by_action, mismatch = {}, []
        for k in self.desc["layout"]["keys"]:
            entry = factory[k["m"]] if k["m"] < len(factory) else (0, 0, 0)
            by_action.setdefault(tuple(entry), k["m"])
            if "default" in k and tuple(k["default"]) != tuple(entry):
                mismatch.append({"m": k["m"], "label": k.get("label", ""), "file": list(k["default"]), "device": list(entry)})
        mode = base["mode"] if 0 <= base["mode"] < np.MODES else 0
        # the reports name a key by its factory action in the mode the keyboard is in: the
        # modes' factory layers differ (Fn in Gaming, Super/Alt swapped in Mac), so that mode's
        # layer first, the description's layer for the keys it leaves out
        mode_layer = mode * np.LAYERS_PER_MODE
        if mode_layer != layer:
            try:
                own, _ = np.parse_matrix(self.read_region(np.CMD["GetDefaultKeyMatrix"], mode_layer * np.MATRIX_SIZE, np.MATRIX_SIZE))
                first = {}
                for k in self.desc["layout"]["keys"]:
                    if k["m"] < len(own) and tuple(own[k["m"]]) != (0, 0, 0):
                        first.setdefault(tuple(own[k["m"]]), k["m"])
                for a, m in by_action.items():
                    if m not in first.values():
                        first.setdefault(a, m)
                by_action = first
            except np.ProtocolError:
                pass
            except DeviceError as e:
                if e.code in ("gone", "deaf"):
                    raise
        self.by_action = by_action
        rt = self.read_keys_rt(mode)
        pairs, _ = self.read_pairs(mode)
        actions, factory_layer = self.read_layer(mode, self.layer)
        step(4 + np.MODES, total)
        names = self.opts.get("modes") or ["1", "2", "3"]
        if self.writes:
            allowed = (self.desc.get("firmware") or {}).get("writes") or {}
            known = bool(allowed) and int(allowed.get("min", 0)) <= version <= int(allowed.get("max", 0))
            self.why_readonly = "firmware" if not known else "mismatch" if mismatch else ""
        self.state = {
            "kind": "keyboard",
            "readonly": self.why_readonly,
            "pairs": pairs,
            "actions": actions,
            "labels": {m: np.action_name(e) for m, e in actions.items()},
            "changed": sorted(m for m, e in actions.items() if list(e) != factory_layer[m]),
            "layer": self.layer,
            "layers": np.LAYERS_PER_MODE,
            "backup": self.find_backup(),
            "firmware": info,
            "mode": mode,
            "modeName": names[mode] if mode < len(names) else str(mode),
            "modeNames": names,
            "layersPerMode": base["layersPerMode"],
            "modes": modes,
            "keys": rt,
            "mismatch": mismatch,
            "upload": bool(modes[mode]["keyStatusUpload"]),
            "special": self.read_special(mode, actions),
            "baseLabels": self.base_labels(mode, actions),
            "baseChanged": self._base_changed,
            "profiles": self.profiles(),
            "reportRates": {str(code): hz for code, hz in np.REPORT_RATE.items()},
            "catalog": np.catalog(mode),
        }
        return self.state

    def read_keys_rt(self, mode):
        """{matrix number: travel settings in mm} of the description's keys in one mode."""
        data = self.read_region(np.CMD["GetKeyRTInfo"], mode * np.RT_SIZE, np.RT_SIZE)
        out = {}
        for k in self.desc["layout"]["keys"]:
            m = k["m"]
            rt = np.parse_rt(data[m * np.RT_RECORD:(m + 1) * np.RT_RECORD])
            out[m] = {
                "switch": rt["switch"], "trigger": rt["trigger"], "priority": rt["priority"],
                "actuation": round((rt["actuation"] + 1) * self.step, 3),
                "press": np.mm_sensitivity(rt["press"], rt["pressStep"]),
                "release": np.mm_sensitivity(rt["release"], rt["releaseStep"]),
                "pressDead": np.mm_dead(rt["pressDead"]),
                "releaseDead": np.mm_dead(rt["releaseDead"]),
            }
        return out

    # ---- Snap Tap pairs and the keys' actions ----
    def read_pairs(self, mode):
        """([{"a", "b", "kind": "socd" | "rs", "slot"}], {m: (type, code0, code1)}) of the
        mode's base layer: a key of a pair holds (type, Mod-Tap slot, the other key's number)."""
        layer = mode * np.LAYERS_PER_MODE
        keys, _ = np.parse_matrix(self.read_region(np.CMD["GetUseKeyMatrix"], layer * np.MATRIX_SIZE, np.MATRIX_SIZE))
        mine = {k["m"] for k in self.desc["layout"]["keys"]}
        pairs, seen = [], set()
        for m in sorted(mine):
            kind, slot, other = keys[m]
            if kind not in (np.SOCD_TYPE, np.RS_TYPE) or m in seen:
                continue
            seen.update((m, other))
            pairs.append({"a": m, "b": other, "kind": "socd" if kind == np.SOCD_TYPE else "rs", "slot": slot,
                          "whole": other in mine and keys[other][0] == kind and keys[other][2] == m})
        return pairs, {m: list(keys[m]) for m in sorted(mine)}

    # ---- the keys' actions, a layer at a time ----
    def read_layer(self, mode, layer):
        """({m: [type, code0, code1]} as assigned, the same from the factory) of one layer."""
        base = (mode * np.LAYERS_PER_MODE + layer) * np.MATRIX_SIZE
        keys, _ = np.parse_matrix(self.read_region(np.CMD["GetUseKeyMatrix"], base, np.MATRIX_SIZE))
        factory, _ = np.parse_matrix(self.read_region(np.CMD["GetDefaultKeyMatrix"], base, np.MATRIX_SIZE))
        mine = sorted(k["m"] for k in self.desc["layout"]["keys"])
        return {m: list(keys[m]) for m in mine}, {m: list(factory[m]) for m in mine}

    def _show_layer(self):
        mode = self.state["mode"]
        actions, factory = self.read_layer(mode, self.layer)
        self.state.update(actions=actions, labels={m: np.action_name(e) for m, e in actions.items()},
                          changed=sorted(m for m, e in actions.items() if list(e) != factory[m]), layer=self.layer,
                          special=self.read_special(mode, actions), baseLabels=self.base_labels(mode, actions),
                          baseChanged=self._base_changed)

    def base_labels(self, mode, actions):
        """What each key does in the mode's base layer: in an Fn layer an empty key (16, 0, 0)
        lets the base layer's action through, and the page shows that one, dimmed."""
        at = mode * np.LAYERS_PER_MODE * np.MATRIX_SIZE
        base, _ = np.parse_matrix(self.read_region(np.CMD["GetUseKeyMatrix"], at, np.MATRIX_SIZE))
        factory, _ = np.parse_matrix(self.read_region(np.CMD["GetDefaultKeyMatrix"], at, np.MATRIX_SIZE))
        # (which of them are not the factory's: those the page names, the rest keep their legend)
        self._base_changed = sorted(m for m in actions if base[m] != factory[m])
        return {m: np.action_name(base[m]) for m in actions}

    # ---- Mod-Tap and Toggle: a key that points into a slot of its mode ----
    def read_special(self, mode, actions):
        """{m: what a Mod-Tap / Toggle / DKS / paired key of the layer shown does}, for the page."""
        mt = tgl = None
        out = {}
        for m, (kind, slot, extra) in actions.items():
            if kind == np.MT_TYPE and slot < np.MT_SLOTS:
                mt = mt if mt is not None else self.read_region(np.CMD["GetMtKeyInfo"], mode * np.MT_SIZE, np.MT_SIZE)
                rec = mt[slot * np.MT_RECORD:(slot + 1) * np.MT_RECORD]
                out[m] = {"kind": "modTap", "slot": slot, "tap": list(rec[:3]), "hold": list(rec[3:6]),
                          "tapName": np.action_name(rec[:3]), "holdName": np.action_name(rec[3:6]), "delay": extra * 10}
            elif kind == np.TGL_TYPE and slot < 32:
                tgl = tgl if tgl is not None else self.read_region(np.CMD["GetTglKeyInfo"], mode * np.TGL_SIZE, np.TGL_SIZE)
                rec = tgl[slot * np.TGL_RECORD:(slot + 1) * np.TGL_RECORD]
                out[m] = {"kind": "toggle", "slot": slot, "action": list(rec), "actionName": np.action_name(rec)}
            elif kind == np.DKS_TYPE:
                out[m] = {"kind": "dks", "slot": slot}
            elif kind in (np.SOCD_TYPE, np.RS_TYPE):
                out[m] = {"kind": "socd" if kind == np.SOCD_TYPE else "rs", "slot": slot, "partner": extra}
        return out

    def _slots_used(self, mode, types):
        """The slots that keys of the mode's four layers hold, of the given kinds of key."""
        used = set()
        for n in range(np.LAYERS_PER_MODE):
            lay = self.read_region(np.CMD["GetUseKeyMatrix"], (mode * np.LAYERS_PER_MODE + n) * np.MATRIX_SIZE, np.MATRIX_SIZE)
            for m in range(np.KEYS):
                if lay[3 * m] in types:
                    used.add(lay[3 * m + 1])
        return used

    @staticmethod
    def _plain_action(action, what):
        try:
            a = [int(b) for b in action]
        except (TypeError, ValueError):
            raise DeviceError("range", "%s: an action is three bytes" % what) from None
        if len(a) != 3 or not all(0 <= b <= 255 for b in a):
            raise DeviceError("range", "%s: an action is three bytes" % what)
        if a[0] in np.SLOT_TYPES + (np.DKS_TYPE, np.TGL_TYPE, 112) or tuple(a[:2]) == np.BOOT_KEY:
            raise DeviceError("refused", "%s: a plain action only (a key, a modifier, media, the mouse, Fn)" % what)
        return bytes(a)

    def _slot_key(self, m, kind, region, size, record, data, tail):
        """Give key m of the layer shown a slotted action: its slot (the one it holds already, or
        a free one of the mode) gets `data`, the key gets (kind, slot, tail)."""
        mode, layer = self.state["mode"], self.layer
        m = int(m)
        if m not in {k["m"] for k in self.desc["layout"]["keys"]}:
            raise DeviceError("range", "no such key")
        base = (mode * np.LAYERS_PER_MODE + layer) * np.MATRIX_SIZE
        old = tuple(self.read_region(np.CMD["GetUseKeyMatrix"], base + 3 * m, 3))
        if old[0] == kind:
            slot = old[1]
        else:
            self._free_slot(mode, layer, m, old)
            types = np.SLOT_TYPES if kind == np.MT_TYPE else (kind,)
            used = self._slots_used(mode, types)
            slot = next((i for i in range(32) if i not in used), None)
            if slot is None:
                raise DeviceError("full", "all 32 slots of this kind are taken in this mode")
        self.write_region(region, mode * size + slot * record, data)
        self.write_region("matrix", base + 3 * m, bytes((kind, slot, tail)))
        if layer == 0:
            self.state["pairs"] = self.read_pairs(mode)[0]
        self._show_layer()

    def set_modtap(self, m, tap, hold, delay=200):
        """Key m (layer shown): a tap sends `tap`, holding it longer than `delay` ms sends `hold`."""
        data = self._plain_action(tap, "tap") + self._plain_action(hold, "hold")
        lo, hi = np.MT_DELAY
        d = max(lo, min(hi, int(round(float(delay))))) // 10
        self._slot_key(m, np.MT_TYPE, "modTap", np.MT_SIZE, np.MT_RECORD, data, d)

    def set_toggle(self, m, action):
        """Key m (layer shown): a tap holds `action` down until the next tap; held, it is plain."""
        self._slot_key(m, np.TGL_TYPE, "toggle", np.TGL_SIZE, np.TGL_RECORD, self._plain_action(action, "toggle"), 0)

    # ---- profiles: every setting into a file of one's own, and back ----
    def profile_dir(self):
        return self.state_dir() / "profiles" / self.desc["id"]

    def profiles(self):
        try:
            files = sorted(self.profile_dir().glob("*.json"), key=lambda f: f.stat().st_mtime, reverse=True)
        except OSError:
            return []
        return [{"name": f.stem, "file": str(f), "taken": time.strftime("%Y-%m-%d %H:%M", time.localtime(f.stat().st_mtime))} for f in files]

    def save_profile(self, name, progress=None):
        name = "".join(c for c in str(name).strip() if c.isalnum() or c in " -_.")[:48].strip() or time.strftime("%Y-%m-%d %H-%M")
        info = self.state["firmware"]
        out = {"format": "angelos-device-backup", "version": 1, "device": self.desc["id"], "family": self.family,
               "firmware": info, "taken": time.strftime("%Y-%m-%dT%H:%M:%S"), "name": name, "regions": self.snapshot(progress)}
        d = self.profile_dir()
        d.mkdir(parents=True, exist_ok=True)
        f = d / (name + ".json")
        f.with_suffix(".tmp").write_text(json.dumps(out, indent=1))
        os.replace(f.with_suffix(".tmp"), f)
        self.state["profiles"] = self.profiles()
        return str(f)

    def delete_profile(self, path):
        p = Path(path)
        if p.parent != self.profile_dir() or p.suffix != ".json":
            raise DeviceError("refused", "not a profile of this device")
        try:
            p.unlink()
        except OSError as e:
            raise DeviceError("io", str(e)) from None
        self.state["profiles"] = self.profiles()

    def set_layer(self, layer):
        """Which layer of the current mode the page shows and assigns keys in (a read)."""
        layer = int(layer)
        if not 0 <= layer < np.LAYERS_PER_MODE:
            raise DeviceError("range", "layers are 0…%d" % (np.LAYERS_PER_MODE - 1))
        self.layer = layer
        self._show_layer()

    def _free_slot(self, mode, layer, m, entry):
        """A key that owns a slot (a Snap Tap pair, Mod-Tap, DKS, Toggle) lets it go before it
        becomes something else: the slot is emptied, as the configurator does."""
        kind, slot = entry[0], entry[1]
        if kind in (np.SOCD_TYPE, np.RS_TYPE) and layer == 0:
            self.clear_pair(m)
            return
        if kind in np.SLOT_TYPES and slot < np.MT_SLOTS:
            self.write_region("modTap", mode * np.MT_SIZE + slot * np.MT_RECORD, bytes(np.MT_RECORD))
        elif kind == 145 and slot < 32:
            self.write_region("toggle", mode * np.TGL_SIZE + slot * np.TGL_RECORD, bytes(np.TGL_RECORD))
        elif kind == 144 and slot < 32:
            self.write_region("dks", mode * np.DKS_SIZE + slot * np.DKS_RECORD, bytes(np.DKS_RECORD))

    def set_keys(self, keys, action):
        """Give the keys (matrix numbers) an action in the layer shown: [type, code0, code1],
        "factory" (what the keyboard shipped with) or "off"."""
        mode = self.state["mode"]
        layer = self.layer
        base = (mode * np.LAYERS_PER_MODE + layer) * np.MATRIX_SIZE
        mine = {k["m"] for k in self.desc["layout"]["keys"]}
        keys = sorted(set(int(k) for k in keys) & mine)
        if not keys:
            raise DeviceError("range", "no such keys")
        if action not in ("factory", "off"):
            try:
                action = [int(b) for b in action]
            except (TypeError, ValueError):
                raise DeviceError("range", "an action is three bytes") from None
            if len(action) != 3 or not all(0 <= b <= 255 for b in action):
                raise DeviceError("range", "an action is three bytes")
            if action[0] in np.SLOT_TYPES + (144, 145, 112):
                raise DeviceError("refused", "pairs, Mod-Tap, DKS, Toggle and macros are made in their own places")
        matrix = self.read_region(np.CMD["GetUseKeyMatrix"], base, np.MATRIX_SIZE)
        factory = self.read_region(np.CMD["GetDefaultKeyMatrix"], base, np.MATRIX_SIZE)
        changed = []
        for m in keys:
            old = tuple(matrix[3 * m:3 * m + 3])
            new = bytes(factory[3 * m:3 * m + 3]) if action == "factory" else bytes(3) if action == "off" else bytes(action)
            if bytes(old) == new:
                continue
            self._free_slot(mode, layer, m, old)
            self.write_region("matrix", base + 3 * m, new)
            changed.append(m)
        if changed:
            pairs, _ = self.read_pairs(mode)
            self.state["pairs"] = pairs
            self._show_layer()
        return changed

    # ---- the lights ----
    def set_light(self, mode, zone, values):
        """A mode's key light ("main") or side light ("side"): effect, brightness 0…100,
        speed 0…4, direction, rainbow, color "#rrggbb", on (off keeps the brightness to come
        back to: the keyboard itself knows only "brightness 0")."""
        if not 0 <= mode < len(self.func_raw) or zone not in np.LIGHT_ZONES:
            raise DeviceError("range", "no such mode or light")
        values = dict(values)
        block = self.func_raw[mode]
        key = (mode, zone)
        if "on" in values:
            on = bool(values.pop("on"))
            now = block[np.LIGHT_ZONES[zone][0] + 1]
            if not on and now > 0:
                self.lit[key] = now
                values["brightness"] = 0
            elif on and now == 0:
                values["brightness"] = self.lit.get(key, 60)
        effects = ((self.desc.get("capabilities") or {}).get("lighting") or {})
        allowed = [e["id"] for e in effects.get(zone, [])] if isinstance(effects, dict) else []
        if "effect" in values and allowed and int(values["effect"]) not in allowed:
            raise DeviceError("range", "no such effect for this light")
        try:
            off, rec = np.light_bytes(block, zone, values)
        except (np.ProtocolError, TypeError, ValueError) as e:
            raise DeviceError("range", str(e)) from None
        if bytes(block[off:off + len(rec)]) == rec:
            return False
        self.write_region("func", mode * np.FUNC_SIZE + off, rec)
        block[off:off + len(rec)] = rec
        self.state["modes"][mode] = dict(np.parse_func(bytes(block)), light=np.parse_light(bytes(block)))
        return True

    # ---- writing ----
    PAIRS = {"func": ("GetFunc", "SetFunc"), "matrix": ("GetUseKeyMatrix", "SetUseKeyMatrix"),
             "rt": ("GetKeyRTInfo", "SetKeyRTInfo"), "modTap": ("GetMtKeyInfo", "SetMtKeyInfo"),
             "toggle": ("GetTglKeyInfo", "SetTglKeyInfo"), "dks": ("GetDKSInfo", "SetDKSInfo"),
             "macro": ("GetMacro", "SetMacro"), "led": ("GetLedDefine", "SetLedDefine"),
             "appDefine": ("GetAppDefine", "SetAppDefine")}

    def state_dir(self):
        return Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "angelos/devices"

    def find_backup(self):
        """The first snapshot ever taken of this device ("" when there is none)."""
        try:
            files = sorted(self.state_dir().glob("backup-%s-*.json" % self.desc["id"]))
        except OSError:
            files = []
        self.backup_file = str(files[0]) if files else ""
        return self.backup_file

    def take_backup(self, progress=None):
        info = (self.state or {}).get("firmware") or np.parse_info(self.request(np.CMD["GetInfo"]))
        out = {"format": "angelos-device-backup", "version": 1, "device": self.desc["id"], "family": self.family,
               "firmware": info, "taken": time.strftime("%Y-%m-%dT%H:%M:%S"), "regions": self.snapshot(progress)}
        d = self.state_dir()
        d.mkdir(parents=True, exist_ok=True)
        f = d / ("backup-%s-%s.json" % (self.desc["id"], time.strftime("%Y%m%d-%H%M%S")))
        tmp = f.with_suffix(".tmp")
        tmp.write_text(json.dumps(out, indent=1))
        os.replace(tmp, f)
        return str(f)

    def ensure_backup(self, progress=None):
        """Before the first write ever: everything as it is now, into a file. No file, no write."""
        if self.backup_file or self.find_backup():
            return self.backup_file
        try:
            self.backup_file = self.take_backup(progress)
        except OSError as e:
            raise DeviceError("nobackup", "the backup could not be saved: %s" % e) from None
        if self.state is not None:
            self.state["backup"] = self.backup_file
        return self.backup_file

    def write_region(self, name, addr, data):
        """Write bytes of a settings region and read them back; DeviceError("verify") when the
        keyboard holds something else afterwards."""
        get, put = self.PAIRS[name]
        if not self.writes or self.why_readonly:
            raise DeviceError("readonly", "this session only reads (%s)" % (self.why_readonly or "off"))
        self.ensure_backup()
        data = bytes(data)
        off = 0
        while off < len(data):
            chunk = data[off:off + np.CHUNK]
            self.request(np.CMD[put], len(chunk), addr + off, chunk)
            off += len(chunk)
        back = self.read_region(np.CMD[get], addr, len(data))
        if back != data:
            raise DeviceError("verify", "%s at %d: wrote %s, the keyboard holds %s" % (name, addr, data.hex(), back.hex()))

    def set_func(self, mode, values):
        """Mode settings by parse_func's names; what is not named stays."""
        if not 0 <= mode < np.MODES or mode >= len(self.func_raw):
            raise DeviceError("range", "no such mode")
        block = self.func_raw[mode]
        new = np.func_bytes(block, values)
        if bytes(block[4:8]) == new:
            return False
        self.write_region("func", mode * np.FUNC_SIZE + 4, new)
        block[4:8] = new
        if self.state:
            self.state["modes"][mode] = dict(np.parse_func(bytes(block)), light=np.parse_light(bytes(block)))
            self.state["upload"] = bool(self.state["modes"][self.state["mode"]]["keyStatusUpload"])
        return True

    def set_upload(self, on):
        """Travel reports on or off, in every mode (a mode switched on the keyboard keeps it)."""
        changed = False
        for mode in range(len(self.func_raw)):
            changed = self.set_func(mode, {"keyStatusUpload": bool(on)}) or changed
        self.managed_upload = bool(on)
        if not on:
            with self.depth_lock:
                for m in self.depth:
                    if self.depth[m]:
                        self.depth[m] = 0.0
                        self.dirty.add(m)
        return changed

    def limits(self):
        caps = self.desc.get("capabilities") or {}
        travel = max((sw["travel"] for sw in self.desc.get("switches", [])), default=3.3)
        a = caps.get("actuation") if isinstance(caps.get("actuation"), dict) else {}
        r = caps.get("rapidTrigger") if isinstance(caps.get("rapidTrigger"), dict) else {}
        d = caps.get("deadZones") if isinstance(caps.get("deadZones"), dict) else {}
        return {"travel": travel, "aMin": a.get("min", 0.1), "aMax": min(a.get("max", travel), travel),
                "rMin": r.get("min", 0.01), "rMax": min(r.get("max", travel), travel), "dMax": d.get("max", 1.28)}

    def set_rt(self, keys, values):
        """Travel settings of the keys (matrix numbers) in the current mode: any of actuation,
        press, release, pressDead, releaseDead (mm), trigger (normal | rapid | continuous).
        Values are brought into the device's limits; what is not named stays as the key has it."""
        mode = self.state["mode"]
        lim = self.limits()
        mine = {k["m"] for k in self.desc["layout"]["keys"]}
        keys = sorted(set(int(k) for k in keys) & mine)
        if not keys:
            raise DeviceError("range", "no such keys")
        if "trigger" in values and values["trigger"] not in np.TRIGGER_ID:
            raise DeviceError("range", "trigger is one of: " + ", ".join(np.TRIGGER_ID))
        data = bytearray(self.read_region(np.CMD["GetKeyRTInfo"], mode * np.RT_SIZE, np.RT_SIZE))
        changed = []
        for m in keys:
            rec = bytes(data[m * np.RT_RECORD:(m + 1) * np.RT_RECORD])
            rt = np.parse_rt(rec)
            if "trigger" in values:
                rt["trigger"] = values["trigger"]
            if "actuation" in values:
                rt["actuation"] = np.units_actuation(max(lim["aMin"], min(lim["aMax"], float(values["actuation"]))), self.step)
            for name, step_name in (("press", "pressStep"), ("release", "releaseStep")):
                if name in values:
                    rt[name] = np.units_sensitivity(max(lim["rMin"], min(lim["rMax"], float(values[name]))), rt[step_name])
            for name in ("pressDead", "releaseDead"):
                if name in values:
                    rt[name] = np.units_dead(max(0.0, min(lim["dMax"], float(values[name]))))
            new = np.build_rt(rt)
            if new != rec:
                data[m * np.RT_RECORD:(m + 1) * np.RT_RECORD] = new
                changed.append(m)
        # neighbours in one write, as the configurator does: a run of keys is one region
        i = 0
        while i < len(changed):
            j = i
            while j + 1 < len(changed) and changed[j + 1] == changed[j] + 1 and (changed[j + 1] - changed[i] + 1) * np.RT_RECORD <= np.CHUNK:
                j += 1
            first, last = changed[i], changed[j]
            self.write_region("rt", mode * np.RT_SIZE + first * np.RT_RECORD, data[first * np.RT_RECORD:(last + 1) * np.RT_RECORD])
            i = j + 1
        if changed:
            fresh = self.read_keys_rt(mode)
            self.state["keys"] = fresh
        return changed

    def _priority(self, mode, m, priority):
        """A key's place in its Snap Tap pair: the high half of the second byte of its travel record."""
        addr = mode * np.RT_SIZE + m * np.RT_RECORD + 1
        old = self.read_region(np.CMD["GetKeyRTInfo"], addr, 1)[0]
        new = old & 0x0F | {v: k for k, v in np.PRIORITY.items()}[priority]
        if new != old:
            self.write_region("rt", addr, bytes((new,)))

    def set_pair(self, a, b, rule="last", kind="socd"):
        """Make keys a and b a Snap Tap pair in the current mode's base layer.
        rule: last (the last one pressed wins) | neutral (both down: neither) | a | b (that key wins).
        kind: socd | rs (Rappy Snappy: the deeper one wins)."""
        mode = self.state["mode"]
        layer = mode * np.LAYERS_PER_MODE
        mine = {k["m"] for k in self.desc["layout"]["keys"]}
        a, b = int(a), int(b)
        if a == b or a not in mine or b not in mine:
            raise DeviceError("range", "a pair is two different keys of this keyboard")
        if rule not in ("last", "neutral", "a", "b") or kind not in ("socd", "rs"):
            raise DeviceError("range", "rule: last | neutral | a | b; kind: socd | rs")
        kind_byte = np.SOCD_TYPE if kind == "socd" else np.RS_TYPE
        base = layer * np.MATRIX_SIZE
        matrix = bytearray(self.read_region(np.CMD["GetUseKeyMatrix"], base, np.MATRIX_SIZE))
        entry = lambda m: tuple(matrix[3 * m:3 * m + 3])
        # a key already in a pair with somebody else first leaves it
        for m in (a, b):
            e = entry(m)
            if e[0] in np.SLOT_TYPES and not (e[0] in (np.SOCD_TYPE, np.RS_TYPE) and e[2] in (a, b)):
                self.clear_pair(m)
                matrix = bytearray(self.read_region(np.CMD["GetUseKeyMatrix"], base, np.MATRIX_SIZE))
        factory = self.read_region(np.CMD["GetDefaultKeyMatrix"], base, np.MATRIX_SIZE)
        # the slots of the Mod-Tap area taken by any key of the mode's four layers
        used = set()
        for n in range(np.LAYERS_PER_MODE):
            lay = matrix if n == 0 else self.read_region(np.CMD["GetUseKeyMatrix"], (layer + n) * np.MATRIX_SIZE, np.MATRIX_SIZE)
            for m in range(np.KEYS):
                if lay[3 * m] in np.SLOT_TYPES:
                    used.add(lay[3 * m + 1])
        slots = {}
        for m in (a, b):
            e = entry(m)
            if e[0] in (np.SOCD_TYPE, np.RS_TYPE):
                slots[m] = e[1]
            else:
                free = next((i for i in range(np.MT_SLOTS) if i not in used), None)
                if free is None:
                    raise DeviceError("full", "all %d slots for paired and Mod-Tap keys are taken in this mode" % np.MT_SLOTS)
                used.add(free)
                slots[m] = free
        own = {m: bytes(factory[3 * m:3 * m + 3]) if entry(m)[0] in np.SLOT_TYPES else bytes(entry(m)) for m in (a, b)}
        for m, other in ((a, b), (b, a)):
            # the slot: this key's own action, then its partner's; then the key itself
            self.write_region("modTap", mode * np.MT_SIZE + slots[m] * np.MT_RECORD, own[m] + own[other])
            self.write_region("matrix", base + 3 * m, bytes((kind_byte, slots[m], other)))
        pr = {"last": ("last", "last"), "neutral": ("neutral", "neutral"), "a": ("own", "bond"), "b": ("bond", "own")}[rule]
        self._priority(mode, a, pr[0])
        self._priority(mode, b, pr[1])
        self._after_pairs(mode)

    def clear_pair(self, m):
        """Take the key (and its partner) out of their pair: both back to what they were."""
        mode = self.state["mode"]
        layer = mode * np.LAYERS_PER_MODE
        base = layer * np.MATRIX_SIZE
        matrix = self.read_region(np.CMD["GetUseKeyMatrix"], base, np.MATRIX_SIZE)
        factory = self.read_region(np.CMD["GetDefaultKeyMatrix"], base, np.MATRIX_SIZE)
        mt = self.read_region(np.CMD["GetMtKeyInfo"], mode * np.MT_SIZE, np.MT_SIZE)
        m = int(m)
        kind, slot, other = matrix[3 * m:3 * m + 3]
        if kind not in (np.SOCD_TYPE, np.RS_TYPE):
            return False
        todo = [m]
        if other < np.KEYS and matrix[3 * other] == kind and matrix[3 * other + 2] == m:
            todo.append(other)
        for k in todo:
            s = matrix[3 * k + 1]
            # what the key was before the pair is the first action of its slot
            was = bytes(mt[s * np.MT_RECORD:s * np.MT_RECORD + 3]) if s < np.MT_SLOTS else b""
            if not was or not any(was) or was[0] in np.SLOT_TYPES:
                was = bytes(factory[3 * k:3 * k + 3])
            self.write_region("matrix", base + 3 * k, was)
            if s < np.MT_SLOTS:
                self.write_region("modTap", mode * np.MT_SIZE + s * np.MT_RECORD, bytes(np.MT_RECORD))
            self._priority(mode, k, "last")
        self._after_pairs(mode)
        return True

    def _after_pairs(self, mode):
        pairs, _ = self.read_pairs(mode)
        self.state["pairs"] = pairs
        self.state["keys"] = self.read_keys_rt(mode)
        self._show_layer()

    def restore(self, path=None, progress=None):
        """Put the settings of a backup file back: only the bytes that differ are written.
        Of the mode settings only bytes 4..7 (the rest is the keyboard's own), and travel
        reports stay as this session has them."""
        path = path or self.backup_file or self.find_backup()
        if not path:
            raise DeviceError("nobackup", "there is no backup of this device")
        try:
            saved = json.loads(Path(path).read_text())
            regions = saved["regions"]
            if saved.get("format") != "angelos-device-backup" or saved.get("device") != self.desc["id"]:
                raise ValueError("not a backup of this device")
        except (OSError, ValueError, KeyError) as e:
            raise DeviceError("nobackup", "the backup cannot be read: %s" % e) from None
        names = [n for n in ("matrix", "rt", "modTap", "toggle", "dks", "macro", "led", "appDefine") if regions.get(n)]
        written = 0
        for n, name in enumerate(names):
            want = bytes.fromhex(regions[name])
            have = self.read_region(np.CMD[self.PAIRS[name][0]], 0, len(want))
            # keys go back whole (three bytes each, 18 a write), and only the keys' own part of a layer
            size = 54 if name == "matrix" else np.CHUNK
            spans = [(L * np.MATRIX_SIZE, L * np.MATRIX_SIZE + np.KEYS * 3) for L in range(len(want) // np.MATRIX_SIZE)] if name == "matrix" else [(0, len(want))]
            for start, stop in spans:
                off = start
                while off < stop:
                    end = min(stop, off + size)
                    if want[off:end] != have[off:end]:
                        self.write_region(name, off, want[off:end])
                        written += end - off
                    off = end
            if progress:
                progress(n + 1, len(names) + 1)
        if regions.get("func"):
            func = bytes.fromhex(regions["func"])
            for mode in range(min(np.MODES, len(func) // np.FUNC_SIZE, len(self.func_raw))):
                saved_block = func[mode * np.FUNC_SIZE:(mode + 1) * np.FUNC_SIZE]
                values = np.parse_func(saved_block)
                values["keyStatusUpload"] = bool(self.func_raw[mode][7] & 8)
                if self.set_func(mode, values):
                    written += 4
                for zone, (off, n) in np.LIGHT_ZONES.items():
                    if bytes(self.func_raw[mode][off:off + n]) != saved_block[off:off + n]:
                        self.write_region("func", mode * np.FUNC_SIZE + off, saved_block[off:off + n])
                        self.func_raw[mode][off:off + n] = saved_block[off:off + n]
                        written += n
        if progress:
            progress(len(names) + 1, len(names) + 1)
        self.load()
        return written

    def snapshot(self, progress=None):
        """Every settings region, raw, for a backup file: {region name: hex}. Only reads."""
        regions = [("base", "GetBase", 0, 16), ("func", "GetFunc", 0, np.MODES * np.FUNC_SIZE),
                   ("defaultMatrix", "GetDefaultKeyMatrix", 0, np.LAYERS * np.MATRIX_SIZE),
                   ("matrix", "GetUseKeyMatrix", 0, np.LAYERS * np.MATRIX_SIZE),
                   ("rt", "GetKeyRTInfo", 0, np.MODES * np.RT_SIZE), ("dks", "GetDKSInfo", 0, 3072),
                   ("modTap", "GetMtKeyInfo", 0, 768), ("toggle", "GetTglKeyInfo", 0, 384),
                   ("macro", "GetMacro", 0, 6144), ("led", "GetLedDefine", 0, 1536),
                   ("appDefine", "GetAppDefine", 0, 1536)]
        out = {}
        for n, (name, cmd, addr, size) in enumerate(regions):
            try:
                out[name] = self.read_region(np.CMD[cmd], addr, size).hex()
            except DeviceError as e:
                if e.code in ("gone", "denied"):
                    raise
                out[name] = None                # a region this firmware does not have
            if progress:
                progress(n + 1, len(regions))
        return out


SESSIONS = {"nuphy-io": NuphySession}
