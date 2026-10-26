pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The chalk: hold Mod+Alt and the left button and the mouse draws pixel chalk over the screen under it; let go
// and it melts away (modules/chalk). An Overlay layer, so the stream sees it too. The key is
// angel-niri's press/release bind (`angelos chalk on|off`): written to cfg/angelos-windows.kdl
// through window-config.py once angel-niri answers Niri.pointer (the same build has the
// binds), taken out again on another niri, where the config would not load with it.
Singleton {
    id: root

    property bool held: false
    // the overlay is up: drawn on, or the strokes still melting (ChalkOverlay ends it)
    property bool shown: false
    property string screenName: ""
    // the chalk's colour, a step of the wheel while drawing (ChalkOverlay); kept till a restart
    property int hue: 0

    function hold(on) {
        if (on === held)
            return;
        held = on;
        if (!on || shown)
            return;
        // the screen under the pointer when the key goes down
        Niri.pointer(p => {
            const s = p && Shell.screenByName(p.output) || Shell.focusedScreen;
            root.screenName = s ? s.name : "";
            root.shown = root.held && root.screenName !== "";
        });
    }

    // ---- the niri key (like the lens's, services/Lens) ----
    property bool niriKeys: false
    property bool niriRead: false
    property bool probed: false
    property string log: ""
    // once per wish: a write that niri validate turned down (rolled back) isn't tried again and again
    property var tried: null
    readonly property bool wantKeys: Niri.pointerSeen
    function sync() {
        if (!Shell.dev && Config.ready && niriRead && probed && niriKeys !== wantKeys && tried !== wantKeys && !writer.running) {
            tried = wantKeys;
            writer.command = ["python3", Quickshell.shellDir + "/scripts/window-config.py", JSON.stringify({
                    "chalk": wantKeys
                })];
            writer.running = true;
        }
    }
    onWantKeysChanged: sync()
    Connections {
        target: Config
        function onReadyChanged() {
            root.sync();
        }
    }
    function probe() {
        if (Niri.ready && !probed)
            Niri.pointer(() => {
                root.probed = true;
                root.sync();
            });
    }
    Component.onCompleted: probe()
    Connections {
        target: Niri
        function onReadyChanged() {
            root.probe();
        }
    }
    Process {
        id: reader
        running: true
        command: ["python3", Quickshell.shellDir + "/scripts/window-config.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.niriKeys = !!JSON.parse(text).chalk;
                    root.niriRead = true;
                    root.sync();
                } catch (e) {}
            }
        }
    }
    Process {
        id: writer
        stderr: StdioCollector {
            onStreamFinished: root.log = text.trim()
        }
        onExited: reader.running = true
    }
}
