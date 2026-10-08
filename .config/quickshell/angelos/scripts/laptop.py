#!/usr/bin/env python3
"""What laptop hardware this machine has, and the few writes it needs (services/Laptop).

  laptop.py probe                 -> JSON: chassis, batteries, backlights, keyboard light,
                                     touchpad / touchscreen, lid and tablet switches,
                                     accelerometer, fingerprint tools, rfkill, hibernate
  laptop.py battery               -> JSON: the batteries' sysfs extras UPower doesn't carry
                                     (cycle count, the charge limit and whether it can be set)
  laptop.py limit <value>         -> set the charge limit (50…100, 100 = off) on every battery
                                     that has one: directly when sysfs lets us, else through
                                     the angelOS helper (extras/charge-limit, pkexec without a
                                     password for the active session). Prints "ok <value>",
                                     "nohelper" or "error <why>"
  laptop.py rfkill [on|off]       -> JSON {airplane, devices}; on/off blocks or unblocks all
                                     radios (the user is in the rfkill group / uaccess)
  laptop.py fprint                -> JSON {reader, enrolled}: fprintd's view (may take a second)

ANGELOS_SYSFS / ANGELOS_PROC point at a fake /sys and /proc (tests, the laptop stand).
Nothing here needs root; nothing is printed about the machine but the keys above.
"""
import glob
import json
import os
import shutil
import subprocess
import sys

SYS = os.environ.get("ANGELOS_SYSFS", "/sys").rstrip("/") or "/"
PROC = os.environ.get("ANGELOS_PROC", "/proc").rstrip("/") or "/"
HELPER = os.environ.get("ANGELOS_CHARGE_HELPER", "/usr/local/libexec/angelos-charge-limit")

# SMBIOS chassis types that are carried around (7.4.1 of the spec)
PORTABLE = {"8": "portable", "9": "laptop", "10": "notebook", "11": "handheld", "14": "subnotebook",
            "30": "tablet", "31": "convertible", "32": "detachable"}
# input capability bits (linux/input-event-codes.h)
ABS_MT_POSITION_X = 0x35
BTN_TOOL_FINGER = 0x145
BTN_TOUCH = 0x14a
SW_LID, SW_TABLET_MODE = 0, 1
PROP_POINTER, PROP_DIRECT = 0, 1


def read(path, default=""):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return default


def num(path, default=None):
    try:
        return int(read(path))
    except ValueError:
        return default


def bits(path):
    """a sysfs capability bitmap (space-separated hex words, most significant first)"""
    value = 0
    for word in read(path).split():
        try:
            value = (value << 64) | int(word, 16)
        except ValueError:
            return 0
    return value


def has(bitmap, bit):
    return bool(bitmap >> bit & 1)


def writable(path):
    return os.path.exists(path) and os.access(path, os.W_OK)


def batteries():
    out = []
    for d in sorted(glob.glob(SYS + "/class/power_supply/*")):
        if read(d + "/type") != "Battery" or read(d + "/scope") == "Device":
            continue                       # a mouse's or a headset's battery is no laptop's
        end = d + "/charge_control_end_threshold"
        start = d + "/charge_control_start_threshold"
        full, design = num(d + "/energy_full") or num(d + "/charge_full"), num(d + "/energy_full_design") or num(d + "/charge_full_design")
        out.append({
            "name": os.path.basename(d),
            "cycles": num(d + "/cycle_count"),
            "health": round(100 * full / design) if full and design else None,
            "limit": num(end) if os.path.exists(end) else None,
            "limitStart": num(start) if os.path.exists(start) else None,
            "limitWritable": writable(end),
            "technology": read(d + "/technology"),
            "model": read(d + "/model_name"),
        })
    return out


def backlights():
    # the one to move first: firmware > platform > raw, as systemd and GNOME pick it
    rank = {"firmware": 0, "platform": 1, "raw": 2}
    out = []
    for d in glob.glob(SYS + "/class/backlight/*"):
        mx = num(d + "/max_brightness", 0)
        if mx <= 0:
            continue
        out.append({"name": os.path.basename(d), "type": read(d + "/type", "raw"), "max": mx,
                    "value": num(d + "/brightness", mx)})
    return sorted(out, key=lambda b: (rank.get(b["type"], 3), b["name"]))


def kbd_lights():
    out = []
    for d in sorted(glob.glob(SYS + "/class/leds/*kbd_backlight*")):
        mx = num(d + "/max_brightness", 0)
        if mx > 0:
            out.append({"name": os.path.basename(d), "max": mx, "value": num(d + "/brightness", 0)})
    return out


def inputs():
    """touchpads, touchscreens, the lid and the tablet-mode switch, from /sys/class/input"""
    found = {"touchpad": [], "touchscreen": [], "lid": False, "tabletSwitch": False}
    for d in sorted(glob.glob(SYS + "/class/input/event*")):
        caps = d + "/device/capabilities/"
        name = read(d + "/device/name")
        sw = bits(caps + "sw")
        if has(sw, SW_LID):
            found["lid"] = True
        if has(sw, SW_TABLET_MODE):
            found["tabletSwitch"] = True
        if not has(bits(caps + "abs"), ABS_MT_POSITION_X):
            continue
        props = bits(d + "/device/properties")
        key = bits(caps + "key")
        if has(props, PROP_DIRECT):
            found["touchscreen"].append(name)
        elif has(key, BTN_TOOL_FINGER) and (has(props, PROP_POINTER) or has(key, BTN_TOUCH)):
            found["touchpad"].append(name)
    if not found["lid"]:
        found["lid"] = bool(glob.glob(PROC + "/acpi/button/lid/*/state"))
    return found


def accelerometer():
    for d in glob.glob(SYS + "/bus/iio/devices/iio:device*"):
        if os.path.exists(d + "/in_accel_x_raw") or "accel" in read(d + "/name"):
            return True
    return False


def rfkill():
    devs = []
    for d in sorted(glob.glob(SYS + "/class/rfkill/rfkill*")):
        devs.append({"type": read(d + "/type"), "soft": read(d + "/soft") == "1", "hard": read(d + "/hard") == "1"})
    radios = [x for x in devs if x["type"] in ("wlan", "bluetooth", "wwan")]
    return {"airplane": bool(radios) and all(x["soft"] or x["hard"] for x in radios), "devices": devs}


def can(what):
    """logind's CanHibernate / CanSuspend: "yes" | "na" | "no" | "challenge" """
    try:
        p = subprocess.run(["busctl", "call", "--system", "org.freedesktop.login1", "/org/freedesktop/login1",
                            "org.freedesktop.login1.Manager", "Can" + what], capture_output=True, text=True, timeout=3)
        return p.stdout.split('"')[1] if p.returncode == 0 and '"' in p.stdout else "no"
    except (OSError, subprocess.TimeoutExpired):
        return "no"


def chassis():
    t = read(SYS + "/class/dmi/id/chassis_type")
    return PORTABLE.get(t, "desktop" if t else "unknown")


def probe():
    inp = inputs()
    bats = batteries()
    kind = chassis()
    return {
        "chassis": kind,
        # a laptop: a portable case, or a battery that powers the machine (no DMI in a VM)
        "laptop": kind in PORTABLE.values() or bool(bats),
        "batteries": bats,
        "backlights": backlights(),
        "kbd": kbd_lights(),
        "touchpad": inp["touchpad"],
        "touchscreen": inp["touchscreen"],
        "lid": inp["lid"],
        "tabletSwitch": inp["tabletSwitch"],
        "accel": accelerometer(),
        "rotateTool": bool(shutil.which("monitor-sensor")),
        "fprintTool": bool(shutil.which("fprintd-list")),
        "osk": next((t for t in ("wvkbd-mobintl", "squeekboard") if shutil.which(t)), ""),
        "mirrorTool": bool(shutil.which("wl-mirror")),
        "rfkill": rfkill(),
        "hibernate": can("Hibernate") == "yes",
        "chargeHelper": os.access(HELPER, os.X_OK),
    }


def set_limit(value):
    value = max(50, min(100, int(value)))
    bats = [b for b in batteries() if b["limit"] is not None]
    if not bats:
        return "error no charge limit on this battery"
    need_helper = False
    for b in bats:
        path = f"{SYS}/class/power_supply/{b['name']}/charge_control_end_threshold"
        try:
            with open(path, "w") as f:
                f.write(str(value))
        except PermissionError:
            need_helper = True
        except OSError as e:
            return "error " + (e.strerror or str(e))
    if need_helper:
        if not os.access(HELPER, os.X_OK):
            return "nohelper"
        p = subprocess.run(["pkexec", HELPER, str(value)], capture_output=True, text=True)
        if p.returncode:
            return "error " + (p.stderr.strip().splitlines() or ["pkexec " + str(p.returncode)])[-1]
    return f"ok {value}"


def set_airplane(on):
    tool = shutil.which("rfkill")
    if not tool:
        return
    subprocess.run([tool, "block" if on else "unblock", "all"], capture_output=True)


def fprint():
    user = os.environ.get("USER") or ""
    if not shutil.which("fprintd-list"):
        return {"reader": False, "enrolled": 0}
    try:
        p = subprocess.run(["fprintd-list", user], capture_output=True, text=True, timeout=8)
    except subprocess.TimeoutExpired:
        return {"reader": False, "enrolled": 0}
    text = p.stdout + p.stderr
    reader = "No devices available" not in text and p.returncode == 0
    # "Fingerprints for user x on Device (press):" then " - #0: right-index-finger"
    enrolled = sum(1 for line in text.splitlines() if line.strip().startswith("- #"))
    return {"reader": reader, "enrolled": enrolled}


def main(argv):
    cmd = argv[1] if len(argv) > 1 else "probe"
    if cmd == "probe":
        print(json.dumps(probe()))
    elif cmd == "battery":
        print(json.dumps(batteries()))
    elif cmd == "limit" and len(argv) > 2:
        print(set_limit(argv[2]))
    elif cmd == "rfkill":
        if len(argv) > 2:
            set_airplane(argv[2] == "on")
        print(json.dumps(rfkill()))
    elif cmd == "fprint":
        print(json.dumps(fprint()))
    else:
        print(__doc__, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
