pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Programs nobody sees go to sleep (scripts/app-sleep.py): every window out of sight for
// windows.appSleepMin minutes, no sound, no camera, no download, idle → its scope is frozen and
// its memory pushed into zram; messengers only nap (5 % of a core, half the memory squeezed), so
// messages still come. A window seen again wakes it at once. Never: Spotify, terminals, Steam and
// games, OBS, X11 programs, windows.appSleepNever. The script wakes everything when it ends.
Singleton {
    id: root

    property var asleep: []          // [{app, how: "sleep" | "nap", units}]
    readonly property bool wanted: Config.ready && Config.windows.appSleep

    function wake() {
        if (daemon.running)
            daemon.write("wake\n");
    }

    Process {
        id: daemon
        running: root.wanted
        stdinEnabled: true
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/app-sleep.py", "--after", String(Config.windows.appSleepMin || 15), "--never", Config.windows.appSleepNever || ""]
        property real startedAt: 0
        onRunningChanged: {
            if (running)
                startedAt = Date.now();
            else
                root.asleep = [];
        }
        stdout: SplitParser {
            onRead: line => {
                try {
                    const j = JSON.parse(line);
                    if (j.asleep)
                        root.asleep = j.asleep;
                } catch (e) {}
            }
        }
        // gone at once (no niri to ask): each try waits twice as long, up to 5 minutes, not 12 a minute
        onExited: if (root.wanted) {
            restart.interval = Date.now() - startedAt < 30000 ? Math.min(restart.interval * 2, 300000) : 5000;
            restart.start();
        }
    }
    Timer {
        id: restart
        interval: 2500
        onTriggered: if (root.wanted)
            daemon.running = true
    }
}
