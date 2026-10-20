import QtQuick
import qs.config

// The 2004 lock's clock (SaveLock): chunky game-HUD digits drawn on the scene's art grid — a
// 5×7 glyph blown up to whole art pixels, its outer corners cut round, a light top edge, the
// bottom dithered into a darker shade, a dark outline and a hard drop shadow. The face in the
// theme's accent, the outline and shadow in the scene's own darks (palette), so it sits in it.
// Painted only when the text changes (the colon blinks once a second): nothing runs per frame.
Item {
    id: root

    property string text: "00:00"
    property real k: 1                 // screen px per art px (SceneWall.k)
    property var palette: []           // [[r, g, b], ...]; empty: the theme's colours
    property color accent: Theme.accent

    readonly property var glyphs: ({
            "0": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
            "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
            "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
            "3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
            "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
            "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
            "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
            "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
            "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
            "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
            ":": [".", ".", "#", ".", "#", ".", "."],
            " ": [".", ".", ".", ".", ".", ".", "."]
        })

    function luma(c) {
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }
    function nearest(cols, want) {
        let best = cols[0], bd = 1e9;
        for (const c of cols) {
            const d = (c.r - want.r) ** 2 * 3 + (c.g - want.g) ** 2 * 4 + (c.b - want.b) ** 2 * 2;
            if (d < bd) {
                bd = d;
                best = c;
            }
        }
        return best;
    }
    // [face, light, mid, ink, shade]: the face is the theme's accent (a HUD over the picture, it
    // must stand out of it), the outline and the shadow the scene's own darks (it sits in it)
    readonly property var colors: {
        const mix = (a, b, t) => Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
        const cols = palette.map(c => Qt.rgba(c[0] / 255, c[1] / 255, c[2] / 255, 1));
        const ink = cols.length ? cols.slice().sort((a, b) => luma(a) - luma(b))[0] : Theme.edge;
        const shade = cols.length ? nearest(cols, mix(ink, accent, 0.35)) : mix(Theme.edge, accent, 0.3);
        return [accent, mix(accent, Qt.rgba(1, 1, 1, 1), 0.55), mix(accent, ink, 0.35), ink, shade];
    }

    Item {
        id: art
        width: Math.max(1, Math.floor(root.width / root.k))
        height: Math.max(1, Math.floor(root.height / root.k))
        scale: root.k
        transformOrigin: Item.TopLeft
        layer.enabled: true
        layer.smooth: false

        Canvas {
            id: canvas
            anchors.fill: parent
            renderStrategy: Canvas.Immediate
            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                const w = width, h = height;
                if (w < 4 || h < 4)
                    return;
                // the line in glyph cells: digits 5 wide, the colon 1, a cell between
                const cells = [];
                let cw = 0;
                for (const ch of root.text) {
                    const g = root.glyphs[ch];
                    if (!g)
                        continue;
                    if (cells.length)
                        cw += 1;
                    cells.push([g, cw]);
                    cw += g[0].length;
                }
                if (!cells.length)
                    return;
                // art px per glyph cell, the biggest that fits with room for the outline and shadow
                const fit = p => Math.floor(Math.min((w - 2 * p) / cw, (h - 2 * p) / 7));
                let s = Math.max(1, fit(3));
                const d = Math.max(1, Math.round(s / 3));       // shadow drop
                s = Math.max(1, fit(d + 1));
                const gw = cw * s, gh = 7 * s;
                const ox = Math.floor((w - gw - d) / 2), oy = Math.floor((h - gh - d) / 2);
                const cut = Math.floor(s / 3);                  // the round of the outer corners
                const on = (g, cx, cy) => cy >= 0 && cy < 7 && cx >= 0 && cx < g[0].length && g[cy][cx] === "#";
                const M = new Uint8Array(w * h);
                for (const [g, at] of cells) {
                    for (let cy = 0; cy < 7; cy++)
                        for (let cx = 0; cx < g[0].length; cx++) {
                            if (!on(g, cx, cy))
                                continue;
                            for (let py = 0; py < s; py++)
                                for (let px = 0; px < s; px++) {
                                    // a corner with nothing on either side of it is cut in steps
                                    const sx = px < s / 2 ? -1 : 1, sy = py < s / 2 ? -1 : 1;
                                    const ex = sx < 0 ? px : s - 1 - px, ey = sy < 0 ? py : s - 1 - py;
                                    if (ex + ey < cut && !on(g, cx + sx, cy) && !on(g, cx, cy + sy) && !on(g, cx + sx, cy + sy))
                                        continue;
                                    const x = ox + (at + cx) * s + px, yy = oy + cy * s + py;
                                    if (x >= 0 && x < w && yy >= 0 && yy < h)
                                        M[yy * w + x] = 1;
                                }
                        }
                }
                const m = (x, yy) => x >= 0 && x < w && yy >= 0 && yy < h && M[yy * w + x] === 1;
                // the outline: everything next to the glyphs (8 ways)
                const O = new Uint8Array(w * h);
                for (let yy = 0; yy < h; yy++)
                    for (let x = 0; x < w; x++)
                        if (!M[yy * w + x] && (m(x - 1, yy) || m(x + 1, yy) || m(x, yy - 1) || m(x, yy + 1) || m(x - 1, yy - 1) || m(x + 1, yy - 1) || m(x - 1, yy + 1) || m(x + 1, yy + 1)))
                            O[yy * w + x] = 1;
                const body = (x, yy) => x >= 0 && x < w && yy >= 0 && yy < h && (M[yy * w + x] || O[yy * w + x]);
                const hb = Math.max(1, Math.floor(s / 3));
                const c = root.colors;
                // each pixel's colour (an index into c, -1 none), then drawn in runs along the rows
                const at = (x, yy) => {
                    const i = yy * w + x;
                    if (M[i]) {
                        const gy = (yy - oy) / gh;
                        for (let b = 1; b <= hb; b++)
                            if (!m(x, yy - b))
                                return 1;
                        if (!m(x + 1, yy) || !m(x, yy + 1) || gy >= 0.82 || (gy >= 0.6 && (x + yy) % 2))
                            return 2;
                        return 0;
                    }
                    return O[i] ? 3 : body(x - d, yy - d) ? 4 : -1;
                };
                for (let yy = 0; yy < h; yy++) {
                    let run = -1, from = 0;
                    for (let x = 0; x <= w; x++) {
                        const ci = x < w ? at(x, yy) : -2;
                        if (ci === run)
                            continue;
                        if (run >= 0) {
                            ctx.fillStyle = c[run];
                            ctx.fillRect(from, yy, x - from, 1);
                        }
                        run = ci;
                        from = x;
                    }
                }
            }
        }
    }

    onTextChanged: canvas.requestPaint()
    onColorsChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()
    onKChanged: canvas.requestPaint()
}
