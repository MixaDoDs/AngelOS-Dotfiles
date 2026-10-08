import QtQuick
import qs.config
import qs.services

// ASCII art drawn on a small Canvas every frame, one effect at a time:
// reveal → hold → dissolve → short pause → the next (random) effect.
Item {
    id: root

    property string text: ""
    property real maxWidth: 800
    property real maxHeight: 400
    property string effect: "random"       // random | one of Idle.effects
    property string palette: "accent"      // accent | mono | rainbow
    property bool running: visible
    property string fontFamily: "CozetteVector"
    signal ticked

    readonly property var grid: text.split("\n").map(l => Array.from(l.replace(/\s+$/, "")))
    readonly property int rows: Math.max(1, grid.length)
    readonly property int cols: Math.max(1, grid.reduce((m, l) => Math.max(m, l.length), 0))
    readonly property int basePx: 13
    readonly property real baseW: Math.max(1, metrics.advanceWidth)
    // integer scale keeps the pixel font crisp
    readonly property int scaleK: Math.max(1, Math.floor(Math.min(maxWidth / (cols * baseW), maxHeight / (rows * basePx))))
    readonly property int fontPx: basePx * scaleK
    readonly property real cw: baseW * scaleK
    readonly property real ch: basePx * scaleK

    implicitWidth: cols * cw
    implicitHeight: rows * ch

    TextMetrics {
        id: metrics
        font.family: root.fontFamily
        font.pixelSize: root.basePx
        text: "█"
    }

    // ---- effect clock ----
    readonly property var durations: ({
            "in": 2.4,
            "hold": 5.0,
            "out": 1.6,
            "gap": 0.5
        })
    property string current: "decrypt"
    property string phase: "in"
    property real t: 0
    property real clock: 0
    property var seeds: []
    property var colSeeds: []

    function reseed() {
        const s = [];
        for (let i = 0; i < rows * cols; i++)
            s.push(Math.random());
        seeds = s;
        const c = [];
        for (let i = 0; i < cols; i++)
            c.push(Math.random());
        colSeeds = c;
    }
    function nextEffect() {
        if (effect !== "random" && Idle.effects.includes(effect)) {
            current = effect;
        } else {
            const pool = Idle.effects.filter(e => e !== current);
            current = pool[Math.floor(Math.random() * pool.length)];
        }
        reseed();
    }
    function restart() {
        phase = "in";
        t = 0;
        nextEffect();
        canvas.requestPaint();
    }
    onEffectChanged: restart()
    onTextChanged: restart()
    Component.onCompleted: restart()

    FrameAnimation {
        running: root.running
        onTriggered: {
            const dt = Math.min(frameTime, 0.1);
            root.t += dt;
            root.clock += dt;
            if (root.t >= root.durations[root.phase]) {
                root.t = 0;
                root.phase = ({
                        "in": "hold",
                        "hold": "out",
                        "out": "gap",
                        "gap": "in"
                    })[root.phase];
                if (root.phase === "in")
                    root.nextEffect();
            }
            canvas.requestPaint();
            root.ticked();
        }
    }

    // ---- helpers ----
    readonly property string noise: "▓▒░#%&@*+=:.<>/\\"
    function clamp(v) {
        return Math.max(0, Math.min(1, v));
    }
    function rgba(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a.toFixed(3) + ")";
    }
    function colorAt(col) {
        const f = cols > 1 ? col / (cols - 1) : 0;
        if (palette === "mono")
            return Theme.text;
        if (palette === "rainbow")
            return Qt.hsla((f * 0.8 + clock * 0.08) % 1, 0.75, 0.68, 1);
        return Theme.mix(Theme.accent, Theme.accent2, f);
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);
            ctx.font = root.fontPx + "px \"" + root.fontFamily + "\"";
            ctx.textBaseline = "top";
            const R = root.rows, C = root.cols, cw = root.cw, chh = root.ch;
            const phase = root.phase, e = root.current;
            if (phase === "gap")
                return;
            const p = root.clamp(root.t / root.durations[phase]);
            const inn = phase === "in", out = phase === "out", hold = phase === "hold";
            const colors = [];
            for (let c = 0; c < C; c++)
                colors.push(root.colorAt(c));
            const white = Qt.color("#ffffff");
            const dim = Theme.accent2;
            // row-major order of printable cells (typewriter)
            let order = 0, total = 0;
            if (e === "typewriter")
                for (const line of root.grid)
                    for (const g of line)
                        if (g !== " ")
                            total++;
            const burst = e === "glitch" && hold && (Math.floor(root.clock * 2) % 5 === 0) && Math.random() < 0.6;

            for (let r = 0; r < R; r++) {
                const line = root.grid[r] || [];
                const rowJitter = e === "glitch" ? (Math.random() - 0.5) * cw * 6 : 0;
                for (let c = 0; c < line.length; c++) {
                    const g = line[c];
                    if (g === " ")
                        continue;
                    const s = root.seeds[r * C + c] || 0;
                    let glyph = g, alpha = 1, dx = 0, dy = 0, color = colors[c], show = true;
                    if (e === "decrypt") {
                        const at = s * 0.8;
                        if (inn && p < at)
                            show = false;
                        else if (inn && p < at + 0.15) {
                            glyph = root.noise[Math.floor(Math.random() * root.noise.length)];
                            color = dim;
                            alpha = 0.7;
                        } else if (out && p > at + 0.15)
                            show = false;
                        else if (out && p > at) {
                            glyph = root.noise[Math.floor(Math.random() * root.noise.length)];
                            color = dim;
                            alpha = 0.7;
                        } else if (hold && Math.random() < 0.004) {
                            glyph = root.noise[Math.floor(Math.random() * root.noise.length)];
                        }
                    } else if (e === "rain") {
                        const d = (root.colSeeds[c] || 0) * 0.55;
                        const f = root.clamp((p - d) / 0.45);
                        if (inn) {
                            show = f > 0;
                            const b = 1 - f;
                            dy = -b * b * (r + 3) * chh;
                            alpha = Math.min(1, f * 2);
                        } else if (out) {
                            dy = f * f * (R - r + 3) * chh;
                            alpha = 1 - f;
                        }
                    } else if (e === "beams") {
                        const dir = r % 2 === 0 ? c : C - 1 - c;
                        const head = (p * 1.5 - r * 0.05) * C;
                        if (inn) {
                            show = dir < head;
                            if (head - dir < 3)
                                color = white;
                        } else if (out) {
                            show = dir >= head;
                            if (dir - head < 2 && show)
                                color = white;
                        }
                    } else if (e === "wave") {
                        dy = Math.sin(root.clock * 3 + c * 0.35) * chh * 0.35;
                        color = Qt.hsla(((cols > 1 ? c / (C - 1) : 0) * 0.5 + root.clock * 0.12) % 1, 0.7, 0.68, 1);
                        if (root.palette === "mono")
                            color = colors[c];
                        if (inn)
                            show = c / C < p * 1.2;
                        else if (out)
                            alpha = 1 - p;
                    } else if (e === "typewriter") {
                        const n = inn ? Math.floor(p * total) : out ? Math.floor((1 - p) * total) : total;
                        show = order < n;
                        order++;
                    } else if (e === "hearts") {
                        const at = s * 0.6;
                        if (inn) {
                            if (p < at)
                                show = false;
                            else if (p < at + 0.25) {
                                glyph = "♡";
                                color = Theme.accent;
                            }
                        } else if (out) {
                            const f = root.clamp((p - s * 0.5) / 0.5);
                            if (f > 0) {
                                glyph = "♡";
                                color = Theme.accent;
                                dy = -f * chh * 4;
                                alpha = 1 - f;
                            }
                        }
                    } else if (e === "glitch") {
                        if (inn) {
                            dx = rowJitter * (1 - p);
                            alpha = p;
                            show = Math.random() < 0.4 + p;
                        } else if (out) {
                            dx = rowJitter * p;
                            alpha = 1 - p;
                            show = Math.random() < 1.4 - p;
                        } else if (burst) {
                            dx = rowJitter * 0.5;
                        }
                        if (show && (inn || out || burst)) {
                            ctx.fillStyle = root.rgba(Qt.color("#00e5ff"), 0.45 * alpha);
                            ctx.fillText(glyph, c * cw + dx - root.scaleK * 2, r * chh);
                            ctx.fillStyle = root.rgba(Qt.color("#ff2e7e"), 0.45 * alpha);
                            ctx.fillText(glyph, c * cw + dx + root.scaleK * 2, r * chh);
                        }
                    }
                    if (!show || alpha <= 0.01)
                        continue;
                    ctx.fillStyle = root.rgba(color, alpha);
                    ctx.fillText(glyph, Math.round(c * cw + dx), Math.round(r * chh + dy));
                }
            }
            // typewriter cursor
            if (e === "typewriter" && !hold) {
                const blink = Math.floor(root.clock * 4) % 2 === 0;
                if (blink) {
                    let n = inn ? Math.floor(p * total) : Math.floor((1 - p) * total), cr = 0, cc = 0;
                    outer: for (let r = 0; r < R; r++)
                        for (let c = 0; c < (root.grid[r] || []).length; c++)
                            if (root.grid[r][c] !== " ") {
                                if (n-- <= 0) {
                                    cr = r;
                                    cc = c;
                                    break outer;
                                }
                            }
                    ctx.fillStyle = root.rgba(Theme.accent, 0.9);
                    ctx.fillRect(cc * cw, cr * chh, cw, chh);
                }
            }
        }
    }
}
