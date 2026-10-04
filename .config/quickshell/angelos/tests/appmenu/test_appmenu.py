#!/usr/bin/env python3
"""scripts/appmenu.py finds the focused app's menu by its pid and the menu works. Offline, on a
private session bus (it re-runs itself under dbus-run-session), with stand-in apps
(tests/appmenu/fake_app.py) that export menus the way each toolkit does.

  python3 tests/appmenu/test_appmenu.py      exit 0 = all good, 77 = skipped (no gi / dbus-run-session)

  registrar    the helper owns com.canonical.AppMenu.Registrar (Qt exports menus only then)
  qt           Qt's /MenuBar/<n>, not the tray icon's /MenuBar; labels without mnemonics,
               hidden items left out, shortcuts as keys, toggles; "clicked" reaches the app
  qt-open      a submenu opening asks AboutToShow and sends "opened"
  qt-two       two windows with menus: the newest, marked ambiguous
  x11          a window registered with RegisterWindow (an X11 app) is found by its sender's pid
  gtk-menubar  a GtkApplication's menubar: sections flattened, accelerators as keys, the
               toggle's state, a dead item (no such action) left out; activation runs the action
  gtk-actions  an empty menubar: the app's actions for the shell's standard menus; app.about runs
  gtk-two      two windows: only app.* actions (win.* would hit an unknown window)
  module       appmenu-gtk-module: the non-empty per-window menubar, "unity." actions, the
               submenu-action set while the submenu shows
  none         a pid with nothing: source "none"
  gone         the app quits: the menu goes with it
"""
import json
import os
import select
import shutil
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
HELPER = HERE.parents[1] / "scripts" / "appmenu.py"
FAKE = HERE / "fake_app.py"

try:
    import gi  # noqa: F401
    from gi.repository import Gio  # noqa: F401
except ImportError:
    print("SKIP: python-gobject (gi) is not installed")
    sys.exit(77)

if not os.environ.get("APPMENU_TEST_BUS"):
    if not shutil.which("dbus-run-session"):
        print("SKIP: dbus-run-session is missing")
        sys.exit(77)
    env = dict(os.environ, APPMENU_TEST_BUS="1")
    sys.exit(subprocess.run(["dbus-run-session", "--", sys.executable, __file__], env=env).returncode)

failures = []


def check(name, ok, detail=""):
    print("  %s %s %s" % ("✓" if ok else "✕", name, detail if not ok else ""))
    if not ok:
        failures.append(name)


class Proc:
    def __init__(self, argv):
        self.p = subprocess.Popen(argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)
        self.lines = []

    def send(self, obj):
        self.p.stdin.write(json.dumps(obj) + "\n")
        self.p.stdin.flush()

    def wait_for(self, pred, timeout=5.0):
        end = time.time() + timeout
        while time.time() < end:
            for line in self.lines:
                if pred(line):
                    self.lines.remove(line)
                    return line
            r, _, _ = select.select([self.p.stdout], [], [], 0.1)
            if r:
                line = self.p.stdout.readline()
                if not line:
                    break
                self.lines.append(line.rstrip("\n"))
        return None

    def stop(self):
        self.p.kill()
        self.p.wait()


def fake(*args):
    f = Proc([sys.executable, str(FAKE)] + list(args))
    if not f.wait_for(lambda l: l == "READY"):
        raise SystemExit("fake app %s did not start: %s" % (args, f.p.stderr.read()))
    return f


helper = Proc([sys.executable, str(HELPER), "serve"])


def menu_for(pid, app="", timeout=5.0):
    helper.send({"cmd": "focus", "pid": pid, "app": app})
    line = helper.wait_for(lambda l: l.startswith("{") and json.loads(l).get("ev") == "menu" and json.loads(l).get("pid") == pid, timeout)
    return json.loads(line) if line else None


def find(items, label):
    for it in items:
        if it.get("label") == label:
            return it
        hit = find(it.get("children", []), label)
        if hit:
            return hit
    return None


def labels(items):
    return [it.get("label", "—") for it in items]


try:
    owned = helper.wait_for(lambda l: '"registrar"' in l)
    check("registrar", owned is not None and json.loads(owned)["owned"], str(owned))

    # ---- Qt ----
    qt = fake("qt")
    m = menu_for(qt.p.pid)
    check("qt", m is not None and m["source"] == "dbusmenu" and labels(m["menus"]) == ["File", "Edit", "Help"]
          and not m["ambiguous"], str(m and (m["source"], labels(m["menus"]))))
    if m:
        f = m["menus"][0]
        check("qt mnemonic", f.get("mnemonic") == "f", str(f.get("mnemonic")))
        check("qt hidden item left out", find(m["menus"], "Hidden") is None)
        check("qt separator kept", [c.get("type") for c in f["children"]] == ["item", "separator", "item"], str(f["children"]))
        check("qt keys", find(m["menus"], "Quit w0")["keys"] == ["ctrl", "q"], str(find(m["menus"], "Quit w0")))
        undo, wrap = find(m["menus"], "Undo"), find(m["menus"], "Word Wrap")
        check("qt disabled", undo and undo["enabled"] is False)
        check("qt toggle", wrap and wrap["toggle"] == "check" and wrap["checked"] is True, str(wrap))
        quit_id = find(m["menus"], "Quit w0")["id"]
        helper.send({"cmd": "activate", "id": quit_id})
        ev = qt.wait_for(lambda l: l.startswith("EVENT w0 clicked"))
        check("qt clicked reaches the app", ev == "EVENT w0 clicked 13", str(ev))
        check("qt tray menu never clicked", qt.wait_for(lambda l: "tray" in l, 0.3) is None)
        helper.send({"cmd": "open", "id": m["menus"][0]["id"]})
        a = qt.wait_for(lambda l: l.startswith("ABOUT w0"))
        o = qt.wait_for(lambda l: l.startswith("EVENT w0 opened"))
        check("qt-open", a == "ABOUT w0 1" and o == "EVENT w0 opened 1", "%s %s" % (a, o))
    qt.stop()
    gone = helper.wait_for(lambda l: '"menu"' in l and json.loads(l)["source"] == "none", 5)
    check("gone", gone is not None, "the menu stayed after the app quit")

    qt2 = fake("qt", "2")
    m = menu_for(qt2.p.pid)
    check("qt-two", m is not None and m["ambiguous"] and m["windows"] == 2 and find(m["menus"], "Quit w1") is not None,
          str(m and (m["ambiguous"], m["windows"], labels(m["menus"][0]["children"]))))
    qt2.stop()

    # ---- an X11 app through the registrar ----
    x11 = fake("x11")
    x11.wait_for(lambda l: l == "REGISTERED")
    m = menu_for(x11.p.pid)
    check("x11", m is not None and m["source"] == "dbusmenu" and find(m["menus"], "Quit x11") is not None, str(m and m["source"]))
    x11.stop()

    # ---- GtkApplication with a menubar ----
    g = fake("gtkapp", "menubar")
    m = menu_for(g.p.pid, "org.example.App")
    check("gtk-menubar", m is not None and m["source"] == "gmenu" and labels(m["menus"]) == ["File", "View"],
          str(m and (m["source"], labels(m["menus"]))))
    if m:
        f = m["menus"][0]["children"]
        check("gtk sections flattened", labels(f) == ["New Window", "New Tab", "—", "Quit"], str(labels(f)))
        check("gtk dead item left out", find(m["menus"], "Dead") is None)
        check("gtk accel as keys", find(m["menus"], "New Tab")["keys"] == ["ctrl", "t"], str(find(m["menus"], "New Tab")))
        side = find(m["menus"], "Sidebar")
        check("gtk toggle state", side and side["toggle"] == "check" and side["checked"], str(side))
        helper.send({"cmd": "activate", "id": find(m["menus"], "Quit")["id"]})
        check("gtk activate", g.wait_for(lambda l: l == "ACTION app.quit") is not None)
        helper.send({"cmd": "activate", "id": find(m["menus"], "New Tab")["id"]})
        check("gtk win action", g.wait_for(lambda l: l == "ACTION win.new-tab") is not None)
    g.stop()

    # ---- GtkApplication without a menubar ----
    g = fake("gtkapp", "empty")
    m = menu_for(g.p.pid, "org.example.App")
    names = sorted(a["id"] for a in (m or {}).get("actions", []))
    check("gtk-actions", m is not None and m["source"] == "actions" and "a:app.about" in names and "a:win.new-tab" in names,
          str(m and (m["source"], names)))
    if m:
        undo = next((a for a in m["actions"] if a["id"] == "a:win.undo"), None)
        check("gtk-actions disabled", undo and undo["enabled"] is False, str(undo))
        helper.send({"cmd": "activate", "id": "a:app.about"})
        check("gtk-actions activate", g.wait_for(lambda l: l == "ACTION app.about") is not None)
    g.stop()

    g = fake("gtkapp", "empty", "2")
    m = menu_for(g.p.pid, "org.example.App")
    names = sorted(a["id"] for a in (m or {}).get("actions", []))
    check("gtk-two", m is not None and m["ambiguous"] and "a:app.quit" in names and not any(n.startswith("a:win.") for n in names),
          str(m and (m["ambiguous"], names)))
    g.stop()

    # ---- appmenu-gtk-module ----
    mod = fake("module")
    m = menu_for(mod.p.pid, "audacity")
    check("module", m is not None and m["source"] == "gmenu" and labels(m["menus"]) == ["File"]
          and labels(m["menus"][0]["children"]) == ["New", "Quit"], str(m and (m["source"], m["menus"])))
    if m:
        helper.send({"cmd": "open", "id": m["menus"][0]["id"]})
        check("module submenu-action on", mod.wait_for(lambda l: l == "STATE unity.-File True") is not None)
        helper.send({"cmd": "closed", "id": m["menus"][0]["id"]})
        check("module submenu-action off", mod.wait_for(lambda l: l == "STATE unity.-File False") is not None)
        helper.send({"cmd": "activate", "id": find(m["menus"], "New")["id"]})
        check("module activate", mod.wait_for(lambda l: l == "ACTION unity.-New") is not None)
    mod.stop()

    # ---- nothing ----
    plain = subprocess.Popen(["sleep", "30"])
    m = menu_for(plain.pid)
    check("none", m is not None and m["source"] == "none" and m["menus"] == [], str(m))
    plain.kill()
finally:
    helper.stop()

err = helper.p.stderr.read()
if "Traceback" in err:
    check("no tracebacks", False, err[-800:])
if failures:
    print("» appmenu tests FAILED: " + ", ".join(failures))
    sys.exit(1)
print("» appmenu tests passed")
