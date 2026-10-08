#!/usr/bin/env python3
"""A laptop's /sys and /proc in a folder, for tests and the laptop stand (no laptop needed).

  fakesys.py <dir> [--desktop] [--no-limit] [--convertible]

Builds <dir>/sys and <dir>/proc like a ThinkPad's: BAT0 (charge limit, 312 cycles, 87 %
health), intel_backlight 0…19200, tpacpi::kbd_backlight 0…2, a Synaptics touchpad, the lid,
wlan + bluetooth radios; --convertible adds the tablet-mode switch, a touchscreen and an
accelerometer. Point scripts/laptop.py at it with ANGELOS_SYSFS=<dir>/sys ANGELOS_PROC=<dir>/proc.
"""
import os
import sys


def put(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(str(text) + "\n")


def hexbits(*bits):
    """a capability bitmap the way sysfs prints it: 64-bit hex words, most significant first"""
    value = 0
    for b in bits:
        value |= 1 << b
    words = []
    while True:
        words.append("%x" % (value & (2**64 - 1)))
        value >>= 64
        if not value:
            break
    return " ".join(reversed(words))


def input_dev(sysd, n, name, abs_=(), key=(), sw=(), props=()):
    d = f"{sysd}/class/input/event{n}/device"
    put(d + "/name", name)
    put(d + "/capabilities/abs", hexbits(*abs_) if abs_ else "0")
    put(d + "/capabilities/key", hexbits(*key) if key else "0")
    put(d + "/capabilities/sw", hexbits(*sw) if sw else "0")
    put(d + "/properties", hexbits(*props) if props else "0")


def build(root, desktop=False, limit=True, convertible=False):
    sysd, procd = root + "/sys", root + "/proc"
    put(sysd + "/class/dmi/id/chassis_type", "3" if desktop else ("31" if convertible else "10"))
    os.makedirs(procd, exist_ok=True)
    if desktop:
        input_dev(sysd, 0, "Logitech USB Receiver", key=(0x110, 0x111))
        return
    bat = sysd + "/class/power_supply/BAT0"
    put(bat + "/type", "Battery")
    put(bat + "/scope", "System")
    put(bat + "/cycle_count", 312)
    put(bat + "/energy_full", 49590000)
    put(bat + "/energy_full_design", 57000000)
    put(bat + "/technology", "Li-poly")
    put(bat + "/model_name", "5B10W13930")
    if limit:
        put(bat + "/charge_control_end_threshold", 100)
        put(bat + "/charge_control_start_threshold", 0)
    put(sysd + "/class/power_supply/AC/type", "Mains")
    # a wireless mouse's battery: not the laptop's
    put(sysd + "/class/power_supply/hidpp_battery_0/type", "Battery")
    put(sysd + "/class/power_supply/hidpp_battery_0/scope", "Device")
    bl = sysd + "/class/backlight/intel_backlight"
    put(bl + "/type", "raw")
    put(bl + "/max_brightness", 19200)
    put(bl + "/brightness", 9600)
    put(bl + "/actual_brightness", 9600)
    kb = sysd + "/class/leds/tpacpi::kbd_backlight"
    put(kb + "/max_brightness", 2)
    put(kb + "/brightness", 0)
    input_dev(sysd, 0, "AT Translated Set 2 keyboard", key=(1, 2, 3))
    input_dev(sysd, 1, "SynPS/2 Synaptics TouchPad", abs_=(0, 1, 0x2f, 0x35, 0x36, 0x39),
              key=(0x110, 0x145, 0x14a, 0x14d, 0x14e, 0x14f), props=(0, 2))
    input_dev(sysd, 2, "Lid Switch", sw=(0,))
    put(procd + "/acpi/button/lid/LID/state", "state:      open")
    for i, (kind, name) in enumerate((("wlan", "phy0"), ("bluetooth", "hci0"))):
        r = f"{sysd}/class/rfkill/rfkill{i}"
        put(r + "/type", kind)
        put(r + "/name", name)
        put(r + "/soft", 0)
        put(r + "/hard", 0)
    if convertible:
        input_dev(sysd, 3, "Intel HID switches", sw=(1,))
        input_dev(sysd, 4, "Wacom Pen and multitouch sensor Finger", abs_=(0, 1, 0x2f, 0x35, 0x36, 0x39),
                  key=(0x14a,), props=(1,))
        put(sysd + "/bus/iio/devices/iio:device0/name", "accel_3d")
        put(sysd + "/bus/iio/devices/iio:device0/in_accel_x_raw", 0)


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    build(args[0], "--desktop" in args, "--no-limit" not in args, "--convertible" in args)
