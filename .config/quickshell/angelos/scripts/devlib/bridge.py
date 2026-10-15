"""The client's end of the USB bridge (extras/usb-bridge/bridge.py; docs/devices.md, «Доступ»):
a channel like usbfs.Interface — open(), read(), write(), close() — that goes through the
bridge's socket instead of the device's USB node. The node itself stays closed to the user;
what goes to the device is filtered on the other side.
"""
import json
import os
import socket

from .usbfs import UsbError

SOCKET = os.environ.get("ANGELOS_USB_BRIDGE", "/run/angelos-usb/bridge.sock")


def available(path=None):
    """Is the bridge installed and listening (the socket is there)."""
    try:
        import stat
        return stat.S_ISSOCK(os.stat(path or SOCKET).st_mode)
    except OSError:
        return False


class BridgeChannel:
    def __init__(self, vid, pid, path=None):
        self.key = "%04x:%04x" % (int(str(vid), 16), int(str(pid), 16))
        self.path = path or SOCKET
        self.sock = None
        self.deaf = False
        self.refused = ""           # why the bridge did not pass the last packet on, if it did not
        self.family = ""

    def open(self):
        s = socket.socket(socket.AF_UNIX, socket.SOCK_SEQPACKET)
        try:
            s.settimeout(3)
            s.connect(self.path)
            s.send(b"J" + json.dumps({"open": self.key}).encode())
            # an older bridge can let a packet of the device (or a "deaf" note) in before its
            # answer: those are not the answer
            reply, deaf = {}, False
            for _ in range(64):
                answer = s.recv(4096)
                if answer[:1] != b"J":
                    if not answer:
                        break
                    continue
                try:
                    reply = json.loads(answer[1:])
                except ValueError:
                    reply = {}
                    break
                if "deaf" in reply and "ok" not in reply and "error" not in reply:
                    deaf = bool(reply["deaf"])
                    reply = {}
                    continue
                break
        except (OSError, socket.timeout) as e:
            s.close()
            raise UsbError("denied", "the USB bridge does not answer: %s" % e) from None
        if deaf and reply.get("ok"):
            self.deaf = True
        if not reply.get("ok"):
            s.close()
            raise UsbError(str(reply.get("error") or "io"), str(reply.get("message") or "the USB bridge refused"))
        self.family = str(reply.get("family") or "")
        self.sock = s
        return self

    def close(self):
        if self.sock:
            try:
                self.sock.close()
            except OSError:
                pass
            self.sock = None

    def read(self, size=64, timeout_ms=100):
        if not self.sock:
            raise UsbError("gone", "closed")
        self.sock.settimeout(max(0.001, timeout_ms / 1000))
        try:
            msg = self.sock.recv(4096)
        except socket.timeout:
            if self.deaf:
                raise UsbError("io", "bus errors on the IN endpoint", 71) from None
            return b""
        except OSError as e:
            raise UsbError("gone", str(e)) from None
        if not msg:
            raise UsbError("gone", "the USB bridge closed the connection")
        if msg[:1] == b"P":
            self.deaf = False
            return msg[1:1 + size]
        try:
            note = json.loads(msg[1:])
        except ValueError:
            return b""
        if "error" in note:
            raise UsbError(str(note["error"]), str(note.get("message") or ""))
        if "refused" in note:
            self.refused = str(note["refused"])
        if "deaf" in note:
            self.deaf = bool(note["deaf"])
        return b""

    def write(self, data, timeout_ms=1000):
        if not self.sock:
            raise UsbError("gone", "closed")
        self.refused = ""
        try:
            self.sock.settimeout(max(0.001, timeout_ms / 1000))
            self.sock.send(b"P" + bytes(data))
        except (OSError, socket.timeout) as e:
            raise UsbError("gone", str(e)) from None
        return len(data)
