import QtQuick
import QtQuick.Shapes
import qs.config
import qs.services

// The cat of the Mac look (Skin.mac): a smooth one-colour silhouette, like a macOS menu bar extra
// — no pixels. It runs in five gallop frames (CatSprite sets `frame` and `pace` from the CPU
// load) and sits, tail around its paws, with a slow "z" when idle (a sitting cat reads as a cat
// even at 16 px; a curled one doesn't). Drawn as vector paths in a 34 × 20
// unit box scaled to `size` (its height); `color` is its only colour (the menu bar's ink there).
Item {
    id: root

    property real size: 16
    property color color: Skin.text
    property int frame: 0
    property string pace: "idle"           // idle | walk | run
    property bool blink: false             // the sleeping "z" shown
    readonly property real k: size / 20     // one unit in px
    readonly property bool asleep: pace === "idle"

    implicitWidth: Math.round(34 * k)
    implicitHeight: Math.round(20 * k)

    // the legs' angles from vertical per frame (front pair, back pair), degrees — a gallop
    readonly property var gait: [[35, 15, -10, -30], [10, -10, 20, 0], [-25, -35, 35, 25], [-10, 5, 10, -15], [20, 30, -25, -35]]
    readonly property var g: gait[Math.max(0, frame) % gait.length]
    readonly property real bob: frame % 2 === 1 ? -0.6 : 0
    readonly property real legLen: 6.4
    function footX(jx, a) {
        return (jx + Math.sin(a * Math.PI / 180) * legLen) * k;
    }
    function footY(jy, a) {
        return (jy + bob + Math.cos(a * Math.PI / 180) * legLen) * k;
    }

    // ---- running ----
    Shape {
        id: run
        anchors.fill: parent
        visible: !root.asleep
        preferredRendererType: Shape.CurveRenderer
        // body, head, ears: each its own path (overlapping parts of one path would cut holes)
        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"
            scale: Qt.size(root.k, root.k)
            PathSvg {
                path: "M7 " + (10.5 + root.bob) + " a9 4.2 0 1 0 18 0 a9 4.2 0 1 0 -18 0 Z"
            }
        }
        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"
            scale: Qt.size(root.k, root.k)
            PathSvg {
                path: "M22.4 " + (7.4 + root.bob) + " a4.1 4.1 0 1 0 8.2 0 a4.1 4.1 0 1 0 -8.2 0 Z"
            }
        }
        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"
            scale: Qt.size(root.k, root.k)
            PathSvg {
                path: "M23.3 " + (5.0 + root.bob) + " L24.3 " + (1.2 + root.bob) + " L26.6 " + (4.0 + root.bob) + " Z M27.3 " + (3.9 + root.bob) + " L29.9 " + (1.4 + root.bob) + " L30.4 " + (5.4 + root.bob) + " Z"
            }
        }
        // the tail, swaying with the stride
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: 1.9 * root.k
            capStyle: ShapePath.RoundCap
            startX: 7.6 * root.k
            startY: (9.6 + root.bob) * root.k
            PathQuad {
                controlX: 3.2 * root.k
                controlY: (8.6 + root.bob + (root.frame % 2 ? 1.2 : -0.6)) * root.k
                x: 1.6 * root.k
                y: (4.2 + root.bob + (root.frame % 2 ? 1.4 : 0)) * root.k
            }
        }
        // four legs: two at the shoulder, two at the hip
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: 2.1 * root.k
            capStyle: ShapePath.RoundCap
            startX: 22.6 * root.k
            startY: (12.4 + root.bob) * root.k
            PathLine {
                x: root.footX(22.6, root.g[0])
                y: root.footY(12.4, root.g[0])
            }
            PathMove {
                x: 21.2 * root.k
                y: (12.6 + root.bob) * root.k
            }
            PathLine {
                x: root.footX(21.2, root.g[1])
                y: root.footY(12.6, root.g[1])
            }
            PathMove {
                x: 10.4 * root.k
                y: (12.4 + root.bob) * root.k
            }
            PathLine {
                x: root.footX(10.4, root.g[2])
                y: root.footY(12.4, root.g[2])
            }
            PathMove {
                x: 9 * root.k
                y: (12.2 + root.bob) * root.k
            }
            PathLine {
                x: root.footX(9, root.g[3])
                y: root.footY(12.2, root.g[3])
            }
        }
    }

    // ---- idle: sitting, the tail around its paws, a slow "z" ----
    Shape {
        anchors.fill: parent
        visible: root.asleep
        preferredRendererType: Shape.CurveRenderer
        // the body (a pear, wide at the bottom), the head, two pointed ears — each its own path
        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"
            scale: Qt.size(root.k, root.k)
            PathSvg {
                path: "M14.6 19.6 C12.4 19.6 11.8 17.2 12.6 14.4 C13.4 11.6 14.8 9.6 16.6 9.0 L20.2 9.0 C21.8 10.6 23.4 13.8 23.4 16.6 C23.4 18.6 22.4 19.6 20.8 19.6 Z"
            }
        }
        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"
            scale: Qt.size(root.k, root.k)
            PathSvg {
                path: "M14.9 6.6 a3.9 3.7 0 1 0 7.8 0 a3.9 3.7 0 1 0 -7.8 0 Z"
            }
        }
        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"
            scale: Qt.size(root.k, root.k)
            PathSvg {
                path: "M15.3 5.2 L15.6 0.8 L18.1 3.4 Z M19.6 3.3 L22.2 0.9 L22.4 5.3 Z"
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: 1.9 * root.k
            capStyle: ShapePath.RoundCap
            // the tail, from behind, around the front paws
            startX: 22.4 * root.k
            startY: 18.4 * root.k
            PathQuad {
                controlX: 27.6 * root.k
                controlY: 19.8 * root.k
                x: 27.0 * root.k
                y: 15.2 * root.k
            }
        }
    }
    Text {
        visible: root.asleep && root.blink
        x: 24.6 * root.k
        y: -1.2 * root.k
        text: "z"
        color: root.color
        font.family: Skin.font
        font.pixelSize: Math.max(7, Math.round(7 * root.k))
        font.bold: true
        renderType: Text.QtRendering
    }
}
