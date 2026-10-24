#!/usr/bin/env python3
"""Report a lone tap of the Meta (Super) key, like the Windows Start key.

Prints "tap" when Meta is pressed and released within --max-ms with no other
key, mouse button or wheel in between; holding Meta or using it as a modifier
(Mod+Space, Mod+drag, …) never triggers. niri has no binds for a bare modifier,
so this reads evdev devices directly (needs the `input` group).

Privacy: no key codes are stored, logged or printed; the only state kept is
"Meta is down" and "something else happened while it was down". Devices are
opened read-only and never grabbed.
"""
import argparse
import os
import selectors
import sys
import time

try:
    import evdev
    from evdev import ecodes
except ImportError:
    print("noevdev", flush=True)
    sys.exit(2)

META = {ecodes.KEY_LEFTMETA, ecodes.KEY_RIGHTMETA}


def say(word):
    print(word, flush=True)


def is_candidate(device):
    caps = device.capabilities().get(ecodes.EV_KEY, [])
    # keyboards (to see Meta and other keys) and pointers (a click cancels a tap)
    return bool(META & set(caps)) or ecodes.BTN_LEFT in caps


class Detector:
    """Lone Meta tap state machine; knows nothing about which keys are pressed."""

    def __init__(self, limit):
        self.limit = limit
        self.down_at = None     # monotonic time Meta went down
        self.spoiled = False    # anything else happened while Meta was down

    def meta_down(self, now, combo):
        if self.down_at is None:
            self.down_at = now
            self.spoiled = combo
        else:
            self.spoiled = self.spoiled or combo

    def other(self):
        if self.down_at is not None:
            self.spoiled = True

    def meta_up(self, now):
        if self.down_at is None:
            return False
        tap = not self.spoiled and now - self.down_at <= self.limit
        self.down_at = None
        return tap


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--max-ms", type=int, default=400)
    args = parser.parse_args()
    detector = Detector(max(100, min(2000, args.max_ms)) / 1000)

    selector = selectors.DefaultSelector()
    devices = {}
    denied = False
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

    def rescan():
        nonlocal denied
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
            if not is_candidate(device):
                device.close()
                continue
            devices[path] = device
            selector.register(device, selectors.EVENT_READ)
        for path in list(devices):
            if path not in seen:
                drop(path)
        if blocked and not devices and not denied:
            denied = True
            say("noperm")

    say("ready")
    while True:
        now = time.monotonic()
        if now - last_scan > 3:
            rescan()
            last_scan = now
        for key, _ in selector.select(timeout=1.0):
            device = key.fileobj
            try:
                events = list(device.read())
            except OSError:
                drop(device.path)
                continue
            for event in events:
                if event.type == ecodes.EV_KEY and event.code in META:
                    if event.value == 1:
                        # Ctrl/Shift/… already held: a combo, not a tap
                        try:
                            combo = bool(set(device.active_keys()) - META)
                        except OSError:
                            combo = False
                        detector.meta_down(time.monotonic(), combo)
                    elif event.value == 0 and detector.meta_up(time.monotonic()):
                        say("tap")
                elif event.type == ecodes.EV_KEY and event.value == 1:
                    detector.other()
                elif event.type == ecodes.EV_REL and event.code in (ecodes.REL_WHEEL, ecodes.REL_HWHEEL):
                    detector.other()


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
