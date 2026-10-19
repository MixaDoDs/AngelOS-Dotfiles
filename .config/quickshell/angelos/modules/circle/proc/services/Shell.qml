pragma Singleton

import QtQuick
import Quickshell
import qs.config

// The overlay process's stand-in for services/Shell (scripts/circle-proc.sh puts it in place of
// the real one): the screens, picked as the shell picks them (ANGELOS_SCREENS on dev runs, the
// main screen), and Settings, which the shell opens (CircleLink). The real one would bring half
// the shell up in this process.
Singleton {
    readonly property bool dev: Quickshell.env("ANGELOS_DEV") === "1"
    readonly property var onlyScreens: (Quickshell.env("ANGELOS_SCREENS") || "").split(",").filter(s => s !== "")
    readonly property var screens: dev && onlyScreens.length ? Quickshell.screens.filter(s => onlyScreens.includes(s.name)) : Quickshell.screens
    readonly property var widestScreen: screens.reduce((best, s) => !best || s.width > best.width ? s : best, null)
    readonly property var primaryScreen: screenByName(Config.system.primaryScreen) || widestScreen
    readonly property string primaryName: primaryScreen ? primaryScreen.name : ""

    function screenByName(name) {
        return screens.find(s => s.name === name) || null;
    }
    function openSettings(page, sub) {
        CircleLink.send({
            "t": "settings",
            "page": page || "",
            "sub": sub || ""
        });
    }
}
