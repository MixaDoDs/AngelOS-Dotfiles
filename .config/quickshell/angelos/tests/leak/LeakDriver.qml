pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.modules.settings

// tests/leak/run.sh: the settings window offscreen, every page opened in turn, round after
// round. A page that leaves something behind when it goes (a Connections to a service, a
// timer, a cache that only grows) makes every round cost more; one that cleans up costs
// nothing after the first. Prints "ROUND n" after each round and rests a moment (run.sh reads
// the shell's memory then), "DONE" after the last.
Scope {
    id: root

    readonly property int rounds: parseInt(Quickshell.env("LEAK_ROUNDS") || "6")
    readonly property int dwell: parseInt(Quickshell.env("LEAK_DWELL_MS") || "120")
    property var pages: []
    property int round: 0
    property int index: -1
    property int rest: 0
    property double booted: Date.now()

    FloatingWindow {
        id: win
        implicitWidth: 1100
        implicitHeight: 780
        title: "angelOS leak test"
        color: Theme.desk

        SettingsView {
            id: view
            anchors.fill: parent
            hostWindow: win
        }
    }

    Timer {
        interval: root.dwell
        running: true
        repeat: true
        onTriggered: {
            if (root.rest > 0) {
                root.rest--;
                return;
            }
            if (root.pages.length === 0) {
                if (!(Config.ready && view.allPages.length > 0) && Date.now() - root.booted < 120000)
                    return;
                // plugin pages and the author's own come and go with things outside the shell
                root.pages = view.allPages.map(p => p.id).filter(id => !/^plugin/.test(id) && id !== "owner");
                if (root.pages.length === 0) {
                    console.log("LEAK no settings pages");
                    Qt.quit();
                    return;
                }
                console.log("LEAK pages " + root.pages.length);
            }
            root.index++;
            if (root.index < root.pages.length) {
                Shell.settingsPage = root.pages[root.index];
                return;
            }
            // the round is over: back home, the garbage collected, a rest while run.sh reads
            Shell.settingsPage = "home";
            gc();
            console.log("ROUND " + root.round);
            root.rest = Math.ceil(3000 / root.dwell);
            root.index = -1;
            root.round++;
            if (root.round >= root.rounds) {
                console.log("DONE");
                running = false;
            }
        }
    }
}
