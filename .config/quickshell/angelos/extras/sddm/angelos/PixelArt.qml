import QtQuick

// Pixel art painted cell by cell from a shape: a cloud, a disc (the sun, the moon), a
// ring (a halo), a pentagram. `cell` screen px a cell; repaints when its look changes.
Canvas {
    id: root

    property string shape: "cloud"           // cloud | disc | ring | crescent | pentagram
    property int cell: 4
    property int cols: 40
    property int rows: 14
    property int seed: 1
    property color body: "#ffffff"
    property color shade: "#dfe8ff"
    property color rim: "#ffffff"
    property color ink: "transparent"

    width: cols * cell
    height: rows * cell
    renderStrategy: Canvas.Cooperative

    function rnd(i) {
        const x = Math.sin((seed * 97.13 + i * 13.37)) * 43758.5453;
        return x - Math.floor(x);
    }
    // is cell (x, y) part of the shape
    function inside(x, y) {
        if (x < 0 || y < 0 || x >= cols || y >= rows)
            return false;
        const cx = (x + 0.5) / cols, cy = (y + 0.5) / rows;
        if (shape === "cloud") {
            // a flat bottom and a few puffs along it
            if (cy > 0.92)
                return cx > 0.06 && cx < 0.94;
            const n = 4 + Math.floor(rnd(0) * 2);
            for (let i = 0; i < n; i++) {
                const px = 0.12 + (i + 0.5) / n * 0.76 + (rnd(i + 1) - 0.5) * 0.08;
                const r = 0.34 + rnd(i + 7) * 0.22 + (i === Math.floor(n / 2) ? 0.16 : 0);
                const py = 1 - r * 0.82;
                const dx = (cx - px) / (r * rows / cols), dy = (cy - py) / r;
                if (dx * dx + dy * dy <= 1)
                    return true;
            }
            return false;
        }
        const dx = cx - 0.5, dy = cy - 0.5, d = Math.sqrt(dx * dx + dy * dy);
        if (shape === "disc")
            return d <= 0.5;
        if (shape === "ring")
            return d <= 0.5 && d >= 0.5 - 1.6 / Math.min(cols, rows);
        if (shape === "crescent") {
            const ex = cx - 0.68, ey = cy - 0.38;
            return d <= 0.5 && Math.sqrt(ex * ex + ey * ey) > 0.42;
        }
        if (shape === "pentagram") {
            const w = 1.4 / Math.min(cols, rows);
            if (Math.abs(d - 0.48) < w * 0.7)
                return true;
            // the five lines of the star, point up
            const pts = [];
            for (let i = 0; i < 5; i++) {
                const a = -Math.PI / 2 + i * 2 * Math.PI / 5;
                pts.push([0.5 + 0.44 * Math.cos(a), 0.5 + 0.44 * Math.sin(a)]);
            }
            for (let i = 0; i < 5; i++) {
                const a = pts[i], b = pts[(i + 2) % 5];
                const vx = b[0] - a[0], vy = b[1] - a[1];
                const t = Math.max(0, Math.min(1, ((cx - a[0]) * vx + (cy - a[1]) * vy) / (vx * vx + vy * vy)));
                const qx = a[0] + vx * t - cx, qy = a[1] + vy * t - cy;
                if (Math.sqrt(qx * qx + qy * qy) < w * 0.6)
                    return true;
            }
            return false;
        }
        return false;
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        for (let y = 0; y < rows; y++)
            for (let x = 0; x < cols; x++) {
                if (!inside(x, y)) {
                    // an outline round the shape, if it has one
                    if (ink.a > 0 && (inside(x - 1, y) || inside(x + 1, y) || inside(x, y - 1) || inside(x, y + 1))) {
                        ctx.fillStyle = ink;
                        ctx.fillRect(x * cell, y * cell, cell, cell);
                    }
                    continue;
                }
                let c = body;
                if (shape === "cloud") {
                    // lit along the top, shaded underneath
                    if (!inside(x, y - 1))
                        c = rim;
                    else if (y >= rows * 0.72 || !inside(x, y + 2))
                        c = shade;
                } else if (shape === "disc" || shape === "crescent") {
                    const dx = (x + 0.5) / cols - 0.38, dy = (y + 0.5) / rows - 0.36;
                    if (Math.sqrt(dx * dx + dy * dy) < 0.16)
                        c = rim;
                    else if (!inside(x + 1, y + 1))
                        c = shade;
                }
                ctx.fillStyle = c;
                ctx.fillRect(x * cell, y * cell, cell, cell);
            }
    }
    onCellChanged: requestPaint()
    onColsChanged: requestPaint()
    onRowsChanged: requestPaint()
    onBodyChanged: requestPaint()
    onShadeChanged: requestPaint()
    onRimChanged: requestPaint()
    onShapeChanged: requestPaint()
}
