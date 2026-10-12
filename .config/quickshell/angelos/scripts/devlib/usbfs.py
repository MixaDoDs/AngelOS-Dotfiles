"""One interface of a USB device through usbfs, with nothing but the standard library.

Why not hidraw: a keyboard whose service interface the kernel's usbhid must not touch (the
NuPhy Air60 HE resets itself when usbhid polls it: keys stick) has no /dev/hidraw node for it.
The interface is claimed here instead, and only while a driver of this shell needs it.

What this module never does, by design:
  * it never detaches a kernel driver (no USBDEVFS_DISCONNECT / DISCONNECT_CLAIM): an
    interface the kernel drives (the one you type through) answers EBUSY and stays the kernel's;
  * it never resets the device and never sets a configuration (both make the kernel probe
    every interface again, which would hand the service interface back to usbhid);
  * releasing the interface does not bind a driver to it: after close() it is as it was.
"""
import ctypes
import errno
import fcntl
import os
from pathlib import Path

SYSFS = Path(os.environ.get("ANGELOS_SYSFS", "/sys"))
DEVFS = Path(os.environ.get("ANGELOS_DEVFS", "/dev"))

_IOC_NRBITS, _IOC_TYPEBITS, _IOC_SIZEBITS = 8, 8, 14
_IOC_NRSHIFT = 0
_IOC_TYPESHIFT = _IOC_NRSHIFT + _IOC_NRBITS
_IOC_SIZESHIFT = _IOC_TYPESHIFT + _IOC_TYPEBITS
_IOC_DIRSHIFT = _IOC_SIZESHIFT + _IOC_SIZEBITS
_IOC_WRITE, _IOC_READ = 1, 2


def _ioc(direction, nr, size):
    return (direction << _IOC_DIRSHIFT) | (ord("U") << _IOC_TYPESHIFT) | (nr << _IOC_NRSHIFT) | (size << _IOC_SIZESHIFT)


class _CtrlTransfer(ctypes.Structure):
    _fields_ = [("bRequestType", ctypes.c_uint8), ("bRequest", ctypes.c_uint8), ("wValue", ctypes.c_uint16),
                ("wIndex", ctypes.c_uint16), ("wLength", ctypes.c_uint16), ("timeout", ctypes.c_uint32),
                ("data", ctypes.c_void_p)]


class _BulkTransfer(ctypes.Structure):
    _fields_ = [("ep", ctypes.c_uint), ("len", ctypes.c_uint), ("timeout", ctypes.c_uint), ("data", ctypes.c_void_p)]


class _GetDriver(ctypes.Structure):
    _fields_ = [("interface", ctypes.c_uint), ("driver", ctypes.c_char * 256)]


USBDEVFS_CONTROL = _ioc(_IOC_READ | _IOC_WRITE, 0, ctypes.sizeof(_CtrlTransfer))
USBDEVFS_BULK = _ioc(_IOC_READ | _IOC_WRITE, 2, ctypes.sizeof(_BulkTransfer))
USBDEVFS_GETDRIVER = _ioc(_IOC_WRITE, 8, ctypes.sizeof(_GetDriver))
USBDEVFS_CLAIMINTERFACE = _ioc(_IOC_READ, 15, ctypes.sizeof(ctypes.c_uint))
USBDEVFS_RELEASEINTERFACE = _ioc(_IOC_READ, 16, ctypes.sizeof(ctypes.c_uint))
USBDEVFS_CLEAR_HALT = _ioc(_IOC_READ, 21, ctypes.sizeof(ctypes.c_uint))


class UsbError(OSError):
    """code: denied | busy | gone | timeout | io"""

    def __init__(self, code, message, errno_=0):
        super().__init__(message)
        self.code = code
        self.errno = errno_


def _hex4(text):
    return str(text).strip().lower().rjust(4, "0")


def find(vid, pid):
    """Every connected device of that id, read from sysfs alone (nothing is opened):
    [{"sys", "node", "bus", "dev", "name", "serial", "version", "interfaces": {n: driver or ""}}]."""
    vid, pid = _hex4(vid), _hex4(pid)
    out = []
    root = SYSFS / "bus/usb/devices"
    try:
        entries = sorted(root.iterdir())
    except OSError:
        return out
    for d in entries:
        if ":" in d.name:
            continue
        try:
            if _hex4((d / "idVendor").read_text()) != vid or _hex4((d / "idProduct").read_text()) != pid:
                continue
            bus, dev = int((d / "busnum").read_text()), int((d / "devnum").read_text())
        except (OSError, ValueError):
            continue
        interfaces = {}
        for i in sorted(d.glob(d.name + ":*")):
            try:
                n = int((i / "bInterfaceNumber").read_text(), 16)
            except (OSError, ValueError):
                continue
            drv = i / "driver"
            interfaces[n] = os.path.basename(os.readlink(drv)) if drv.is_symlink() else ""

        def text(name):
            try:
                return (d / name).read_text(errors="ignore").strip()
            except OSError:
                return ""
        out.append({"sys": str(d), "node": str(DEVFS / "bus/usb" / ("%03d" % bus) / ("%03d" % dev)), "bus": bus, "dev": dev,
                    "name": (text("manufacturer") + " " + text("product")).strip(), "version": text("bcdDevice"),
                    "interfaces": interfaces})
    return out


def access(node):
    """"ok" | "denied" | "gone": may this user open the node for reading and writing."""
    if not os.path.exists(node):
        return "gone"
    return "ok" if os.access(node, os.R_OK | os.W_OK) else "denied"


class Interface:
    """One claimed interface: interrupt (or bulk) packets in and out."""

    def __init__(self, node, interface, ep_in, ep_out):
        self.node, self.interface, self.ep_in, self.ep_out = node, int(interface), int(ep_in), int(ep_out)
        self.fd = -1

    def open(self):
        try:
            self.fd = os.open(self.node, os.O_RDWR | os.O_CLOEXEC)
        except PermissionError as e:
            raise UsbError("denied", str(e)) from None
        except FileNotFoundError as e:
            raise UsbError("gone", str(e)) from None
        except OSError as e:
            raise UsbError("io", str(e)) from None
        try:
            # the kernel's own driver on it (usbhid): refuse rather than push it off
            drv = _GetDriver(self.interface, b"")
            try:
                fcntl.ioctl(self.fd, USBDEVFS_GETDRIVER, drv)
                name = drv.driver.decode(errors="ignore")
                if name and name != "usbfs":
                    raise UsbError("busy", "interface %d is driven by %s" % (self.interface, name))
            except OSError as e:
                if e.errno != errno.ENODATA:            # ENODATA: no driver, as it should be
                    raise
            fcntl.ioctl(self.fd, USBDEVFS_CLAIMINTERFACE, ctypes.c_uint(self.interface))
        except UsbError:
            self.close()
            raise
        except OSError as e:
            self.close()
            raise UsbError("busy" if e.errno == errno.EBUSY else "gone" if e.errno == errno.ENODEV else "io", str(e)) from None
        return self

    def close(self):
        if self.fd < 0:
            return
        try:
            fcntl.ioctl(self.fd, USBDEVFS_RELEASEINTERFACE, ctypes.c_uint(self.interface))
        except OSError:
            pass
        try:
            os.close(self.fd)
        except OSError:
            pass
        self.fd = -1

    def __enter__(self):
        return self.open()

    def __exit__(self, *exc):
        self.close()

    def _transfer(self, ep, buf, length, timeout_ms):
        t = _BulkTransfer(ep, length, int(timeout_ms), ctypes.cast(buf, ctypes.c_void_p))
        try:
            return fcntl.ioctl(self.fd, USBDEVFS_BULK, t)
        except TimeoutError:
            raise UsbError("timeout", "no answer") from None
        except OSError as e:
            if e.errno == errno.ETIMEDOUT:
                raise UsbError("timeout", "no answer") from None
            if e.errno in (errno.ENODEV, errno.ESHUTDOWN, errno.EBADF):
                raise UsbError("gone", str(e)) from None
            raise UsbError("io", str(e), e.errno) from None

    def read(self, size=64, timeout_ms=100):
        """One packet from the IN endpoint, b"" when nothing came in time. A transfer the bus
        garbled (EPROTO, what makes the kernel's usbhid reset this keyboard) is an "io" error
        for the caller to count and read on: nothing here resets anything. A stalled endpoint
        gets the standard "clear halt" for that endpoint alone."""
        buf = ctypes.create_string_buffer(size)
        try:
            n = self._transfer(self.ep_in, buf, size, timeout_ms)
        except UsbError as e:
            if e.code == "timeout":
                return b""
            if e.errno == errno.EPIPE:
                try:
                    fcntl.ioctl(self.fd, USBDEVFS_CLEAR_HALT, ctypes.c_uint(self.ep_in))
                except OSError:
                    pass
            raise
        return buf.raw[:n]

    def write(self, data, timeout_ms=1000):
        buf = ctypes.create_string_buffer(bytes(data), len(data))
        return self._transfer(self.ep_out, buf, len(data), timeout_ms)

    def hid_report_descriptor(self, size=512):
        """The interface's HID report descriptor (a standard GET_DESCRIPTOR: a read)."""
        buf = ctypes.create_string_buffer(size)
        t = _CtrlTransfer(0x81, 0x06, 0x2200, self.interface, size, 1000, ctypes.cast(buf, ctypes.c_void_p))
        try:
            n = fcntl.ioctl(self.fd, USBDEVFS_CONTROL, t)
        except OSError as e:
            raise UsbError("io", str(e)) from None
        return buf.raw[:n]
