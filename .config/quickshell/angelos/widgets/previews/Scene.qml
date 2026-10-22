import QtQuick
import qs.config

// Base of every preview scene: the loop clock and a few timeline helpers.
Item {
    id: root

    property real t: 0                       // 0..1 through the pass
    property string variant: ""
    property int loops: 0

    // 0 before a, 1 after b, linear between
    function seg(a, b) {
        return Math.max(0, Math.min(1, (t - a) / (b - a)));
    }
    function ease(x) {
        return x < 0.5 ? 2 * x * x : 1 - Math.pow(-2 * x + 2, 2) / 2;
    }
    function mixp(p0, p1, k) {
        return Qt.point(p0.x + (p1.x - p0.x) * k, p0.y + (p1.y - p0.y) * k);
    }
    // stepped like a gif: `n` distinct positions per segment
    function steps(x, n) {
        return Math.floor(x * n) / n;
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.desk
    }
    // faint checker on the desk so it reads as a screen
    // (painted, not a Repeater of cells: a cell count follows the width, and every pixel of a
    // resize built all the cells again)
    Canvas {
        id: checker
        readonly property int cell: Theme.u * 6
        readonly property color ink: Theme.accent
        anchors.fill: parent
        opacity: 0.06
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onCellChanged: requestPaint()
        onInkChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.fillStyle = ink;
            for (let r = 0; r * cell < height; r++)
                for (let c = 0; c * cell < width; c++)
                    if ((c + r) % 2)
                        ctx.fillRect(c * cell, r * cell, cell, cell);
        }
    }
}
