import QtQuick

// A theme at a glance: the desk, a window with its title strip and lines, the bar — in a
// palette (Theme.paletteFor): the wizard's look cards, the tips' theme scene.
Item {
    id: pic
    property var pal: ({})
    clip: true
    Rectangle {
        anchors.fill: parent
        color: pic.pal.desk || "#000000"
        border.width: 1
        border.color: Qt.alpha(pic.pal.text || "#ffffff", 0.3)
    }
    Rectangle {
        x: parent.width * 0.14
        y: parent.height * 0.14
        width: parent.width * 0.62
        height: parent.height * 0.56
        color: pic.pal.face || "#202020"
        Rectangle {
            width: parent.width
            height: Math.max(2, parent.height * 0.18)
            color: pic.pal.accent || "#ff69b4"
        }
        Column {
            x: parent.width * 0.1
            y: parent.height * 0.32
            spacing: Math.max(1, parent.height * 0.08)
            Repeater {
                model: [0.7, 0.5, 0.6]
                Rectangle {
                    required property real modelData
                    width: pic.width * 0.62 * 0.8 * modelData
                    height: Math.max(1, pic.height * 0.04)
                    color: pic.pal.text || "#ffffff"
                    opacity: 0.8
                }
            }
        }
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: Math.max(2, parent.height * 0.12)
        color: pic.pal.faceAlt || "#303030"
    }
}
