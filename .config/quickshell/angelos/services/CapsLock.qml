pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Caps Lock, for the bar's mark next to the layout (bar/parts/KbLayout). The state is the
// keyboards' LED (scripts/caps-watch.py): a Caps Lock remapped to Escape / Ctrl / the layout
// switch never lights it and is never shown. Settings → Звук → Индикаторы на экране.
Singleton {
    id: root

    property bool on: false
    readonly property bool wanted: Config.ready && Config.osd.caps

    Process {
        id: daemon
        running: root.wanted
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/caps-watch.py"]
        onRunningChanged: if (!running)
            root.on = false
        stdout: SplitParser {
            onRead: line => {
                if (line === "on" || line === "off")
                    root.on = line === "on";
            }
        }
        stderr: StdioCollector {}
        onExited: if (root.wanted)
            restart.start()
    }
    Timer {
        id: restart
        interval: 5000
        onTriggered: if (root.wanted)
            daemon.running = true
    }
}
