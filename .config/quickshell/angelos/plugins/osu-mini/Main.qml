import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets

// The game window, opened from Start, the launcher, the desktop menu or IPC.
Item {
    id: root
    property var plugin
    signal demoRequested

    IpcHandler {
        target: "osu"
        function start(): void {
            Shell.gameOpen = true;
        }
        function stop(): void {
            Shell.gameOpen = false;
        }
        // the game plays itself
        function demo(): void {
            Shell.gameOpen = true;
            Qt.callLater(() => root.demoRequested());
        }
    }

    LazyLoader {
        active: Shell.gameOpen && !!root.plugin
        FloatingWindow {
            id: win
            title: Shell.appTitle + " · osu!mini"
            visible: true
            implicitWidth: 1000
            implicitHeight: 680
            minimumSize: Qt.size(640, 460)
            color: Theme.desk
            onClosed: Shell.gameOpen = false
            onVisibleChanged: if (!visible)
                Shell.gameOpen = false

            // ♡ the hearts (Game) or ♪ the rhythm mode (Rhythm), as last picked; the Halo's «Ритм»
            // and `angelos rhythm` (Shell.gameAsk = "rhythm") go straight into a round
            property string mode: root.plugin.get("mode", "hearts")
            function pick(m) {
                mode = m;
                root.plugin.set("mode", m);
            }
            function ask() {
                if (Shell.gameAsk !== "rhythm")
                    return;
                Shell.gameAsk = "";
                pick("rhythm");
                Qt.callLater(() => game.item.start(false));
            }
            Component.onCompleted: ask()
            // `qs ipc call osu demo`: the hearts play themselves
            Connections {
                target: root
                function onDemoRequested() {
                    win.pick("hearts");
                    Qt.callLater(() => game.item.start(true));
                }
            }
            Connections {
                target: Shell
                function onGameAskChanged() {
                    win.ask();
                }
            }
            Loader {
                id: game
                anchors.fill: parent
                focus: true
                sourceComponent: win.mode === "rhythm" ? rhythm : hearts
            }
            Component {
                id: hearts
                Game {
                    plugin: root.plugin
                    onQuitRequested: Shell.gameOpen = false
                    onModeRequested: m => win.pick(m)
                }
            }
            Component {
                id: rhythm
                Rhythm {
                    plugin: root.plugin
                    onQuitRequested: Shell.gameOpen = false
                    onModeRequested: m => win.pick(m)
                }
            }

            RightClickGuard {}
        }
    }
}
