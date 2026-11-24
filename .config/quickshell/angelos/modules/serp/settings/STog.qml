import QtQuick
import qs.services

// serp-skin settings: Serpantinum's Toggle — a 44×24 pill, the knob springs across (OutBack)
Item {
    id: t
    property bool checked: false
    signal toggled(bool on)
    implicitWidth: Serp.px(44)
    implicitHeight: Serp.px(24)
    scale: ma.containsMouse ? 1.04 : 1
    Behavior on scale {
        NumberAnimation {
            duration: Serp.quick
            easing.type: Easing.OutCubic
        }
    }
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
            readonly property real inset: Serp.px(3)
            width: parent.height - inset * 2
            height: width
            radius: width / 2
            y: inset
            x: t.checked ? parent.width - width - inset : inset
            color: t.checked ? Serp.onAccent : Serp.subtext1
            Behavior on x {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.2
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Serp.normal
                }
            }
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: t.toggled(!t.checked)
    }
}
