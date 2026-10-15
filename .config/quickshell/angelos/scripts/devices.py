#!/usr/bin/env python3
"""The devices' driver of angelOS: Hall-effect keyboards and mice set up from the shell
(services/Devices; Settings → Devices → Device driver; docs/devices.md).

  devices.py list [--json]            the devices connected that a description knows, and the
                                      description files that are broken
  devices.py info [ID] [--json]       open one, read its settings (only reads), print them
  devices.py dump [ID] [-o FILE]      every settings region, raw, into a JSON file
  devices.py sniff [ID] [--seconds N] the packets the device sends by itself, hex and decoded
            [--usb VID:PID --interface N --in 0x82 --out 0x02]   …of a device no file describes yet
  devices.py check FILE…              is this description file good; every problem by line
  devices.py serve                    JSON lines for the shell (below)

serve — a line in, lines out:
  {"cmd": "scan"}                  -> {"t": "devices", "devices": […], "known": […], "broken": […]}
  {"cmd": "open", "id": ID}        -> {"t": "progress", "n", "of"}… {"t": "state", "id", …}
  {"cmd": "stream", "on": bool}    -> {"t": "d", "k": [m, mm, m, mm, …]}   key travel, the keys
                                      that moved since the last line, at most one line a frame
  {"cmd": "close"}
  changes, each answered {"t": "state", …} + {"t": "done", "what"} or {"t": "failed", "what", "code", "ru", "en"}:
  {"cmd": "set", "what": "rt" | "mode" | "mouse", …}   travel settings, a mode's settings, a mouse setting
  {"cmd": "layer", "layer": 0..3}                      which layer the keys' actions are shown and set in
  {"cmd": "keys", "keys": [m…], "action": [t, c0, c1] | "factory" | "off"}
  {"cmd": "modtap", "m", "tap", "hold", "delay"}  {"cmd": "toggle", "m", "action"}
  {"cmd": "pair" | "unpair", …}  {"cmd": "light", "mode", "zone", "values"}  {"cmd": "restore"}
  {"cmd": "profile", "do": "save" | "load" | "delete", "name" | "file"}
  errors: {"t": "error", "id", "code", "ru", "en"};  a device unplugged: {"t": "gone", "id"}
  The list is sent again by itself when a device is plugged in or a description file changes.
  stdin closing ends it and lets the device go.

Every write is checked by the protocol's guard, read back and compared; a backup of every
setting is taken before the first one (docs/devices.md, "Запись"). No firmware command
exists in this code.

ANGELOS_DEVICES_FAKE=wave | idle | press:3,17   every shipped keyboard is "connected" as an
  emulator playing that script (devlib/emulator.py): the stands, the tests, work without hardware.
ANGELOS_DEVICES_DIR / ANGELOS_DEVICES_BUILTIN move the two description folders.
"""
import argparse
import json
import os
import select
import signal
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from devlib import bridge, emulator, hidraw, registry, usbfs   # noqa: E402
from devlib.mouse import AuroraSession                 # noqa: E402
from devlib import nuphy_io as np                      # noqa: E402
from devlib.session import SESSIONS, DeviceError       # noqa: E402

FAKE = os.environ.get("ANGELOS_DEVICES_FAKE", "")
SESSIONS = dict(SESSIONS, **{"lamzu-aurora": AuroraSession})
FRAME = 0.004           # travel lines are at most this often: one a frame of a 240 Hz screen
RESCAN = 2.0            # how often the USB list and the description folders are looked at

MESSAGES = {
    "denied": ("система не даёт открыть служебный канал устройства", "the system won't let the device's service channel be opened"),
    "busy": ("служебный интерфейс занят: его держит драйвер ядра или другая программа; оболочка его не отнимает", "the service interface is taken: a kernel driver or another program holds it; the shell does not take it away"),
    "gone": ("устройство отключено", "the device is not connected"),
    "timeout": ("устройство не отвечает", "the device does not answer"),
"asleep": ("мышь спит: отвечает один донгл. Пошевели её", "the mouse is asleep: the dongle alone answers. Move it"),
    "deaf": ("устройство принимает команды, но ничего не отвечает: его служебный канал завис (ошибка шины −71) и оживёт после переподключения устройства",
             "the device takes commands and answers nothing: its service channel is stuck (bus error −71) and comes back when the device is plugged in again"),
    "protocol": ("устройство ответило не так, как ждёт этот драйвер", "the device answered not as this driver expects"),
    "readonly": ("это устройство открыто только на чтение", "this device is open for reading only"),
    "unknown": ("такого устройства нет в списке", "no such device in the list"),
"refused": ("такую запись драйвер не делает", "the driver does not make such a write"),
"verify": ("клавиатура не приняла запись: после неё прочиталось другое", "the keyboard did not take the write: something else was read back"),
"range": ("значение вне пределов устройства", "the value is outside the device's limits"),
"full": ("в этом режиме клавиатуры кончились ячейки для парных клавиш", "this keyboard mode has no slots left for paired keys"),
"nobackup": ("нет резервной копии — без неё оболочка не пишет в устройство", "no backup: without one the shell does not write to a device"),
    "io": ("ошибка обмена с устройством", "an I/O error talking to the device"),
}


def message(code, detail=""):
    ru, en = MESSAGES.get(code, MESSAGES["io"])
    return {"code": code, "ru": ru, "en": en, "detail": detail}


def public(desc):
    """A description as the shell needs it."""
    return {k: desc.get(k) for k in ("id", "name", "maker", "kind", "family", "support", "checked", "capabilities",
                                    "switches", "layout", "notes", "origin", "file")}


def scan():
    """(connected, known, broken). connected: the description + how it is reachable."""
    descs, broken = registry.load_all()
    connected = []
    for d in descs:
        if FAKE:
            if d["origin"] == "builtin":
                connected.append(dict(public(d), access="ok", fake=True, node="", usbVersion=""))
            continue
        if d["channel"].get("via") == "hidraw":
            # a mouse's configuration interface: a hidraw node with feature reports alone
            for u in d["usb"]:
                for n, dev in enumerate(hidraw.find(u["vid"], u["pid"])):
                    connected.append(dict(public(d), id=d["id"] + ("#%d" % (n + 1) if n else ""), base=d["id"], access=hidraw.access(dev["node"]),
                                          via="hidraw", fake=False, node=dev["node"], usbVersion="", driver="", held=False, vid=u["vid"], pid=u["pid"]))
            continue
        for u in d["usb"]:
            for n, dev in enumerate(usbfs.find(u["vid"], u["pid"])):
                iface = d["channel"]["interface"]
                driver = dev["interfaces"].get(iface)
                # through the bridge where it is installed (it filters what goes to the device);
                # straight to the USB node only where somebody opened the node to this user
                via = "bridge" if bridge.available() else "usbfs"
                # "usbfs" on the interface is no kernel driver: somebody (this shell's page,
                # another `angelos devices`) holds it right now
                held = driver == "usbfs" and via != "bridge"
                acc = "busy" if driver and not held else "ok" if via == "bridge" else usbfs.access(dev["node"])
                connected.append(dict(public(d), id=d["id"] + ("#%d" % (n + 1) if n else ""), base=d["id"], access=acc, via=via,
                                      fake=False, node=dev["node"], usbVersion=dev["version"], driver=driver or "",
                                      held=held, vid=u["vid"], pid=u["pid"]))
    connected.sort(key=lambda d: (d["kind"] != "keyboard", d["name"]))
    known = [{k: d.get(k) for k in ("id", "name", "maker", "kind", "family", "support", "checked", "origin")} for d in descs]
    return connected, sorted(known, key=lambda k: (k["maker"] or "", k["name"])), broken


def open_session(dev, descs, writes=False):
    """The session of a connected device from scan()."""
    desc = next((d for d in descs if d["id"] == dev.get("base", dev["id"])), None)
    if not desc:
        raise DeviceError("unknown")
    if dev.get("fake"):
        channel = emulator.AuroraEmu(desc, FAKE) if desc["family"] == "lamzu-aurora" else emulator.NuphyEmu(desc, FAKE)
    elif dev.get("via") == "hidraw":
        channel = hidraw.FeatureChannel(dev["node"])
    else:
        ch = desc["channel"]
        if dev.get("via") == "bridge":
            channel = bridge.BridgeChannel(dev["vid"], dev["pid"])
        else:
            channel = usbfs.Interface(dev["node"], ch["interface"], registry.endpoint(ch["in"]), registry.endpoint(ch["out"]))
    s = SESSIONS[desc["family"]](desc, channel, writes=writes)
    try:
        s.open()
    except usbfs.UsbError as e:
        raise DeviceError(e.code, str(e)) from None
    return s


def pick(connected, wanted):
    if not connected:
        return None
    if not wanted:
        return connected[0]
    return next((d for d in connected if d["id"] == wanted or d.get("base") == wanted), None)


# ---- the shell's helper --------------------------------------------------------------------

def emit(obj):
    sys.stdout.write(json.dumps(obj, ensure_ascii=False, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def serve():
    session, sid, streaming = None, "", False
    kept = False                                # the device is read by the bridge all the time
    stamp, seen = None, None
    last_frame = 0.0
    connected, descs = [], []

    def tell():
        st = session.state
        emit(dict(st, t="state", id=sid, keys={str(k): v for k, v in st["keys"].items()},
                  actions={str(k): v for k, v in st["actions"].items()}))

    def change(what, fn):
        """One write asked by the shell: done and the new state, or why not. Only a device
        that is gone ends the session; a refused or failed write leaves it open."""
        if not session or not session.state:
            emit(dict(message("gone"), t="failed", what=what))
            return
        try:
            fn()
            tell()
            emit({"t": "done", "what": what})
        except DeviceError as e:
            if e.code in ("gone", "deaf", "timeout", "denied"):
                emit(dict(message(e.code, str(e)), t="error", id=sid))
                drop()
            else:
                # (a mouse that fell asleep meanwhile is not gone: "move it" and the session stays)
                emit(dict(message(e.code, str(e)), t="failed", what=what))
        except (KeyError, TypeError, ValueError) as e:
            emit(dict(message("range", str(e)), t="failed", what=what))
        except AttributeError:
            # a keyboard's setting asked of a mouse, or the other way round
            emit(dict(message("refused", "not a setting of this device"), t="failed", what=what))

    def drop():
        nonlocal session, sid, streaming
        if session:
            session.close()
        session, sid, streaming = None, "", False

    def rescan(force=False):
        nonlocal stamp, seen, connected, descs
        s = registry.stamp()
        c, known, broken = scan()
        key = json.dumps([[d["id"], d["access"], d.get("via", ""), d.get("node", ""), d.get("driver", "")] for d in c])
        if not force and s == stamp and key == seen:
            return
        stamp, seen, connected = s, key, c
        descs = registry.load_all()[0]
        emit({"t": "devices", "devices": c, "known": known, "broken": broken})
        if session and not any(d["id"] == sid for d in c):
            emit({"t": "gone", "id": sid})
            drop()

    try:
        rescan(True)
        stdin = sys.stdin.fileno()
        buf = b""
        next_scan = time.monotonic() + RESCAN
        while True:
            # asleep until the shell says something; with a device open, a look at it every frame
            # while travel is streamed and ten times a second otherwise
            wait = FRAME if streaming else 0.1 if session else RESCAN
            try:
                ready, _, _ = select.select([stdin], [], [], wait)
            except (OSError, ValueError):
                break
            if ready:
                chunk = os.read(stdin, 65536)
                if not chunk:
                    break
                buf += chunk
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    try:
                        msg = json.loads(line)
                    except ValueError:
                        continue
                    cmd = msg.get("cmd")
                    if cmd == "scan":
                        rescan(True)
                    elif cmd == "close":
                        drop()
                    elif cmd == "stream":
                        streaming = bool(msg.get("on")) and session is not None
                        if session and session.state and hasattr(session, "set_upload") and not session.why_readonly and bool(session.state["upload"]) != streaming \
                                and (streaming or not kept):
                            # the keyboard reports travel only while somebody watches it here. Through
                            # the bridge it is read all the time anyway: once on, it stays on (no
                            # write each time the page is left)
                            want = streaming
                            change("upload", lambda: session.set_upload(want))
                        if session and streaming:
                            keys = session.all_depth()      # a key held down already is seen at once
                            if keys:
                                emit({"t": "d", "k": keys})
                    elif cmd == "set" and msg.get("what") == "rt":
                        change("rt", lambda: session.set_rt(msg.get("keys") or [], msg.get("values") or {}))
                    elif cmd == "set" and msg.get("what") == "mode":
                        values = {k: v for k, v in (msg.get("values") or {}).items() if k != "keyStatusUpload"}
                        change("mode", lambda: session.set_func(int(msg.get("mode", -1)), values))
                    elif cmd == "set" and msg.get("what") == "mouse":
                        change("mouse", lambda: session.set_setting(msg.get("name"), msg.get("value")))
                    elif cmd == "layer":
                        change("layer", lambda: session.set_layer(msg.get("layer", 0)))
                    elif cmd == "keys":
                        change("keys", lambda: session.set_keys(msg.get("keys") or [], msg.get("action")))
                    elif cmd == "modtap":
                        change("modtap", lambda: session.set_modtap(msg["m"], msg.get("tap"), msg.get("hold"), msg.get("delay", 200)))
                    elif cmd == "toggle":
                        change("toggle", lambda: session.set_toggle(msg["m"], msg.get("action")))
                    elif cmd == "light":
                        change("light", lambda: session.set_light(int(msg.get("mode", -1)), msg.get("zone", "main"), msg.get("values") or {}))
                    elif cmd == "profile":
                        act = msg.get("do")
                        if act == "save":
                            change("profile", lambda: session.save_profile(msg.get("name", ""), lambda n, of: emit({"t": "progress", "id": sid, "n": n, "of": of})))
                        elif act == "load":
                            change("profile", lambda: session.restore(msg.get("file"), lambda n, of: emit({"t": "progress", "id": sid, "n": n, "of": of})))
                        elif act == "delete":
                            change("profile", lambda: session.delete_profile(msg.get("file", "")))
                    elif cmd == "pair":
                        change("pair", lambda: session.set_pair(msg["a"], msg["b"], msg.get("rule", "last"), msg.get("kind", "socd")))
                    elif cmd == "unpair":
                        change("pair", lambda: session.clear_pair(msg["m"]))
                    elif cmd == "restore":
                        change("restore", lambda: session.restore(None, lambda n, of: emit({"t": "progress", "id": sid, "n": n, "of": of})))
                    elif cmd == "open":
                        drop()
                        dev = pick(connected, msg.get("id"))
                        want = msg.get("id") or (dev or {}).get("id", "")
                        if not dev:
                            emit(dict(message("unknown"), t="error", id=want))
                            continue
                        if dev["access"] != "ok":
                            emit(dict(message(dev["access"]), t="error", id=dev["id"]))
                            continue
                        try:
                            session = open_session(dev, descs, writes=True)
                            sid = dev["id"]
                            session.load(lambda n, of: emit({"t": "progress", "id": sid, "n": n, "of": of}))
                            kept = dev.get("via") == "bridge"
                            if not session.why_readonly:
                                # the first time ever: everything as it is now, into a file
                                session.ensure_backup(lambda n, of: emit({"t": "progress", "id": sid, "n": n, "of": of, "what": "backup"}))
                                if session.state.get("upload") and hasattr(session, "set_upload") and not kept:
                                    # left on by somebody (the maker's site, a shell that fell): off
                                    # until a picture of the keyboard asks for it. Never a reason
                                    # not to open the device
                                    try:
                                        session.set_upload(False)
                                    except DeviceError as e:
                                        if e.code in ("gone", "deaf"):
                                            raise
                            tell()
                        except DeviceError as e:
                            emit(dict(message(e.code, str(e)), t="error", id=dev["id"]))
                            drop()
            if session:
                while not session.events.empty():
                    ev = session.events.get()
                    if ev["type"] == "gone":
                        emit({"t": "gone", "id": sid})
                        drop()
                        break
                    if ev["type"] == "func" and session.state and session.state.get("modes"):
                        # light / sleep / Win lock changed with keys on the keyboard
                        cur = session.state["modes"][session.state["mode"]]
                        changed = {k: ev[k] for k in ("lockWin", "sleepMinutes", "sleep") if k in cur and cur[k] != ev[k]}
                        if changed:
                            cur.update(changed)
                            tell()
                        continue
                    if ev["type"] == "state" and session.state and ev["mode"] != session.state["mode"] and 0 <= ev["mode"] < np.MODES:
                        # the mode was switched on the keyboard: its keys' settings are another set
                        try:
                            session.load()
                            tell()
                        except DeviceError as e:
                            emit(dict(message(e.code, str(e)), t="error", id=sid))
                            drop()
                            break
            if session and streaming:
                now = time.monotonic()
                if now - last_frame >= FRAME:
                    keys = session.take_depth()
                    if keys:
                        emit({"t": "d", "k": keys})
                        last_frame = now
            # a device plugged in or out, a description file put into the folder
            if time.monotonic() >= next_scan:
                rescan()
                next_scan = time.monotonic() + RESCAN
    finally:
        # the shell let go (or is gone): the interface is released, nothing stays claimed
        drop()
    return 0


# ---- the command line ----------------------------------------------------------------------

def cmd_list(args):
    connected, known, broken = scan()
    if args.json:
        print(json.dumps({"devices": [{k: v for k, v in d.items() if k != "layout"} for d in connected], "known": known, "broken": broken}, ensure_ascii=False, indent=1))
        return 0
    if not connected:
        print("Ни одно описанное устройство не подключено.")
    for d in connected:
        state = {"ok": "доступно через мост" if d.get("via") == "bridge" else "доступно", "denied": "нет доступа к " + d["node"], "busy": "служебный интерфейс у драйвера " + d.get("driver", "")}.get(d["access"], d["access"])
        print("%-22s %-24s %-10s %s%s" % (d["id"], d["name"], d["family"], state, "  (эмулятор)" if d.get("fake") else ""))
    print("\nОписаний устройств: %d" % len(known))
    for k in known:
        mark = {"verified": "проверено на железе", "described": "по описанию, не проверено", "readonly": "только чтение"}[k["support"]]
        print("  %-22s %-24s %s%s" % (k["id"], k["name"], mark, "" if k["origin"] == "builtin" else "  [ваш файл]"))
    for b in broken:
        print("\nФайл с ошибками: " + b["file"])
        for p in b["problems"]:
            print("  %s: %s" % (p["at"] or "файл", p["ru"]))
    return 1 if broken else 0


def borrow(dev):
    """A page of the shell holds the device: ask the shell to let it go for a while."""
    import shutil
    import subprocess
    # through the bridge sysfs cannot tell whether the page has it (the bridge holds it all the
    # time): ask anyway, the shell lets go only what it holds
    if not dev or not (dev.get("held") or dev.get("via") == "bridge") or not shutil.which("qs"):
        return False
    try:
        r = subprocess.run(["qs", "-c", "angelos", "ipc", "call", "angelos", "devices", "lend 30"], capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.SubprocessError):
        return False
    if r.returncode != 0 or "lent" not in r.stdout:
        return False
    time.sleep(0.6)
    return True


def give_back():
    import shutil
    import subprocess
    if shutil.which("qs"):
        try:
            subprocess.run(["qs", "-c", "angelos", "ipc", "call", "angelos", "devices", "back"], capture_output=True, timeout=5)
        except (OSError, subprocess.SubprocessError):
            pass


def with_session(args, fn):
    connected, _, _ = scan()
    dev = pick(connected, getattr(args, "id", None))
    borrowed = borrow(dev)
    try:
        return _with_session(args, fn, dev)
    finally:
        if borrowed:
            give_back()


def _with_session(args, fn, dev):
    if not dev:
        print("Устройство не найдено. `angelos devices list` покажет подключённые.", file=sys.stderr)
        return 2
    if dev["access"] != "ok":
        m = message(dev["access"])
        print("%s: %s." % (dev["name"], m["ru"]), file=sys.stderr)
        if dev["access"] == "denied":
            print("Узел %s открыт только root. Как выдать доступ: docs/devices.md, «Доступ»." % dev["node"], file=sys.stderr)
        return 3
    try:
        s = open_session(dev, registry.load_all()[0])
    except DeviceError as e:
        print("%s: %s (%s)." % (dev["name"], message(e.code)["ru"], e), file=sys.stderr)
        return 3
    try:
        return fn(dev, s) or 0
    except DeviceError as e:
        print("%s: %s (%s)." % (dev["name"], message(e.code)["ru"], e), file=sys.stderr)
        return 4
    finally:
        s.close()


def cmd_info(args):
    def run(dev, s):
        st = s.load()
        if st.get("kind") == "mouse" and not args.json:
            b = st["battery"]
            print("%s — прошивка %s, профиль %d" % (dev["name"], st["firmware"]["version"], st["profile"]))
            print("заряд: %d %%%s" % (b["percent"], ", заряжается" if b["charging"] else ""))
            print("частота опроса: %d Гц" % st["pollingRate"])
            print("DPI: " + ", ".join(("[%s]" if n + 1 == st["dpiActive"] else "%s") % (x["x"] if x["x"] == x["y"] else "%d×%d" % (x["x"], x["y"])) for n, x in enumerate(st["dpiStages"])))
            print("высота отрыва: %s мм, debounce: %d мс, Motion Sync: %s, Angle Snap: %s, Ripple Control: %s" % (
                st["lod"], st["debounce"], "вкл" if st["motionSync"] else "выкл", "вкл" if st["angleSnap"] else "выкл", "вкл" if st["ripple"] else "выкл"))
            print("сон через: %s" % ("никогда" if not st["sleep"] else "%d с" % st["sleep"]))
            return
        if args.json:
            print(json.dumps(dict(st, keys={str(k): v for k, v in st["keys"].items()}, actions={str(k): v for k, v in st["actions"].items()}), ensure_ascii=False, indent=1))
            return
        fw = st["firmware"]
        print("%s — прошивка %s (%s)" % (dev["name"], fw["version"], fw.get("built", "")))
        print("режим: %s (%d из %s), слоёв в режиме: %d" % (st["modeName"], st["mode"], "/".join(st["modeNames"]), st["layersPerMode"]))
        for n, m in enumerate(st["modes"]):
            print("  %-8s reportRate=%d tickRate=%d сон=%s %d мин  Win-lock=%s  speed=%s game=%s dynCal=%s стабилизация=%d  поток хода=%s" % (
                st["modeNames"][n], m["reportRate"], m["tickRate"], "да" if m["sleep"] else "нет", m["sleepMinutes"], m["lockWin"],
                m["speedMode"], m["gameOptimization"], m["dynamicCalibration"], m["stabilization"], "ВКЛ" if m["keyStatusUpload"] else "выкл"))
        if st["mismatch"]:
            print("Раскладка в файле описания не сходится с клавиатурой в %d клавишах:" % len(st["mismatch"]))
            for x in st["mismatch"][:12]:
                print("  клавиша %d «%s»: в файле %s, в клавиатуре %s" % (x["m"], x["label"], x["file"], x["device"]))
        else:
            print("Раскладка файла описания сходится с заводской матрицей клавиатуры (%d клавиш)." % len(s.desc["layout"]["keys"]))
        labels = {k["m"]: k.get("label", "") for k in s.desc["layout"]["keys"]}
        print("\nХод клавиш в режиме %s (мм):" % st["modeName"])
        print("  %-3s %-10s %-10s %-6s %-6s %-6s %-6s %-6s %s" % ("№", "клавиша", "режим", "сраб.", "RT↓", "RT↑", "мз↓", "мз↑", "SOCD"))
        for m in sorted(st["keys"]):
            k = st["keys"][m]
            print("  %-3d %-10s %-10s %-6.2f %-6.3f %-6.3f %-6.2f %-6.2f %s" % (m, labels.get(m, ""), k["trigger"], k["actuation"], k["press"], k["release"], k["pressDead"], k["releaseDead"], k["priority"]))
        print("\nпакетов: %(packets)d, отчётов: %(reports)d, неизвестных: %(unknown)d, плохих сумм: %(badSum)d, повторов: %(retries)d, ошибок шины: %(ioErrors)d" % s.stats)
    return with_session(args, run)


def cmd_dump(args):
    def run(dev, s):
        st = s.load()
        snap = s.snapshot(lambda n, of: print("\r%d/%d" % (n, of), end="", file=sys.stderr))
        print(file=sys.stderr)
        out = {"format": "angelos-device-backup", "version": 1, "device": dev.get("base", dev["id"]), "family": s.family,
               "firmware": st["firmware"], "taken": time.strftime("%Y-%m-%dT%H:%M:%S"), "regions": snap}
        target = Path(args.output) if args.output else Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "angelos/devices" / (
            "backup-%s-%s.json" % (dev.get("base", dev["id"]), time.strftime("%Y%m%d-%H%M%S")))
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(out, indent=1))
        print(target)
    return with_session(args, run)


def sniff_line(packet, t0):
    r = np.parse_report(packet) if packet and packet[0] != np.FLAG_ANSWER else None
    note = ""
    if r and r["type"] == "key":
        note = "  key %s  travel %d  raw %d  %s" % (np.action_name(r["key"]), r["travel"], r["raw"], r["status"])
    elif r:
        note = "  " + json.dumps(r, ensure_ascii=False)
    elif packet and packet[0] == np.FLAG_ANSWER:
        note = "  answer to %s" % np.CMD_NAME.get(packet[1], packet[1])
    return "%8.3f  %s%s" % (time.monotonic() - t0, packet[:24].hex(" "), note)


def cmd_sniff(args):
    seconds = max(0.5, float(args.seconds))
    if args.usb:
        # a device no description knows yet: only listen on the interface named
        vid, _, pid = args.usb.partition(":")
        found = usbfs.find(vid, pid)
        if not found:
            print("Устройство %s не подключено." % args.usb, file=sys.stderr)
            return 2
        ch = usbfs.Interface(found[0]["node"], args.interface, int(args.ep_in, 0), int(args.ep_out, 0))
        try:
            ch.open()
        except usbfs.UsbError as e:
            print("%s: %s (%s)." % (args.usb, message(e.code)["ru"], e), file=sys.stderr)
            return 3
        t0 = time.monotonic()
        try:
            print("HID-описатель интерфейса %d: %s" % (args.interface, ch.hid_report_descriptor().hex(" ")))
            while time.monotonic() - t0 < seconds:
                p = ch.read(64, 100)
                if p:
                    print(sniff_line(p, t0), flush=True)
        finally:
            ch.close()
        return 0

    def run(dev, s):
        t0 = time.monotonic()

        def tap(p):
            try:
                print(sniff_line(p, t0), flush=True)
            except (BrokenPipeError, ValueError):
                s.raw_tap = None            # the reader of this output is gone
        s.raw_tap = tap
        try:
            st = s.load()
            print("# %s, прошивка %s, режим %s, поток хода клавиш %s" % (dev["name"], st["firmware"]["version"], st["modeName"], "включён" if st["upload"] else "выключен"), flush=True)
        except DeviceError as e:
            print("# настройки не прочитались (%s); слушаю дальше" % e, flush=True)
        time.sleep(seconds)
        s.raw_tap = None
        print("# пакетов: %(packets)d, отчётов: %(reports)d, неизвестных: %(unknown)d, ошибок шины: %(ioErrors)d" % s.stats)
    return with_session(args, run)


def cmd_check(args):
    bad = 0
    for f in args.files:
        d, problems = registry.load_file(f)
        if d is not None:
            keys = len(d.get("layout", {}).get("keys", []))
            print("%s: в порядке — %s, семейство %s%s" % (f, d["name"], d["family"], ", клавиш: %d" % keys if keys else ""))
            continue
        bad += 1
        print("%s: ошибок: %d" % (f, len(problems)))
        for p in problems:
            print("  %s: %s" % (p["at"] or "файл", p["ru"]))
    return 1 if bad else 0


def main(argv):
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    ap = argparse.ArgumentParser(prog="angelos devices", description="Hall-effect keyboards and mice from the shell (read-only stage)")
    sub = ap.add_subparsers(dest="cmd")
    p = sub.add_parser("list")
    p.add_argument("--json", action="store_true")
    p = sub.add_parser("info")
    p.add_argument("id", nargs="?")
    p.add_argument("--json", action="store_true")
    p = sub.add_parser("dump")
    p.add_argument("id", nargs="?")
    p.add_argument("-o", "--output")
    p = sub.add_parser("sniff")
    p.add_argument("id", nargs="?")
    p.add_argument("--seconds", default="10")
    p.add_argument("--usb")
    p.add_argument("--interface", type=int, default=1)
    p.add_argument("--in", dest="ep_in", default="0x82")
    p.add_argument("--out", dest="ep_out", default="0x02")
    p = sub.add_parser("check")
    p.add_argument("files", nargs="+")
    sub.add_parser("serve")
    sub.add_parser("schema")
    args = ap.parse_args(argv)
    if args.cmd == "serve":
        return serve()
    if args.cmd == "schema":
        print(json.dumps(registry.schema(), indent=2, ensure_ascii=False))
        return 0
    if args.cmd in (None, "list"):
        if args.cmd is None:
            args.json = False
        return cmd_list(args)
    return {"info": cmd_info, "dump": cmd_dump, "sniff": cmd_sniff, "check": cmd_check}[args.cmd](args)


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except (KeyboardInterrupt, BrokenPipeError):
        sys.exit(0)
