pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// Idle screen (screensaver) in the spirit of Omarchy: animated ASCII art on a
// dark screen, any key or mouse movement brings the desktop back.
Singleton {
    id: root

    property bool active: false
    property bool preview: false        // started by hand from Settings: any input exits
    readonly property var effects: ["decrypt", "rain", "beams", "wave", "typewriter", "hearts", "glitch"]
    readonly property string defaultArt: [
        "                           ·  ˚ ♡ ˚  ·",
        " █████╗ ███╗   ██╗ ██████╗ ███████╗██╗      ██████╗ ███████╗",
        "██╔══██╗████╗  ██║██╔════╝ ██╔════╝██║     ██╔═══██╗██╔════╝",
        "███████║██╔██╗ ██║██║  ███╗█████╗  ██║     ██║   ██║███████╗",
        "██╔══██║██║╚██╗██║██║   ██║██╔══╝  ██║     ██║   ██║╚════██║",
        "██║  ██║██║ ╚████║╚██████╔╝███████╗███████╗╚██████╔╝███████║",
        "╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚══════╝ ╚═════╝ ╚══════╝",
        "",
        "        ♡ ~ internet angel operating system ~ ♡"
    ].join("\n")
    readonly property string text: (Config.idle.text || "").replace(/\t/g, "    ").trim() !== "" ? Config.idle.text.replace(/\t/g, "    ") : defaultArt

    function start() {
        if (Shell.locked)
            return;
        Shell.closeStart();
        Shell.launcherOpen = false;
        Shell.sessionOpen = false;
        active = true;
    }
    function stop() {
        active = false;
    }
    function toggle() {
        if (active)
            stop();
        else
            start();
    }

    // lock always wins: the lock surface replaces the idle screen
    Connections {
        target: Shell
        function onLockedChanged() {
            if (Shell.locked)
                root.stop();
        }
    }

    IdleWatch {
        enabled: Config.idle.minutes > 0 && !root.active && !Shell.locked && !Shell.setupLocked
        timeout: Math.max(1, Config.idle.minutes) * 60
        respectInhibitors: true
        onIsIdleChanged: if (isIdle)
            root.start()
    }
}
