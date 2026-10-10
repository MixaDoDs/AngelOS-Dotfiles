#!/usr/bin/env python3
"""A stand-in org.freedesktop.portal.Desktop with only FileChooser.OpenFile, for test_pick_file.py.

  fake_portal.py CODE [URI...]  answers every OpenFile with Response(CODE, {uris: [URI...]})

It prints "ready" once it owns the name, and each call's title, filters, current_folder and
multiple as one JSON line.
"""
import json
import sys
import warnings

from gi.repository import Gio, GLib

# register_object with Python closures: the deprecated call is the one PyGObject takes
warnings.simplefilter("ignore", DeprecationWarning)

XML = """<node><interface name="org.freedesktop.portal.FileChooser">
<method name="OpenFile"><arg type="s" direction="in"/><arg type="s" direction="in"/>
<arg type="a{sv}" direction="in"/><arg type="o" direction="out"/></method>
</interface></node>"""
CODE = int(sys.argv[1])
URIS = sys.argv[2:]


def call(conn, sender, _path, _iface, method, params, inv):
    _parent, title, options = params.unpack()
    cur = options.get("current_folder")
    print(json.dumps({"title": title, "filters": options.get("filters"), "multiple": options.get("multiple", False),
                      "current_folder": bytes(cur).rstrip(b"\0").decode() if cur else None}), flush=True)
    handle = "/org/freedesktop/portal/desktop/request/%s/%s" % (sender[1:].replace(".", "_"), options.get("handle_token", "t"))
    inv.return_value(GLib.Variant("(o)", (handle,)))
    results = {"uris": GLib.Variant("as", URIS)} if URIS else {}

    def answer():
        conn.emit_signal(sender, handle, "org.freedesktop.portal.Request", "Response",
                         GLib.Variant("(ua{sv})", (CODE, results)))
        return False
    GLib.timeout_add(100, answer)


def acquired(conn, _name):
    print("ready", flush=True)


bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
bus.register_object("/org/freedesktop/portal/desktop", Gio.DBusNodeInfo.new_for_xml(XML).interfaces[0], call, None, None)
Gio.bus_own_name_on_connection(bus, "org.freedesktop.portal.Desktop", Gio.BusNameOwnerFlags.NONE, acquired, None)
GLib.MainLoop().run()
