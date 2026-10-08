pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// How the shell renders (Settings → System → Rendering). bin/angelos reads
// ~/.config/angelos/renderer when it starts the shell:
//   auto   — OpenGL; on NVIDIA with Qt < 6.12 the patched wayland-egl plugin from
//            scripts/qt-egl-fix.sh brings back the threaded, vsync-driven loop
//   vulkan — Qt's Vulkan backend
//   opengl — stock Qt
Singleton {
    id: root

    readonly property string file: Config.dir + "/renderer"
    property string mode: "auto"
    property var fix: ({})               // {qt, nvidia, needed, built, path}
    property var log: []
    readonly property bool building: builder.running
    // what this running shell actually uses
    readonly property string active: Quickshell.env("QSG_RHI_BACKEND") === "vulkan" ? "vulkan" : (Quickshell.env("QT_PLUGIN_PATH") || "").includes("/angelos/qt/") ? "patched" : "stock"

    function setMode(m) {
        if (!["auto", "vulkan", "opengl"].includes(m))
            return;
        mode = m;
        store.write(m + "\n");
    }
    function refresh() {
        if (!status.running)
            status.running = true;
    }
    function build() {
        if (builder.running)
            return;
        log = [];
        builder.running = true;
    }

    AsyncFile {
        id: store
        path: root.file
        printErrors: false
        onLoaded: {
            const m = text().trim();
            root.mode = ["auto", "vulkan", "opengl"].includes(m) ? m : "auto";
        }
    }
    Process {
        id: status
        running: true
        command: ["bash", Quickshell.shellDir + "/scripts/qt-egl-fix.sh", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.fix = JSON.parse(text);
                } catch (e) {}
            }
        }
    }
    Process {
        id: builder
        command: ["bash", Quickshell.shellDir + "/scripts/qt-egl-fix.sh", "build"]
        stdout: SplitParser {
            onRead: line => root.log = root.log.concat([line]).slice(-60)
        }
        stderr: SplitParser {
            onRead: line => root.log = root.log.concat([line]).slice(-60)
        }
        onExited: root.refresh()
    }
}
