#!/usr/bin/env python3
"""A laptop's system bus for the laptop stand: UPower (a battery), power-profiles-daemon and
logind (brightness, inhibitors, sleep), driven by hand. Needs python-dbus and python-gobject.

  fakebus.py <bus address> <fake root from fakesys.py>

Owns org.freedesktop.UPower, org.freedesktop.UPower.PowerProfiles and org.freedesktop.login1 on
that bus (start a private dbus-daemon, see stand.sh) and org.angelos.FakeLaptop, the remote:

  busctl --address=<bus> call org.angelos.FakeLaptop /org/angelos/FakeLaptop \
      org.angelos.FakeLaptop Set s '{"percent": 18, "charging": false}'

keys: percent (0…100), charging (bool: plugged in; full at 100), rate (W), lid ("closed" |
"open": logind's lid and a LidClosed line on stdout), sleep (true: PrepareForSleep(true), a
second later false, as a real suspend), profile. Session.SetBrightness writes
<root>/sys/class/<subsystem>/<name>/brightness, as logind does for the session's owner.
Every call is printed to stdout, one line each ("inhibit handle-lid-switch block", …).
"""
import json
import os
import sys

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

PROPS = "org.freedesktop.DBus.Properties"
UP = "org.freedesktop.UPower"
DEV = "org.freedesktop.UPower.Device"
PP = "org.freedesktop.UPower.PowerProfiles"
LOGIN = "org.freedesktop.login1"


def log(*a):
    print(*a, flush=True)


class Props(dbus.service.Object):
    iface = ""

    def __init__(self, bus, path, props):
        super().__init__(bus, path)
        self.props = props

    @dbus.service.method(PROPS, in_signature="ss", out_signature="v")
    def Get(self, iface, name):
        return self.props[name]

    @dbus.service.method(PROPS, in_signature="s", out_signature="a{sv}")
    def GetAll(self, iface):
        return dbus.Dictionary(self.props, signature="sv") if iface in ("", self.iface) else dbus.Dictionary({}, signature="sv")

    @dbus.service.method(PROPS, in_signature="ssv")
    def Set(self, iface, name, value):
        self.props[name] = value
        self.changed({name: value})

    @dbus.service.signal(PROPS, signature="sa{sv}as")
    def PropertiesChanged(self, iface, changed, invalidated):
        pass

    def changed(self, d):
        self.props.update(d)
        self.PropertiesChanged(self.iface, dbus.Dictionary(d, signature="sv"), dbus.Array([], signature="s"))


class Device(Props):
    iface = DEV

    def __init__(self, bus, path, display):
        super().__init__(bus, path, {
            "NativePath": dbus.String("" if display else "BAT0"),
            "Vendor": dbus.String("SMP"), "Model": dbus.String("5B10W13930"),
            "Type": dbus.UInt32(2), "PowerSupply": dbus.Boolean(True), "Online": dbus.Boolean(False),
            "IsPresent": dbus.Boolean(True), "IsRechargeable": dbus.Boolean(True),
            "Percentage": dbus.Double(72.0), "State": dbus.UInt32(2),
            "Energy": dbus.Double(35.7), "EnergyFull": dbus.Double(49.59), "EnergyFullDesign": dbus.Double(57.0),
            "EnergyEmpty": dbus.Double(0.0), "EnergyRate": dbus.Double(9.4), "Voltage": dbus.Double(11.9),
            "TimeToEmpty": dbus.Int64(13680), "TimeToFull": dbus.Int64(0),
            "Capacity": dbus.Double(87.0), "Technology": dbus.UInt32(2), "WarningLevel": dbus.UInt32(1),
            "BatteryLevel": dbus.UInt32(1), "IconName": dbus.String("battery-good-symbolic"),
            "ChargeCycles": dbus.Int32(312), "UpdateTime": dbus.UInt64(0), "Luminosity": dbus.Double(0),
            "Temperature": dbus.Double(0), "HasHistory": dbus.Boolean(False), "HasStatistics": dbus.Boolean(False),
            "ChargeStartThreshold": dbus.UInt32(0), "ChargeEndThreshold": dbus.UInt32(100),
            "ChargeThresholdEnabled": dbus.Boolean(False), "ChargeThresholdSupported": dbus.Boolean(True),
            "VoltageMinDesign": dbus.Double(0), "VoltageMaxDesign": dbus.Double(0), "CapacityLevel": dbus.String(""),
        })

    @dbus.service.method(DEV)
    def Refresh(self):
        pass


class UPower(Props):
    iface = UP

    def __init__(self, bus, devices):
        super().__init__(bus, "/org/freedesktop/UPower", {
            "DaemonVersion": dbus.String("1.91.5"), "OnBattery": dbus.Boolean(True),
            "LidIsClosed": dbus.Boolean(False), "LidIsPresent": dbus.Boolean(True)})
        self.devices = devices

    @dbus.service.method(UP, out_signature="ao")
    def EnumerateDevices(self):
        return dbus.Array([dbus.ObjectPath("/org/freedesktop/UPower/devices/battery_BAT0")], signature="o")

    @dbus.service.method(UP, out_signature="o")
    def GetDisplayDevice(self):
        return dbus.ObjectPath("/org/freedesktop/UPower/devices/DisplayDevice")

    @dbus.service.method(UP, out_signature="s")
    def GetCriticalAction(self):
        return "PowerOff"

    @dbus.service.signal(UP, signature="o")
    def DeviceAdded(self, path):
        pass

    @dbus.service.signal(UP, signature="o")
    def DeviceRemoved(self, path):
        pass


class Profiles(Props):
    iface = PP

    def __init__(self, bus):
        prof = lambda name: dbus.Dictionary({"Profile": dbus.String(name), "Driver": dbus.String("placeholder")}, signature="sv")
        super().__init__(bus, "/org/freedesktop/UPower/PowerProfiles", {
            "ActiveProfile": dbus.String("balanced"), "PerformanceDegraded": dbus.String(""),
            "Profiles": dbus.Array([prof("power-saver"), prof("balanced"), prof("performance")], signature="a{sv}"),
            "Actions": dbus.Array([], signature="s"), "ActiveProfileHolds": dbus.Array([], signature="a{sv}"),
            "Version": dbus.String("0.30")})

    @dbus.service.method(PROPS, in_signature="ssv")
    def Set(self, iface, name, value):
        log("profile", str(value))
        self.changed({name: value})


class Session(Props):
    iface = LOGIN + ".Session"

    def __init__(self, bus, path, root):
        super().__init__(bus, path, {"Id": dbus.String("1"), "Active": dbus.Boolean(True), "LockedHint": dbus.Boolean(False)})
        self.root = root

    @dbus.service.method(LOGIN + ".Session", in_signature="ssu")
    def SetBrightness(self, subsystem, name, value):
        if subsystem not in ("backlight", "leds") or "/" in name or name.startswith("."):
            raise dbus.exceptions.DBusException("bad device", name="org.freedesktop.DBus.Error.InvalidArgs")
        path = f"{self.root}/sys/class/{subsystem}/{name}/brightness"
        if not os.path.exists(path):
            raise dbus.exceptions.DBusException("no such device", name="org.freedesktop.DBus.Error.InvalidArgs")
        with open(path, "w") as f:
            f.write(f"{int(value)}\n")
        log("brightness", subsystem, name, int(value))

    @dbus.service.method(LOGIN + ".Session", in_signature="b")
    def SetLockedHint(self, locked):
        self.changed({"LockedHint": dbus.Boolean(locked)})

    @dbus.service.signal(LOGIN + ".Session")
    def Lock(self):
        pass

    @dbus.service.signal(LOGIN + ".Session")
    def Unlock(self):
        pass


class Login(Props):
    iface = LOGIN + ".Manager"

    def __init__(self, bus):
        super().__init__(bus, "/org/freedesktop/login1", {"LidClosed": dbus.Boolean(False), "Docked": dbus.Boolean(False),
                                                           "OnExternalPower": dbus.Boolean(False)})
        self.held = []

    @dbus.service.method(LOGIN + ".Manager", in_signature="ssss", out_signature="h")
    def Inhibit(self, what, who, why, mode):
        r, w = os.pipe()
        log("inhibit", what, mode, "by", who)
        self.held.append((what, r))
        # the holder closing its end = released (logind watches the fifo the same way)
        GLib.io_add_watch(r, GLib.IO_HUP | GLib.IO_ERR, self._released, what)
        return dbus.types.UnixFd(w)

    def _released(self, fd, cond, what):
        log("released", what)
        os.close(fd)
        return False

    @dbus.service.method(LOGIN + ".Manager", in_signature="s", out_signature="o")
    def GetSession(self, sid):
        return dbus.ObjectPath("/org/freedesktop/login1/session/auto")

    @dbus.service.method(LOGIN + ".Manager", out_signature="s")
    def CanSuspend(self):
        return "yes"

    @dbus.service.method(LOGIN + ".Manager", out_signature="s")
    def CanHibernate(self):
        return "yes"

    @dbus.service.method(LOGIN + ".Manager", out_signature="s")
    def CanPowerOff(self):
        return "yes"

    @dbus.service.method(LOGIN + ".Manager", in_signature="b")
    def Suspend(self, interactive):
        log("suspend")
        self.sleep()

    @dbus.service.method(LOGIN + ".Manager", in_signature="b")
    def Hibernate(self, interactive):
        log("hibernate")
        self.sleep()

    @dbus.service.method(LOGIN + ".Manager", in_signature="b")
    def PowerOff(self, interactive):
        log("poweroff")

    @dbus.service.signal(LOGIN + ".Manager", signature="b")
    def PrepareForSleep(self, start):
        pass

    def sleep(self):
        self.PrepareForSleep(True)
        GLib.timeout_add(1200, lambda: self.PrepareForSleep(False) and False)


class Remote(dbus.service.Object):
    def __init__(self, bus, world):
        super().__init__(bus, "/org/angelos/FakeLaptop")
        self.w = world

    @dbus.service.method("org.angelos.FakeLaptop", in_signature="s", out_signature="s")
    def Set(self, js):
        self.w.apply(json.loads(js))
        return json.dumps(self.w.state)


class World:
    def __init__(self, bus, root):
        self.state = {"percent": 72.0, "charging": False, "rate": 9.4}
        self.bat = Device(bus, "/org/freedesktop/UPower/devices/battery_BAT0", False)
        self.disp = Device(bus, "/org/freedesktop/UPower/devices/DisplayDevice", True)
        self.up = UPower(bus, [self.bat])
        self.pp = Profiles(bus)
        self.login = Login(bus)
        self.sessions = [Session(bus, "/org/freedesktop/login1/session/" + p, root) for p in ("auto", "self", "_31", "_32", "_33")]
        Remote(bus, self)

    def apply(self, ch):
        s = self.state
        s.update({k: v for k, v in ch.items() if k in ("percent", "charging", "rate")})
        pct, rate = max(0.0, min(100.0, float(s["percent"]))), max(0.5, float(s["rate"]))
        full = 49.59
        if s["charging"]:
            state = 4 if pct >= 100 else 1
            tte, ttf = 0, 0 if pct >= 100 else int((100 - pct) / 100 * full / rate * 3600)
        else:
            state, tte, ttf = 2, int(pct / 100 * full / rate * 3600), 0
        level = 1 if pct > 10 else 3 if pct > 5 else 4
        d = {"Percentage": dbus.Double(pct), "State": dbus.UInt32(state), "Energy": dbus.Double(round(pct / 100 * full, 2)),
             "EnergyRate": dbus.Double(rate), "TimeToEmpty": dbus.Int64(tte), "TimeToFull": dbus.Int64(ttf),
             "WarningLevel": dbus.UInt32(level)}
        self.bat.changed(d)
        self.disp.changed(d)
        if "charging" in ch:
            self.up.changed({"OnBattery": dbus.Boolean(not s["charging"])})
            self.login.changed({"OnExternalPower": dbus.Boolean(bool(s["charging"]))})
        if "lid" in ch:
            closed = ch["lid"] == "closed"
            self.up.changed({"LidIsClosed": dbus.Boolean(closed)})
            self.login.changed({"LidClosed": dbus.Boolean(closed)})
            log("lid", ch["lid"])
        if ch.get("sleep"):
            self.login.sleep()
        if "profile" in ch:
            self.pp.changed({"ActiveProfile": dbus.String(ch["profile"])})
        log("state", json.dumps(s))


def main():
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    DBusGMainLoop(set_as_default=True)
    bus = dbus.bus.BusConnection(sys.argv[1])
    names = [dbus.service.BusName(n, bus) for n in (UP, PP, LOGIN, "org.angelos.FakeLaptop")]
    World(bus, sys.argv[2]).apply({})
    log("ready")
    GLib.MainLoop().run()
    del names


if __name__ == "__main__":
    main()
