pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.services
import qs.modules.serp

// serp-skin: Serpantinum's network orbit — this PC (the adapter) is the core in the middle, the
// networks / devices circle it on three tilted rings (the strongest closest), the near half of a
// ring passes in front of the core, the far half behind it. The connected one is tied to the core
// by a line of the accent with a spark running along it. Only Items and static Shapes: the rings
// are drawn once, the satellites just move. The slow turn runs only while `running`.
Item {
    id: orb
    // [{key, obj, ring 0..2, angle, icon, label, connected, locked, busy}]
    property var model: []
    property var selected: null
    property string centerIcon: "monitor"
    property string centerLabel: ""
    property string centerSub: ""
    property bool live: false          // the core lit (connected / powered)
    property bool off: false           // the radio is off: everything dims
    property bool pulsing: false       // scanning: waves go out of the core
    property bool running: false       // the slow turn
    property real intro: 1
    signal picked(var obj)
    signal coreClicked

    function st(d) {
        return Math.max(0, Math.min(1, (intro - d) / Math.max(0.01, 1 - d)));
    }
    function ease(t) {
        return 1 - Math.pow(1 - t, 3);
    }

    readonly property real cx: width / 2
    readonly property real cy: height / 2 - Serp.px(4)
    readonly property real tilt: 0.56
    readonly property real maxR: Math.max(Serp.px(60), Math.min(width / 2 - Serp.px(26), (height / 2 - Serp.px(36)) / tilt))
    readonly property var radii: [maxR * 0.52, maxR * 0.76, maxR]
    readonly property var speeds: [1, 0.72, 0.5]

    property real spin: 0
    NumberAnimation on spin {
        from: 0
        to: Math.PI * 2
        duration: 140000
        loops: Animation.Infinite
        running: true
        paused: !orb.running
    }

    function angleOf(m) {
        return m.angle + spin * speeds[m.ring];
    }

    // a faint glow under the core
    Rectangle {
        width: orb.radii[1] * 2
        height: width * orb.tilt
        radius: height / 2
        x: orb.cx - width / 2
        y: orb.cy - height / 2
        opacity: orb.ease(orb.st(0)) * (orb.off ? 0.3 : 1)
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 0.5
                color: Qt.alpha(orb.live ? Serp.accent : Serp.text, 0.05)
            }
            GradientStop {
                position: 1
                color: "transparent"
            }
        }
    }

    // the rings
    Repeater {
        model: 3
        Shape {
            id: ring
            required property int index
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            opacity: orb.ease(orb.st(0.05 + index * 0.08)) * (orb.off ? 0.4 : 1)
            scale: 0.85 + 0.15 * orb.ease(orb.st(0.05 + index * 0.08))
            ShapePath {
                strokeWidth: 1
                strokeColor: ring.index === 0 && orb.live ? Qt.alpha(Serp.accent, 0.4) : Qt.alpha(Serp.text, ring.index === 2 ? 0.07 : 0.11)
                fillColor: "transparent"
                PathAngleArc {
                    centerX: orb.cx
                    centerY: orb.cy
                    radiusX: orb.radii[ring.index]
                    radiusY: orb.radii[ring.index] * orb.tilt
                    startAngle: 0
                    sweepAngle: 360
                }
            }
        }
    }

    // scanning: waves out of the core
    Repeater {
        model: 2
        Rectangle {
            id: wave
            required property int index
            property real t: 0
            width: orb.radii[2] * 2
            height: width * orb.tilt
            radius: height / 2
            x: orb.cx - width / 2
            y: orb.cy - height / 2
            color: "transparent"
            border.width: Serp.px(2)
            border.color: Serp.accent
            scale: 0.2 + 0.8 * t
            opacity: orb.pulsing ? 0.35 * (1 - t) : 0
            visible: orb.pulsing
            SequentialAnimation on t {
                running: orb.pulsing && orb.running
                loops: Animation.Infinite
                PauseAnimation {
                    duration: wave.index * 1300
                }
                NumberAnimation {
                    from: 0
                    to: 1
                    duration: 2600
                    easing.type: Easing.OutCubic
                }
                PauseAnimation {
                    duration: (1 - wave.index) * 1300
                }
            }
        }
    }

    // the line to the connected one
    Item {
        id: link
        readonly property var m: orb.model.find(x => x.connected) || null
        readonly property real a: m ? orb.angleOf(m) : 0
        readonly property real tx: m ? Math.cos(a) * orb.radii[m.ring] : 0
        readonly property real ty: m ? Math.sin(a) * orb.radii[m.ring] * orb.tilt : 0
        readonly property real len: Math.max(0, Math.sqrt(tx * tx + ty * ty))
        property real t: 0
        visible: !!m && !orb.off
        x: orb.cx
        y: orb.cy
        z: Math.sin(a) > 0 ? 15 : 4
        opacity: orb.ease(orb.st(0.4))
        NumberAnimation on t {
            from: 0
            to: 1
            duration: 1800
            loops: Animation.Infinite
            running: link.visible && orb.running
        }
        Rectangle {
            width: link.len
            height: Serp.px(2)
            y: -height / 2
            transformOrigin: Item.Left
            rotation: Math.atan2(link.ty, link.tx) * 180 / Math.PI
            antialiasing: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: Qt.alpha(Serp.accent, 0.15)
                }
                GradientStop {
                    position: 1
                    color: Serp.accent
                }
            }
            Rectangle {
                width: Serp.px(6)
                height: width
                radius: width / 2
                y: parent.height / 2 - height / 2
                x: (parent.width - width) * link.t
                color: Qt.lighter(Serp.accent, 1.25)
                opacity: Math.sin(link.t * Math.PI)
            }
        }
    }

    // the core: this PC / the adapter
    Item {
        id: core
        z: 10
        width: Serp.px(76)
        height: width
        x: orb.cx - width / 2
        y: orb.cy - height / 2
        property real lift: coreMa.containsMouse ? 1 : 0
        Behavior on lift {
            NumberAnimation {
                duration: Serp.normal
                easing.type: Easing.OutCubic
            }
        }
        scale: (0.6 + 0.4 * orb.ease(orb.st(0))) * (1 + 0.05 * lift)
        opacity: orb.ease(orb.st(0))
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + Serp.px(16)
            height: width
            radius: width / 2
            color: Qt.alpha(orb.live ? Serp.accent : Serp.text, orb.live ? 0.12 : 0.04)
            border.width: 1
            border.color: Qt.alpha(orb.live ? Serp.accent : Serp.text, 0.12)
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            border.width: Serp.px(2)
            border.color: orb.live ? Qt.lighter(Serp.accent, 1.15) : Serp.surface2
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: orb.live ? Qt.lighter(Serp.accent, 1.15) : Serp.surface1
                }
                GradientStop {
                    position: 1
                    color: orb.live ? Qt.darker(Serp.accent, 1.15) : Serp.mantle
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: Serp.normal
                }
            }
            SIcon {
                anchors.centerIn: parent
                name: orb.centerIcon
                size: Serp.px(28)
                color: orb.live ? Serp.onAccent : Serp.subtext0
            }
        }
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height + Serp.px(12)
            spacing: Serp.px(1)
            SText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: orb.centerLabel
                size: Serp.px(11)
                bold: true
                width: Math.min(implicitWidth, Serp.px(180))
                horizontalAlignment: Text.AlignHCenter
            }
            SText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: text !== ""
                text: orb.centerSub
                size: Serp.px(9.5)
                dim: true
                width: Math.min(implicitWidth, Serp.px(180))
                horizontalAlignment: Text.AlignHCenter
            }
        }
        MouseArea {
            id: coreMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: orb.coreClicked()
        }
    }

    // the satellites
    Repeater {
        model: orb.off ? [] : orb.model
        SerpNetNode {
            id: sat
            required property var modelData
            required property int index
            readonly property real a: orb.angleOf(modelData)
            readonly property real r: orb.radii[modelData.ring]
            x: orb.cx + Math.cos(a) * r - width / 2
            y: orb.cy + Math.sin(a) * r * orb.tilt - height / 2
            z: hovered ? 30 : Math.sin(a) > 0 ? 20 : 5
            depth: (Math.sin(a) + 1) / 2
            intro: orb.ease(orb.st(0.25 + Math.min(index, 10) * 0.035))
            icon: modelData.icon
            label: modelData.label
            connected: modelData.connected
            locked: modelData.locked
            busy: modelData.busy
            selected: !!orb.selected && orb.selected === modelData.obj
            onClicked: orb.picked(modelData.obj)
        }
    }
}
