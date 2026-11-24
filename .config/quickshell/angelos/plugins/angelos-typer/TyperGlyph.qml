import QtQuick
import qs.config
import qs.services
import qs.widgets

Item {
    property color ink: Skin.text
    property bool mac: Skin.mac
    implicitWidth: mac ? Skin.px(16) : Theme.u * 11
    implicitHeight: implicitWidth
    PxIcon {
        visible: !parent.mac
        anchors.centerIn: parent
        ink: parent.ink
        fill: parent.ink
        light: parent.ink
        bitmap: ["...........",".######....",".#....##...",".#....#.#..",
            ".#....###..",".#......#..",".#.####.#..",".#......#..",
            ".#.##...#..",".########..","..........."]
    }
    MacIcon { visible: parent.mac; anchors.centerIn: parent; name: "file-text"; size: Skin.px(15); color: parent.ink; stroke: 1.65 }
}
