import QtQuick
import qs.config

// The coloured square a settings section wears in the sidebar and in link cards (like
// macOS's): a pixel tile in the section's tint with its icon in white.
Rectangle {
    id: root

    property string icon: "gear"
    property color tint: Theme.accent
    property int size: Theme.u * 11
    // how much of the tile the icon takes (a big tile: a title plate's badge, less)
    property real iconFill: 1

    width: size
    height: size
    color: tint
    border.width: Math.max(1, Theme.u / 2)
    border.color: Qt.darker(tint, 1.45)
    // a lighter top edge, the pixel bevel
    Rectangle {
        x: root.border.width
        y: root.border.width
        width: root.width - root.border.width * 2
        height: Math.max(1, Theme.u / 2)
        color: Qt.lighter(root.tint, 1.35)
    }
    PxIcon {
        anchors.centerIn: parent
        name: root.icon
        // a 9-pixel icon filling the tile, a pixel of the tint around it
        pixel: Math.max(1, Math.floor((root.size * root.iconFill - Theme.u * 2) / 9))
        // white outline, the fills a lighter tint, the body a darker one: reads on any tint
        ink: "#ffffff"
        fill: Qt.lighter(root.tint, 1.45)
        fill2: Qt.lighter(root.tint, 1.3)
        fill3: Qt.lighter(root.tint, 1.6)
        light: Qt.lighter(root.tint, 1.8)
        bad: "#ffffff"
        body: Qt.darker(root.tint, 1.3)
    }
}
