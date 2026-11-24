import QtQuick
import qs.services

// serp-skin: a thick rounded slider (Serpantinum's quick actions): the filled part in the
// accent, an icon riding inside it; drag or wheel
Item {
    id: sl
    property real value: 0          // 0..1
    property string icon: ""
    property color fill: Serp.accent
    signal moved(real v)
    implicitHeight: Serp.px(34)
    implicitWidth: Serp.px(220)
    function setFrom(x) {
        sl.moved(Math.max(0, Math.min(1, x / width)));
    }
    Rectangle {
        anchors.fill: parent
        radius: Serp.radiusSmall
        color: Serp.surface1
        clip: true
        Rectangle {
            width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, sl.value)))
            height: parent.height
            radius: parent.radius
            color: sl.fill
            Behavior on width {
                enabled: !ma.pressed
                NumberAnimation {
                    duration: Serp.normal
                    easing.type: Easing.OutCubic
                }
            }
        }
        SIcon {
            visible: sl.icon !== ""
            name: sl.icon
            anchors.verticalCenter: parent.verticalCenter
            x: Serp.px(10)
            size: Serp.px(16)
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
        onWheel: w => sl.moved(Math.max(0, Math.min(1, sl.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
