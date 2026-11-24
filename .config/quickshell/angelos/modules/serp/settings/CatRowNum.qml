import QtQuick
import qs.services
import qs.modules.serp

// serp-skin settings: a catalog number (CatSpin) as Serpantinum's NumberSelector — −  value  +,
// held buttons repeat. Real steps and decimals (SNumber is whole numbers only).
Row {
    id: ns
    property real value: 0
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property int decimals: 0
    property string suffix: ""
    signal moved(real v)
    spacing: Serp.px(6)

    function nudge(dir) {
        const step = stepSize > 0 ? stepSize : 1;
        let v = Math.max(from, Math.min(to, value + dir * step));
        v = Number(v.toFixed(Math.max(decimals, 6)));
        if (v !== value)
            moved(v);
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
        width: Math.max(Serp.px(46), implicitWidth)
        height: Serp.px(28)
        horizontalAlignment: Text.AlignHCenter
        text: ns.value.toFixed(ns.decimals) + ns.suffix
        bold: true
    }
    Step {
        dir: 1
    }
}
