pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.modules.settings

// Where the tips (services/Tour) show, offscreen with three screens (tests/tour/run.sh):
// DP-1 the streamed one, HDMI-A-1 the main one (Settings → Monitor), HDMI-A-2 another. Each has a
// stand-in bar with Start (registered like modules/bar). Ten times each: the wizard answered on the
// main screen and niri's focus elsewhere when it closes; the wizard answered on the streamed screen
// in stream mode; the tips from Settings with the focus elsewhere — always on HDMI-A-1, the circled
// Start button the one on that screen, never DP-1. And a main screen without a bar: a bar screen.
Scope {
    id: root

    property int failures: 0
    property int phase: 0
    property int round: 0
    property double since: 0
    property var seen: []
    function report(name, ok, detail) {
        if (!ok)
            failures++;
        console.log("TEST " + name + " " + (ok ? "PASS" : "FAIL") + (detail ? " " + detail : ""));
    }
    function focus(name) {
        Niri.allWorkspaces = [{
                "id": 1,
                "idx": 1,
                "output": name,
                "is_focused": true,
                "is_active": true
            }];
    }
    function where() {
        const t = Tour.target("bar:start");
        return Tour.screen + " (Start on " + (t && t.window && t.window.screen ? t.window.screen.name : "none") + ")";
    }

    SetupFlow {
        id: flow
    }
    // a stand-in bar per screen: its Start button registered as the real bars do
    Variants {
        model: Quickshell.screens
        FloatingWindow {
            id: bar
            required property var modelData
            screen: modelData
            implicitWidth: 200
            implicitHeight: 40
            title: "bar " + modelData.name
            Item {
                id: start
                width: 30
                height: 30
            }
            // (offscreen puts every window on the first screen: the bar says its own, as a
            // layer-shell bar's screen does)
            QtObject {
                id: place
                property var screen: bar.modelData
            }
            Component.onCompleted: {
                Shell.registerStartButton(modelData.name, start, place);
                Tour.register("bar:start", start, place);
            }
        }
    }

    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: root.tick()
    }
    function tick() {
        if (phase === 0) {
            if (!Config.ready || Object.keys(Shell.startButtons).length < 3)
                return;
            report("screens", Shell.screens.length === 3 && Shell.primaryName === "HDMI-A-1", Shell.screens.map(s => s.name).join(", ") + ", main " + Shell.primaryName);
            phase = 1;
            return;
        }
        // 1: the wizard on the main screen, niri's focus moves to DP-1 as it closes
        // 2: stream mode, the wizard on the streamed DP-1
        if (phase === 1 || phase === 2) {
            if (!since) {
                Tour.stop();
                Config.stream.manual = phase === 2;
                Config.stream.screens = ["DP-1"];
                focus(phase === 1 ? "HDMI-A-1" : "DP-1");
                Shell.setupOpen = true;
                flow.tipsAfter = true;
                if (phase === 1)
                    focus("DP-1");
                flow.finish();
                since = Date.now();
                return;
            }
            if (!Tour.running && Date.now() - since < 5000)
                return;
            seen.push(Tour.running ? where() : "no tips");
            since = 0;
            if (++round < 10)
                return;
            const ok = seen.every(s => s === "HDMI-A-1 (Start on HDMI-A-1)");
            report(phase === 1 ? "tour-after-wizard" : "tour-stream", ok, "10 runs: " + (ok ? seen[0] : seen.join("; ")));
            seen = [];
            round = 0;
            phase++;
            return;
        }
        // 3: the tips from Settings (Tour.start, nothing given), focus on another screen
        if (phase === 3) {
            Config.stream.manual = false;
            const got = [];
            for (let i = 0; i < 10; i++) {
                focus(i % 2 ? "DP-1" : "HDMI-A-2");
                Tour.start();
                got.push(where());
                Tour.stop();
            }
            report("tour-from-settings", got.every(s => s === "HDMI-A-1 (Start on HDMI-A-1)"), got[0]);
            // 4: the main screen has no bar: a screen with Start, never the streamed one
            Config.stream.manual = true;
            const bar = Shell.startButtons["HDMI-A-1"];
            Shell.unregisterStartButton("HDMI-A-1", bar.item);
            focus("DP-1");
            Tour.start();
            const nobar = Tour.screen;
            Tour.stop();
            Shell.registerStartButton("HDMI-A-1", bar.item, bar.window);
            Config.stream.manual = false;
            report("tour-main-without-bar", nobar === "HDMI-A-2", "→ " + nobar);
            console.log("TEST DONE " + failures);
            Qt.quit();
        }
    }
}
