import QtQuick

// The waiting chat's lines (Main.qml's chatModel), the newest at the bottom; only a new
// line slides in, the others stay put.
Column {
    id: root

    required property var theme              // Main.qml's root: pal, u, fonts, chatModel
    readonly property int u: theme.u
    spacing: u * 2

    Repeater {
        model: root.theme.chatModel
        Row {
            id: line
            required property string nick
            required property string msg
            required property bool bot
            required property real hue
            width: root.width
            spacing: root.u * 3
            property real slide: 1
            x: Math.round(slide * root.u * 20)
            opacity: 1 - slide
            NumberAnimation on slide {
                from: 1
                to: 0
                duration: 160
            }
            Text {
                id: who
                text: (line.bot ? "✦ " : "") + line.nick + ":"
                color: line.bot ? root.theme.pal.accent : Qt.hsla(line.hue, 0.7, 0.7, 1)
                font.family: root.theme.bodyFont
                font.pixelSize: root.theme.bodyPx(13)
                font.bold: true
                renderType: Text.NativeRendering
            }
            Text {
                width: Math.max(0, line.width - who.width - line.spacing)
                text: line.msg
                elide: Text.ElideRight
                color: root.theme.pal.text
                font.family: root.theme.bodyFont
                font.pixelSize: root.theme.bodyPx(13)
                renderType: Text.NativeRendering
            }
        }
    }
}
