pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Shake the mouse to find the pointer, like macOS (Settings → Cursor): scripts/shake-watch.py
// spots a shake in evdev (needs the `input` group, like the Meta tap), modules/cursor/ShakeCursor
// draws the arrow of the cursor theme (scripts/cursor-image.py) bigger for a moment. While it
// is up the overlay holds the pointer (the real arrow hides under it); a click or a wheel step
// that lands there is handed on to what is under the pointer by scripts/vpointer.py.
Singleton {
    id: root

    property string status: "off"      // off | starting | ready | noperm | noevdev | error
    property bool shaking: false
    // the arrow picture: {png, nominal, width, height, xhot, yhot}
    property var image: null
    readonly property bool wanted: Config.ready && Config.cursor.shake && (!Shell.dev || Quickshell.env("ANGELOS_DEV_SHAKE") === "1")
    readonly property real zoom: Math.max(1.5, Math.min(8, Config.cursor.shakeScale || 4))
    // angel-niri draws the arrow bigger itself (set-cursor-zoom): the pointer keeps working over
    // every window while it is big, as on macOS — no overlay, nothing handed on. Stock niri
    // answers Err to the action: the overlay (modules/cursor/ShakeCursor) as before
    property bool ownZoom: false
    function _probe() {
        Niri.request({
            "Action": {
                "SetCursorZoom": {
                    "zoom": 1,
                    "ms": 0
                }
            }
        }, (ok, err) => root.ownZoom = !err, true);
    }
    function _zoomTo(z, ms) {
        Niri.request({
            "Action": {
                "SetCursorZoom": {
                    "zoom": z,
                    "ms": Motion.calm ? 0 : ms
                }
            }
        }, null, true);
    }

    function pulse() {
        // games and fullscreen video: fast flicks are not a lost pointer
        if (Shell.locked || MetaTap.coversOutput(Niri.focusedWindow))
            return;
        shaking = true;
        calm.interval = 420;
        calm.restart();
    }
    // Settings → Cursor → "Show me": long enough to move the mouse and see it
    function demo() {
        if (!image && !imager.running)
            imager.load();
        shaking = true;
        calm.interval = 1600;
        calm.restart();
    }
    // a click while it is big: shrink at once
    function dismiss() {
        calm.stop();
        shaking = false;
    }
    // …and once the overlay is gone, the same click (a Linux button code) or wheel steps
    // (notches, + = down / right) go to what is under the pointer
    function pass(button) {
        if (hand.ok)
            hand.write("click " + button + "\n");
    }
    function wheel(dy, dx) {
        if (hand.ok)
            hand.write("wheel " + dy + " " + dx + "\n");
    }
    // the virtual pointer that hands clicks on: up while shaking is on, or since a demo
    property bool _shown: false
    onShakingChanged: {
        if (ownZoom)
            _zoomTo(shaking ? zoom : 1, shaking ? 170 : 240);
        else if (shaking)
            _shown = true;
    }
    Process {
        id: hand
        property bool ok: false
        running: !root.ownZoom && (root.wanted || root._shown)
        stdinEnabled: true
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/vpointer.py"]
        onRunningChanged: if (!running)
            ok = false
        stdout: SplitParser {
            onRead: line => hand.ok = line === "ready"
        }
        stderr: StdioCollector {}
    }
    Timer {
        id: calm
        interval: 420
        onTriggered: root.shaking = false
    }

    Process {
        id: daemon
        running: root.wanted
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/shake-watch.py", "--sensitivity", ["low", "normal", "high"].includes(Config.cursor.shakeSensitivity) ? Config.cursor.shakeSensitivity : "normal"]
        onRunningChanged: {
            if (running)
                root.status = "starting";
            else if (root.status === "starting" || root.status === "ready")
                root.status = root.wanted ? "error" : "off";
        }
        stdout: SplitParser {
            onRead: line => {
                if (line === "shake")
                    root.pulse();
                else if (["ready", "noperm", "noevdev"].includes(line))
                    root.status = line;
            }
        }
        stderr: StdioCollector {}
        onExited: if (root.wanted && root.status !== "noperm" && root.status !== "noevdev")
            restart.start()
    }
    Timer {
        id: restart
        interval: 5000
        onTriggered: if (root.wanted)
            daemon.running = true
    }
    onWantedChanged: {
        if (!wanted)
            status = "off";
        else if (!image)
            imager.load();
        if (wanted)
            _probe();
    }

    // the arrow of the current theme, again when the theme changes
    readonly property string theme: Cursors.active || "default"
    onThemeChanged: if (wanted)
        imager.load()
    Component.onCompleted: {
        // (asked whether the shake is on or not: Settings → Cursor → "Show me" uses it too)
        _probe();
        if (wanted)
            imager.load();
    }
    Process {
        id: imager
        function load() {
            running = false;
            command = ["python3", Quickshell.shellDir + "/scripts/cursor-image.py", root.theme, Config.cacheDir + "/cursor-" + root.theme.replace(/[^A-Za-z0-9_.-]/g, "_") + ".png"];
            running = true;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    root.image = j.png ? j : null;
                } catch (e) {
                    root.image = null;
                }
            }
        }
        stderr: StdioCollector {}
    }
}
