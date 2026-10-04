import QtQuick

// A tiny Golden Gate desktop — the menu bar, a window with traffic lights, the Dock — for the
// cards that offer the skin (the setup wizard's "Coming from a Mac?").
Rectangle {
    id: root
    implicitWidth: 160
    implicitHeight: 100
    radius: Math.max(2, width * 0.03)
    clip: true
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop {
            position: 0
            color: "#e9dcc6"
        }
        GradientStop {
            position: 0.55
            color: "#b7b0c8"
        }
        GradientStop {
            position: 1
            color: "#8f9cb2"
        }
    }
    Rectangle {
        width: parent.width
        height: Math.max(3, parent.height * 0.08)
        color: Qt.rgba(1, 1, 1, 0.35)
    }
    Rectangle {
        x: parent.width * 0.16
        y: parent.height * 0.2
        width: parent.width * 0.62
        height: parent.height * 0.5
        radius: Math.max(2, width * 0.05)
        color: "#f5f5f7"
        Row {
            x: parent.width * 0.05
            y: parent.height * 0.08
            spacing: Math.max(1, parent.width * 0.025)
            Repeater {
                model: ["#ff5f57", "#d1d1d6", "#28c840"]
                Rectangle {
                    required property string modelData
                    width: Math.max(2, root.width * 0.035)
                    height: width
                    radius: width / 2
                    color: modelData
                }
            }
        }
        Rectangle {
            y: parent.height * 0.22
            width: parent.width * 0.3
            height: parent.height * 0.78
            color: "#e8e8ea"
            bottomLeftRadius: parent.radius
        }
    }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.8
        width: parent.width * 0.56
        height: parent.height * 0.13
        radius: height * 0.35
        color: Qt.rgba(1, 1, 1, 0.55)
        Row {
            anchors.centerIn: parent
            spacing: Math.max(1, root.width * 0.02)
            Repeater {
                model: ["#2f8cff", "#ffffff", "#ff7a2f", "#8a8a90", "#4cd964"]
                Rectangle {
                    required property string modelData
                    width: root.height * 0.08
                    height: width
                    radius: width * 0.25
                    color: modelData
                }
            }
        }
    }
}
