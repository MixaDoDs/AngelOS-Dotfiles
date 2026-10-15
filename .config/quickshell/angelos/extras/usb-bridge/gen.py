#!/usr/bin/python3 -I
"""What install.sh puts into the system for the USB bridge, worked out from the device
descriptions angelOS ships (data/devices): the bridge's list of devices and the udev rule.
Only the shipped descriptions count: a file in a user's own folder never widens what root
installs.   gen.py DATA_DIR allow | rule | ifaces"""
import json
import sys
from pathlib import Path


def devices(data_dir):
    out = []
    for f in sorted(Path(data_dir).glob("*/*.json")):
        try:
            d = json.loads(f.read_text())
            ch = d["channel"]
            if ch.get("via") != "usbfs":
                continue
            iface, ep_in, ep_out = int(ch["interface"]), int(str(ch["in"]), 0), int(str(ch["out"]), 0)
            for u in d["usb"]:
                vid, pid = "%04x" % int(u["vid"], 16), "%04x" % int(u["pid"], 16)
                out.append({"vid": vid, "pid": pid, "interface": iface, "in": ep_in, "out": ep_out,
                            "family": str(d["family"]), "name": " ".join(str(d.get("name", "")).split())[:60]})
        except (OSError, ValueError, KeyError, TypeError):
            continue
    seen, uniq = set(), []
    for d in out:
        if (d["vid"], d["pid"]) not in seen:
            seen.add((d["vid"], d["pid"]))
            uniq.append(d)
    return uniq


def allow(devs):
    return json.dumps({"devices": [{k: d[k] for k in ("vid", "pid", "interface", "in", "out", "family")} for d in devs]}, indent=1) + "\n"


def rule(devs):
    lines = [
        "# angelOS: the USB bridge (extras/usb-bridge; docs/devices.md, «Доступ»). Written by its",
        "# install.sh from the device descriptions angelOS ships; do not edit, an update writes it again.",
        "#",
        "# For each device below:",
        "#   - its USB node goes to the group angelos-usb, whose only member is the bridge's own system",
        "#     user. No person and no program of a person gets the node: they get the bridge, which",
        "#     hands out one service interface and filters what is sent to it;",
        "#   - the kernel's usbhid is kept off that service interface (the keyboard resets itself when",
        "#     usbhid polls it, and keys stick). The interfaces you type through are not touched.",
    ]
    for d in devs:
        safe = "".join(c for c in d["name"] if c.isalnum() or c in " -_.")
        lines.append("")
        lines.append("# %s:%s %s, service interface %d" % (d["vid"], d["pid"], safe, d["interface"]))
        lines.append('ACTION!="remove", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="%s", ATTR{idProduct}=="%s", GROUP="angelos-usb"' % (d["vid"], d["pid"]))
        # "add" too: at boot the initramfs binds usbhid before these rules exist, and the
        # coldplug that replays the events afterwards sends "add", never "bind"
        lines.append('ACTION=="add|bind", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_interface", DRIVER=="usbhid", ATTRS{idVendor}=="%s", ATTRS{idProduct}=="%s", ATTR{bInterfaceNumber}=="%02x", RUN+="/bin/sh -c \'echo -n %%k > /sys/bus/usb/drivers/usbhid/unbind\'"' % (d["vid"], d["pid"], d["interface"]))
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    devs = devices(sys.argv[1])
    if sys.argv[2] == "ifaces":
        # "vid pid interface" a line: what install.sh frees from usbhid right away
        sys.stdout.write("".join("%s %s %02x\n" % (d["vid"], d["pid"], d["interface"]) for d in devs))
    else:
        sys.stdout.write(allow(devs) if sys.argv[2] == "allow" else rule(devs))
