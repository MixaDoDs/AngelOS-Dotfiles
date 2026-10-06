pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.widgets

// The streamer's webcam on the lock's stream: the angel in her room (LockAngel), framed
// from the waist up. She sleeps while nobody is there, wakes when you type, shuts her
// eyes on the password, cries at a mistake and cheers at the unlock.
PxWindow {
    id: root

    required property var lockScope
    readonly property alias angel: angel
    title: I18n.exe("cam")
    icon: "eye"
    compact: true
    closable: false
    height: titleHeight + Theme.u * 96 + Theme.pad * 2 + Theme.u * 6

    Item {
        id: room
        width: parent.width
        height: Theme.u * 96
        clip: true

        // her room: a wall in the theme's colours, a window with the night or the day, a shelf
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.mix(Theme.desk, Theme.accent2, 0.25)
                }
                GradientStop {
                    position: 1
                    color: Theme.mix(Theme.desk, Theme.accent, 0.3)
                }
            }
        }
        Rectangle {
            x: parent.width * 0.62
            y: Theme.u * 8
            width: Theme.u * 34
            height: Theme.u * 30
            color: new Date().getHours() < 6 || new Date().getHours() >= 20 ? "#1a1640" : "#9fd3ff"
            border.width: Theme.u * 2
            border.color: Theme.edge
            Rectangle {
                anchors.centerIn: parent
                width: Theme.u * 2
                height: parent.height
                color: Theme.edge
            }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: Theme.u * 2
                color: Theme.edge
            }
        }
        Rectangle {
            x: Theme.u * 6
            y: Theme.u * 22
            width: Theme.u * 30
            height: Theme.u * 3
            color: Theme.edge
        }
        Repeater {
            model: 3
            Rectangle {
                required property int index
                x: Theme.u * (9 + index * 9)
                y: Theme.u * (12 + index % 2 * 2)
                width: Theme.u * 6
                height: Theme.u * (10 - index % 2 * 2)
                color: [Theme.accent, Theme.accent2, Theme.accent3][index]
                border.width: Math.max(1, Theme.u / 2)
                border.color: Theme.edge
            }
        }

        LockAngel {
            id: angel
            lockScope: root.lockScope
            // waist up: her body a little taller than the frame
            px: Math.max(1, room.height * 1.35 / 120)
            x: Math.round((room.width - width) / 2)
            y: Math.round(room.height * 0.1)
        }

        // REC and what she says
        Row {
            x: Theme.u * 4
            y: Theme.u * 4
            spacing: Theme.u * 2
            Rectangle {
                width: Theme.u * 4
                height: width
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.danger
                opacity: Math.floor(angel.tick / 5) % 2 ? 1 : 0.3
            }
            PxText {
                text: "REC"
                kind: "tiny"
                color: "#ffffff"
                style: Text.Outline
                styleColor: Theme.edge
                font.bold: true
            }
        }
        PxBox {
            visible: angel.say !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.u * 3
            width: Math.min(room.width - Theme.u * 8, sayText.implicitWidth + Theme.u * 8)
            height: sayText.implicitHeight + Theme.u * 4
            color: Qt.alpha(Theme.face, 0.92)
            PxText {
                id: sayText
                anchors.centerIn: parent
                width: Math.min(implicitWidth, room.width - Theme.u * 16)
                elide: Text.ElideRight
                text: angel.say
                kind: "tiny"
            }
        }
        // scanlines: it's a camera
        Column {
            anchors.fill: parent
            opacity: 0.1
            spacing: Theme.u
            Repeater {
                model: Math.ceil(room.height / (Theme.u * 2))
                Rectangle {
                    width: room.width
                    height: Theme.u
                    color: "#000000"
                }
            }
        }
    }
}
