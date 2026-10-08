import QtQuick
import QtQuick.Shapes
import qs.config

// One ring of a macOS widget (Activity, battery, system gauges): a faint track of the ring's own
// colour and the value as an arc from 12 o'clock, clockwise, with round ends. value 0…1; a
// negative value draws the track only (no reading). `shaded`: the arc deepens from its start to a
// lighter tip like Apple's Activity rings (a conical stroke gradient, Qt 6.12 strokeGradient).
Item {
    id: root

    property real value: 0
    property color color: "#0a84ff"
    property color track: Qt.alpha(color, 0.22)
    property real lineWidth: 8
    property bool animate: !Motion.still
    property bool shaded: true
    property real shown: Math.max(0, Math.min(1, value))
    Behavior on shown {
        enabled: root.animate
        NumberAnimation {
            duration: 450
            easing.type: Easing.OutCubic
        }
    }

    implicitWidth: 64
    implicitHeight: 64

    readonly property real r: (Math.min(width, height) - lineWidth) / 2

    // the arc runs clockwise from 12 o'clock; the gradient runs anticlockwise from there, so the
    // start is at 1 and the tip at 1 - shown. The bright-to-deep turn sits where nothing is drawn
    // (between the tip and the start), so both round ends keep their own colour.
    ConicalGradient {
        id: sweep
        centerX: root.width / 2
        centerY: root.height / 2
        angle: 90
        GradientStop {
            position: 0
            color: Qt.darker(root.color, 1.3)
        }
        GradientStop {
            position: Math.max(0.001, (1 - root.shown) / 2)
            color: Qt.darker(root.color, 1.3)
        }
        GradientStop {
            position: Math.max(0.002, 1 - root.shown)
            color: Qt.lighter(root.color, 1.18)
        }
        GradientStop {
            position: 1
            color: Qt.darker(root.color, 1.3)
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.track
            strokeWidth: root.lineWidth
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.r
                radiusY: root.r
                startAngle: 0
                sweepAngle: 360
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.shown > 0.002 ? root.color : "transparent"
            strokeGradient: root.shaded && root.shown > 0.002 ? sweep : null
            strokeWidth: root.lineWidth
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.r
                radiusY: root.r
                startAngle: -90
                sweepAngle: Math.max(0.5, root.shown * 359.9)
            }
        }
    }
}
