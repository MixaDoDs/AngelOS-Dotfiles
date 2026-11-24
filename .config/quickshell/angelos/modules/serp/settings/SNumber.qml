import QtQuick
import qs.services
import qs.modules.serp

// serp-skin settings: Serpantinum's NumberSelector — −  value  +, held buttons repeat
Row {
    id: ns
    property int value: 0
    property int from: 0
    property int to: 100
    property int stepSize: 1
    property string suffix: ""
    signal picked(int v)
    spacing: Serp.px(6)

    function nudge(dir) {
        const v = Math.max(from, Math.min(to, value + dir * stepSize));
        if (v !== value)
            picked(v);
    }

    component Step: Rectangle {
        id: st
        property int dir: 1
        readonly property bool can: st.dir > 0 ? ns.value < ns.to : ns.value > ns.from
        width: Serp.px(28)
        height: Serp.px(28)
        radius: Serp.radiusSmall
        color: ma.containsMouse && can ? Serp.surface2 : Serp.surface1
        opacity: can ? 1 : 0.45
        scale: ma.pressed ? 0.92 : 1
        Behavior on scale {
            NumberAnimation {
                duration: Serp.quick
                easing.type: Easing.OutCubic
            }
        }
        SIcon {
            anchors.centerIn: parent
            name: st.dir > 0 ? "plus" : "minus"
            size: Serp.px(14)
        }
        // first step on press, then a pause, then a quick repeat while held
        Timer {
            id: rep
            interval: 380
            repeat: true
            onTriggered: {
                interval = 70;
                ns.nudge(st.dir);
            }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: {
                ns.nudge(st.dir);
                rep.interval = 380;
                rep.start();
            }
            onReleased: rep.stop()
            onCanceled: rep.stop()
        }
    }

    Step {
        dir: -1
    }
    SText {
        width: Serp.px(46)
        height: Serp.px(28)
        horizontalAlignment: Text.AlignHCenter
        text: ns.value + ns.suffix
        bold: true
    }
    Step {
        dir: 1
    }
}
