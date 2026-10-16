import QtQuick
import qs.config

// A pill (or a rounded card) with pixel corners: each corner a staircase of whole art pixels
// (Theme.u), no antialiasing, no blur. radius is in screen pixels; it never goes past half the
// height, so a short one is a full pill and a tall one a card with round corners.
// edge: a one-pixel outline in its own staircase ("transparent" = none).
Item {
    id: root

    property color color: Theme.panel
    property color edge: "transparent"
    property real radius: height / 2
    // square top corners, no outline along the top: glued to the screen's edge (the Halo's notch)
    property bool flatTop: false
    readonly property int u: Theme.u

    PillShape {
        anchors.fill: parent
        fill: root.edge
        visible: root.edge.a > 0
    }
    PillShape {
        anchors.fill: parent
        anchors.margins: root.edge.a > 0 ? root.u : 0
        anchors.topMargin: root.flatTop ? 0 : anchors.margins
        fill: root.color
    }

    component PillShape: Item {
        id: shape
        property color fill
        // the corner's size in art pixels
        readonly property int n: Math.max(0, Math.min(Math.round(root.radius / root.u), Math.floor(Math.min(width, height) / 2 / root.u)))
        Rectangle {
            y: shape.n * root.u
            width: shape.width
            height: Math.max(0, shape.height - 2 * shape.n * root.u)
            color: shape.fill
        }
        Repeater {
            model: shape.n
            Item {
                id: step
                required property int index
                // how far row `index` (from the top) stands in from the side
                readonly property int inset: Math.round(shape.n - Math.sqrt(shape.n * shape.n - Math.pow(shape.n - index - 0.5, 2)))
                Rectangle {
                    x: root.flatTop ? 0 : step.inset * root.u
                    y: step.index * root.u
                    width: shape.width - 2 * x
                    height: root.u
                    color: shape.fill
                }
                Rectangle {
                    x: step.inset * root.u
                    y: shape.height - (step.index + 1) * root.u
                    width: shape.width - 2 * x
                    height: root.u
                    color: shape.fill
                }
            }
        }
    }
}
