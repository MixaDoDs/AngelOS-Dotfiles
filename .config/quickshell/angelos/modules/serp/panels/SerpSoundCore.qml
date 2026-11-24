import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import qs.services
import qs.modules.serp

// serp-skin: the sound panel's core (Serpantinum's VolumePopup core): an orb of liquid filled to
// the volume, its surface a wave that rolls only while `live`, a 270° gauge ring around it
// (0…150 %, the part over 100 % in peach). Drag up / down or wheel = volume, a click = mute.
// The waves are two fixed paths that only slide sideways: no geometry is rebuilt per frame.
Item {
    id: core
    property real level: 0              // 0..1.5
    property bool muted: false
    property bool live: true            // the waves roll (the panel is shown)
    property color tint: Serp.accent
    signal moved(real v)
    signal toggled

    readonly property color c: muted ? Serp.red : tint
    readonly property real fill: Math.max(0, Math.min(1, level))
    readonly property int pct: Math.round(level * 100)
    readonly property string label: muted ? "выкл" : pct + "%"
    readonly property real ringW: Serp.px(4)
    readonly property real orbD: width - Serp.px(26)

    implicitWidth: Serp.px(124)
    implicitHeight: Serp.px(124)

    // ---- the soft halo, breathing while it sounds ----
    Rectangle {
        anchors.centerIn: parent
        width: core.orbD + Serp.px(14)
        height: width
        radius: width / 2
        color: core.c
        opacity: core.muted ? 0.12 : 0.07
        Behavior on color {
            ColorAnimation {
                duration: Serp.normal
            }
        }
        SequentialAnimation on scale {
            running: core.live && !core.muted
            loops: Animation.Infinite
            NumberAnimation {
                to: 1.05
                duration: 2000
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 1
                duration: 2000
                easing.type: Easing.InOutSine
            }
        }
    }

    // ---- the gauge ring: track, 0…100 %, 100…150 % ----
    property real shownLevel: Math.max(0, Math.min(1.5, level))
    Behavior on shownLevel {
        enabled: !ma.dragging
        NumberAnimation {
            duration: Serp.normal
            easing.type: Easing.OutCubic
        }
    }
    Shape {
        id: ring
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        readonly property real r: width / 2 - core.ringW / 2 - Serp.px(1)
        ShapePath {
            strokeColor: Serp.surface1
            strokeWidth: core.ringW
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.r
                radiusY: ring.r
                startAngle: 135
                sweepAngle: 270
            }
        }
        ShapePath {
            strokeColor: core.muted ? Serp.overlay : core.tint
            strokeWidth: core.ringW
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.r
                radiusY: ring.r
                startAngle: 135
                sweepAngle: Math.max(0.1, 180 * Math.min(1, core.shownLevel))
            }
        }
        ShapePath {
            strokeColor: core.shownLevel > 1.005 ? (core.muted ? Serp.overlay : Serp.peach) : "transparent"
            strokeWidth: core.ringW
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.r
                radiusY: ring.r
                startAngle: 315
                sweepAngle: Math.max(0.1, 180 * Math.max(0, core.shownLevel - 1))
            }
        }
    }
    // the 100 % notch (two thirds round the gauge, at 315°)
    Rectangle {
        width: Serp.px(2)
        height: core.ringW + Serp.px(5)
        radius: width / 2
        x: ring.width / 2 + ring.r * Math.cos(Math.PI * 1.75) - width / 2
        y: ring.height / 2 + ring.r * Math.sin(Math.PI * 1.75) - height / 2
        rotation: 45
        color: Serp.subtext0
        opacity: 0.7
    }
    // in the ring's gap at the bottom: what the click does
    SIcon {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -Serp.px(2)
        name: core.muted || core.level === 0 ? "volume-x" : core.level < 0.5 ? "volume-1" : "volume-2"
        size: Serp.px(13)
        color: core.muted ? Serp.red : Serp.subtext0
    }

    // ---- the orb ----
    Item {
        id: orb
        anchors.centerIn: parent
        width: core.orbD
        height: width
        scale: ma.pressed ? 0.97 : ma.containsMouse ? 1.03 : 1
        Behavior on scale {
            NumberAnimation {
                duration: Serp.normal
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Serp.crust
        }

        // where the surface stands (the waves ride on it)
        property real surface: height * (1 - core.fill)
        Behavior on surface {
            enabled: !ma.dragging
            NumberAnimation {
                duration: Serp.slow
                easing.type: Easing.OutQuint
            }
        }
        readonly property real amp: Serp.px(5) * Math.max(0.25, Math.sin(core.fill * Math.PI)) * (core.fill > 0.995 ? 0 : 1)

        Item {
            id: liquid
            anchors.fill: parent
            visible: core.fill > 0
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: orbMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }
            SerpSoundWave {
                id: back
                span: orb.width
                amp: orb.amp * 0.8
                y: orb.surface - amp - Serp.px(3)
                depth: orb.height + Serp.px(8)
                hi: Qt.alpha(core.c, 0.45)
                lo: Qt.alpha(core.c, 0.3)
                NumberAnimation on x {
                    running: core.live && orb.amp > 0
                    loops: Animation.Infinite
                    from: -orb.width
                    to: 0
                    duration: 3600
                }
            }
            SerpSoundWave {
                id: front
                span: orb.width
                amp: orb.amp
                y: orb.surface - amp
                depth: orb.height + Serp.px(8)
                hi: Qt.lighter(core.c, 1.12)
                lo: core.c
                NumberAnimation on x {
                    running: core.live && orb.amp > 0
                    loops: Animation.Infinite
                    from: 0
                    to: -orb.width
                    duration: 2400
                }
            }
        }
        Item {
            id: orbMask
            anchors.fill: parent
            visible: false
            layer.enabled: true
            Rectangle {
                anchors.fill: parent
                radius: width / 2
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: Serp.px(2)
            border.color: Qt.alpha(core.c, 0.8)
            Behavior on border.color {
                ColorAnimation {
                    duration: Serp.normal
                }
            }
        }

        // the number: light over the dark, dark over the liquid
        SText {
            width: orb.width
            height: orb.height
            horizontalAlignment: Text.AlignHCenter
            text: core.label
            size: Serp.px(core.pct >= 100 && !core.muted ? 22 : 25)
            black: true
            color: core.muted ? Serp.red : Serp.text
        }
        Item {
            anchors.bottom: parent.bottom
            width: parent.width
            height: Math.max(0, parent.height - orb.surface)
            clip: true
            visible: core.fill > 0
            SText {
                width: orb.width
                height: orb.height
                horizontalAlignment: Text.AlignHCenter
                text: core.label
                size: Serp.px(core.pct >= 100 && !core.muted ? 22 : 25)
                black: true
                y: -(orb.height - parent.height)
                color: Serp.onAccent
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: orb
        enabled: core.enabled
        hoverEnabled: true
        property real y0: 0
        property real v0: 0
        property bool dragging: false
        cursorShape: dragging ? Qt.SizeVerCursor : Qt.PointingHandCursor
        onPressed: m => {
            y0 = m.y;
            v0 = core.level;
            dragging = false;
        }
        onPositionChanged: m => {
            if (!pressed)
                return;
            if (!dragging && Math.abs(m.y - y0) > Serp.px(4))
                dragging = true;
            if (dragging)
                core.moved(Math.max(0, Math.min(1.5, Math.round((v0 + (y0 - m.y) / orb.height) * 100) / 100)));
        }
        onReleased: {
            if (!dragging)
                core.toggled();
            dragging = false;
        }
        onCanceled: dragging = false
        onWheel: w => core.moved(Math.max(0, Math.min(1.5, Math.round((core.level + (w.angleDelta.y > 0 ? 0.05 : -0.05)) * 100) / 100)))
    }
}
