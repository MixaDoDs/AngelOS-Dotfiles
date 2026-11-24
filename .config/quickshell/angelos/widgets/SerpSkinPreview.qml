import QtQuick
import qs.services

// serp-skin: the little drawing on the skin's card (Settings → Appearance → Skin): a dark desk,
// three islands on top (the desks' pills, the clock, the status), a dock of tiles at the bottom —
// in the skin's own colours
Rectangle {
    id: root
    color: Serp.base
    readonly property real u: width / 100
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.alpha(Serp.accent, 0.10)
            }
            GradientStop {
                position: 1
                color: "transparent"
            }
        }
    }
    component Pill: Rectangle {
        y: root.u * 3
        height: root.u * 7
        radius: root.u * 2.2
        color: Serp.surface0
        border.width: 1
        border.color: Qt.alpha(Serp.text, 0.08)
    }
    Pill {
        x: root.u * 3
        width: root.u * 24
        Row {
            anchors.centerIn: parent
            spacing: root.u * 1.4
            Rectangle {
                width: root.u * 6
                height: root.u * 2.2
                radius: height / 2
                color: Serp.accent
            }
            Repeater {
                model: 3
                Rectangle {
                    width: root.u * 2.2
                    height: width
                    radius: width / 2
                    color: Qt.alpha(Serp.text, 0.3)
                }
            }
        }
    }
    Pill {
        x: (root.width - width) / 2
        width: root.u * 16
        Rectangle {
            anchors.centerIn: parent
            width: root.u * 8
            height: root.u * 2.4
            radius: height / 2
            color: Serp.accent
        }
    }
    Pill {
        x: root.width - width - root.u * 3
        width: root.u * 22
        Row {
            anchors.centerIn: parent
            spacing: root.u * 1.5
            Repeater {
                model: 4
                Rectangle {
                    width: root.u * 2.6
                    height: width
                    radius: root.u * 0.8
                    color: Qt.alpha(Serp.text, 0.55)
                }
            }
        }
    }
    // a window in the Strip
    Rectangle {
        x: root.u * 8
        y: root.u * 14
        width: root.u * 50
        height: root.height - root.u * 31
        radius: root.u * 2
        color: Serp.mantle
        border.width: 1
        border.color: Qt.alpha(Serp.text, 0.08)
    }
    Rectangle {
        x: root.u * 61
        y: root.u * 14
        width: root.u * 31
        height: root.height - root.u * 31
        radius: root.u * 2
        color: Serp.mantle
        border.width: 1
        border.color: Qt.alpha(Serp.text, 0.08)
    }
    // the dock
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height - height - root.u * 2.5
        width: root.u * 44
        height: root.u * 10
        radius: root.u * 3
        color: Serp.surface0
        Row {
            anchors.centerIn: parent
            spacing: root.u * 1.6
            Repeater {
                model: 6
                Rectangle {
                    width: root.u * 5.6
                    height: width
                    radius: width * 0.28
                    color: index === 1 ? Serp.accent : Serp.surface2
                }
            }
        }
    }
}
