import QtQuick
import qs.services

// serp-skin: the slim slider of the sound panel's rows (Serpantinum's Draggable): a thin rail,
// the filled part in the tab's colour, a round handle; drag or wheel. value 0..1
Item {
    id: sl
    property real value: 0
    property color tint: Serp.accent
    property bool muted: false
    readonly property bool dragging: ma.pressed
    signal moved(real v)
    implicitWidth: Serp.px(200)
    implicitHeight: Serp.px(18)
    readonly property real knob: Serp.px(16)
    readonly property real frac: Math.max(0, Math.min(1, value))
    function setFrom(x) {
        sl.moved(Math.round(Math.max(0, Math.min(1, (x - knob / 2) / Math.max(1, width - knob))) * 100) / 100);
    }

    Rectangle {
        id: rail
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Serp.px(6)
        radius: height / 2
        color: Serp.surface1
        Rectangle {
            height: parent.height
            radius: parent.radius
            width: handle.x + sl.knob / 2
            color: sl.muted ? Serp.surface2 : sl.tint
            Behavior on color {
                ColorAnimation {
                    duration: Serp.normal
                }
            }
        }
    }
    Rectangle {
        id: handle
        anchors.verticalCenter: parent.verticalCenter
        x: sl.frac * (sl.width - sl.knob)
        width: sl.knob
        height: width
        radius: width / 2
        color: sl.muted ? Serp.overlay : ma.pressed ? Serp.text : Qt.lighter(sl.tint, 1.15)
        border.width: 1
        border.color: Qt.alpha(Serp.crust, 0.4)
        scale: ma.pressed ? 1.15 : ma.containsMouse ? 1.08 : 1
        Behavior on x {
            enabled: !ma.pressed
            NumberAnimation {
                duration: Serp.normal
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Serp.quick
            }
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.topMargin: -Serp.px(4)
        anchors.bottomMargin: -Serp.px(4)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: m => sl.setFrom(m.x)
        onPositionChanged: m => {
            if (pressed)
                sl.setFrom(m.x);
        }
        onWheel: w => sl.moved(Math.max(0, Math.min(1, Math.round((sl.value + (w.angleDelta.y > 0 ? 0.05 : -0.05)) * 100) / 100)))
    }
}
