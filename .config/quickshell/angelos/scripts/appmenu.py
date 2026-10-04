#!/usr/bin/env python3
"""The Golden Gate skin's global menu: the menus of the focused window's app, over D-Bus.

usage: appmenu.py serve [--no-registrar]   the shell's helper (services/AppMenu.qml), JSON lines
       appmenu.py dump [PID…]               what it finds for the open niri windows (or these PIDs)

Wayland has no common way to put an app's menus into a panel, and niri ties no menu to a
window. What apps do offer, checked on CachyOS 2026-10 (docs/GLOBAL-MENU.md):

  Qt 5/6        exports its QMenuBar as com.canonical.dbusmenu at /MenuBar/<n> when the
                AppMenu registrar is on the bus as it starts (QGenericUnixTheme, qt6ct) and
                hides the in-window bar. On Wayland it does not call RegisterWindow (no window
                id), so the menu is found on the app's own bus connections, by its pid.
  GTK 3         with appmenu-gtk-module (gtk-modules in settings.ini): every GtkMenuBar as a
                GMenuModel (org.gtk.Menus) at /org/appmenu/gtk/window/menus/menubar/<n>, its
                actions (org.gtk.Actions, "unity.") on the same object.
  GtkApplication (GTK 3 and 4): a menubar set with gtk_application_set_menubar at
                <app path>/menus/menubar, and always the actions: "app." at <app path>,
                "win." at <app path>/window/<n> — about, preferences, quit, new-window, …
                The shell makes standard menus out of those (services/AppMenu.qml).
  Electron, Chromium, Firefox, kitty, Alacritty, Steam: nothing on Wayland.

The registrar (com.canonical.AppMenu.Registrar) is owned while this runs, so apps started now
export their menus; apps that registered a window (X11 apps through XWayland) are found by it.
An app started while it runs keeps its menu outside even after it stops — until restarted.

Protocol. stdin, one JSON object a line:
  {"cmd": "focus", "pid": 123, "app": "org.gnome.Nautilus"}   the focused window (pid 0: none)
  {"cmd": "open", "id": "d:12"}      a submenu opens (dbusmenu AboutToShow, may refresh it)
  {"cmd": "closed", "id": "d:12"}    it closed again
  {"cmd": "activate", "id": "d:7"}   an item was chosen ("g:…" a GMenu item, "a:app.quit" an action)
  {"cmd": "refresh"}                 look again (an app that just started)
stdout, one JSON object a line:
  {"ev": "registrar", "owned": true}
  {"ev": "menu", "pid": 123, "app": "…", "source": "dbusmenu"|"gmenu"|"actions"|"none",
   "ambiguous": false, "windows": 1, "menus": [item…], "actions": [action…]}
     item: {"id", "label", "mnemonic", "enabled", "type": "item"|"separator"|"submenu",
            "toggle": ""|"check"|"radio", "checked", "keys": ["ctrl","shift","t"], "icon",
            "children": [item…]}
     action (source "actions"): {"id": "a:app.about", "scope": "app"|"win", "name", "enabled",
            "state": bool|str|null}
     ambiguous: the app has several windows with menus and which one is focused is unknown;
            the shell then uses an item's shortcut (it reaches the focused window) and leaves
            out what has none.
"""
import json
import os
import subprocess
import sys
import time
import warnings
import xml.etree.ElementTree as ET

try:
    from gi.repository import Gio, GLib
except ImportError:  # python-gobject is in packages/pacman.txt; say so instead of a traceback
    print(json.dumps({"ev": "error", "error": "python-gobject (gi) is missing"}), flush=True)
    sys.exit(2)

warnings.simplefilter("ignore", DeprecationWarning)   # register_object: the closure API is not in every PyGObject

REGISTRAR = "com.canonical.AppMenu.Registrar"
REGISTRAR_PATH = "/com/canonical/AppMenu/Registrar"
REGISTRAR_XML = """<node><interface name="com.canonical.AppMenu.Registrar">
<method name="RegisterWindow"><arg type="u" direction="in"/><arg type="o" direction="in"/></method>
<method name="UnregisterWindow"><arg type="u" direction="in"/></method>
<method name="GetMenuForWindow"><arg type="u" direction="in"/><arg type="s" direction="out"/><arg type="o" direction="out"/></method>
<method name="GetMenus"><arg type="a(uso)" direction="out"/></method>
<signal name="WindowRegistered"><arg type="u"/><arg type="s"/><arg type="o"/></signal>
<signal name="WindowUnregistered"><arg type="u"/></signal>
</interface></node>"""
DBUSMENU = "com.canonical.dbusmenu"
GMENUS = "org.gtk.Menus"
GACTIONS = "org.gtk.Actions"
SNI = "org.kde.StatusNotifierItem"
TIMEOUT = 700            # ms per D-Bus call: a hung app must not hang the menu bar
WALK_NODES = 240         # objects looked at per connection
WALK_DEPTH = 8           # /org/appmenu/gtk/window/menus/menubar/<n> is 7 deep
CACHE_SECONDS = 20
# subtrees with nothing menu-like in them (portals, a11y, GVfs, Chromium's own)
SKIP = ("/org/freedesktop/portal", "/org/a11y", "/org/gtk/vfs", "/org/gtk/Profiler", "/org/freedesktop/FileManager1",
        "/org/mpris", "/org/freedesktop/Notifications", "/org/chromium", "/org/mozilla")

# key names in dbusmenu shortcuts and GTK accelerators → wtype names (services/AppMenu.qml shows them)
MODS = {"control": "ctrl", "ctrl": "ctrl", "primary": "ctrl", "shift": "shift", "alt": "alt", "mod1": "alt",
        "super": "logo", "meta": "logo", "mod4": "logo", "hyper": "logo"}


def log(*a):
    print(*a, file=sys.stderr, flush=True)


def emit(obj):
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def unpack(v):
    return v.unpack() if isinstance(v, GLib.Variant) else v


def strip_mnemonic(label):
    """"_File" → ("File", "f"); "__" is a literal underscore."""
    out, mn, i = "", "", 0
    label = label or ""
    while i < len(label):
        c = label[i]
        if c == "_" and i + 1 < len(label):
            if label[i + 1] == "_":
                out += "_"
            else:
                mn = mn or label[i + 1].lower()
                out += label[i + 1]
            i += 2
            continue
        out += c
        i += 1
    return out, mn


def keys_from_dbusmenu(shortcut):
    """[["Control", "Shift", "T"]] → ["ctrl", "shift", "t"] (the first chord only)."""
    if not shortcut:
        return []
    chord = list(shortcut[0]) if isinstance(shortcut[0], (list, tuple)) else list(shortcut)
    out = []
    for k in chord:
        m = MODS.get(str(k).lower())
        out.append(m if m else norm_key(str(k)))
    return out


def keys_from_accel(accel):
    """"<Primary><Shift>t" → ["ctrl", "shift", "t"]."""
    if not accel:
        return []
    out, rest = [], accel
    while rest.startswith("<"):
        end = rest.find(">")
        if end < 0:
            break
        m = MODS.get(rest[1:end].lower())
        if m and m not in out:
            out.append(m)
        rest = rest[end + 1:]
    return out + [norm_key(rest)] if rest else []


def norm_key(k):
    """Single letters lower case (wtype sends the keysym, the layout does not matter)."""
    return k.lower() if len(k) == 1 else {"Return": "Return", "Enter": "Return", "Del": "Delete", "Esc": "Escape",
                                          "PgUp": "Prior", "PgDown": "Next", "+": "plus", "-": "minus"}.get(k, k)


class Bus:
    def __init__(self, conn):
        self.conn = conn
        self.pids = {}          # unique name -> pid
        self.walks = {}         # unique name -> (time, [(path, iface)], {sni menu paths})
        conn.signal_subscribe("org.freedesktop.DBus", "org.freedesktop.DBus", "NameOwnerChanged",
                              "/org/freedesktop/DBus", None, Gio.DBusSignalFlags.NONE, self._owner_changed)
        self.on_gone = None

    def call(self, dest, path, iface, method, args=None, sig=None, timeout=TIMEOUT):
        r = self.conn.call_sync(dest, path, iface, method, args, GLib.VariantType(sig) if sig else None,
                                Gio.DBusCallFlags.NO_AUTO_START, timeout, None)
        return r.unpack() if r is not None else ()

    def _owner_changed(self, conn, sender, path, iface, signal, params):
        name, old, new = params.unpack()
        if name.startswith(":") and not new:
            self.pids.pop(name, None)
            self.walks.pop(name, None)
            if self.on_gone:
                self.on_gone(name)

    def pid_of(self, name):
        if name not in self.pids:
            try:
                self.pids[name] = self.call("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
                                            "GetConnectionUnixProcessID", GLib.Variant("(s)", (name,)))[0]
            except GLib.Error:
                self.pids[name] = -1
        return self.pids[name]

    def names_of(self, pid):
        try:
            names = self.call("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "ListNames")[0]
        except GLib.Error:
            return []
        return [n for n in names if n.startswith(":") and self.pid_of(n) == pid]

    def walk(self, dest, fresh=False):
        """Objects of one connection that implement menus or actions, and its tray menus."""
        hit = self.walks.get(dest)
        if hit and not fresh and time.monotonic() - hit[0] < CACHE_SECONDS:
            return hit[1], hit[2]
        found, sni, todo, seen = [], set(), [("/", 0)], 0
        while todo and seen < WALK_NODES:
            path, depth = todo.pop(0)
            seen += 1
            try:
                xml = self.call(dest, path, "org.freedesktop.DBus.Introspectable", "Introspect")[0]
                root = ET.fromstring(xml)
            except (GLib.Error, ET.ParseError):
                continue
            ifaces = {i.get("name") for i in root.findall("interface")}
            for i in (DBUSMENU, GMENUS, GACTIONS):
                if i in ifaces:
                    found.append((path, i))
            if SNI in ifaces:
                try:
                    menu = self.call(dest, path, "org.freedesktop.DBus.Properties", "Get",
                                     GLib.Variant("(ss)", (SNI, "Menu")))[0]
                    sni.add(str(menu))
                except GLib.Error:
                    pass
            if depth < WALK_DEPTH:
                for n in root.findall("node"):
                    child = path.rstrip("/") + "/" + n.get("name")
                    if not child.startswith(SKIP):
                        todo.append((child, depth + 1))
        self.walks[dest] = (time.monotonic(), found, sni)
        return found, sni


class Registrar:
    """com.canonical.AppMenu.Registrar: who registered which window's menu."""

    def __init__(self, bus, changed):
        self.bus = bus
        self.changed = changed
        self.windows = {}       # window id -> (sender, path, time)
        self.owned = False
        node = Gio.DBusNodeInfo.new_for_xml(REGISTRAR_XML)
        self.iface = node.interfaces[0]
        bus.conn.register_object(REGISTRAR_PATH, self.iface, self._call, None, None)

    def own(self):
        Gio.bus_own_name_on_connection(self.bus.conn, REGISTRAR, Gio.BusNameOwnerFlags.NONE,
                                       lambda *a: self._owned(True), lambda *a: self._owned(False))

    def _owned(self, yes):
        self.owned = yes
        emit({"ev": "registrar", "owned": yes})

    def _call(self, conn, sender, path, iface, method, params, inv):
        p = params.unpack()
        if method == "RegisterWindow":
            wid, opath = p
            self.windows[wid] = (sender, opath, time.monotonic())
            inv.return_value(None)
            conn.emit_signal(None, REGISTRAR_PATH, REGISTRAR, "WindowRegistered", GLib.Variant("(uso)", (wid, sender, opath)))
            self.changed(sender)
        elif method == "UnregisterWindow":
            self.windows.pop(p[0], None)
            inv.return_value(None)
            conn.emit_signal(None, REGISTRAR_PATH, REGISTRAR, "WindowUnregistered", GLib.Variant("(u)", (p[0],)))
            self.changed(sender)
        elif method == "GetMenuForWindow":
            s, o, _ = self.windows.get(p[0], ("", "/", 0))
            inv.return_value(GLib.Variant("(so)", (s, o)))
        elif method == "GetMenus":
            inv.return_value(GLib.Variant("(a(uso))", ([(w, s, o) for w, (s, o, _) in self.windows.items()],)))
        else:
            inv.return_dbus_error("org.freedesktop.DBus.Error.UnknownMethod", method)

    def gone(self, name):
        for wid in [w for w, (s, _, _) in self.windows.items() if s == name]:
            del self.windows[wid]

    def by_senders(self, names):
        """Registered menus of these connections, newest first."""
        hits = [(t, s, o) for (s, o, t) in self.windows.values() if s in names]
        return [(s, o) for t, s, o in sorted(hits, reverse=True)]


class DbusMenu:
    """A com.canonical.dbusmenu menu (Qt, libdbusmenu, X11 apps)."""
    source = "dbusmenu"

    def __init__(self, bus, dest, path, ambiguous, windows, changed):
        self.bus, self.dest, self.path = bus, dest, path
        self.ambiguous, self.windows = ambiguous, windows
        self.items = []
        self.subs = [bus.conn.signal_subscribe(dest, DBUSMENU, sig, path, None, Gio.DBusSignalFlags.NONE,
                                               lambda *a: changed())
                     for sig in ("LayoutUpdated", "ItemsPropertiesUpdated")]

    def stop(self):
        for s in self.subs:
            self.bus.conn.signal_unsubscribe(s)

    def load(self):
        try:
            rev, layout = self.bus.call(self.dest, self.path, DBUSMENU, "GetLayout", GLib.Variant("(iias)", (0, -1, [])))
        except GLib.Error as e:
            log("dbusmenu", self.dest, self.path, e)
            self.items = []
            return False
        self.items = [i for i in (self._item(k) for k in layout[2]) if i]
        return bool(self.items)

    def _item(self, node):
        nid, props, kids = unpack(node)
        props = {k: unpack(v) for k, v in props.items()}
        if not props.get("visible", True):
            return None
        if props.get("type") == "separator":
            return {"id": "d:%d" % nid, "type": "separator"}
        label, mn = strip_mnemonic(props.get("label", ""))
        children = [i for i in (self._item(k) for k in kids) if i]
        submenu = bool(children) or props.get("children-display") == "submenu"
        toggle = {"checkmark": "check", "radio": "radio"}.get(props.get("toggle-type", ""), "")
        return {"id": "d:%d" % nid, "label": label, "mnemonic": mn, "enabled": bool(props.get("enabled", True)),
                "type": "submenu" if submenu else "item", "toggle": toggle,
                "checked": props.get("toggle-state", 0) == 1, "keys": keys_from_dbusmenu(props.get("shortcut")),
                "icon": props.get("icon-name", ""), "children": children}

    def open(self, iid):
        try:
            need = self.bus.call(self.dest, self.path, DBUSMENU, "AboutToShow", GLib.Variant("(i)", (int(iid[2:]),)))[0]
        except GLib.Error:
            need = False
        try:
            self.bus.call(self.dest, self.path, DBUSMENU, "Event",
                          GLib.Variant("(isvu)", (int(iid[2:]), "opened", GLib.Variant("i", 0), int(time.time()))))
        except GLib.Error:
            pass
        return need

    def closed(self, iid):
        try:
            self.bus.call(self.dest, self.path, DBUSMENU, "Event",
                          GLib.Variant("(isvu)", (int(iid[2:]), "closed", GLib.Variant("i", 0), int(time.time()))))
        except GLib.Error:
            pass

    def activate(self, iid):
        self.bus.call(self.dest, self.path, DBUSMENU, "Event",
                      GLib.Variant("(isvu)", (int(iid[2:]), "clicked", GLib.Variant("i", 0), int(time.time()))))
        return True

    def payload(self):
        return {"menus": self.items, "actions": []}


class Actions:
    """org.gtk.Actions groups of one app: prefix -> object path ("app", "win", "unity")."""

    def __init__(self, bus, dest, groups, changed):
        self.bus, self.dest, self.groups = bus, dest, groups
        self.state = {}         # "app.quit" -> (enabled, param type, state)
        self.subs = [bus.conn.signal_subscribe(dest, GACTIONS, "Changed", path, None, Gio.DBusSignalFlags.NONE,
                                               lambda *a: (self.load(), changed()))
                     for path in set(groups.values())]
        self.load()

    def stop(self):
        for s in self.subs:
            self.bus.conn.signal_unsubscribe(s)

    def load(self):
        self.state = {}
        for prefix, path in self.groups.items():
            try:
                for name, (enabled, ptype, state) in self.bus.call(self.dest, path, GACTIONS, "DescribeAll")[0].items():
                    self.state["%s.%s" % (prefix, name)] = (enabled, ptype, [unpack(s) for s in state])
            except GLib.Error:
                pass

    def set_state(self, full, value):
        prefix, _, name = full.partition(".")
        path = self.groups.get(prefix)
        if not path or not name:
            return False
        try:
            self.bus.call(self.dest, path, GACTIONS, "SetState", GLib.Variant("(sva{sv})", (name, GLib.Variant("b", value), {})))
        except GLib.Error:
            return False
        return value

    def activate(self, full, target=None):
        prefix, _, name = full.partition(".")
        path = self.groups.get(prefix)
        if not path:
            return False
        params = []
        if target is not None:
            params = [target if isinstance(target, GLib.Variant) else GLib.Variant("s", str(target))]
        self.bus.call(self.dest, path, GACTIONS, "Activate", GLib.Variant("(sava{sv})", (name, params, {})))
        return True


class GMenu:
    """A GMenuModel menubar (org.gtk.Menus) with its action groups."""
    source = "gmenu"

    def __init__(self, bus, dest, path, groups, ambiguous, windows, changed):
        self.bus, self.dest, self.path = bus, dest, path
        self.ambiguous, self.windows = ambiguous, windows
        self.changed = changed
        self.actions = Actions(bus, dest, groups, changed)
        self.groups = {}        # (group, menu) -> [item dict]
        self.subscribed = set()
        self.items, self.index, self.opening = [], {}, {}
        self.sub = bus.conn.signal_subscribe(dest, GMENUS, "Changed", path, None, Gio.DBusSignalFlags.NONE, self._changed)

    def stop(self):
        self.actions.stop()
        self.bus.conn.signal_unsubscribe(self.sub)
        try:
            self.bus.call(self.dest, self.path, GMENUS, "End", GLib.Variant("(au)", (sorted(self.subscribed),)))
        except GLib.Error:
            pass

    def _start(self, gids):
        gids = [g for g in gids if g not in self.subscribed]
        if not gids:
            return
        self.subscribed.update(gids)
        try:
            for g, m, items in self.bus.call(self.dest, self.path, GMENUS, "Start", GLib.Variant("(au)", (gids,)))[0]:
                self.groups[(g, m)] = [{k: unpack(v) for k, v in it.items()} for it in items]
        except GLib.Error as e:
            log("gmenu start", self.dest, self.path, e)

    def _changed(self, conn, sender, path, iface, signal, params):
        for g, m, pos, removed, added in params.unpack()[0]:
            items = self.groups.setdefault((g, m), [])
            items[pos:pos + removed] = [{k: unpack(v) for k, v in it.items()} for it in added]
        self.changed()

    def load(self):
        self._start([0])
        # follow the sections and submenus down, subscribing to their groups
        for _ in range(8):
            want = {it[k][0] for items in list(self.groups.values()) for it in items
                    for k in (":section", ":submenu") if k in it}
            if not want - self.subscribed:
                break
            self._start(sorted(want))
        # appmenu-gtk-module fills its action group as the menus are subscribed to
        self.actions.load()
        self.index, self.opening = {}, {}
        self.items = self._menu(0, 0)
        return bool(self.items)

    def _menu(self, g, m, depth=0):
        out = []
        for n, it in enumerate(self.groups.get((g, m), [])):
            if ":section" in it:
                sec = self._menu(*it[":section"], depth=depth + 1) if depth < 10 else []
                if sec:
                    if out and out[-1].get("type") != "separator":
                        out.append({"id": "g:%d.%d.%d.sep" % (g, m, n), "type": "separator"})
                    out += sec
                continue
            label, mn = strip_mnemonic(it.get("label", ""))
            iid = "g:%d.%d.%d" % (g, m, n)
            if ":submenu" in it:
                kids = self._menu(*it[":submenu"], depth=depth + 1) if depth < 10 else []
                if it.get("submenu-action") in self.actions.state:
                    self.opening[iid] = it["submenu-action"]
                out.append({"id": iid, "label": label, "mnemonic": mn, "enabled": True, "type": "submenu",
                            "toggle": "", "checked": False, "keys": [], "icon": "", "children": kids})
                continue
            action = it.get("action", "")
            target = it.get("target")
            enabled, ptype, state = self.actions.state.get(action, (False, "", []))
            if action and action not in self.actions.state:
                continue        # an action nobody exports would be a dead item
            toggle, checked = "", False
            if state:
                if isinstance(state[0], bool):
                    toggle, checked = "check", state[0]
                elif target is not None:
                    toggle, checked = "radio", state[0] == target
            self.index[iid] = (action, target)
            out.append({"id": iid, "label": label, "mnemonic": mn, "enabled": bool(enabled), "type": "item",
                        "toggle": toggle, "checked": checked, "keys": keys_from_accel(it.get("accel", "")),
                        "icon": "", "children": []})
        while out and out[-1].get("type") == "separator":
            out.pop()
        while out and out[0].get("type") == "separator":
            out.pop(0)
        return out

    def open(self, iid):
        # GTK sets a submenu's "submenu-action" to true while it shows (the app may update it)
        return self.actions.set_state(self.opening.get(iid, ""), True)

    def closed(self, iid):
        self.actions.set_state(self.opening.get(iid, ""), False)

    def activate(self, iid):
        action, target = self.index.get(iid, ("", None))
        if not action:
            return False
        if target is not None and not isinstance(target, GLib.Variant):
            target = GLib.Variant("s", target) if isinstance(target, str) else \
                GLib.Variant("b", target) if isinstance(target, bool) else \
                GLib.Variant("i", target) if isinstance(target, int) else GLib.Variant("s", str(target))
        return self.actions.activate(action, target)

    def payload(self):
        return {"menus": self.items, "actions": []}


class ActionsOnly:
    """A GtkApplication without a menubar: its actions, for the shell's standard menus."""
    source = "actions"

    def __init__(self, bus, dest, groups, ambiguous, windows, changed):
        self.ambiguous, self.windows = ambiguous, windows
        self.actions = Actions(bus, dest, groups, changed)

    def stop(self):
        self.actions.stop()

    def load(self):
        return bool(self.actions.state)

    def open(self, iid):
        return False

    def closed(self, iid):
        pass

    def activate(self, iid):
        return self.actions.activate(iid[2:]) if iid.startswith("a:") else False

    def payload(self):
        acts = []
        for full, (enabled, ptype, state) in sorted(self.actions.state.items()):
            if ptype:           # actions that need a parameter have no place in a standard menu
                continue
            scope, _, name = full.partition(".")
            acts.append({"id": "a:" + full, "scope": scope, "name": name, "enabled": bool(enabled),
                         "state": state[0] if state else None})
        return {"menus": [], "actions": acts}


class Finder:
    def __init__(self, bus, registrar):
        self.bus, self.registrar = bus, registrar

    def find(self, pid, app, changed, fresh=False):
        """The best menu source of this pid, or None."""
        names = self.bus.names_of(pid)
        if not names:
            return None
        # 1. a window registered with the registrar (X11 apps, libdbusmenu)
        if self.registrar:
            regs = self.registrar.by_senders(names)
            for dest, path in regs:
                src = DbusMenu(self.bus, dest, path, len(regs) > 1, len(regs), changed)
                if src.load():
                    return src
                src.stop()
        walks = {n: self.bus.walk(n, fresh) for n in names}
        # 2. Qt's own exports (/MenuBar/<n>), not the tray icon's menu
        qt = [(n, p) for n, (found, sni) in walks.items() for p, i in found
              if i == DBUSMENU and p not in sni and p.startswith("/MenuBar/")]
        loaded = []
        for n, p in qt:
            src = DbusMenu(self.bus, n, p, False, 0, changed)
            if src.load():
                loaded.append((p, src))
            else:
                src.stop()
        if loaded:
            loaded.sort(key=lambda x: int(x[0].rsplit("/", 1)[1]) if x[0].rsplit("/", 1)[1].isdigit() else 0)
            for _, s in loaded[:-1]:
                s.stop()
            best = loaded[-1][1]
            best.ambiguous, best.windows = len(loaded) > 1, len(loaded)
            return best
        # 3. GMenuModel menubars: appmenu-gtk-module's per window, GtkApplication's app-wide
        own = "/" + app.replace(".", "/").replace("-", "_") if app else ""
        for n, (found, sni) in walks.items():
            paths = {p for p, i in found}
            acts = {p for p, i in found if i == GACTIONS}
            parents = {p.rsplit("/", 1)[0] for p in acts}
            # a GtkApplication's object: it has windows or a menubar under it, or is the path
            # GApplication makes of the app id (org.telegram.desktop → /org/telegram/desktop)
            app_paths = sorted(p for p in acts if not p.startswith("/org/appmenu") and
                               (p + "/window" in parents or p + "/menus/menubar" in paths or p == own))
            win_paths = sorted(p for p in acts if "/window/" in p and not p.startswith("/org/appmenu"))
            module = sorted((p for p, i in found if i == GMENUS and p.startswith("/org/appmenu/gtk/window/menus/menubar")),
                            key=lambda p: int(p.rsplit("/", 1)[1]) if p.rsplit("/", 1)[1].isdigit() else 0)
            full = []
            for p in module:
                src = GMenu(self.bus, n, p, {"unity": p}, False, 0, changed)
                if src.load():
                    full.append(src)
                else:
                    src.stop()
            if full:
                for s in full[:-1]:
                    s.stop()
                best = full[-1]
                best.ambiguous, best.windows = len(full) > 1, len(full)
                return best
            for app in app_paths:
                wins = [w for w in win_paths if w.startswith(app + "/window/")]
                groups = {"app": app}
                if len(wins) == 1:
                    groups["win"] = wins[0]
                if app + "/menus/menubar" in paths:
                    src = GMenu(self.bus, n, app + "/menus/menubar", groups, len(wins) > 1, len(wins), changed)
                    if src.load():
                        return src
                    src.stop()
                src = ActionsOnly(self.bus, n, groups, len(wins) > 1, len(wins), changed)
                if src.load():
                    return src
                src.stop()
        return None


class Server:
    def __init__(self, own_registrar=True):
        self.conn = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        self.bus = Bus(self.conn)
        self.registrar = Registrar(self.bus, self._registered) if own_registrar else None
        self.finder = Finder(self.bus, self.registrar)
        self.bus.on_gone = self._gone
        self.pid, self.app, self.src = 0, "", None
        self.pending = 0        # a debounced re-send
        self.retries = 0
        if self.registrar:
            self.registrar.own()

    def _gone(self, name):
        if self.registrar:
            self.registrar.gone(name)
        if self.src and getattr(self.src, "dest", None) == name:
            self._focus(self.pid, self.app, True)

    def _registered(self, sender):
        if self.bus.pid_of(sender) == self.pid:
            GLib.timeout_add(150, lambda: (self._focus(self.pid, self.app, True), False)[1])

    def _changed(self):
        if self.pending:
            return
        self.pending = GLib.timeout_add(60, self._reload)

    def _reload(self):
        self.pending = 0
        if self.src:
            self.src.load()
            self._send()
        return False

    def _send(self):
        out = {"ev": "menu", "pid": self.pid, "app": self.app, "source": "none", "ambiguous": False, "windows": 0,
               "menus": [], "actions": []}
        if self.src:
            out.update(self.src.payload())
            out.update(source=self.src.source, ambiguous=bool(self.src.ambiguous), windows=self.src.windows)
        emit(out)

    def _focus(self, pid, app, fresh=False):
        if self.src:
            self.src.stop()
            self.src = None
        self.pid, self.app = pid, app
        if pid > 0:
            try:
                self.src = self.finder.find(pid, app, self._changed, fresh)
            except GLib.Error as e:
                log("find", pid, e)
        self._send()
        # an app that just started may export its menu a moment later
        if pid > 0 and not self.src and self.retries < 3:
            self.retries += 1
            wanted = pid
            GLib.timeout_add(600 * self.retries, lambda: (self.pid == wanted and self._focus(wanted, app, True), False)[1])

    def command(self, msg):
        cmd = msg.get("cmd")
        if cmd == "focus":
            pid = int(msg.get("pid") or 0)
            if pid != self.pid or msg.get("app", "") != self.app:
                self.retries = 0
                self._focus(pid, msg.get("app", ""))
        elif cmd == "refresh":
            self.retries = 0
            self._focus(self.pid, self.app, True)
        elif cmd in ("open", "closed", "activate") and self.src:
            iid = str(msg.get("id", ""))
            try:
                if cmd == "open":
                    if self.src.open(iid):
                        self._changed()
                elif cmd == "closed":
                    self.src.closed(iid)
                else:
                    ok = self.src.activate(iid)
                    emit({"ev": "activated", "id": iid, "ok": bool(ok)})
            except GLib.Error as e:
                emit({"ev": "activated", "id": iid, "ok": False, "error": str(e)})

    def run(self):
        loop = GLib.MainLoop()
        stdin = GLib.IOChannel.unix_new(sys.stdin.fileno())

        def readable(ch, cond):
            if cond & (GLib.IO_HUP | GLib.IO_ERR):
                loop.quit()
                return False
            line = sys.stdin.readline()
            if not line:
                loop.quit()
                return False
            try:
                self.command(json.loads(line))
            except (ValueError, TypeError) as e:
                log("bad command", line.strip(), e)
            return True

        GLib.io_add_watch(stdin, GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, readable)
        loop.run()


def dump(pids):
    """For the report: what every open window's app offers."""
    conn = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    bus = Bus(conn)
    finder = Finder(bus, None)
    wins = []
    if not pids:
        try:
            wins = json.loads(subprocess.run(["niri", "msg", "-j", "windows"], capture_output=True, text=True, timeout=5).stdout)
        except (OSError, ValueError, subprocess.TimeoutExpired):
            wins = []
        pids = sorted({w.get("pid") for w in wins if w.get("pid")})
    names = {w.get("pid"): w.get("app_id") for w in wins}

    def labels(items, depth=0):
        out = []
        for it in items:
            if it.get("type") == "separator":
                out.append("—")
            elif it.get("type") == "submenu":
                out.append("%s[%s]" % (it["label"], ", ".join(labels(it["children"], depth + 1))) if depth < 1 else it["label"] + " ›")
            else:
                out.append(it["label"] + ("" if it.get("enabled") else " (off)"))
        return out

    for pid in pids:
        src = finder.find(pid, names.get(pid, ""), lambda: None)
        row = {"pid": pid, "app": names.get(pid, ""), "source": src.source if src else "none",
               "ambiguous": bool(src and src.ambiguous)}
        if src:
            pay = src.payload()
            row["menus"] = labels(pay["menus"])
            row["actions"] = [a["id"][2:] for a in pay["actions"]]
            src.stop()
        print(json.dumps(row, ensure_ascii=False))


def main():
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(__doc__.strip().split("\n\n")[0])
        return 0
    if args[0] == "serve":
        Server(own_registrar="--no-registrar" not in args).run()
        return 0
    if args[0] == "dump":
        dump([int(a) for a in args[1:] if a.isdigit()])
        return 0
    print("unknown command: %s" % args[0], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
