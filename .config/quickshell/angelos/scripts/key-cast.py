#!/usr/bin/env python3
"""The keys you press, for guides and streams (services/KeyCast, Mod+Shift+K): one JSON line per
press on stdout. Keyboards are read through evdev (the input group), read-only and never grabbed.

  {"keys": "Ctrl+Shift+T"}    a shortcut, or a key of its own (Enter, Esc, F5, arrows…)
  {"text": "a"}               a plain character (only with --text; never while secret)
  {"secret": true|false}      a password is being typed now / no longer
  {"tap": "l"|"r"|"b"}        with --taps, every key pressed: only the side of the keyboard (the
                              Halo's bongo cat, a paw down) — never while secret

Passwords never leave this script: while one is typed nothing is printed at all, not even
shortcuts. Secret is
  - the focused widget is a password field (AT-SPI, ROLE_PASSWORD_TEXT: GTK, Qt with
    accessibility, Firefox; best effort — an app without accessibility tells nothing), or
  - the shell says so on stdin ("secret 1" / "secret 0"): its own password fields, the polkit
    dialog, the lock, a focused window that looks like a password prompt (services/KeyCast).

  key-cast.py [--text] [--taps]
  key-cast.py --self-test     the labels and the secret gate, no devices
"""
import json
import os
import sys

MODS = {"KEY_LEFTCTRL": "Ctrl", "KEY_RIGHTCTRL": "Ctrl", "KEY_LEFTSHIFT": "Shift", "KEY_RIGHTSHIFT": "Shift",
        "KEY_LEFTALT": "Alt", "KEY_RIGHTALT": "AltGr", "KEY_LEFTMETA": "Super", "KEY_RIGHTMETA": "Super"}
ORDER = ["Super", "Ctrl", "Alt", "AltGr", "Shift"]
NAMES = {"ENTER": "Enter", "KPENTER": "Enter", "ESC": "Esc", "BACKSPACE": "⌫", "TAB": "Tab", "SPACE": "Space",
         "DELETE": "Del", "INSERT": "Ins", "HOME": "Home", "END": "End", "PAGEUP": "PgUp", "PAGEDOWN": "PgDn",
         "UP": "↑", "DOWN": "↓", "LEFT": "←", "RIGHT": "→", "CAPSLOCK": "Caps", "SYSRQ": "PrtSc", "PRINT": "PrtSc",
         "MINUS": "-", "EQUAL": "=", "LEFTBRACE": "[", "RIGHTBRACE": "]", "SEMICOLON": ";", "APOSTROPHE": "'",
         "GRAVE": "`", "BACKSLASH": "\\", "COMMA": ",", "DOT": ".", "SLASH": "/", "KPPLUS": "+", "KPMINUS": "-",
         "KPASTERISK": "*", "KPSLASH": "/", "KPDOT": "."}
# the right hand's keys (QWERTY place, any layout): the bongo cat's right paw; Space is both
RIGHT = {"6", "7", "8", "9", "0", "MINUS", "EQUAL", "BACKSPACE", "Y", "U", "I", "O", "P", "LEFTBRACE", "RIGHTBRACE",
         "BACKSLASH", "H", "J", "K", "L", "SEMICOLON", "APOSTROPHE", "ENTER", "N", "M", "COMMA", "DOT", "SLASH",
         "UP", "DOWN", "LEFT", "RIGHT", "HOME", "END", "PAGEUP", "PAGEDOWN", "INSERT", "DELETE"}
# keys that are a command by themselves (shown without a modifier); the rest is typing
SPECIAL = {"Enter", "Esc", "⌫", "Tab", "Del", "Ins", "Home", "End", "PgUp", "PgDn", "↑", "↓", "←", "→", "Caps", "PrtSc"}


def label(code):
    """KEY_A → A, KEY_KP7 → 7, KEY_F5 → F5, KEY_ENTER → Enter"""
    n = code[4:] if code.startswith("KEY_") else code
    if n in NAMES:
        return NAMES[n]
    if n.startswith("KP") and n[2:].isdigit():
        return n[2:]
    return n.capitalize() if len(n) > 1 and not (n[0] == "F" and n[1:].isdigit()) else n


class Caster:
    """modifiers held → the line a press makes (None: nothing to say)"""

    def __init__(self, text=False, out=print, taps=False):
        self.text, self.out, self.taps = text, out, taps
        self.held = set()
        self.secret_focus = False      # AT-SPI
        self.secret_shell = False      # the shell (stdin)
        self._said_secret = False

    @property
    def secret(self):
        return self.secret_focus or self.secret_shell

    def _tell_secret(self):
        if self.secret != self._said_secret:
            self._said_secret = self.secret
            self.out(json.dumps({"secret": self.secret}))

    def set_secret(self, focus=None, shell=None):
        if focus is not None:
            self.secret_focus = focus
        if shell is not None:
            self.secret_shell = shell
        self._tell_secret()

    def key(self, code, value):
        """value 1 press, 0 release, 2 repeat (ignored: one press, one line)"""
        if code in MODS:
            (self.held.add if value else self.held.discard)(MODS[code])
            return
        if value != 1 or self.secret:
            return
        if self.taps:
            n = code[4:]
            side = "b" if n == "SPACE" else "r" if n in RIGHT or n.startswith("KP") or (n[:1] == "F" and n[1:].isdigit() and int(n[1:]) > 6) else "l"
            self.out(json.dumps({"tap": side}))
        name = label(code)
        mods = [m for m in ORDER if m in self.held]
        if mods and mods != ["Shift"]:
            self.out(json.dumps({"keys": "+".join(mods + [name])}, ensure_ascii=False))
        elif name in SPECIAL or (name.startswith("F") and name[1:].isdigit()):
            self.out(json.dumps({"keys": "+".join(mods + [name])}, ensure_ascii=False))
        elif self.text:
            # the key's own name, not the layout's letter: evdev knows no layout
            self.out(json.dumps({"text": " " if name == "Space" else name if "Shift" in mods or len(name) > 1 else name.lower()}, ensure_ascii=False))


def self_test():
    lines = []
    c = Caster(text=True, out=lines.append)
    for code, v in [("KEY_LEFTCTRL", 1), ("KEY_LEFTSHIFT", 1), ("KEY_T", 1), ("KEY_T", 0), ("KEY_LEFTSHIFT", 0),
                    ("KEY_LEFTCTRL", 0), ("KEY_A", 1), ("KEY_A", 2), ("KEY_ENTER", 1), ("KEY_F5", 1)]:
        c.key(code, v)
    assert [json.loads(x) for x in lines] == [{"keys": "Ctrl+Shift+T"}, {"text": "a"}, {"keys": "Enter"}, {"keys": "F5"}], lines
    lines.clear()
    c.set_secret(focus=True)
    for code in ("KEY_LEFTMETA", "KEY_P", "KEY_A", "KEY_ENTER"):
        c.key(code, 1)
    assert [json.loads(x) for x in lines] == [{"secret": True}], "nothing at all while a password is typed: " + str(lines)
    c.set_secret(focus=False, shell=True)
    c.key("KEY_B", 1)
    c.set_secret(shell=False)
    c.key("KEY_LEFTMETA", 0)
    c.key("KEY_C", 1)
    assert [json.loads(x) for x in lines] == [{"secret": True}, {"secret": False}, {"text": "c"}], lines
    quiet = Caster(text=False, out=lines.append)
    lines.clear()
    quiet.key("KEY_A", 1)
    quiet.key("KEY_LEFTSHIFT", 1)
    quiet.key("KEY_A", 1)
    assert lines == [], "plain typing is not shown without --text"
    assert label("KEY_KP7") == "7" and label("KEY_SPACE") == "Space" and label("KEY_F12") == "F12"
    drum = Caster(out=lines.append, taps=True)
    lines.clear()
    for code in ("KEY_A", "KEY_J", "KEY_SPACE", "KEY_LEFTSHIFT", "KEY_ENTER"):
        drum.key(code, 1)
    assert [json.loads(x) for x in lines] == [{"tap": "l"}, {"tap": "r"}, {"tap": "b"}, {"tap": "r"}, {"keys": "Shift+Enter"}], lines
    lines.clear()
    drum.set_secret(focus=True)
    drum.key("KEY_A", 1)
    assert [json.loads(x) for x in lines] == [{"secret": True}], "no paw while a password is typed: " + str(lines)
    print("key-cast ok")


def keyboards(evdev):
    out = []
    for path in evdev.list_devices():
        try:
            d = evdev.InputDevice(path)
        except OSError:
            continue
        keys = d.capabilities().get(evdev.ecodes.EV_KEY, [])
        # a keyboard: letters and Enter (mice, power buttons, the virtual copies of key-cast-likes no)
        if evdev.ecodes.KEY_A in keys and evdev.ecodes.KEY_ENTER in keys and "angelos" not in (d.name or "").lower():
            out.append(d)
        else:
            d.close()
    return out


def watch_focus(caster):
    """AT-SPI: is the focused widget a password field? (no a11y bus: nothing, the shell's word stays)"""
    try:
        import gi
        gi.require_version("Atspi", "2.0")
        from gi.repository import Atspi
    except (ImportError, ValueError):
        return
    try:
        Atspi.init()
    except Exception:  # noqa: BLE001 — no accessibility bus
        return

    def on_focus(event):
        if not event.detail1:
            return
        try:
            role = event.source.get_role()
        except Exception:  # noqa: BLE001 — the app went away
            return
        caster.set_secret(focus=role == Atspi.Role.PASSWORD_TEXT)

    listener = Atspi.EventListener.new(on_focus)
    listener.register("object:state-changed:focused")
    watch_focus.listener = listener          # kept alive


def main():
    if "--self-test" in sys.argv:
        return self_test()
    try:
        import evdev
    except ImportError:
        print(json.dumps({"error": "python-evdev is not installed"}), flush=True)
        return 2
    from gi.repository import GLib

    caster = Caster(text="--text" in sys.argv, out=lambda s: print(s, flush=True), taps="--taps" in sys.argv)
    devices = keyboards(evdev)
    if not devices:
        print(json.dumps({"error": "no keyboard readable: is this user in the input group?"}), flush=True)
        return 3
    watch_focus(caster)
    watched = {}                             # path → device
    looking = []                             # a rescan timer runs (a keyboard was lost)

    def watch(d):
        watched[d.path] = d
        GLib.io_add_watch(d.fd, GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, on_device, d)

    def rescan():
        back = False
        for d in keyboards(evdev):
            if d.path in watched:
                d.close()
            else:
                watch(d)
                back = True
        if back:
            looking.clear()
        return not back                      # keep looking until a keyboard is back

    def lost(dev):
        watched.pop(dev.path, None)
        try:
            dev.close()
        except OSError:
            pass
        if not looking:
            looking.append(GLib.timeout_add_seconds(3, rescan))
        return False

    def on_device(fd, cond, dev):
        # unplugged (a wireless keyboard asleep): HUP/ERR forever — an IN-only watch spun a core on it
        if cond & (GLib.IO_HUP | GLib.IO_ERR):
            return lost(dev)
        try:
            for e in dev.read():
                if e.type == evdev.ecodes.EV_KEY:
                    code = evdev.ecodes.KEY.get(e.code)
                    if isinstance(code, list):
                        code = code[0]
                    if code:
                        caster.key(code, e.value)
        except BlockingIOError:
            pass
        except OSError:
            return lost(dev)                 # unplugged
        return True

    for d in devices:
        watch(d)

    def on_stdin(_fd, _cond):
        line = sys.stdin.readline()
        if not line:
            loop.quit()                      # the shell went away
            return False
        parts = line.split()
        if len(parts) == 2 and parts[0] == "secret":
            caster.set_secret(shell=parts[1] == "1")
        return True

    GLib.io_add_watch(sys.stdin.fileno(), GLib.IO_IN | GLib.IO_HUP, on_stdin)
    loop = GLib.MainLoop()
    loop.run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
