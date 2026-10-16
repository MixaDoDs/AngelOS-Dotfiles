import QtQuick
import qs.config

// A pixel progress ring, as the iPhone's island shows a download: a round track of square cells
// (the art pixel, no smooth arcs) filled clockwise from the top. value 0…1; value < 0 = nobody
// knows how much: a quarter of the ring runs round instead.
//   value · size (px, the outer diameter) · cell (px) · fill · track
Item {
    id: root

    property real value: 0
    property int cell: Math.max(1, Theme.u)
    property int size: cell * 9
    property color fill: Theme.accent
    property color track: Qt.rgba(Theme.textDim.r, Theme.textDim.g, Theme.textDim.b, 0.28)
    property int thick: 2                     // cells
    readonly property bool unknown: value < 0

    implicitWidth: size
    implicitHeight: size
    Accessible.role: Accessible.ProgressBar
    Accessible.name: unknown ? "…" : Math.round(value * 100) + "%"

    // eased (a readonly one can't carry a Behavior)
    property real shown: Math.max(0, Math.min(1, value))
    Behavior on shown {
        NumberAnimation {
            duration: Motion.ms(450)
            easing.type: Easing.OutCubic
        }
    }
    property real phase: 0
    NumberAnimation on phase {
        running: root.unknown && root.visible
        from: 0
        to: 1
        duration: 1100
        loops: Animation.Infinite
    }

    onShownChanged: art.requestPaint()
    onPhaseChanged: if (unknown)
        art.requestPaint()
    onUnknownChanged: art.requestPaint()
    onFillChanged: art.requestPaint()
    onTrackChanged: art.requestPaint()

    Canvas {
        id: art
        readonly property int n: Math.max(5, Math.floor(root.size / root.cell))
        width: n * root.cell
        height: width
        anchors.centerIn: parent
        renderStrategy: Canvas.Cooperative
        onNChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const c = root.cell, half = n / 2, outer = half, inner = half - root.thick;
            for (let j = 0; j < n; j++)
                for (let i = 0; i < n; i++) {
                    const x = i + 0.5 - half, y = j + 0.5 - half;
                    const d = Math.sqrt(x * x + y * y);
                    if (d > outer || d < inner)
                        continue;
                    // from the top, clockwise, 0…1
                    let a = Math.atan2(x, -y) / (2 * Math.PI);
                    if (a < 0)
                        a += 1;
                    const lit = root.unknown ? ((a - root.phase) % 1 + 1) % 1 < 0.25 : a < root.shown;
                    ctx.fillStyle = lit ? root.fill : root.track;
                    ctx.fillRect(i * c, j * c, c, c);
                }
        }
    }
}
