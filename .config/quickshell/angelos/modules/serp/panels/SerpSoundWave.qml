import QtQuick
import QtQuick.Shapes

// serp-skin: one liquid layer of the sound core: a wave two wavelengths long (`span` each) over a body
// `depth` deep. Built once; the core slides it sideways by span to make it roll.
Shape {
    id: w
    property real span: 100
    property real amp: 4
    property real depth: 100
    property color hi: "white"
    property color lo: "white"
    width: 2 * span
    height: depth + 2 * amp
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeColor: "transparent"
        strokeWidth: 0
        fillGradient: LinearGradient {
            x1: 0
            y1: 0
            x2: 0
            y2: w.height
            GradientStop {
                position: 0
                color: w.hi
            }
            GradientStop {
                position: 1
                color: w.lo
            }
        }
        startX: 0
        startY: w.amp
        // four half-waves: a quad's peak sits halfway to its control point
        PathQuad {
            x: w.span * 0.5
            y: w.amp
            controlX: w.span * 0.25
            controlY: -w.amp
        }
        PathQuad {
            x: w.span
            y: w.amp
            controlX: w.span * 0.75
            controlY: 3 * w.amp
        }
        PathQuad {
            x: w.span * 1.5
            y: w.amp
            controlX: w.span * 1.25
            controlY: -w.amp
        }
        PathQuad {
            x: w.span * 2
            y: w.amp
            controlX: w.span * 1.75
            controlY: 3 * w.amp
        }
        PathLine {
            x: w.span * 2
            y: w.height
        }
        PathLine {
            x: 0
            y: w.height
        }
        PathLine {
            x: 0
            y: w.amp
        }
    }
}
