pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Region screenshot / screen recording through the dotfiles tools, which draw
// the selector in the skin chosen in Settings → Screenshots (Config.capture.skin).
// They are spawned by niri, exactly like from the keybind, a moment after the
// window or menu that asked has closed: started by the shell itself they took
// its environment and blocked signals along, and the selector could stay on
// screen after the shot (issue #8).
Singleton {
    id: root

    readonly property string screenshotTool: Config.home + "/.local/bin/niri-screenshot-region"
    readonly property string recordTool: Config.home + "/.local/bin/niri-record-region"

    // the recorder is there (the dotfiles put it): Golden Gate's Control Center offers
    // recording only then
    property bool canRecord: false
    Process {
        running: true
        command: ["test", "-x", root.recordTool]
        onExited: code => root.canRecord = code === 0
    }

    function screenshot() {
        launch(screenshotTool, "niri msg action screenshot");
    }
    function record() {
        launch(recordTool, 'notify-send -a angelOS "niri-record-region не найден"');
    }
    function launch(tool, fallback) {
        later.tool = tool;
        later.fallback = fallback;
        later.restart();
    }
    Timer {
        id: later
        property string tool: ""
        property string fallback: ""
        interval: 220
        onTriggered: Quickshell.execDetached(["sh", "-c", '[ -x "$1" ] || exec sh -c "$2"; niri msg action spawn -- "$1" >/dev/null 2>&1 || exec "$1"', "sh", tool, fallback])
    }
}
