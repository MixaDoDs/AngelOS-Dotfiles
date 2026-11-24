import QtQuick
import qs.services
import qs.modules.serp

// serp-skin settings: Serpantinum's ThemePresetTile — the preset in its own colours: its base
// as the ground, its text for the name, six dots of its roles. "wallpaper" wears the wallpaper.
Item {
    id: tile
    property string pid: ""
    readonly property var p: Serp.paletteOf(pid)
    readonly property bool selected: Serp.cfg.palette === pid
    readonly property bool wall: pid === "wallpaper"
    readonly property color ink: p.text
    height: Serp.px(60)
    scale: ma.pressed ? 0.96 : ma.containsMouse ? 1.03 : 1
    Behavior on scale {
        NumberAnimation {
            duration: Serp.quick
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Serp.radiusSmall
        color: tile.p.base
    }
    Loader {
        anchors.fill: parent
        active: tile.wall && Serp.wallFile !== ""
        sourceComponent: RoundImage {
            source: Serp.wallFile
            radius: Serp.radiusSmall
            blur: 0.7
            brightness: -0.35
            sourceWidth: 240
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: Serp.radiusSmall
        color: Qt.alpha(tile.ink, tile.selected ? 0.15 : ma.containsMouse ? 0.08 : 0)
        border.width: tile.selected ? 1.5 : 1
        border.color: tile.selected ? Serp.mauve : Qt.alpha(tile.ink, 0.08)
        Behavior on color {
            ColorAnimation {
                duration: Serp.quick
            }
        }
    }
    SText {
        x: Serp.px(10)
        y: Serp.px(9)
        width: parent.width - Serp.px(20) - (tile.selected ? Serp.px(16) : 0)
        text: tile.p.name || tile.pid
        size: Serp.px(11)
        bold: tile.selected
        color: tile.ink
    }
    SIcon {
        visible: tile.selected
        anchors.right: parent.right
        anchors.rightMargin: Serp.px(9)
        y: Serp.px(10)
        name: "check"
        size: Serp.px(12)
        color: tile.ink
    }
    Row {
        x: Serp.px(10)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Serp.px(10)
        spacing: Serp.px(4)
        Repeater {
            model: ["text", "blue", "mauve", "peach", "green", "red"]
            delegate: Rectangle {
                required property string modelData
                width: Serp.px(8)
                height: width
                radius: width / 2
                color: tile.p[modelData] || "transparent"
            }
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Serp.cfg.palette = tile.pid
    }
}
