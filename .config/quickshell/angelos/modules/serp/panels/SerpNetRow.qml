import QtQuick
import qs.services
import qs.modules.serp

// serp-skin: one line of the network panel's list — icon, name, a small second line, then the
// lock / battery / connected check on the right. Selected = the accent's plate.
Item {
    id: row
    property string icon: "wifi"
    property string name: ""
    property string sub: ""
    property bool connected: false
    property bool selected: false
    property bool locked: false
    property bool busy: false
    property string badge: ""          // e.g. a battery "82%"
    property real intro: 1
    signal clicked

    implicitHeight: Serp.px(42)
    opacity: intro
    transform: Translate {
        x: (1 - row.intro) * Serp.px(18)
    }

    Rectangle {
        anchors.fill: parent
        radius: Serp.radiusSmall
        color: row.selected ? Serp.selected : ma.containsMouse ? Serp.hover : "transparent"
        border.width: row.selected ? 1 : 0
        border.color: Qt.alpha(Serp.accent, 0.35)
        Behavior on color {
            ColorAnimation {
                duration: Serp.quick
            }
        }
    }
    Rectangle {
        id: ico
        x: Serp.px(6)
        anchors.verticalCenter: parent.verticalCenter
        width: Serp.px(30)
        height: width
        radius: width / 2
        color: row.connected ? Serp.accent : Serp.surface1
        SIcon {
            anchors.centerIn: parent
            name: row.icon
            size: Serp.px(15)
            color: row.connected ? Serp.onAccent : Serp.subtext1
        }
    }
    Column {
        anchors.left: ico.right
        anchors.leftMargin: Serp.px(10)
        anchors.right: tail.left
        anchors.rightMargin: Serp.px(6)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Serp.px(1)
        SText {
            width: parent.width
            text: row.name
            size: Serp.px(12)
            bold: row.connected
            color: row.connected ? Serp.accent : Serp.text
        }
        SText {
            width: parent.width
            visible: row.sub !== ""
            text: row.sub
            size: Serp.px(9.5)
            dim: true
        }
    }
    Row {
        id: tail
        anchors.right: parent.right
        anchors.rightMargin: Serp.px(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Serp.px(6)
        SText {
            visible: row.badge !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: row.badge
            size: Serp.px(10)
            dim: true
        }
        SIcon {
            visible: row.locked
            anchors.verticalCenter: parent.verticalCenter
            name: "lock"
            size: Serp.px(12)
            color: Serp.subtext0
        }
        SIcon {
            id: spin
            visible: row.busy
            anchors.verticalCenter: parent.verticalCenter
            name: "refresh-cw"
            size: Serp.px(13)
            color: Serp.accent
            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite
                running: spin.visible
            }
        }
        Rectangle {
            visible: row.connected && !row.busy
            anchors.verticalCenter: parent.verticalCenter
            width: Serp.px(18)
            height: width
            radius: width / 2
            color: Qt.alpha(Serp.accent, 0.2)
            SIcon {
                anchors.centerIn: parent
                name: "check"
                size: Serp.px(11)
                color: Serp.accent
            }
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.clicked()
    }
}
