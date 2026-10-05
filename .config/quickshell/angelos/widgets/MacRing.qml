import QtQuick
import QtQuick.Shapes
import qs.config

// One ring of a macOS widget (Activity, battery, system gauges): a faint track of the ring's own
// colour and the value as an arc from 12 o'clock, clockwise, with round ends. value 0…1; a
// negative value draws the track only (no reading).
Item {
    id: root

    property real value: 0
    property color color: "#0a84ff"
    property color track: Qt.alpha(color, 0.22)
    property real lineWidth: 8
    property bool animate: !Motion.still
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
