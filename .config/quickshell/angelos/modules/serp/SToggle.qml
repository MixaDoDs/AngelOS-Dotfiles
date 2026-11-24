import QtQuick
import qs.services

// serp-skin: Serpantinum's switch — a pill track, the knob slides, the accent when on
Item {
    id: t
    property bool checked: false
    signal toggled(bool on)
    implicitWidth: Serp.px(40)
    implicitHeight: Serp.px(22)
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: t.checked ? Serp.accent : Serp.surface2
        Behavior on color {
            ColorAnimation {
                duration: Serp.normal
            }
        }
        Rectangle {
            width: parent.height - Serp.px(6)
            height: width
            radius: width / 2
            y: Serp.px(3)
            x: t.checked ? parent.width - width - Serp.px(3) : Serp.px(3)
            color: t.checked ? Serp.onAccent : Serp.subtext
            Behavior on x {
                NumberAnimation {
                    duration: Serp.normal
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: t.toggled(!t.checked)
    }
}
