#!/usr/bin/env python3
# A stand-in app for tests/appmenu/test_appmenu.py: exports a menu the way one toolkit does and
# prints what the menu bar asked of it ("EVENT …", "ACTION …") on stdout.
#   fake_app.py qt [n]        com.canonical.dbusmenu at /MenuBar/<n> (n menubars: several windows),
#                             a tray icon whose menu is /MenuBar (must not be taken for the app's)
#   fake_app.py x11           a dbusmenu at /com/example/Menu, registered with RegisterWindow
#   fake_app.py gtkapp [m]    a GtkApplication: actions app./win., a menubar when m = "menubar"
#   fake_app.py module        appmenu-gtk-module: a GMenuModel menubar + "unity." actions
import os
import sys
import time
import warnings

from gi.repository import Gio, GLib

warnings.simplefilter("ignore", DeprecationWarning)
conn = Gio.bus_get_sync(Gio.BusType.SESSION, None)
mode = sys.argv[1]
# FAKE_DELAY=seconds: an app that takes a while to start (on the bus at once, its objects later)
if os.environ.get("FAKE_DELAY"):
    time.sleep(float(os.environ["FAKE_DELAY"]))


def say(*a):
    print(*a, flush=True)


DBUSMENU_XML = """<node><interface name="com.canonical.dbusmenu">
<method name="GetLayout"><arg type="i" direction="in"/><arg type="i" direction="in"/><arg type="as" direction="in"/>
<arg type="u" direction="out"/><arg type="(ia{sv}av)" direction="out"/></method>
<method name="Event"><arg type="i" direction="in"/><arg type="s" direction="in"/><arg type="v" direction="in"/><arg type="u" direction="in"/></method>
<method name="AboutToShow"><arg type="i" direction="in"/><arg type="b" direction="out"/></method>
<signal name="LayoutUpdated"><arg type="u"/><arg type="i"/></signal>
<signal name="ItemsPropertiesUpdated"><arg type="a(ia{sv})"/><arg type="a(ias)"/></signal>
</interface></node>"""
SNI_XML = """<node><interface name="org.kde.StatusNotifierItem"><property name="Menu" type="o" access="read"/></interface></node>"""


def node(i, props, kids=()):
    # a layout node as a tuple; children wrapped as variants (unpack() would lose the inner ones)
    return (i, props, [GLib.Variant("(ia{sv}av)", k) for k in kids])


def label(text, **kw):
    p = {"label": GLib.Variant("s", text)}
    for k, v in kw.items():
        key = k.replace("_", "-")
        p[key] = v if isinstance(v, GLib.Variant) else GLib.Variant("b", v) if isinstance(v, bool) else \
            GLib.Variant("i", v) if isinstance(v, int) else GLib.Variant("s", v)
    return p


def qt_menu(tag):
    file_ = node(1, label("_File", children_display="submenu"), [
        node(11, label("_New Window", shortcut=GLib.Variant("aas", [["Control", "N"]]))),
        node(12, {"type": GLib.Variant("s", "separator")}),
        node(13, label("_Quit " + tag, shortcut=GLib.Variant("aas", [["Control", "Q"]]))),
        node(14, label("Hidden", visible=False)),
    ])
    edit = node(2, label("_Edit", children_display="submenu"), [
        node(21, label("Undo", enabled=False)),
        node(22, label("Word Wrap", toggle_type="checkmark", toggle_state=1)),
    ])
    help_ = node(3, label("_Help", children_display="submenu"), [node(31, label("About"))])
    return node(0, {"children-display": GLib.Variant("s", "submenu")}, [file_, edit, help_])


def tray_menu():
    return node(0, {"children-display": GLib.Variant("s", "submenu")}, [node(1, label("Show")), node(2, label("Exit"))])


def export_dbusmenu(path, layout_fn, tag):
    iface = Gio.DBusNodeInfo.new_for_xml(DBUSMENU_XML).interfaces[0]

    def call(c, sender, p, i, method, params, inv):
        if method == "GetLayout":
            inv.return_value(GLib.Variant("(u(ia{sv}av))", (1, layout_fn())))
        elif method == "Event":
            nid, kind, _, _ = params.unpack()
            say("EVENT", tag, kind, nid)
            inv.return_value(None)
        elif method == "AboutToShow":
            say("ABOUT", tag, params.unpack()[0])
            inv.return_value(GLib.Variant("(b)", (False,)))
    conn.register_object(path, iface, call, None, None)


if mode == "qt":
    count = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    for n in range(count):
        export_dbusmenu("/MenuBar/%d" % (n + 2), lambda n=n: qt_menu("w%d" % n), "w%d" % n)
    # the tray icon: its menu sits at /MenuBar (on a second connection, as Qt does)
    tray = Gio.DBusConnection.new_for_address_sync(Gio.dbus_address_get_for_bus_sync(Gio.BusType.SESSION, None),
                                                   Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT | Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION, None, None)
    conn_saved, conn = conn, tray
    export_dbusmenu("/MenuBar", tray_menu, "tray")
    sni = Gio.DBusNodeInfo.new_for_xml(SNI_XML).interfaces[0]
    tray.register_object("/StatusNotifierItem", sni, None,
                         lambda c, s, p, i, prop: GLib.Variant("o", "/MenuBar"), None)
    conn = conn_saved
elif mode == "x11":
    export_dbusmenu("/com/example/Menu", lambda: qt_menu("x11"), "x11")

    def register():
        conn.call_sync("com.canonical.AppMenu.Registrar", "/com/canonical/AppMenu/Registrar", "com.canonical.AppMenu.Registrar",
                       "RegisterWindow", GLib.Variant("(uo)", (77, "/com/example/Menu")), None, 0, 2000, None)
        say("REGISTERED")
        return False
    GLib.timeout_add(int(sys.argv[2]) if len(sys.argv) > 2 else 10, register)
elif mode in ("gtkapp", "module"):
    def action(group, name, scope):
        a = Gio.SimpleAction.new(name, None)
        a.connect("activate", lambda *x: say("ACTION", scope + "." + name))
        group.add_action(a)
        return a

    if mode == "gtkapp":
        app = Gio.SimpleActionGroup()
        for name in ("about", "preferences", "quit", "new-window"):
            action(app, name, "app")
        win = Gio.SimpleActionGroup()
        action(win, "new-tab", "win")
        action(win, "undo", "win").set_enabled(False)
        side = Gio.SimpleAction.new_stateful("toggle-sidebar", None, GLib.Variant("b", True))
        side.connect("change-state", lambda a, v: (a.set_state(v), say("STATE win.toggle-sidebar", v.unpack())))
        win.add_action(side)
        conn.export_action_group("/org/example/App", app)
        for n in range(int(sys.argv[3]) if len(sys.argv) > 3 else 1):
            conn.export_action_group("/org/example/App/window/%d" % (n + 1), win)
        if len(sys.argv) > 2 and sys.argv[2] == "menubar":
            bar = Gio.Menu()
            f = Gio.Menu()
            sec = Gio.Menu()
            sec.append("_New Window", "app.new-window")
            item = Gio.MenuItem.new("New _Tab", "win.new-tab")
            item.set_attribute_value("accel", GLib.Variant("s", "<Primary>t"))
            sec.append_item(item)
            f.append_section(None, sec)
            sec2 = Gio.Menu()
            sec2.append("_Quit", "app.quit")
            sec2.append("Dead", "app.nobody-exports-this")
            f.append_section(None, sec2)
            bar.append_submenu("_File", f)
            v = Gio.Menu()
            v.append("Sidebar", "win.toggle-sidebar")
            bar.append_submenu("_View", v)
            conn.export_menu_model("/org/example/App/menus/menubar", bar)
        else:
            conn.export_menu_model("/org/example/App/menus/menubar", Gio.Menu())   # empty, like Meld's
    else:
        acts = Gio.SimpleActionGroup()
        for name in ("-New", "-Quit"):
            action(acts, name, "unity")
        sub = Gio.SimpleAction.new_stateful("-File", None, GLib.Variant("b", False))
        sub.connect("change-state", lambda a, v: (a.set_state(v), say("STATE unity.-File", v.unpack())))
        acts.add_action(sub)
        bar = Gio.Menu()
        f = Gio.Menu()
        f.append("_New", "unity.-New")
        f.append("_Quit", "unity.-Quit")
        item = Gio.MenuItem.new_submenu("_File", f)
        item.set_attribute_value("submenu-action", GLib.Variant("s", "unity.-File"))
        bar.append_item(item)
        empty = "/org/appmenu/gtk/window/menus/menubar/0"
        full = "/org/appmenu/gtk/window/menus/menubar/1"
        conn.export_menu_model(empty, Gio.Menu())
        conn.export_action_group(empty, Gio.SimpleActionGroup())
        conn.export_menu_model(full, bar)
        conn.export_action_group(full, acts)

say("READY")
GLib.MainLoop().run()
