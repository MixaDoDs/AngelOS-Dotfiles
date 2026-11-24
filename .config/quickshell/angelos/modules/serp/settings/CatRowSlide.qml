import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.serp

// serp-skin settings: a catalog slider (CatSlider) in Serpantinum's look — a thin track, the
// accent up to a pill that carries the value. Real values (from/to/stepSize/decimals/valueScale),
// `live`, moved while dragging and released when let go; as PxSlider, `value` is never assigned:
// what the pointer set shows until the owner's binding answers.
Item {
    id: sl
    property real from: 0
    property real to: 1
    property real value: 0
    property real stepSize: 0
    property bool live: true
    property string suffix: ""
    property int decimals: 0
    property bool showValue: true
    property real valueScale: 1
    property color fill: Serp.accent
    signal moved(real value)
    signal released(real value)

    property real _held: NaN
    readonly property real shown: isNaN(_held) ? value : _held
    onValueChanged: if (!ma.pressed)
        _held = NaN
    readonly property real frac: to === from ? 0 : Math.max(0, Math.min(1, (shown - from) / (to - from)))
    readonly property real travel: width - knob.width

    implicitWidth: Serp.px(220)
    implicitHeight: Serp.px(24)

    function valueAt(x) {
        const f = Math.max(0, Math.min(1, (x - knob.width / 2) / Math.max(1, travel)));
        let v = from + f * (to - from);
        if (stepSize > 0)
            v = Math.round((v - from) / stepSize) * stepSize + from;
        return Math.max(Math.min(from, to), Math.min(Math.max(from, to), v));
    }
    function nudge(dir) {
        const step = stepSize > 0 ? stepSize : (to - from) / 50;
        const v = Math.max(Math.min(from, to), Math.min(Math.max(from, to), shown + dir * step));
        _held = v;
        moved(v);
        released(v);
        letGo.restart();
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Serp.px(6)
        radius: height / 2
        color: Serp.surface2
        Rectangle {
            width: Math.max(parent.height, knob.x + knob.width / 2)
            height: parent.height
            radius: parent.radius
            color: sl.fill
        }
    }
    Rectangle {
        id: knob
        width: sl.showValue ? Math.max(Serp.px(42), valueText.implicitWidth + Serp.px(16)) : Serp.px(20)
        height: sl.showValue ? parent.height : Serp.px(20)
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        x: sl.frac * sl.travel
        color: sl.fill
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
            id: valueText
            visible: sl.showValue
            anchors.centerIn: parent
            text: (sl.shown * sl.valueScale).toFixed(sl.decimals) + sl.suffix
            size: Serp.px(10)
            bold: true
            color: Serp.onAccent
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.topMargin: -Serp.px(6)
        anchors.bottomMargin: -Serp.px(6)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        property bool dragOpen: false
        function apply(mx) {
            const v = sl.valueAt(mx);
            if (sl.live)
                sl._held = v;
            sl.moved(v);
        }
        onPressed: m => {
            dragOpen = true;
            apply(m.x);
        }
        onPositionChanged: m => {
            if (pressed)
                apply(m.x);
        }
        onReleased: m => {
            dragOpen = false;
            const v = sl.valueAt(m.x);
            sl._held = v;
            sl.released(v);
            letGo.restart();
        }
        onCanceled: {
            if (!dragOpen)
                return;
            dragOpen = false;
            sl.released(sl.shown);
            letGo.restart();
        }
        // only once the pointer rests on it: scrolling the page past it doesn't turn it
        onWheel: w => {
            const n = gate.steps(w);
            if (n !== 0)
                sl.nudge(n);
        }
        WheelGate {
            id: gate
            hovered: ma.containsMouse
            held: ma.pressed
        }
    }
    Timer {
        id: letGo
        interval: 2000
        onTriggered: if (!ma.pressed)
            sl._held = NaN
    }
}
