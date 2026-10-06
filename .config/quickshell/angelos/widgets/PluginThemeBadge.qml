import QtQuick
import qs.config
import qs.services

// The themes a plugin draws, as a small badge: "macOS", "Pixel" or "both themes"
// (Plugins.themesOf: manifest "themes", a registry entry's "themes"; none declared — Pixel).
// In the accent when it fits the look in use, red when it doesn't. Pixel: a square outlined tag;
// the Mac look (settingsSkin "goldengate"): a rounded pill.
Item {
    id: root

    property var plugin: null
    readonly property bool mac: Theme.settingsSkinFor(parent) === "goldengate"
    readonly property bool fits: Plugins.supportsCurrent(plugin)
    readonly property color tint: fits ? Theme.accent : Theme.danger

    implicitWidth: label.implicitWidth + (mac ? GoldenGate.px(14) : Theme.u * 6)
    implicitHeight: label.implicitHeight + (mac ? GoldenGate.px(4) : Theme.u * 2)

    Rectangle {
        anchors.fill: parent
        radius: root.mac ? height / 2 : 0
        color: Qt.alpha(root.tint, root.mac ? 0.14 : 0.12)
        border.width: root.mac ? 0 : Math.max(1, Theme.u / 2)
        border.color: root.tint
    }
    PxText {
        id: label
        anchors.centerIn: parent
        kind: "tiny"
        text: Plugins.themeLabel(root.plugin)
        color: root.tint
        font.bold: true
    }
}
