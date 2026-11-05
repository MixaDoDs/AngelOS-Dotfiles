pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import qs.config

// The Golden Gate Dock's icons drawn like macOS: MacTahoe (scripts/mac-icons.py — GPL-3.0, a
// pinned release, downloaded once while the skin is on; or a MacTahoe installed already). Only
// the Dock reads it: GTK and the rest keep their icon theme. Without it (not downloaded yet, no
// network, turned off in Settings) the Dock shows the theme's icons as before.
// Your own icons come before both: ~/.local/share/angelos/icons/dock/<name>.svg or .png, under
// any name the Dock looks for (the .desktop's icon, the app's id, the last part of a reverse-DNS
// id). For an app MacTahoe draws badly (Steam's is cut at the tile's edge), or one it lacks.
// Read live: an icon put there shows at once. With MacTahoe off they still do.
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
    // ---- your own icons (see above) ----
    readonly property string ownDir: Config.home + "/.local/share/angelos/icons/dock"
    // name (without .svg / .png) -> file url; an .svg wins over a .png of the same name
    readonly property var own: {
        const out = {};
        for (let i = 0; i < ownModel.count; i++) {
            const f = String(ownModel.get(i, "fileName"));
            const m = f.match(/^(.+)\.(svg|png)$/i);
            if (m && (!out[m[1]] || m[2].toLowerCase() === "svg"))
                out[m[1]] = "file://" + ownDir + "/" + f;
        }
        return out;
    }
    FolderListModel {
        id: ownModel
        folder: "file://" + root.ownDir
        nameFilters: ["*.svg", "*.png", "*.SVG", "*.PNG"]
        showDirs: false
    }
    // one of the names: your icon, else MacTahoe's (while it is on)
    function pick(kind, names) {
        for (const n of names)
            if (own[n])
                return own[n];
        if (!ready || !Config.mac.dockMacIcons)
            return "";
        for (const n of names) {
            const f = file(kind, n);
            if (f)
                return f;
        }
        return "";
    }
    // the icon of a Dock item, "" when MacTahoe has none: its .desktop icon, its id, the last
    // part of a reverse-DNS id (org.gnome.Nautilus -> nautilus)
    function forItem(it) {
        if (!it)
            return "";
        if (it.kind === "apps")
            return pick("apps", ["view-app-grid"]);
        if (it.kind === "settings")
            return pick("apps", [AppMenu.shellSettingsIcon]);
        if (it.kind === "downloads")
            return pick("places", ["folder-download"]);
        if (it.kind === "trash")
            return pick("places", [it.icon === "user-trash-full" ? "user-trash-full" : "user-trash"]);
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
        return pick("apps", out);
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
