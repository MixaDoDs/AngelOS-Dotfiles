pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// «Смерть на смене», a mini-game after Peace, Death!: the window modules/reaper/ReaperWindow
// (modules/LazyWindows, while `open`), its rules modules/reaper/ReaperCore.js. Opened by the
// Halo's button «Смерть» (services/HaloButtons) or `qs -c angelos ipc call reaper open`.
// The day reached and the best one: ~/.config/angelos/reaper.json.
Singleton {
    id: root

    property bool open: false
    onOpenChanged: if (open)
        Achievements.note("explore", "reaper")
    readonly property alias day: save.day
    readonly property alias best: save.best

    // a shift handed in: the next day opens, the best is kept
    function passed(d) {
        save.day = Math.max(save.day, d + 1);
        save.best = Math.max(save.best, d);
    }
    function restart() {
        save.day = 1;
    }

    FileView {
        path: Config.dir + "/reaper.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()
        JsonAdapter {
            id: save
            property int day: 1
            property int best: 0
        }
    }

    IpcHandler {
        target: "reaper"
        function open(): void {
            root.open = true;
        }
        function close(): void {
            root.open = false;
        }
    }
}
