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

    // niri's own shots (Print, screenshot-window/-screen) land loose in the screenshots folder:
    // scripts/screenshot-sort.py moves each into its month (<shots>/2026-10 Октябрь), and on its
    // first run tidies the per-app folders of before into months too
    property bool sorting: false        // set by the process (read before it exists: undefined)
    Process {
        id: sorter
        running: true
        onRunningChanged: root.sorting = running
        command: ["python3", Quickshell.shellDir + "/scripts/screenshot-sort.py", "watch"]
        onExited: sorterAgain.restart()
    }
    Timer {
        id: sorterAgain
        interval: 5000
        onTriggered: sorter.running = true
    }

    function screenshot() {
        Achievements.note("screenshot");
        launch(screenshotTool, "niri msg action screenshot");
    }
    function record() {
        launch(recordTool, 'notify-send -a angelOS "' + I18n.t("Запись экрана не установлена: нет niri-record-region", "Screen recording isn't installed: niri-record-region is missing") + '"');
    }
    // the Golden Gate skin's ⇧⌘3 / ⇧⌘4 / ⇧⌘5 menu (scripts/mac-screenshot.sh: screen | region |
    // window | record): a picture of the screen, of a part, of the focused window, a video
    readonly property string macTool: Quickshell.shellDir + "/scripts/mac-screenshot.sh"
    function mac(kind) {
        launch(macTool, "niri msg action screenshot", [kind]);
    }
    function launch(tool, fallback, args) {
        later.tool = tool;
        later.fallback = fallback;
        later.args = args || [];
        later.restart();
    }
    Timer {
        id: later
        property string tool: ""
        property string fallback: ""
        property var args: []
        interval: 220
        onTriggered: Quickshell.execDetached(["sh", "-c", 't="$1"; f="$2"; shift 2; [ -x "$t" ] || exec sh -c "$f"; niri msg action spawn -- "$t" "$@" >/dev/null 2>&1 || exec "$t" "$@"', "sh", tool, fallback].concat(args))
    }
}
