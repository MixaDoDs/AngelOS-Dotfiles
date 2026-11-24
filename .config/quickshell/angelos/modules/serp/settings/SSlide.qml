import QtQuick
import qs.services
import qs.modules.serp

// serp-skin settings: a thin track with a pill handle that carries the value inside it
Item {
    id: sl
    property int value: 0
    property int from: 0
    property int to: 100
    property string suffix: "%"
    signal moved(int v)
    implicitWidth: Serp.px(220)
    implicitHeight: Serp.px(24)
    readonly property real frac: (Math.max(from, Math.min(to, value)) - from) / Math.max(1, to - from)
    readonly property real travel: width - knob.width

    function setFrom(x) {
        const f = Math.max(0, Math.min(1, (x - knob.width / 2) / Math.max(1, travel)));
        const v = Math.round(from + f * (to - from));
        if (v !== value)
            moved(v);
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Serp.px(6)
        radius: height / 2
        color: Serp.surface2
        Rectangle {
            width: knob.x + knob.width / 2
            height: parent.height
            radius: parent.radius
            color: Serp.accent
        }
    }
    Rectangle {
        id: knob
        width: Serp.px(42)
        height: parent.height
        radius: height / 2
        x: sl.frac * sl.travel
        color: Serp.accent
        border.width: Serp.px(2)
        border.color: Serp.base
        scale: ma.pressed ? 1.06 : 1
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
        SText {
            anchors.centerIn: parent
            text: sl.value + sl.suffix
            size: Serp.px(10)
            bold: true
            color: Serp.onAccent
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: m => sl.setFrom(m.x)
        onPositionChanged: m => {
            if (pressed)
                sl.setFrom(m.x);
        }
        onWheel: w => {
            const v = Math.max(sl.from, Math.min(sl.to, sl.value + (w.angleDelta.y > 0 ? 1 : -1)));
            if (v !== sl.value)
                sl.moved(v);
        }
    }
}
