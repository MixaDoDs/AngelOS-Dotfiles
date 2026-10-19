pragma Singleton

import QtQuick
import Quickshell
import qs.config

// The overlay process's stand-in for services/GoldenGate: the skin's switch and the measures and
// colours the overlay's buttons use (the formulas of services/GoldenGate.qml); hell from the
// shell's realm (CircleLink sets Theme.realm). The real one starts the theme export, the
// wallpapers, the angel.
Singleton {
    readonly property bool chosen: Config.ready && Config.settingsUi.skin === "goldengate"
    readonly property bool on: chosen
    readonly property bool hell: on && Theme.hell
    readonly property bool dark: hell || Theme.dark

    readonly property real s: Theme.fs
    function px(v) {
        return Math.round(v * s);
    }
    readonly property int iconSize: px(16)

    readonly property color accent: hell ? Theme.hellAccent : Theme.macAccent
    readonly property color label: hell ? Theme.hellText : dark ? Qt.rgba(1, 1, 1, 0.88) : Qt.rgba(0, 0, 0, 0.86)
    readonly property color separator: dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.1)
    readonly property color hoverBg: dark ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(0, 0, 0, 0.07)
    readonly property var lights: ["#ff5f57", "#febc2e", "#28c840"]
}
