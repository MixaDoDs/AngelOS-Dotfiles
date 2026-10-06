pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// Heaven's gate, in pixels (42×62 art pixels of `cell` screen pixels): a gold arch on two
// fluted pillars with a halo over a heart keystone, and two cream doors with a heart split
// between them. A thread of light leaks through the seam; `open` (0..1) swings the doors
// in and the light behind them comes out.
Item {
    id: root

    property int cell: Theme.u * 4
    property real open: 0
    property color heart: Theme.accent
    property bool dim: false
    readonly property int cols: 42
    readonly property int rows: 62
    readonly property real cx: 20.5
    readonly property int archTop: 6          // the arch starts below the halo
    readonly property real arcY: archTop + 21
    readonly property real outerR: 21
    readonly property real innerR: 15

    width: cols * cell
    height: rows * cell

    readonly property var c: ({
            "gold": "#f2c95c",
            "goldHi": "#fff2b8",
            "goldLo": "#c99a3e",
            "edge": "#8a5a1e",
            "cream": "#fff8ea",
            "creamLo": "#efdfbf",
            "trim": "#e3bd6a",
            "halo": "#ffe9a0"
        })

    // what is at (x, y): "" | frame | door | halo | heart
    function isFrame(x, y) {
        if (y < archTop)
            return false;
        if (y >= rows - 4)
            return true;                                   // the base
        const dx = x - cx + 0.5, dy = y - arcY + 0.5;
        if (y <= arcY) {
            const d = Math.sqrt(dx * dx + dy * dy);
            return d <= outerR && d > innerR;
        }
        return x <= 5 || x >= 36;
    }
    function isDoor(x, y) {
        if (y < archTop || y >= rows - 4 || isFrame(x, y))
            return false;
        const dx = x - cx + 0.5, dy = y - arcY + 0.5;
        if (y <= arcY)
            return Math.sqrt(dx * dx + dy * dy) <= innerR;
        return x > 5 && x < 36;
    }
    // the halo over the keystone, 17 wide
    readonly property var halo: ["....#########....", "..##hhhhhhhhh##..", ".#hh.........hh#.", "..##hhhhhhhhh##..", "....#########...."]
    function haloAt(x, y) {
        const hx = x - 12;
        if (y < 0 || y >= halo.length || hx < 0 || hx >= 17)
            return "";
        const ch = halo[y][hx];
        return ch === "#" ? c.goldLo : ch === "h" ? (y < 2 ? "#ffffff" : c.halo) : "";
    }
    // the keystone heart, 9 wide
    readonly property var keystone: [".##...##.", "#hh#.#hh#", "#hhh#hhh#", "#hhhhhhh#", ".#hhhhh#.", "..#hhh#..", "...#h#...", "....#...."]
    // the doors' heart, 10 wide, split by the seam
    readonly property var doorHeart: [".##....##.", "#hh#..#hh#", "#hhh##hhh#", "#hhhhhhhh#", ".#hhhhhh#.", "..#hhhh#..", "...#hh#...", "....##...."]

    function paintCell(ctx, x, y, col) {
        ctx.fillStyle = col;
        ctx.fillRect(x * cell, y * cell, cell, cell);
    }
    function frameColor(x, y) {
        const n = (a, b) => isFrame(a, b);
        if (!n(x - 1, y) || !n(x + 1, y) || !n(x, y - 1) || !n(x, y + 1))
            return c.edge;
        if (!n(x, y - 2) || !n(x - 2, y))
            return c.goldHi;
        if (!n(x, y + 2) || !n(x + 2, y))
            return c.goldLo;
        // fluting on the pillars, a line along the arch
        if (y > arcY && y < rows - 4 && (x === 2 || x === 39))
            return c.goldHi;
        if (y > arcY && y < rows - 4 && (x === 3 || x === 38))
            return c.goldLo;
        if (y === rows - 4 + 1)
            return c.goldHi;
        return c.gold;
    }
    function doorColor(x, y, left) {
        const seam = left ? x === 20 : x === 21;
        const nd = (a, b) => isDoor(a, b) && (left ? a <= 20 : a >= 21);
        if (!nd(x - 1, y) || !nd(x + 1, y) || !nd(x, y - 1) || !nd(x, y + 1) || seam)
            return c.trim;
        // the heart between the doors
        const hy = y - (archTop + 24), hx = x - 16;
        if (hy >= 0 && hy < doorHeart.length && hx >= 0 && hx < 10) {
            const ch = doorHeart[hy][hx];
            if (ch === "#")
                return c.edge;
            if (ch === "h")
                return hy === 1 && (hx === 1 || hx === 7) ? "#ffffff" : String(heart);
        }
        // panels: an arched top panel of rays, two rectangles below
        const inset = left ? [9, 17] : [24, 32];
        const onX = x === inset[0] || x === inset[1];
        const inX = x >= inset[0] && x <= inset[1];
        if (inX && (y === archTop + 34 || y === archTop + 44) || onX && y >= archTop + 34 && y <= archTop + 44)
            return c.trim;
        if (inX && (y === archTop + 46 || y === archTop + 52) || onX && y >= archTop + 46 && y <= archTop + 52)
            return c.trim;
        if (y <= arcY - 2 && (x + y) % 4 === 0 && Math.abs(x - cx + 0.5) > 2)
            return c.creamLo;
        if (x === (left ? 19 : 22))
            return c.creamLo;
        return c.cream;
    }

    // the light behind the doors
    Canvas {
        id: light
        anchors.fill: parent
        opacity: Math.min(1, 0.15 + root.open * 1.4)
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            for (let y = 0; y < root.rows; y++)
                for (let x = 0; x < root.cols; x++)
                    if (root.isDoor(x, y)) {
                        const k = Math.abs(x - root.cx + 0.5) / 15;
                        root.paintCell(ctx, x, y, k < 0.2 ? "#ffffff" : k < 0.5 ? "#fff6d6" : k < 0.8 ? "#ffe9a8" : "#ffd98a");
                    }
        }
    }
    Canvas {
        id: leftDoor
        anchors.fill: parent
        transform: Scale {
            origin.x: 6 * root.cell
            xScale: 1 - root.open * 0.9
        }
        opacity: 1 - root.open * 0.4
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            for (let y = 0; y < root.rows; y++)
                for (let x = 0; x <= 20; x++)
                    if (root.isDoor(x, y))
                        root.paintCell(ctx, x, y, root.doorColor(x, y, true));
        }
    }
    Canvas {
        id: rightDoor
        anchors.fill: parent
        transform: Scale {
            origin.x: 36 * root.cell
            xScale: 1 - root.open * 0.9
        }
        opacity: 1 - root.open * 0.4
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            for (let y = 0; y < root.rows; y++)
                for (let x = 21; x < root.cols; x++)
                    if (root.isDoor(x, y))
                        root.paintCell(ctx, x, y, root.doorColor(x, y, false));
        }
    }
    // the thread of light in the seam
    Rectangle {
        x: 20.5 * root.cell
        y: (root.archTop + 7) * root.cell
        width: Math.max(1, root.cell / 2)
        height: (root.rows - 4 - root.archTop - 7) * root.cell
        color: "#fffbe8"
        visible: root.open < 0.05
        SequentialAnimation on opacity {
            loops: Animation.Infinite
            running: !Motion.still && root.visible
            NumberAnimation {
                to: 0.25
                duration: 1400
            }
            NumberAnimation {
                to: 0.9
                duration: 1400
            }
        }
    }
    Canvas {
        id: frame
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            for (let y = 0; y < root.rows; y++)
                for (let x = 0; x < root.cols; x++) {
                    if (root.isFrame(x, y))
                        root.paintCell(ctx, x, y, root.frameColor(x, y));
                    else if (root.haloAt(x, y) !== "")
                        root.paintCell(ctx, x, y, root.haloAt(x, y));
                }
            // the keystone heart on top of the arch
            for (let r = 0; r < root.keystone.length; r++)
                for (let k = 0; k < 9; k++) {
                    const ch = root.keystone[r][k];
                    if (ch === "#")
                        root.paintCell(ctx, 16 + k, root.archTop - 1 + r, root.c.edge);
                    else if (ch === "h")
                        root.paintCell(ctx, 16 + k, root.archTop - 1 + r, r === 1 && (k === 1 || k === 5) ? "#ffffff" : String(root.heart));
                }
        }
    }
    onCellChanged: {
        light.requestPaint();
        leftDoor.requestPaint();
        rightDoor.requestPaint();
        frame.requestPaint();
    }
    onHeartChanged: {
        leftDoor.requestPaint();
        rightDoor.requestPaint();
        frame.requestPaint();
    }
}
