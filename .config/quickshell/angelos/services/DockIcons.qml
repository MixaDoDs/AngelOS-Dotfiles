pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The Golden Gate Dock's icons drawn like macOS: MacTahoe (scripts/mac-icons.py — GPL-3.0, a
// pinned release, downloaded once while the skin is on; or a MacTahoe installed already). Only
// the Dock reads it: GTK and the rest keep their icon theme. Without it (not downloaded yet, no
// network, turned off in Settings) the Dock shows the theme's icons as before.
Singleton {
    id: root

    property string dir: ""
    property var have: ({})                 // "apps/<name>" and "places/<name>" -> true
    property string error: ""
    property bool tried: false              // a download once a session, not again on failure
    readonly property bool ready: dir !== ""
    readonly property bool busy: worker.running
    readonly property bool wanted: GoldenGate.on && Config.mac.dockMacIcons

    function file(kind, name) {
        return name && have[kind + "/" + name] ? "file://" + dir + "/" + kind + "/scalable/" + name + ".svg" : "";
    }
    // the icon of a Dock item, "" when MacTahoe has none: its .desktop icon, its id, the last
    // part of a reverse-DNS id (org.gnome.Nautilus -> nautilus)
    function forItem(it) {
        if (!ready || !Config.mac.dockMacIcons || !it)
            return "";
        if (it.kind === "apps")
            return file("apps", "view-app-grid");
        if (it.kind === "settings")
            return file("apps", "preferences-system");
        if (it.kind === "downloads")
            return file("places", "folder-download");
        if (it.kind === "trash")
            return file("places", it.icon === "user-trash-full" ? "user-trash-full" : "user-trash");
        const out = [];
        const add = n => {
            n = String(n || "").replace(/\.desktop$/, "");
            if (!n || n.startsWith("/") || out.includes(n))
                return;
            out.push(n, n.toLowerCase());
        };
        add(it.icon);
        add(it.id);
        if (it.entry)
            add(it.entry.id);
        for (const n of out.slice()) {
            const tail = n.split(".").pop();
            if (n.indexOf(".") > 0 && tail.length > 2)
                add(tail);
        }
        for (const n of out) {
            const f = file("apps", n);
            if (f)
                return f;
        }
        return "";
    }

    function refresh() {
        if (!lister.running)
            lister.running = true;
    }
    function install() {
        if (worker.running)
            return;
        tried = true;
        error = "";
        worker.running = true;
    }

    // (not in dev runs and tests: nothing is downloaded)
    onWantedChanged: if (wanted)
        refresh()
    Component.onCompleted: if (wanted)
        refresh()
    Connections {
        target: GoldenGate
        function onLiveChanged() {
            if (root.wanted && GoldenGate.live && !root.ready)
                root.refresh();
        }
    }

    Process {
        id: lister
        command: ["python3", Quickshell.shellDir + "/scripts/mac-icons.py", "status"]
        stdout: StdioCollector {
            onStreamFinished: root.take(text)
        }
    }
    Process {
        id: worker
        command: ["python3", Quickshell.shellDir + "/scripts/mac-icons.py", "install"]
        stdout: StdioCollector {
            onStreamFinished: root.take(text)
        }
        stderr: StdioCollector {}
    }
    function take(text) {
        let r = null;
        try {
            r = JSON.parse(text);
        } catch (e) {
            error = I18n.t("Не удалось скачать значки", "Could not download the icons");
            return;
        }
        if (r.error) {
            error = r.error;
            return;
        }
        const h = {};
        for (const kind in r.names || {})
            for (const n of r.names[kind])
                h[kind + "/" + n] = true;
        have = h;
        dir = r.installed ? r.dir : "";
        if (!r.installed && wanted && !tried && GoldenGate.live)
            install();
    }
}
