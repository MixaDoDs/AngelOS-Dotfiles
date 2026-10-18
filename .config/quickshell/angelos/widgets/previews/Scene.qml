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
    Grid {
        id: checker
        readonly property int cell: Theme.u * 6
        readonly property int cols: Math.max(0, Math.ceil(root.width / cell))
        anchors.fill: parent
        columns: cols
        opacity: 0.06
        Repeater {
            // a preview laid out before its size (a moment of negative width) asked for −33 cells
            model: checker.cols * Math.max(0, Math.ceil(root.height / checker.cell))
            Rectangle {
                required property int index
                width: checker.cell
                height: checker.cell
                color: (index % checker.cols + Math.floor(index / checker.cols)) % 2 ? Theme.accent : "transparent"
            }
        }
    }
}
