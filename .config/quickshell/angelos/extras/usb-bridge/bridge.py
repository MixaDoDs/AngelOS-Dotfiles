#!/usr/bin/python3 -I
"""angelOS USB bridge: one service interface of a keyboard, handed to the user at the seat
as a stream of packets — and nothing else of the device (docs/devices.md, «Доступ»).

Why it exists. A keyboard whose service interface the kernel's usbhid must not touch has no
hidraw node for it; the only door is the device's usbfs node, and that node is the whole
device: who may open it may also push the kernel off the interfaces you type through, read
the keys raw, reset the device or send it its firmware loader's commands. So the node is
given to nobody but this program (a udev rule: group angelos-usb), and this program gives
out only what a settings page needs:

  * it runs as the system user angelos-usb (not root), a service from boot on, with nothing
    but USB device nodes in reach; it holds each device's service interface and reads it all
    the time (Keeper: that keyboard's channel dies when nobody reads it), and lends it to one
    client at a time through /run/angelos-usb/bridge.sock;
  * it talks only to someone who sits at this computer now: the peer's uid must own an
    active local session on a seat (logind's /run/systemd/sessions);
  * it opens only the devices of /etc/angelos/usb-bridge.json (root's file, written by
    install.sh from the descriptions angelOS ships), and of each only the one interface and
    the two endpoints named there. It never detaches a kernel driver, never resets a device,
    never sets a configuration (devlib/usbfs.py has no such call);
  * every packet going to the device passes the protocol family's filter: a known settings
    command or it is dropped and the client told. The firmware loader's commands and the
    settings byte that enters it do not pass (devlib/nuphy_io.py guard_write).

What stays possible through it, and is meant to be: reading and changing the keyboard's
settings, as the maker's own site does.

The wire (SOCK_SEQPACKET, one message a datagram, the first byte its kind):
  client: J{"open": "19f5:fee0"}      -> J{"ok": true, "family": …} | J{"error": code, "message": …}
          P<64 bytes>                 a packet for the device (filtered)
  bridge: P<bytes>                    a packet from the device
          J{"refused": reason}        a packet of yours was not passed on
          J{"error": code, …}         the device is gone / stopped; the connection ends
"""
import json
import os
import socket
import struct
import sys
import threading
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from devlib import nuphy_io, usbfs                         # noqa: E402

ALLOW = "/etc/angelos/usb-bridge.json"
SESSIONS = "/run/systemd/sessions"
PACKET_MAX = 64


# ---- who is asking -------------------------------------------------------------------------

def peer_uid(sock):
    pid, uid, gid = struct.unpack("3i", sock.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, struct.calcsize("3i")))
    return uid


def seated_uids(sessions=SESSIONS):
    """The uids with an active, local session on a seat: the people at this computer now."""
    out = set()
    try:
        names = os.listdir(sessions)
    except OSError:
        return out
    for name in names:
        if not name.isdigit():
            continue
        fields = {}
        try:
            with open(os.path.join(sessions, name)) as f:
                for line in f:
                    k, sep, v = line.strip().partition("=")
                    if sep:
                        fields[k] = v
        except OSError:
            continue
        if fields.get("ACTIVE") == "1" and fields.get("REMOTE", "0") == "0" and fields.get("SEAT") and fields.get("CLASS", "user") == "user":
            try:
                out.add(int(fields["UID"]))
            except (KeyError, ValueError):
                pass
    return out


# ---- what may be opened --------------------------------------------------------------------

def load_allow(path=ALLOW):
    """{"vvvv:pppp": {"interface", "in", "out", "family"}} from root's list; a line that is not
    whole is left out."""
    try:
        st = os.stat(path)
        if st.st_uid != 0 or st.st_mode & 0o022:
            return {}                       # not root's alone: not believed
        with open(path) as f:
            data = json.load(f)
    except (OSError, ValueError):
        return {}
    return parse_allow(data)


def parse_allow(data):
    out = {}
    for d in data.get("devices", []) if isinstance(data, dict) else []:
        try:
            vid, pid = "%04x" % int(d["vid"], 16), "%04x" % int(d["pid"], 16)
            entry = {"interface": int(d["interface"]), "in": int(d["in"]), "out": int(d["out"]), "family": str(d["family"])}
        except (KeyError, TypeError, ValueError):
            continue
        if entry["family"] not in FILTERS or not entry["in"] & 0x80 or entry["out"] & 0x80 or not 0 <= entry["interface"] <= 31:
            continue
        out[vid + ":" + pid] = entry
    return out


# ---- what may be said to a device ----------------------------------------------------------

def filter_nuphy_io(packet):
    """None for a packet that may go, else why not."""
    if len(packet) != nuphy_io.PACKET:
        return "a packet is %d bytes" % nuphy_io.PACKET
    if packet[0] != nuphy_io.FLAG_HOST:
        return "not a host packet"
    if nuphy_io.checksum(packet) != packet[3]:
        return "wrong checksum"
    cmd, length, addr = packet[1], packet[4], packet[5] | packet[6] << 8
    if length > nuphy_io.CHUNK:
        return "too long"
    if cmd in nuphy_io.READS:
        return None
    if cmd in nuphy_io.DANGEROUS or cmd in (nuphy_io.CMD["QuickCommStart"], nuphy_io.CMD["QuickCommEnd"]):
        return None                         # the keyboard's own, reversible actions; the shell asks before them
    try:
        nuphy_io.guard_write(cmd, addr, bytes(packet[nuphy_io.DATA:nuphy_io.DATA + length]))
    except nuphy_io.ProtocolError as e:
        return str(e)
    return None


FILTERS = {"nuphy-io": filter_nuphy_io}


# ---- one connection ------------------------------------------------------------------------

def log(text):
    # to the journal: only as the service (started by systemd itself), quiet in the tests
    if os.getppid() == 1:
        print(text, file=sys.stderr, flush=True)


def say(sock, obj):
    try:
        sock.send(b"J" + json.dumps(obj).encode())
    except OSError:
        pass


def open_device(key, entry):
    """The claimed interface of the first connected device of that id."""
    vid, pid = key.split(":")
    last = usbfs.UsbError("gone", "not connected")
    for dev in usbfs.find(vid, pid):
        try:
            return usbfs.Interface(dev["node"], entry["interface"], entry["in"], entry["out"]).open()
        except usbfs.UsbError as e:
            last = e
    raise last


class Keeper:
    """One device of the list, held: its service interface claimed and read all the time,
    whether a client is there or not. The NuPhy Air60 HE's service channel dies within a
    couple of minutes of nobody reading it (the keyboard sends a packet of its own on every
    key, and an endpoint left full answers bus errors until the keyboard is plugged in again),
    so the bridge reads it from the moment it is plugged in. Unplugged, reset by a suspend:
    the keeper takes it again by itself."""

    def __init__(self, key, entry, opener=None):
        self.key, self.entry = key, entry
        self.opener = opener or open_device
        self.channel = None
        self.client = None
        self.bad = 0
        self.deaf = False
        self.why = None                             # the last reason it could not be taken (journal)
        self.dropped = 0
        self.lock = threading.Lock()
        self.stop = threading.Event()
        self.thread = threading.Thread(target=self.run, daemon=True)

    def start(self):
        self.thread.start()
        return self

    def close(self):
        self.stop.set()
        if self.thread.is_alive() and self.thread is not threading.current_thread():
            self.thread.join(timeout=2)
        self._drop()

    def _drop(self):
        ch, self.channel = self.channel, None
        if ch:
            try:
                ch.close()
            except Exception:
                pass

    def run(self):
        while not self.stop.is_set():
            if self.channel is None:
                try:
                    self.channel = self.opener(self.key, self.entry)
                    self.bad, self.deaf = 0, False
                    if self.why is not None:
                        log("%s: taken (was %s)" % (self.key, self.why))
                    else:
                        log("%s: taken" % self.key)
                    self.why = None
                except usbfs.UsbError as e:
                    if e.code != self.why:
                        # said once a change, not every second: "busy" here is usually the kernel's
                        # usbhid on the service interface (the udev rule unbinds it)
                        log("%s: cannot take it: %s (%s)" % (self.key, e.code, e))
                        self.why = e.code
                    self.stop.wait(1.0)             # not plugged in (or busy): look again in a second
                    continue
            try:
                packet = self.channel.read(PACKET_MAX, 500)
            except Exception as e:
                code = getattr(e, "code", "gone")
                if code != "io":
                    # gone: unplugged, or the kernel reset it (a suspend): the client is told
                    # and let go, and the device is taken again when it is back
                    self._drop()
                    log("%s: lost: %s (%s)" % (self.key, code, e))
                    self.why = code
                    self.kick({"error": code, "message": str(e)})
                    self.stop.wait(0.5)
                    continue
                self.bad += 1
                if self.bad == 20:
                    self.deaf = True
                    self.tell({"deaf": True, "errno": getattr(e, "errno", 0)})
                self.stop.wait(0.25 if self.bad >= 20 else 0.005)
                continue
            if self.bad >= 20:
                self.deaf = False
                self.tell({"deaf": False})
            self.bad = 0
            if packet:
                with self.lock:
                    c = self.client
                if c is not None:
                    try:
                        # never wait for a slow client: the keeper must go on reading the USB
                        # side, or the channel dies as if nobody read it
                        c.send(b"P" + packet, socket.MSG_DONTWAIT)
                    except BlockingIOError:
                        self.dropped += 1
                    except OSError:
                        self.detach(c)

    def tell(self, obj):
        with self.lock:
            c = self.client
        if c is not None:
            say(c, obj)

    def kick(self, obj):
        with self.lock:
            c, self.client = self.client, None
        if c is not None:
            say(c, obj)
            try:
                c.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass

    def attach(self, sock, hello=None):
        """None, or why this client cannot have the device now. `hello` is said before the
        first packet can reach the client (the client takes the first message as the answer)."""
        with self.lock:
            if self.channel is None:
                return "gone"
            if self.client is not None:
                return "busy"
            if hello is not None:
                say(sock, hello)
            self.client = sock
        if self.deaf:
            say(sock, {"deaf": True})
        return None

    def detach(self, sock):
        with self.lock:
            if self.client is sock:
                self.client = None

    def write(self, packet):
        ch = self.channel
        if ch is None:
            raise usbfs.UsbError("gone", "not connected")
        ch.write(packet)


def serve(sock, allow, opener=open_device, uids=seated_uids, peer=peer_uid, keepers=None):
    """Talk to one client until it goes. With `keepers` (the service), the device is the
    keeper's, held all the time; without (one connection, the tests), it is opened for this
    client alone. `opener`, `uids` and `peer` are replaced by the tests."""
    try:
        uid = peer(sock)
        # the first message is taken before anything is answered: a door shut on unread words
        # reaches the client as a reset connection, not as the reason
        sock.settimeout(5)
        first = sock.recv(4096)
        sock.settimeout(None)
    except OSError:
        return 1
    if uid not in uids():
        say(sock, {"error": "denied", "message": "only the user at this computer's seat"})
        return 1
    try:
        if first[:1] != b"J":
            raise ValueError
        key = str(json.loads(first[1:])["open"]).lower()
    except (ValueError, KeyError, TypeError):
        say(sock, {"error": "protocol", "message": "expected J{\"open\": \"vvvv:pppp\"}"})
        return 1
    entry = allow.get(key)
    if not entry:
        say(sock, {"error": "unknown", "message": "not a device of the bridge's list"})
        return 1
    own = keepers is None
    if own:
        try:
            channel = opener(key, entry)
        except usbfs.UsbError as e:
            say(sock, {"error": e.code, "message": str(e)})
            return 1
        keeper = Keeper(key, entry, opener=lambda k, e: channel).start()
        for _ in range(100):                # (the keeper takes the channel on its first turn)
            if keeper.channel is not None:
                break
            time.sleep(0.01)
    else:
        keeper = keepers.get(key)
        if keeper is None:
            say(sock, {"error": "unknown", "message": "not a device of the bridge's list"})
            return 1
    why = keeper.attach(sock, {"ok": True, "family": entry["family"]})
    if why:
        say(sock, {"error": why, "message": "the device is not connected" if why == "gone" else "another program has the device now"})
        if own:
            keeper.close()
        return 1
    check = FILTERS[entry["family"]]
    try:
        while True:
            try:
                msg = sock.recv(4096)
            except OSError:
                break
            if not msg:
                break
            if msg[:1] != b"P":
                continue
            packet = msg[1:]
            why = check(packet)
            if why:
                say(sock, {"refused": why})
                continue
            try:
                keeper.write(packet)
            except Exception as e:
                say(sock, {"error": getattr(e, "code", "gone"), "message": str(e)})
                break
    finally:
        keeper.detach(sock)
        if own:
            keeper.close()
    return 0


def main():
    # systemd hands over fd 3: the listening socket (the service, Accept=no) or, from an older
    # socket unit (Accept=yes), one accepted connection
    if os.environ.get("LISTEN_FDS") != "1":
        print("started by angelos-usb-bridge.socket only", file=sys.stderr)
        return 2
    sock = socket.socket(fileno=3)
    if not sock.getsockopt(socket.SOL_SOCKET, socket.SO_ACCEPTCONN):
        try:
            return serve(sock, load_allow())
        finally:
            sock.close()
    allow = load_allow()
    keepers = {key: Keeper(key, entry).start() for key, entry in allow.items()}
    while True:
        try:
            conn, _ = sock.accept()
        except InterruptedError:
            continue
        threading.Thread(target=lambda c=conn: (serve(c, allow, keepers=keepers), c.close()), daemon=True).start()


if __name__ == "__main__":
    sys.exit(main())
