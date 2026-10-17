pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.config
import qs.widgets
import "ShotMarks.js" as Marks

// One mark of the screenshot editor (ShotMarks.js says what each holds), drawn in the picture's
// pixels: the paper it is on is the picture at its own size (ShotEditor grabs it as the result).
Item {
    id: root

    required property var mark
    property bool selected: false
    property point offset: Qt.point(0, 0)     // dragged, not yet let go
    readonly property string t: mark ? mark.t || "" : ""

    transform: Translate {
        x: root.offset.x
        y: root.offset.y
    }

    Loader {
        active: root.t === "pen" || root.t === "marker"
        sourceComponent: Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.t === "marker" ? Qt.alpha(root.mark.c, 0.42) : root.mark.c
                strokeWidth: root.mark.w
                fillColor: "transparent"
                capStyle: root.t === "marker" ? ShapePath.SquareCap : ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathPolyline {
                    // one point: a dot
                    path: (root.mark.pts.length > 1 ? root.mark.pts : root.mark.pts.concat([[root.mark.pts[0][0] + 0.1, root.mark.pts[0][1]]])).map(p => Qt.point(p[0], p[1]))
                }
            }
        }
    }
    Loader {
        active: root.t === "line" || root.t === "arrow"
        sourceComponent: Shape {
            id: ln
            preferredRendererType: Shape.CurveRenderer
            readonly property var head: Marks.arrowHead(root.mark.a, root.mark.b, root.mark.w)
            readonly property var end: root.t === "arrow" ? head.shaftEnd : root.mark.b
            ShapePath {
                strokeColor: root.mark.c
                strokeWidth: root.mark.w
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: root.mark.a[0]
                startY: root.mark.a[1]
                PathLine {
                    x: ln.end[0]
                    y: ln.end[1]
                }
            }
            ShapePath {
                strokeColor: root.t === "arrow" ? root.mark.c : "transparent"
                strokeWidth: root.t === "arrow" ? Math.max(1, root.mark.w / 2) : 0
                fillColor: root.t === "arrow" ? root.mark.c : "transparent"
                joinStyle: ShapePath.RoundJoin
                startX: ln.head.tip[0]
                startY: ln.head.tip[1]
                PathLine {
                    x: ln.head.left[0]
                    y: ln.head.left[1]
                }
                PathLine {
                    x: ln.head.right[0]
                    y: ln.head.right[1]
                }
                PathLine {
                    x: ln.head.tip[0]
                    y: ln.head.tip[1]
                }
            }
        }
    }
    Loader {
        active: root.t === "rect"
        sourceComponent: Rectangle {
            x: root.mark.x
            y: root.mark.y
            width: root.mark.w
            height: root.mark.h
            color: root.mark.fill ? Qt.alpha(root.mark.c, 0.3) : "transparent"
            border.width: root.mark.lw
            border.color: root.mark.c
        }
    }
    Loader {
        active: root.t === "ellipse"
        sourceComponent: Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.mark.c
                strokeWidth: root.mark.lw
                fillColor: root.mark.fill ? Qt.alpha(root.mark.c, 0.3) : "transparent"
                PathAngleArc {
                    centerX: root.mark.x + root.mark.w / 2
                    centerY: root.mark.y + root.mark.h / 2
                    radiusX: root.mark.w / 2
                    radiusY: root.mark.h / 2
                    startAngle: 0
                    sweepAngle: 360
                }
            }
        }
    }
    // a numbered step (Flameshot's counter): a filled circle with its number
    Loader {
        active: root.t === "num"
        sourceComponent: Rectangle {
            x: root.mark.x - root.mark.s / 2
            y: root.mark.y - root.mark.s / 2
            width: root.mark.s
            height: root.mark.s
            radius: width / 2
            color: root.mark.c
            border.width: Math.max(2, root.mark.s / 14)
            border.color: "white"
            Text {
                anchors.centerIn: parent
                text: root.mark.n
                color: Qt.colorEqual(root.mark.c, "#ffffff") || root.mark.c === "#ffd23f" ? "#111111" : "white"
                font.family: Theme.macFont
                font.bold: true
                font.pixelSize: root.mark.s * 0.55
            }
        }
    }
    Loader {
        active: root.t === "text"
        sourceComponent: Text {
            x: root.mark.x
            y: root.mark.y
            text: root.mark.s
            color: root.mark.c
            font.family: root.mark.pixel ? Theme.fontTitle : Theme.macFont
            font.bold: true
            font.pixelSize: root.mark.size
            // readable on any picture: a thin outline of the other tone
            style: Text.Outline
            styleColor: Qt.colorEqual(root.mark.c, "#111111") ? "white" : Qt.rgba(0, 0, 0, 0.75)
        }
    }
    // angelOS's own pixel icons as stickers
    Loader {
        active: root.t === "sticker"
        sourceComponent: PxIcon {
            name: root.mark.icon
            exactPixel: root.mark.s / 10
            x: root.mark.x - width / 2
            y: root.mark.y - height / 2
        }
    }

    // picked with the select tool: a dashed box round it
    Shape {
        id: sel
        visible: root.selected
        readonly property var b: root.mark ? Marks.bounds(root.mark) : ({
                "x": 0,
                "y": 0,
                "w": 0,
                "h": 0
            })
        ShapePath {
            strokeColor: "white"
            strokeWidth: 2
            strokeStyle: ShapePath.DashLine
            dashPattern: [3, 3]
            fillColor: "transparent"
            startX: sel.b.x - 4
            startY: sel.b.y - 4
            PathLine {
                x: sel.b.x + sel.b.w + 4
                y: sel.b.y - 4
            }
            PathLine {
                x: sel.b.x + sel.b.w + 4
                y: sel.b.y + sel.b.h + 4
            }
            PathLine {
                x: sel.b.x - 4
                y: sel.b.y + sel.b.h + 4
            }
            PathLine {
                x: sel.b.x - 4
                y: sel.b.y - 4
            }
        }
    }
}
