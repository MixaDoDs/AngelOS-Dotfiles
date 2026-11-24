import QtQuick
import qs.config
import qs.services  // serp-skin

// The coloured square a settings section wears in the sidebar and in link cards (like
// macOS's): a pixel tile in the section's tint with its icon in white.
Rectangle {
    id: root

    property string icon: "gear"
    property color tint: Theme.accent
    property int size: Theme.u * 11
    // how much of the tile the icon takes (a big tile: a title plate's badge, less)
    property real iconFill: 1

    // serp-skin: the skin's accent, rounded, flat
    readonly property color face: Serp.on ? Serp.accent : tint  // serp-skin
    width: size
    height: size
    color: face  // serp-skin
    radius: Serp.on ? Serp.radiusSmall : 0  // serp-skin
    border.width: Serp.on ? 0 : Math.max(1, Theme.u / 2)  // serp-skin
    border.color: Qt.darker(tint, 1.45)
    // a lighter top edge, the pixel bevel
    Rectangle {
        x: root.border.width
        y: root.border.width
        width: root.width - root.border.width * 2
        height: Math.max(1, Theme.u / 2)
        visible: !Serp.on  // serp-skin
        color: Qt.lighter(root.tint, 1.35)
    }
    PxIcon {
        anchors.centerIn: parent
        name: root.icon
        // a 9-pixel icon filling the tile, a pixel of the tint around it
        pixel: Math.max(1, Math.floor((root.size * root.iconFill - Theme.u * 2) / 9))
        // white outline, the fills a lighter tint, the body a darker one: reads on any tint
        ink: Serp.on ? Serp.onAccent : "#ffffff"  // serp-skin
        fill: Qt.lighter(root.face, 1.45)  // serp-skin: face (= tint without the skin)
        fill2: Qt.lighter(root.face, 1.3)
        fill3: Qt.lighter(root.face, 1.6)
        light: Qt.lighter(root.face, 1.8)
        bad: Serp.on ? Serp.onAccent : "#ffffff"
        body: Qt.darker(root.face, 1.3)
    }
}
