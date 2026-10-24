#!/usr/bin/env python3
"""Report Caps Lock going on and off, for the bar's mark (services/CapsLock).

Prints "on" / "off" once at the start and on every change. niri tells nobody
about lock keys, so this listens to the keyboards' own Caps Lock LED: the
kernel sends an EV_LED event the moment the compositor switches it (needs the
`input` group). Without python-evdev or without access it falls back to
looking at /sys/class/leds a few times a second.

Caps Lock remapped to Escape / Ctrl / layout switch never lights the LED, so
nothing is reported for it.

Privacy: only LED events are looked at; key events are dropped unread, nothing
is stored or logged. Devices are opened read-only and never grabbed.
"""
import glob
import selectors
import sys
import time

try:
    import evdev
    from evdev import ecodes
except ImportError:
    evdev = None

SYSFS = "/sys/class/leds/*::capslock/brightness"


def say(word):
    print(word, flush=True)


class State:
    """Caps Lock over several keyboards: on while any of them shows it."""

    def __init__(self):
        self.leds = {}      # device path -> its LED is lit
        self.last = None    # what was last reported

    def set(self, path, lit):
        self.leds[path] = bool(lit)
        return self.changed()

    def drop(self, path):
        self.leds.pop(path, None)
        return self.changed()

    def changed(self):
        """"on" / "off" when the answer differs from the last one given, else None."""
        now = any(self.leds.values())
        if now == self.last:
            return None
        self.last = now
        return "on" if now else "off"


def sysfs_lit():
    lit = False
    for led in glob.glob(SYSFS):
        try:
            lit = lit or int(open(led).read().strip() or 0) > 0
        except (OSError, ValueError):
            pass
    return lit


def poll(state):
    while True:
        word = state.set("sysfs", sysfs_lit())
        if word:
            say(word)
        time.sleep(0.25)


def listen(state):
    selector = selectors.DefaultSelector()
    devices = {}
    last_scan = 0.0

    def drop(path):
        device = devices.pop(path, None)
        if device is None:
            return
        try:
            selector.unregister(device)
        except (KeyError, ValueError):
            pass
        try:
            device.close()
        except OSError:
            pass
        word = state.drop(path)
        if word:
            say(word)

    def rescan():
        seen = set()
        blocked = 0
        for path in evdev.list_devices():
            seen.add(path)
            if path in devices:
                continue
            try:
                device = evdev.InputDevice(path)
            except PermissionError:
                blocked += 1
                continue
            except OSError:
                continue
            try:
                has_led = ecodes.LED_CAPSL in device.capabilities().get(ecodes.EV_LED, [])
                lit = has_led and ecodes.LED_CAPSL in device.leds()
            except OSError:
                has_led = False
            if not has_led:
                device.close()
                continue
            devices[path] = device
            selector.register(device, selectors.EVENT_READ)
            word = state.set(path, lit)
            if word:
                say(word)
        for path in list(devices):
            if path not in seen:
                drop(path)
        return blocked and not devices

    while True:
        now = time.monotonic()
        if now - last_scan > 3:
            if rescan():
                return False    # no access to any keyboard: the caller polls instead
            last_scan = now
            if state.last is None:
                say(state.changed() or "off")
        for key, _ in selector.select(timeout=3.0):
            device = key.fileobj
            try:
                events = list(device.read())
            except OSError:
                drop(device.path)
                continue
            for event in events:
                if event.type == ecodes.EV_LED and event.code == ecodes.LED_CAPSL:
                    word = state.set(device.path, event.value)
                    if word:
                        say(word)


def main():
    state = State()
    if evdev is not None:
        listen(state)
    poll(state)


if __name__ == "__main__":
    try:  # go away together with the shell, even on its SIGKILL (stand restarts left copies behind)
        import ctypes
        import signal
        ctypes.CDLL(None).prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG
    except (OSError, AttributeError):
        pass
    try:
        main()
    except KeyboardInterrupt:
        pass
