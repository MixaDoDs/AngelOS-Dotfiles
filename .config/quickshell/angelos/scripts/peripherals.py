#!/usr/bin/env python3
"""The charge of the devices UPower knows nothing about (services/Peripherals; the bar's
ampoules, Settings → Devices → Device charge).

  peripherals.py                      one poll, one JSON line
  peripherals.py --watch SECONDS      a poll now and every SECONDS, a line when the answer
                                      changed; a line on stdin ("poll") asks at once and is
                                      always answered, stdin closing ends it. A dongle whose
                                      mouse went silent (asleep: it stops answering within a
                                      minute of lying still) is asked every half a minute for
                                      the next ten, so the mouse is back soon after it wakes
  --no-vendor / --no-headset          leave a source out

  {"devices": [{"id", "name", "kind", "percent", "charging", "full", "source"}],
   "tools": {"headsetcontrol": bool}, "denied": N}
  denied: how many of the makers' nodes this user may not open — the udev rule of
  extras/hid-access is not installed (install.sh of the dotfiles puts it in; Settings →
  Devices → Device charge offers it)

Sources:
  vendor   a 2.4 GHz mouse behind its dongle, asked over hidraw with the maker's own
           feature report. Only reads: the one "battery" query, nothing is ever set.
             LAMZU (373e): the Aurora report, checked on a Maya X with the 8K dongle
  headset  USB headsets through `headsetcontrol -o json`, where it is installed

Bluetooth devices, Logitech's HID++ and gamepads come from UPower (the shell reads it itself).

ANGELOS_PERIPHERALS_FAKE=file: the devices are that JSON file's ({"devices": […]} or the list
itself), read again at every poll, and no device is asked: the stands and the tests.
ANGELOS_SYSFS / ANGELOS_DEVFS move /sys and /dev (tests/peripherals).
"""
import fcntl
import json
import os
import re
import select
import shutil
import subprocess
import sys
import time
from pathlib import Path

SYSFS = Path(os.environ.get("ANGELOS_SYSFS", "/sys"))
DEVFS = Path(os.environ.get("ANGELOS_DEVFS", "/dev"))
FAKE = os.environ.get("ANGELOS_PERIPHERALS_FAKE", "")

# HIDIOCSFEATURE(65) / HIDIOCGFEATURE(65): report id 0 + 64 bytes
HIDIOCSFEATURE_65 = 0xC0414806
HIDIOCGFEATURE_65 = 0xC0414807

KINDS = ("mouse", "keyboard", "headset", "gamepad", "phone", "pen", "speaker", "touchpad", "other")


def clean_name(name):
    """ "LAMZU LAMZU Maya X 8K Dongle" -> "LAMZU Maya X": the maker once, no receiver words."""
    words = []
    for w in str(name or "").split():
        if words and words[-1].lower() == w.lower():
            continue
        words.append(w)
    out = " ".join(words)
    out = re.sub(r"\s+(\d+K\s+)?(dongle|receiver|wireless receiver|nano receiver|usb receiver)\s*$", "", out, flags=re.I)
    return out.strip() or "?"


def slug(name):
    return re.sub(r"[^a-z0-9]+", "-", str(name).lower()).strip("-") or "device"


# ---- LAMZU: the Aurora report -------------------------------------------------------------

def aurora_battery_query():
    """Report id 0, then 64 bytes: [2] the mouse, [3] the length, [5] 0x83 = read the battery."""
    q = bytearray(65)
    q[3] = 0x02
    q[4] = 0x02
    q[6] = 0x83
    return q


def aurora_battery_parse(resp):
    """(percent, charging, full) from the answer, None for anything else (the mouse asleep or
    off answers zeros): 00 A1 .. 02 .. 83 <state: 0 on battery, 1 charging, 2 full> <percent>."""
    if not resp or len(resp) < 9:
        return None
    if resp[1] != 0xA1 or resp[4] != 0x02 or resp[6] != 0x83:
        return None
    state, level = resp[7], resp[8]
    if state > 2 or not 1 <= level <= 100:
        return None
    return level, state == 1, state == 2 or (state == 1 and level >= 100)


def vendor_feature_interface(descriptor):
    """The maker's own interface: a vendor usage page and nothing but one feature report of 64
    bytes without an id. The mouse's and the keyboard's interfaces are never written to."""
    d = bytes(descriptor)
    if len(d) < 6 or d[0] != 0x06 or d[2] != 0xFF:      # Usage Page (vendor, 0xFFxx)
        return False
    if _has_item(d, 0x85):                              # a report id: not this protocol
        return False
    return _has_item(d, 0xB1) and not _has_item(d, 0x81) and not _has_item(d, 0x91) and _count(d) == 64


def _items(d):
    """(tag byte, data) of a HID report descriptor's short items."""
    i = 0
    while i < len(d):
        b = d[i]
        if b == 0xFE:                                   # a long item
            if i + 1 >= len(d):
                return
            i += 3 + d[i + 1]
            continue
        size = (0, 1, 2, 4)[b & 3]
        yield b & 0xFC, d[i + 1:i + 1 + size]
        i += 1 + size


def _has_item(d, tag):
    return any(t == (tag & 0xFC) for t, _ in _items(d))


def _count(d):
    """Report Count × Report Size / 8 of the last main item: the report's bytes."""
    size = count = 0
    for t, data in _items(d):
        if t == 0x74:
            size = int.from_bytes(data, "little")
        elif t == 0x94:
            count = int.from_bytes(data, "little")
    return size * count // 8


LAMZU_VENDORS = {"373E"}


def lamzu_nodes():
    """[(hidraw path, name)] of LAMZU's vendor interfaces."""
    out = []
    for d in sorted((SYSFS / "class/hidraw").glob("hidraw*")):
        try:
            ue = (d / "device/uevent").read_text(errors="ignore")
            m = re.search(r"^HID_ID=\w+:0*([0-9A-Fa-f]{4}):0*([0-9A-Fa-f]{4})\s*$", ue, re.M)
            if not m or m.group(1).upper() not in LAMZU_VENDORS:
                continue
            if not vendor_feature_interface((d / "device/report_descriptor").read_bytes()):
                continue
            n = re.search(r"^HID_NAME=(.*)$", ue, re.M)
            out.append((str(DEVFS / d.name), clean_name(n.group(1) if n else "LAMZU")))
        except OSError:
            continue
    return out


DENIED = 0          # the makers' nodes the last poll was not allowed to open


def lamzu_read(path, tries=3):
    global DENIED
    try:
        fd = os.open(path, os.O_RDWR | os.O_NONBLOCK)
    except PermissionError:
        DENIED += 1
        return None
    except OSError:
        return None
    try:
        for _ in range(tries):
            try:
                fcntl.ioctl(fd, HIDIOCSFEATURE_65, aurora_battery_query())
                time.sleep(0.1)
                resp = bytearray(65)
                fcntl.ioctl(fd, HIDIOCGFEATURE_65, resp)
            except OSError:
                return None
            got = aurora_battery_parse(resp)
            if got:
                return got
        return None
    finally:
        os.close(fd)


SILENT = False      # the last poll met a dongle whose mouse did not answer


def vendor_devices():
    """One entry a mouse: by cable and through its dongle it is two USB devices of one name;
    the one that charges wins."""
    global SILENT, DENIED
    SILENT = False
    DENIED = 0
    best = {}
    for path, name in lamzu_nodes():
        denied = DENIED
        got = lamzu_read(path)
        if not got:
            SILENT = SILENT or DENIED == denied         # a closed door is not a sleeping mouse
            continue
        percent, charging, full = got
        dev = {"id": "lamzu:" + slug(name.replace("LAMZU", "")), "name": name, "kind": "mouse",
               "percent": percent, "charging": charging, "full": full, "source": "vendor"}
        old = best.get(dev["id"])
        if not old or (charging and not old["charging"]):
            best[dev["id"]] = dev
    return list(best.values())


# ---- headsetcontrol -----------------------------------------------------------------------

def headset_parse(text):
    try:
        data = json.loads(text)
    except ValueError:
        return []
    out = []
    for d in data.get("devices") or []:
        if not isinstance(d, dict):
            continue
        b = d.get("battery") or {}
        status = str(b.get("status") or "")
        level = b.get("level")
        if status not in ("BATTERY_AVAILABLE", "BATTERY_CHARGING") or not isinstance(level, (int, float)) or not 0 <= level <= 100:
            continue
        name = clean_name(d.get("device") or d.get("product") or "Headset")
        vid = str(d.get("id_vendor") or "").lower().replace("0x", "")
        pid = str(d.get("id_product") or "").lower().replace("0x", "")
        out.append({"id": "headset:" + (vid + ":" + pid if vid and pid else slug(name)), "name": name, "kind": "headset",
                    "percent": int(round(level)), "charging": status == "BATTERY_CHARGING",
                    "full": status == "BATTERY_CHARGING" and level >= 100, "source": "headsetcontrol"})
    return out


def headset_devices():
    exe = shutil.which("headsetcontrol")
    if not exe:
        return []
    try:
        p = subprocess.run([exe, "-o", "json"], capture_output=True, text=True, timeout=8)
    except (OSError, subprocess.SubprocessError):
        return []
    return headset_parse(p.stdout)


# ---- the stands' and the tests' devices ---------------------------------------------------

def fake_devices():
    try:
        data = json.loads(Path(FAKE).read_text())
    except (OSError, ValueError):
        return []
    out = []
    for n, d in enumerate(data.get("devices", []) if isinstance(data, dict) else data):
        if not isinstance(d, dict):
            continue
        name = str(d.get("name") or "Device " + str(n + 1))
        kind = d.get("kind") if d.get("kind") in KINDS else "other"
        percent = max(0, min(100, int(d.get("percent", 50))))
        out.append({"id": str(d.get("id") or "fake:" + slug(name)), "name": name, "kind": kind, "percent": percent,
                    "charging": bool(d.get("charging")), "full": bool(d.get("full")), "source": "fake"})
    return out


def poll(vendor=True, headset=True):
    global DENIED
    DENIED = 0
    if FAKE:
        devices = fake_devices()
    else:
        devices = (vendor_devices() if vendor else []) + (headset_devices() if headset else [])
    return {"devices": devices, "tools": {"headsetcontrol": bool(shutil.which("headsetcontrol"))}, "denied": DENIED}


def main(argv):
    vendor = "--no-vendor" not in argv
    headset = "--no-headset" not in argv
    if "--watch" not in argv:
        print(json.dumps(poll(vendor, headset), ensure_ascii=False))
        return 0
    try:
        every = max(15.0, float(argv[argv.index("--watch") + 1]))
    except (IndexError, ValueError):
        every = 300.0
    last, asked, silent = None, True, 0
    while True:
        line = json.dumps(poll(vendor, headset), ensure_ascii=False)
        if asked or line != last:
            print(line, flush=True)
            last = line
        silent = silent + 1 if SILENT else 0
        try:
            ready, _, _ = select.select([sys.stdin], [], [], min(every, 30.0) if 0 < silent <= 20 else every)
        except (OSError, ValueError):
            return 0
        asked = bool(ready)
        if ready and not sys.stdin.readline():
            return 0                                    # the shell is gone


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except (KeyboardInterrupt, BrokenPipeError):
        sys.exit(0)
