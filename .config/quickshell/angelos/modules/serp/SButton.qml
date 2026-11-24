import QtQuick
import qs.services

// serp-skin: a press target with Serpantinum's soft hover plate; `active` = the accent's plate
Item {
    id: btn
    property bool active: false
    property bool flat: true                 // no ground of its own until hovered
    property color ground: Serp.surface0
    property real radius: Serp.radiusSmall
    property int padH: Serp.px(6)
    property alias hovered: ma.containsMouse
    default property alias content: box.data
    signal clicked(var mouse)
    signal wheel(var wheel)
    implicitWidth: Math.max(Serp.px(26), box.childrenRect.width + padH * 2)
    implicitHeight: Serp.px(26)
    Rectangle {
        anchors.fill: parent
        radius: btn.radius
        color: btn.active ? Serp.selected : ma.containsMouse ? Serp.hover : btn.flat ? "transparent" : btn.ground
        Behavior on color {
            ColorAnimation {
                duration: Serp.quick
            }
        }
    }
    Item {
        id: box
        anchors.centerIn: parent
        width: childrenRect.width
        height: childrenRect.height
        scale: ma.pressed ? 0.94 : 1
        Behavior on scale {
            NumberAnimation {
                duration: Serp.quick
                easing.type: Easing.OutCubic
            }
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => btn.clicked(m)
        onWheel: w => btn.wheel(w)
    }
}
