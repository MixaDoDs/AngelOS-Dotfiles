"""A device's configuration interface through /dev/hidraw, feature reports only: what a mouse
of the "lamzu-aurora" family is set up with. Nothing here touches the interfaces the mouse
moves and clicks through: a node is picked by its report descriptor (a vendor page, one
64-byte feature report, no input, no output), the same test extras/hid-access installs its
udev rule with.
"""
import fcntl
import os
import re
from pathlib import Path

from .usbfs import UsbError

SYSFS = Path(os.environ.get("ANGELOS_SYSFS", "/sys"))
DEVFS = Path(os.environ.get("ANGELOS_DEVFS", "/dev"))

HIDIOCSFEATURE_65 = 0xC0414806      # report id 0 + 64 bytes
HIDIOCGFEATURE_65 = 0xC0414807


def _items(d):
    i = 0
    while i < len(d):
        b = d[i]
        if b == 0xFE:
            if i + 1 >= len(d):
                return
            i += 3 + d[i + 1]
            continue
        size = (0, 1, 2, 4)[b & 3]
        yield b & 0xFC, d[i + 1:i + 1 + size]
        i += 1 + size


def feature_only(descriptor):
    """A vendor usage page with one 64-byte feature report and nothing else."""
    d = bytes(descriptor)
    if len(d) < 6 or d[0] != 0x06 or d[2] != 0xFF:
        return False
    tags = [t for t, _ in _items(d)]
    if 0x84 in tags or 0x80 in tags or 0x90 in tags or 0xB0 not in tags:
        return False
    size = count = 0
    for t, data in _items(d):
        if t == 0x74:
            size = int.from_bytes(data, "little")
        elif t == 0x94:
            count = int.from_bytes(data, "little")
    return size * count // 8 == 64


def find(vid, pid):
    """[{"node", "name", "interface"}] of the feature-only nodes of that USB id."""
    want = (str(vid).upper().rjust(4, "0"), str(pid).upper().rjust(4, "0"))
    out = []
    try:
        nodes = sorted((SYSFS / "class/hidraw").glob("hidraw*"))
    except OSError:
        return out
    for d in nodes:
        try:
            ue = (d / "device/uevent").read_text(errors="ignore")
            m = re.search(r"^HID_ID=\w+:0*([0-9A-Fa-f]{4}):0*([0-9A-Fa-f]{4})\s*$", ue, re.M)
            if not m or (m.group(1).upper(), m.group(2).upper()) != want:
                continue
            if not feature_only((d / "device/report_descriptor").read_bytes()):
                continue
            n = re.search(r"^HID_NAME=(.*)$", ue, re.M)
            out.append({"node": str(DEVFS / d.name), "name": n.group(1).strip() if n else ""})
        except OSError:
            continue
    return out


def access(node):
    if not os.path.exists(node):
        return "gone"
    return "ok" if os.access(node, os.R_OK | os.W_OK) else "denied"


class FeatureChannel:
    """set(payload64) / get() -> 64 bytes."""

    def __init__(self, node):
        self.node = node
        self.fd = -1

    def open(self):
        try:
            self.fd = os.open(self.node, os.O_RDWR | os.O_NONBLOCK | os.O_CLOEXEC)
        except PermissionError as e:
            raise UsbError("denied", str(e)) from None
        except FileNotFoundError as e:
            raise UsbError("gone", str(e)) from None
        except OSError as e:
            raise UsbError("io", str(e)) from None
        return self

    def close(self):
        if self.fd >= 0:
            try:
                os.close(self.fd)
            except OSError:
                pass
            self.fd = -1

    def set(self, payload):
        buf = bytearray(65)
        buf[1:1 + len(payload)] = bytes(payload)[:64]
        try:
            fcntl.ioctl(self.fd, HIDIOCSFEATURE_65, buf)
        except OSError as e:
            raise UsbError("gone" if e.errno in (19, 108) else "io", str(e), e.errno) from None

    def get(self):
        buf = bytearray(65)
        try:
            fcntl.ioctl(self.fd, HIDIOCGFEATURE_65, buf)
        except OSError as e:
            raise UsbError("gone" if e.errno in (19, 108) else "io", str(e), e.errno) from None
        return bytes(buf)
