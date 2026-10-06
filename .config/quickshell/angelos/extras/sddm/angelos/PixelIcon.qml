import QtQuick
import "Icons.js" as Icons

// An angelOS pixel icon (Icons.js), painted cell by cell.
Canvas {
    id: root

    property string name: "heart"
    property int pixel: 2
    property color ink: "#1a1a1e"
    property color fill: "#ff5fa2"
    property color fill2: "#c9a0ff"
    property color fill3: "#ffd36a"
    property color light: "#ffffff"
    property color body: "#2d2828"
    property color bad: "#ff4f6d"
    readonly property var rows: Icons.get(name)

    width: rows[0].length * pixel
    height: rows.length * pixel
    renderStrategy: Canvas.Cooperative

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const map = {
            "#": ink,
            "o": fill,
            "x": fill2,
            "y": fill3,
            "w": light,
            "f": body,
            "r": bad
        };
        for (let y = 0; y < rows.length; y++)
            for (let x = 0; x < rows[y].length; x++) {
                const c = map[rows[y][x]];
                if (c === undefined)
                    continue;
                ctx.fillStyle = c;
                ctx.fillRect(x * pixel, y * pixel, pixel, pixel);
            }
    }
    onNameChanged: requestPaint()
    onPixelChanged: requestPaint()
    onFillChanged: requestPaint()
    onInkChanged: requestPaint()
}
