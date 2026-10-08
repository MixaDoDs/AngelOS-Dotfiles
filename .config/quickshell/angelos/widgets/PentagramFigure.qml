import QtQuick
import QtQuick.Shapes

// The lines of widgets/Pentagram: rings and the star as GPU shapes. `shaded`: three hard
// bands down the figure (Qt 6.12 ShapePath.strokeGradient) — highlight, the colour, shadow.
Shape {
    id: fig

    property real stroke: 1
    property color tint: "white"
    property bool shaded: false
    property bool ring: true
    property bool inverted: true
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property real r: Math.max(1, Math.min(width, height) / 2 - stroke * 1.2)
    readonly property real sr: fig.ring ? r * 0.86 : r
    // the star's five points, every second one in turn (a closed polyline)
    readonly property var star: {
        const start = fig.inverted ? Math.PI / 2 : -Math.PI / 2;
        const pts = [];
        for (let i = 0; i <= 5; i++) {
            const a = start + (i % 5) * 2 * Math.PI * 2 / 5;
            pts.push(Qt.point(cx + sr * Math.cos(a), cy + sr * Math.sin(a)));
        }
        return pts;
    }
    // three hard bands down the figure: highlight, the colour itself, shadow
    readonly property LinearGradient bands: LinearGradient {
        x1: 0
        y1: fig.cy - fig.r
        x2: 0
        y2: fig.cy + fig.r
        GradientStop {
            position: 0
            color: Qt.lighter(fig.tint, 1.35)
        }
        GradientStop {
            position: 0.34
            color: Qt.lighter(fig.tint, 1.35)
        }
        GradientStop {
            position: 0.34
            color: fig.tint
        }
        GradientStop {
            position: 0.68
            color: fig.tint
        }
        GradientStop {
            position: 0.68
            color: Qt.darker(fig.tint, 1.35)
        }
        GradientStop {
            position: 1
            color: Qt.darker(fig.tint, 1.35)
        }
    }

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: "transparent"
        strokeColor: fig.ring ? fig.tint : "transparent"
        strokeGradient: fig.shaded && fig.ring ? fig.bands : null
        strokeWidth: fig.stroke
        PathAngleArc {
            centerX: fig.cx
            centerY: fig.cy
            radiusX: fig.r
            radiusY: fig.r
            sweepAngle: 360
        }
    }
    ShapePath {
        fillColor: "transparent"
        strokeColor: fig.ring ? fig.tint : "transparent"
        strokeGradient: fig.shaded && fig.ring ? fig.bands : null
        strokeWidth: Math.max(1, fig.stroke / 2.4)
        PathAngleArc {
            centerX: fig.cx
            centerY: fig.cy
            radiusX: fig.r * 0.86
            radiusY: fig.r * 0.86
            sweepAngle: 360
        }
    }
    ShapePath {
        fillColor: "transparent"
        strokeColor: fig.tint
        strokeGradient: fig.shaded ? fig.bands : null
        strokeWidth: fig.stroke
        joinStyle: ShapePath.MiterJoin
        capStyle: ShapePath.RoundCap
        PathPolyline {
            path: fig.star
        }
    }
}
