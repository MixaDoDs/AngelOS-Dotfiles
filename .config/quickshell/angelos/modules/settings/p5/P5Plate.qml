import QtQuick
import qs.config

// A plate of the P5 window: a polygon (`poly`, [[x, y], …] in this item's pixels) turned by
// `tilt` degrees round its middle, with an optional hard shadow (`shadow`, shifted by
// `shadowX/Y`) and a second one round it (`rim`). One shader (shaders/p5_plate.frag) tests every
// pixel at its art pixel's centre: the slanted edges step on the angelOS pixel grid. Up to 8 corners.
Item {
    id: root

    property var poly: [[0, 0], [width, 0], [width, height], [0, height]]
    property real tilt: 0
    property color color: "white"
    property color shadow: "transparent"
    property real shadowX: Theme.u * 3
    property real shadowY: Theme.u * 3
    property color rim: "transparent"
    property real rimWidth: Theme.u
    // room round the polygon for the tilt and the shadows
    property real pad: Theme.u * 8

    function turned(pts, dx, dy, grow) {
        const cx = width / 2, cy = height / 2, a = tilt * Math.PI / 180;
        const c = Math.cos(a), s = Math.sin(a);
        return pts.map(p => {
            let x = p[0] - cx, y = p[1] - cy;
            if (grow) {
                x += Math.sign(x) * grow;
                y += Math.sign(y) * grow;
            }
            return Qt.point(cx + x * c - y * s + dx + pad, cy + x * s + y * c + dy + pad);
        });
    }

    // 8 corners for the shader: the missing ones repeat the last (an edge that never crosses)
    function eight(pts) {
        const out = pts.slice(0, 8);
        while (out.length < 8)
            out.push(out.length ? out[out.length - 1] : Qt.point(0, 0));
        return out;
    }

    ShaderEffect {
        x: -root.pad
        y: -root.pad
        width: root.width + root.pad * 2
        height: root.height + root.pad * 2
        readonly property var p: root.eight(root.turned(root.poly, 0, 0, 0))
        readonly property var r: root.eight(root.rim.a > 0 ? root.turned(root.poly, root.shadowX, root.shadowY, root.rimWidth) : [])
        property size size: Qt.size(width, height)
        property real u: Theme.u
        property color fill: root.color
        property color shadow: root.shadow
        property color rim: root.rim
        property point shift: Qt.point(root.shadowX, root.shadowY)
        property point p0: p[0]
        property point p1: p[1]
        property point p2: p[2]
        property point p3: p[3]
        property point p4: p[4]
        property point p5: p[5]
        property point p6: p[6]
        property point p7: p[7]
        property point r0: r[0]
        property point r1: r[1]
        property point r2: r[2]
        property point r3: r[3]
        property point r4: r[4]
        property point r5: r[5]
        property point r6: r[6]
        property point r7: r[7]
        fragmentShader: Qt.resolvedUrl("../../../shaders/p5_plate.frag.qsb")
    }
}
