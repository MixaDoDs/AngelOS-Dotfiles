pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What the bars keep from windows on each screen, by edge (their exclusive zones), in
// $XDG_RUNTIME_DIR/angelos/zones.json: {"DP-1": {"top": 0, "bottom": 40, "left": 0, "right": 0}}.
// The region screenshot tool (niri-screenshot-region: hover a window, click it) lays tiled
// windows out itself — niri tells where floating windows are, not tiled ones — and for that
// it needs niri's working area: it measures its size, Wayland won't say where it is; this says
// which edges took the rest. Every bar window reports through a widgets/ZoneReport.
Singleton {
    id: root

    property var parts: ({})                // "screen|key" -> {screen, edge, px}
    readonly property string path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/angelos/zones.json"

    function report(screen, key, edge, px) {
        if (!screen || !key)
            return;
        const id = screen + "|" + key;
        const was = parts[id];
        if (was && was.edge === edge && was.px === px)
            return;
        const p = Object.assign({}, parts);
        p[id] = {
            "screen": screen,
            "edge": edge,
            "px": px
        };
        parts = p;
        later.restart();
    }
    function drop(screen, key) {
        const id = screen + "|" + key;
        if (!(id in parts))
            return;
        const p = Object.assign({}, parts);
        delete p[id];
        parts = p;
        later.restart();
    }

    function write() {
        // a dev instance's bars keep nothing (ExclusionMode.Ignore): it would tell the live one's wrong
        if (Shell.dev)
            return;
        if (writer.running) {
            later.restart();
            return;
        }
        const out = {};
        for (const id in parts) {
            const z = parts[id];
            if (!out[z.screen])
                out[z.screen] = {
                    "top": 0,
                    "bottom": 0,
                    "left": 0,
                    "right": 0
                };
            if (z.edge in out[z.screen])
                out[z.screen][z.edge] += z.px;
        }
        writer.command = ["sh", "-c", 'mkdir -p "${1%/*}" && printf "%s\\n" "$2" > "$1.tmp" && mv -f "$1.tmp" "$1"', "sh", path, JSON.stringify(out)];
        writer.running = true;
    }
    Timer {
        id: later
        interval: 300
        onTriggered: root.write()
    }
    Process {
        id: writer
    }
}
