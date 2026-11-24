import QtQuick
import qs.services
import qs.modules.serp

// serp-skin: one satellite on the network orbit (SerpNetOrbit) — a round chip with the network's
// or the device's icon, a lock badge, the accent when it is the connected one, a ring when it is
// the selected one; hover lifts it and shows its name under it. The item's size is the dot only
// (the orbit centres it on its point), the name hangs below it.
Item {
    id: node
    property string icon: "wifi"
    property string label: ""
    property bool connected: false
    property bool selected: false
    property bool locked: false
    property bool busy: false
    property real depth: 1            // 0 = far side of the orbit, 1 = near side
    property real intro: 1
    readonly property alias hovered: ma.containsMouse
    signal clicked

    implicitWidth: Serp.px(40)
    implicitHeight: Serp.px(40)

    property real lift: hovered ? 1 : 0
    Behavior on lift {
        NumberAnimation {
            duration: Serp.normal
            easing.type: Easing.OutCubic
        }
    }
    opacity: intro * (0.55 + 0.45 * depth + 0.45 * lift)
    scale: intro * (0.82 + 0.18 * depth + 0.16 * lift)

    // the soft halo of the connected / hovered one
    Rectangle {
        anchors.centerIn: dot
        width: dot.width + Serp.px(14)
        height: width
        radius: width / 2
        color: Qt.alpha(node.connected ? Serp.accent : Serp.text, node.connected ? 0.16 : 0.06)
        opacity: node.connected || node.lift > 0 ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Serp.normal
            }
        }
    }
    Rectangle {
        id: dot
        width: parent.width
        height: parent.height
        y: -Serp.px(4) * node.lift
        radius: width / 2
        gradient: Gradient {
            GradientStop {
                position: 0
                color: node.connected ? Qt.lighter(Serp.accent, 1.12) : node.lift > 0.5 ? Serp.surface2 : Serp.surface1
            }
            GradientStop {
                position: 1
                color: node.connected ? Serp.accent : Serp.surface0
            }
        }
        border.width: node.selected ? Serp.px(2) : 1
        border.color: node.selected ? Serp.accent : node.connected ? Qt.lighter(Serp.accent, 1.2) : Serp.line
        Behavior on border.color {
            ColorAnimation {
                duration: Serp.normal
            }
        }
        SIcon {
            anchors.centerIn: parent
            name: node.icon
            size: Serp.px(17)
            color: node.connected ? Serp.onAccent : node.selected ? Serp.accent : Serp.subtext1
        }
        // lock badge
        Rectangle {
            visible: node.locked
            width: Serp.px(15)
            height: width
            radius: width / 2
            x: parent.width - width + Serp.px(2)
            y: parent.height - height + Serp.px(2)
            color: Serp.base
            border.width: 1
            border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
            SIcon {
                anchors.centerIn: parent
                name: "lock"
                size: Serp.px(9)
                color: Serp.subtext0
            }
        }
        // connecting: a turning ring of the accent
        Rectangle {
            visible: node.busy
            anchors.fill: parent
            anchors.margins: -Serp.px(4)
            radius: width / 2
            color: "transparent"
            border.width: Serp.px(2)
            border.color: Qt.alpha(Serp.accent, 0.25)
            Rectangle {
                width: Serp.px(6)
                height: width
                radius: width / 2
                color: Serp.accent
                x: parent.width / 2 - width / 2
                y: -Serp.px(2)
            }
            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 1100
                loops: Animation.Infinite
                running: node.busy && node.visible
            }
        }
    }
    // the name: the connected one and the hovered / selected one only (the list has the rest)
    Rectangle {
        readonly property bool shown: node.connected || node.selected || node.lift > 0
        anchors.horizontalCenter: dot.horizontalCenter
        y: dot.y + dot.height + Serp.px(5)
        width: Math.min(Serp.px(130), name.implicitWidth + Serp.px(12))
        height: Serp.px(18)
        radius: height / 2
        color: Qt.alpha(Serp.crust, 0.85)
        border.width: 1
        border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
        opacity: shown ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Serp.normal
            }
        }
        visible: opacity > 0.01 && node.label !== ""
        SText {
            id: name
            anchors.centerIn: parent
            width: Math.min(implicitWidth, Serp.px(118))
            text: node.label
            size: Serp.px(10)
            bold: node.connected
            color: node.connected ? Serp.accent : Serp.text
        }
    }
    MouseArea {
        id: ma
        anchors.fill: dot
        anchors.margins: -Serp.px(4)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: node.clicked()
    }
}
