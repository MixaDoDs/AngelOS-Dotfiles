import QtQuick
import qs.config

// What fastfetch prints, drawn like a terminal would (scripts/fastfetch_style.py preview:
// lines of runs [text, fg, bg, bold]). Half and full blocks are painted as cells, so the
// pictures come out square and without gaps; the rest is text in the terminal's monospace.
// `screen.frames` (scripts/fastfetch_anim.py --patches): the picture moving as it does in a
// new terminal — each frame the lines that differ from the still one, played in a loop with
// a pause, still while motion is off.
Item {
    id: root

    property var screen: ({
            "cols": 0,
            "lines": []
        })
    property color background: "#16111c"
    property color foreground: "#e8dff0"
    property string font: "monospace"
    // a cell: the font's advance, twice as tall
    property real cellW: metrics.advanceWidth
    readonly property real cellH: Math.round(cellW * 2.1)
    property int pixelSize: Math.max(9, Theme.sizeBody)
    property bool animate: true
    readonly property var frames: screen.frames || []
    property int frame: -1

    implicitWidth: Math.max(1, root.screen.cols || 0) * cellW + Theme.u * 12
    implicitHeight: Math.max(1, (root.screen.lines || []).length) * cellH + Theme.u * 12

    TextMetrics {
        id: metrics
        font.family: root.font
        font.pixelSize: root.pixelSize
        text: "M"
    }
    Rectangle {
        anchors.fill: parent
        color: root.background
    }
    // the frames, then the still picture for a moment, again
    Timer {
        interval: root.frame < 0 ? 1600 : (root.frames[root.frame] || {}).ms || 100
        repeat: true
        running: root.animate && root.visible && root.frames.length > 0 && !Motion.still
        onTriggered: root.frame = root.frame + 1 < root.frames.length ? root.frame + 1 : -1
        onRunningChanged: if (!running)
            root.frame = -1
    }
    Canvas {
        id: canvas
        x: Theme.u * 6
        y: Theme.u * 6
        width: parent.width - x * 2
        height: parent.height - y * 2
        renderStrategy: Canvas.Cooperative
        // a run of cells from column x on line y; `clear`: the terminal's background under it first
        function paintRun(ctx, run, x, y, clear) {
            const cw = root.cellW, ch = root.cellH;
            const text = String(run[0]), fg = run[1] || root.foreground, bg = run[2], bold = run[3];
            ctx.font = (bold ? "bold " : "") + root.pixelSize + "px \"" + root.font + "\"";
            for (const c of text) {
                const X = Math.round(x * cw), Y = Math.round(y * ch), W = Math.round((x + 1) * cw) - X, H = Math.round((y + 1) * ch) - Y;
                if (bg || clear) {
                    ctx.fillStyle = bg || root.background;
                    ctx.fillRect(X, Y, W, H);
                }
                ctx.fillStyle = fg;
                if (c === "█")
                    ctx.fillRect(X, Y, W, H);
                else if (c === "▀")
                    ctx.fillRect(X, Y, W, Math.round(H / 2));
                else if (c === "▄")
                    ctx.fillRect(X, Y + Math.round(H / 2), W, H - Math.round(H / 2));
                else if (c !== " ")
                    ctx.fillText(c, X, Y + H / 2);
                x++;
            }
            return x;
        }
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.textBaseline = "middle";
            const lines = root.screen.lines || [];
            for (let y = 0; y < lines.length; y++) {
                let x = 0;
                for (const run of lines[y])
                    x = paintRun(ctx, run, x, y, false);
            }
            const f = root.frame >= 0 ? root.frames[root.frame] : null;
            for (const patch of (f ? f.lines : [])) {
                let x = patch[1];
                for (const run of patch[2])
                    x = paintRun(ctx, run, x, patch[0], true);
            }
        }
    }
    onScreenChanged: {
        frame = -1;
        canvas.requestPaint();
    }
    onFrameChanged: canvas.requestPaint()
    onCellWChanged: canvas.requestPaint()
}
