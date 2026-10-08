import QtQuick
import qs.config
import "A11y.js" as A11y

// A button of the simple settings view's "Everyday" row, in the settings skin. Its size
// comes from the grid — every button the same width and height, the label elided:
//   classic   an angelOS bevelled box, icon and label
//   windose   a candy pill with an ink rim and a hard shadow
//   stream    a donation button: a dark chip with a coloured edge
Item {
    id: root

    property string skin: Config.settingsUi.skin || "classic"
    property string icon: ""
    property string text: ""
    property bool accent: false
    property int tint: 0                    // which chip colour (stream)
    signal clicked

    Accessible.role: Accessible.Button
    Accessible.name: A11y.name(text, root, icon)
    Accessible.focusable: true
    Accessible.onPressAction: if (enabled)
        clicked()

    readonly property bool hot: mouse.containsMouse && enabled
    readonly property bool down: mouse.pressed
    readonly property var chips: [Theme.ngoPink, Theme.ngoLilac, Theme.ngoMint]
    readonly property color chip: chips[tint % chips.length]
    opacity: enabled ? 1 : 0.45

    // ---- classic ----
    PxBox {
        visible: root.skin === "classic"
        anchors.fill: parent
        sunken: root.down
        color: root.accent ? Theme.accent : root.hot ? Theme.mix(Theme.face, Theme.accent, 0.2) : Theme.face
        shadow: false
    }
    // ---- windose ----
    Rectangle {
        visible: root.skin === "windose"
        x: Theme.u
        y: Theme.u
        width: parent.width - Theme.u
        height: parent.height - Theme.u
        radius: height / 2
        color: Qt.alpha(Theme.shadow, Theme.dark ? 0.25 : 0.12)
    }
    Rectangle {
        visible: root.skin === "windose"
        x: root.down ? Theme.u : 0
        y: root.down ? Theme.u : 0
        width: parent.width - Theme.u
        height: parent.height - Theme.u
        radius: height / 2
        color: root.accent ? Theme.windoseRose : root.hot ? Theme.windoseLavender : Theme.windoseSticker
        border.width: Math.max(1, Theme.u / 2)
        border.color: Theme.windoseLine
    }
    // ---- stream ----
    Rectangle {
        visible: root.skin === "stream"
        anchors.fill: parent
        anchors.margins: root.down ? Theme.u : 0
        radius: Theme.u * 2
        color: root.hot ? Theme.mix(Theme.streamPanel, root.chip, 0.25) : Theme.streamPanel
        border.width: Math.max(1, Theme.u / 2)
        border.color: root.accent ? Theme.streamLive : Qt.alpha(root.chip, 0.6)
        Rectangle {
            width: Theme.u * 2
            height: parent.height
            radius: Theme.u
            color: root.accent ? Theme.streamLive : root.chip
        }
    }

    Row {
        x: Theme.u * (root.skin === "windose" ? 6 : 5) + (root.down ? Theme.u : 0)
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.down ? Theme.u : 0
        width: parent.width - x - Theme.u * 4
        spacing: Theme.u * 3
        PxIcon {
            id: glyph
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon || "heart"
            ink: root.skin === "classic" ? (root.accent ? Theme.selectText : (Theme.dark ? Theme.text : Theme.edge)) : root.skin === "windose" ? Theme.windoseInk : Theme.streamText
            fill: root.skin === "classic" ? Theme.accent : root.skin === "windose" ? Theme.windoseRose : root.chip
        }
        PxText {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (glyph.visible ? glyph.width + parent.spacing : 0)
            elide: Text.ElideRight
            text: root.text
            font.bold: root.skin !== "classic" || root.accent
            color: root.skin === "classic" ? (root.accent ? Theme.selectText : Theme.text) : root.skin === "windose" ? Theme.windoseInk : Theme.streamText
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.enabled)
            root.clicked()
    }
}
