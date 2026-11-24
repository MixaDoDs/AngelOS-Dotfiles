#!/usr/bin/env python3
"""The devices' driver of angelOS: mice set up from the shell (services/Devices;
Settings → Devices → Device driver; docs/devices.md).

  devices.py list [--json]            the devices connected that a description knows, and the
                                      description files that are broken
  devices.py info [ID] [--json]       open one, read its settings (only reads), print them
  devices.py check FILE…              is this description file good; every problem by line
  devices.py serve                    JSON lines for the shell (below)

serve — a line in, lines out:
  {"cmd": "scan"}                  -> {"t": "devices", "devices": […], "known": […], "broken": […]}
  {"cmd": "open", "id": ID}        -> {"t": "progress", "n", "of"}… {"t": "state", "id", …}
  {"cmd": "close"}
  changes, each answered {"t": "state", …} + {"t": "done", "what"} or {"t": "failed", "what", "code", "ru", "en"}:
  {"cmd": "set", "what": "mouse", "name", "value"}   {"cmd": "restore"}
  errors: {"t": "error", "id", "code", "ru", "en"};  a device unplugged: {"t": "gone", "id"}
  The list is sent again by itself when a device is plugged in or a description file changes.
  stdin closing ends it and lets the device go.

Every write is read back and compared; a backup of every setting is taken before the first
one (docs/devices.md, "Запись"). No firmware command exists in this code.

ANGELOS_DEVICES_FAKE=idle | asleep   every shipped mouse is "connected" as an emulator
  (devlib/emulator.py): the stands, the tests, work without hardware.
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
from devlib import emulator, hidraw, registry           # noqa: E402
from devlib.mouse import AuroraSession                 # noqa: E402
from devlib.session import DeviceError                 # noqa: E402

FAKE = os.environ.get("ANGELOS_DEVICES_FAKE", "")
SESSIONS = {"lamzu-aurora": AuroraSession}
RESCAN = 2.0            # how often the USB list and the description folders are looked at

MESSAGES = {
    "denied": ("система не даёт открыть служебный канал устройства", "the system won't let the device's service channel be opened"),
    "gone": ("устройство отключено", "the device is not connected"),
    "timeout": ("устройство не отвечает", "the device does not answer"),
"asleep": ("мышь спит: отвечает один донгл. Пошевели её", "the mouse is asleep: the dongle alone answers. Move it"),
    "readonly": ("это устройство открыто только на чтение", "this device is open for reading only"),
    "unknown": ("такого устройства нет в списке", "no such device in the list"),
"refused": ("такую запись драйвер не делает", "the driver does not make such a write"),
"verify": ("устройство не приняло запись: после неё прочиталось другое", "the device did not take the write: something else was read back"),
"range": ("значение вне пределов устройства", "the value is outside the device's limits"),
"nobackup": ("нет резервной копии — без неё оболочка не пишет в устройство", "no backup: without one the shell does not write to a device"),
    "io": ("ошибка обмена с устройством", "an I/O error talking to the device"),
}


def message(code, detail=""):
    ru, en = MESSAGES.get(code, MESSAGES["io"])
    return {"code": code, "ru": ru, "en": en, "detail": detail}


def public(desc):
    """A description as the shell needs it."""
    return {k: desc.get(k) for k in ("id", "name", "maker", "kind", "family", "support", "checked", "capabilities",
                                    "notes", "origin", "file")}


def scan():
    """(connected, known, broken). connected: the description + how it is reachable."""
    descs, broken = registry.load_all()
    connected = []
    for d in descs:
        if FAKE:
            if d["origin"] == "builtin":
                connected.append(dict(public(d), access="ok", fake=True, node=""))
            continue
        # a mouse's configuration interface: a hidraw node with feature reports alone
        for u in d["usb"]:
            for n, dev in enumerate(hidraw.find(u["vid"], u["pid"])):
                connected.append(dict(public(d), id=d["id"] + ("#%d" % (n + 1) if n else ""), base=d["id"], access=hidraw.access(dev["node"]),
                                      via="hidraw", fake=False, node=dev["node"], vid=u["vid"], pid=u["pid"]))
    connected.sort(key=lambda d: d["name"])
    known = [{k: d.get(k) for k in ("id", "name", "maker", "kind", "family", "support", "checked", "origin")} for d in descs]
    return connected, sorted(known, key=lambda k: (k["maker"] or "", k["name"])), broken


def open_session(dev, descs, writes=False):
    """The session of a connected device from scan()."""
    desc = next((d for d in descs if d["id"] == dev.get("base", dev["id"])), None)
    if not desc:
        raise DeviceError("unknown")
    channel = emulator.AuroraEmu(desc, FAKE) if dev.get("fake") else hidraw.FeatureChannel(dev["node"])
    s = SESSIONS[desc["family"]](desc, channel, writes=writes)
    try:
        s.open()
    except hidraw.UsbError as e:
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
    session, sid = None, ""
    stamp, seen = None, None
    connected, descs = [], []

    def tell():
        emit(dict(session.state, t="state", id=sid))

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
            if e.code in ("gone", "timeout", "denied"):
                emit(dict(message(e.code, str(e)), t="error", id=sid))
                drop()
            else:
                # (a mouse that fell asleep meanwhile is not gone: "move it" and the session stays)
                emit(dict(message(e.code, str(e)), t="failed", what=what))
        except (KeyError, TypeError, ValueError) as e:
            emit(dict(message("range", str(e)), t="failed", what=what))

    def drop():
        nonlocal session, sid
        if session:
            session.close()
        session, sid = None, ""

    def rescan(force=False):
        nonlocal stamp, seen, connected, descs
        s = registry.stamp()
        c, known, broken = scan()
        key = json.dumps([[d["id"], d["access"], d.get("node", "")] for d in c])
        if not force and s == stamp and key == seen:
            return
        stamp, seen, connected = s, key, c
        descs = registry.load_all()[0]
        emit({"t": "devices", "devices": c, "known": known, "broken": broken})
        if session and not any(d["id"] == sid for d in c):
            emit({"t": "gone", "id": sid})
            drop()

    # The shell stops this helper with SIGTERM (a Process set not running): only a flag, the
    # loop ends at its next turn (a write in progress is let finish) and `finally` lets go.
    stopping = []
    signal.signal(signal.SIGTERM, lambda *_: stopping.append(1))
    try:
        rescan(True)
        stdin = sys.stdin.fileno()
        buf = b""
        next_scan = time.monotonic() + RESCAN
        while not stopping:
            try:
                ready, _, _ = select.select([stdin], [], [], RESCAN)
            except (OSError, ValueError):
                break
            if stopping:
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
                    elif cmd == "set" and msg.get("what") == "mouse":
                        change("mouse", lambda: session.set_setting(msg.get("name"), msg.get("value")))
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
                            if not session.why_readonly:
                                # the first time ever: everything as it is now, into a file
                                session.ensure_backup(lambda n, of: emit({"t": "progress", "id": sid, "n": n, "of": of, "what": "backup"}))
                            tell()
                        except DeviceError as e:
                            emit(dict(message(e.code, str(e)), t="error", id=dev["id"]))
                            drop()
            # a device plugged in or out, a description file put into the folder
            if time.monotonic() >= next_scan:
                rescan()
                next_scan = time.monotonic() + RESCAN
    finally:
        # the shell let go (or is gone): nothing stays open
        drop()
    return 0


# ---- the command line ----------------------------------------------------------------------

def cmd_list(args):
    connected, known, broken = scan()
    if args.json:
        print(json.dumps({"devices": connected, "known": known, "broken": broken}, ensure_ascii=False, indent=1))
        return 0
    if not connected:
        print("Ни одно описанное устройство не подключено.")
    for d in connected:
        state = {"ok": "доступно", "denied": "нет доступа к " + d["node"]}.get(d["access"], d["access"])
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


def with_session(args, fn):
    connected, _, _ = scan()
    dev = pick(connected, getattr(args, "id", None))
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
        if args.json:
            print(json.dumps(st, ensure_ascii=False, indent=1))
            return
        b = st["battery"]
        print("%s — прошивка %s, профиль %d" % (dev["name"], st["firmware"]["version"], st["profile"]))
        print("заряд: %d %%%s" % (b["percent"], ", заряжается" if b["charging"] else ""))
        print("частота опроса: %d Гц" % st["pollingRate"])
        print("DPI: " + ", ".join(("[%s]" if n + 1 == st["dpiActive"] else "%s") % (x["x"] if x["x"] == x["y"] else "%d×%d" % (x["x"], x["y"])) for n, x in enumerate(st["dpiStages"])))
        print("высота отрыва: %s мм, debounce: %d мс, Motion Sync: %s, Angle Snap: %s, Ripple Control: %s" % (
            st["lod"], st["debounce"], "вкл" if st["motionSync"] else "выкл", "вкл" if st["angleSnap"] else "выкл", "вкл" if st["ripple"] else "выкл"))
        print("сон через: %s" % ("никогда" if not st["sleep"] else "%d с" % st["sleep"]))
    return with_session(args, run)


def cmd_check(args):
    bad = 0
    for f in args.files:
        d, problems = registry.load_file(f)
        if d is not None:
            print("%s: в порядке — %s, семейство %s" % (f, d["name"], d["family"]))
            continue
        bad += 1
        print("%s: ошибок: %d" % (f, len(problems)))
        for p in problems:
            print("  %s: %s" % (p["at"] or "файл", p["ru"]))
    return 1 if bad else 0


def main(argv):
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    ap = argparse.ArgumentParser(prog="angelos devices", description="mice set up from the shell")
    sub = ap.add_subparsers(dest="cmd")
    p = sub.add_parser("list")
    p.add_argument("--json", action="store_true")
    p = sub.add_parser("info")
    p.add_argument("id", nargs="?")
    p.add_argument("--json", action="store_true")
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
    return {"info": cmd_info, "check": cmd_check}[args.cmd](args)


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except (KeyboardInterrupt, BrokenPipeError):
        sys.exit(0)
