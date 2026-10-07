import QtQuick

// Heaven's gate in pixels: two gold pillars, an arch with a heart for a keystone, the light
// of the other side between them. 64 × 84 cells; `glow` 0…1 brightens the light (the gate
// opening), `light` is its colour.
Canvas {
    id: root

    property int cell: 6
    property color gold: "#f2c14e"
    property color goldHi: "#fff1b0"
    property color goldLo: "#b07a1f"
    property color ink: "#6b4a12"
    property color light: "#ffffff"
    property color lightEdge: "#c9a0ff"
    property color heart: "#ff5fa2"
    property real glow: 0
    readonly property int cols: 64
    readonly property int rows: 84
    // the opening between the pillars, in cells: what's in front can sit on it
    readonly property int innerLeft: 14
    readonly property int innerRight: cols - 14
    readonly property int springY: 30           // where the arch meets the pillars

    width: cols * cell
    height: rows * cell
    renderStrategy: Canvas.Cooperative

    function part(x, y) {
        const W = cols, H = rows, cx = W / 2 - 0.5;
        // the base steps
        if (y >= H - 3)
            return x >= 0 && x < W ? (y === H - 3 ? "hi" : "body") : "";
        if (y >= H - 6)
            return x >= 3 && x < W - 3 ? (y === H - 6 ? "hi" : "body") : "";
        // pillars with capitals
        const inPillar = (x >= 4 && x < 13) || (x >= W - 13 && x < W - 4);
        if (y >= springY - 2 && y < springY + 2)
            return (x >= 2 && x < 15) || (x >= W - 15 && x < W - 2) ? (y === springY - 2 ? "hi" : "body") : "";
        if (y >= springY && inPillar) {
            const lx = x < W / 2 ? x - 4 : x - (W - 13);
            return lx === 0 ? "hi" : lx === 8 ? "lo" : lx % 3 === 1 ? "lo" : "body";
        }
        // the keystone heart
        const hx = x - cx, hy = y - (springY - W / 2 + 4);
        if (hy >= -2 && hy <= 4 && Math.abs(hx) <= 4) {
            const heartRows = ["..##.##..", ".#######.", ".#######.", "..#####..", "...###...", "....#....", "........."];
            const row = heartRows[hy + 2];
            if (row && row[Math.round(hx) + 4] === "#")
                return "heart";
        }
        // the arch: a ring over the opening
        const dx = x - cx, dy = y - springY, d = Math.sqrt(dx * dx + dy * dy);
        if (y < springY && d <= W / 2 - 2 && d >= W / 2 - 11) {
            if (d >= W / 2 - 3)
                return "hi";
            if (d <= W / 2 - 10)
                return "lo";
            return "body";
        }
        // the light inside
        if (x >= 13 && x < W - 13 && (y >= springY || d < W / 2 - 10))
            return "light";
        return "";
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const map = {
            "body": gold,
            "hi": goldHi,
            "lo": goldLo,
            "heart": heart
        };
        for (let y = 0; y < rows; y++)
            for (let x = 0; x < cols; x++) {
                const p = part(x, y);
                if (p === "")
                    continue;
                if (p === "light") {
                    // brighter towards the middle and the bottom, in steps (it's pixels)
                    const dx = Math.abs(x - cols / 2 + 0.5) / (cols / 2 - 13), dy = 1 - y / rows;
                    const k = Math.round((1 - Math.min(1, dx * 0.7 + dy * 0.5)) * 5) / 5;
                    ctx.fillStyle = Qt.tint(lightEdge, Qt.rgba(light.r, light.g, light.b, Math.min(1, k * 0.85 + glow)));
                    ctx.globalAlpha = 0.55 + 0.45 * Math.min(1, k + glow);
                    ctx.fillRect(x * cell, y * cell, cell, cell);
                    ctx.globalAlpha = 1;
                    continue;
                }
                ctx.fillStyle = map[p];
                ctx.fillRect(x * cell, y * cell, cell, cell);
            }
        // the outline: every gold cell next to nothing gets an ink edge on that side
        ctx.fillStyle = ink;
        const t = Math.max(1, Math.round(cell / 3));
        for (let y = 0; y < rows; y++)
            for (let x = 0; x < cols; x++) {
                const p = part(x, y);
                if (p === "" || p === "light")
                    continue;
                const empty = (a, b) => {
                    const q = part(a, b);
                    return q === "" || q === "light";
                };
                if (empty(x - 1, y))
                    ctx.fillRect(x * cell, y * cell, t, cell);
                if (empty(x + 1, y))
                    ctx.fillRect((x + 1) * cell - t, y * cell, t, cell);
                if (empty(x, y - 1))
                    ctx.fillRect(x * cell, y * cell, cell, t);
                if (empty(x, y + 1))
                    ctx.fillRect(x * cell, (y + 1) * cell - t, cell, t);
            }
    }
    onCellChanged: requestPaint()
    onGlowChanged: requestPaint()
    onGoldChanged: requestPaint()
    onLightChanged: requestPaint()
}
