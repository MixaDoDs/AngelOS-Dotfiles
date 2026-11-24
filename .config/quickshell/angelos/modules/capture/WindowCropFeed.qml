pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    required property var windowId
    required property bool requested
    property var crop: null
    property bool once: false
    property int maxWidth: 640
    property int maxHeight: 400
    property string frameUrl: ""
    property bool failed: false

    readonly property string runtime: Quickshell.env("XDG_RUNTIME_DIR")
    property string directory: ""
    property bool stopping: false
    property bool ready: false

    function update() {
        if (!ready)
            return;
        if (!requested) {
            deadline.stop();
            frameUrl = "";
            if (reader.running) {
                stopping = true;
                reader.running = false;
            }
            return;
        }
        if (failed || stopping || reader.running || (once && frameUrl))
            return;
        if (!directory) {
            if (!runtime) {
                failed = true;
            } else if (!makeDir.running) {
                makeDir.running = true;
                deadline.restart();
            }
            return;
        }
        const args = ["niri", "window-crop", "--id", String(windowId), "--directory", directory,
            "--max-width", String(maxWidth), "--max-height", String(maxHeight)];
        if (crop)
            args.push("--crop", [crop.x, crop.y, crop.w, crop.h].join(","));
        if (once)
            args.push("--once");
        reader.command = args;
        reader.running = true;
        deadline.restart();
    }

    onRequestedChanged: {
        if (requested)
            failed = false;
        update();
    }
    Component.onCompleted: {
        ready = true;
        update();
    }
    Component.onDestruction: {
        reader.running = false;
        if (directory)
            Quickshell.execDetached(["sh", "-c",
                'rm -f -- "$1/frame-0.ppm" "$1/frame-1.ppm" "$1/.frame.tmp"; rmdir -- "$1"',
                "window-crop-cleanup", directory]);
    }

    Process {
        id: makeDir
        command: ["mktemp", "-d", root.runtime + "/angelos-window-crop.XXXXXXXX"]
        stdout: StdioCollector {
            id: dirOutput
        }
        onExited: code => {
            if (code !== 0 || !dirOutput.text.trim()) {
                deadline.stop();
                root.failed = true;
                return;
            }
            root.directory = dirOutput.text.trim();
            root.update();
        }
    }
    Process {
        id: reader
        stdout: SplitParser {
            onRead: line => {
                if (root.requested && !root.stopping && /^frame-[01]\.ppm$/.test(line)) {
                    deadline.stop();
                    root.frameUrl = "file://" + root.directory + "/" + line;
                }
            }
        }
        stderr: SplitParser {
            onRead: line => console.warn("Window crop: " + line)
        }
        onExited: {
            deadline.stop();
            if (root.stopping) {
                root.stopping = false;
                root.update();
            } else if (root.requested && (!root.once || !root.frameUrl)) {
                root.failed = true;
            }
        }
    }
    Timer {
        id: deadline
        interval: 6000
        onTriggered: {
            root.failed = true;
            reader.running = false;
        }
    }
}
