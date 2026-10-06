import QtQuick

// A pentagram in a circle, drawn with lines: hell's achievement card (modules/y2k/AchievementToast)
// and the Angel's diary cover (modules/diary/DiaryBook). `glow` breathes a soft halo behind the
// lines, `spin` turns it slowly (both stop with Motion off: `animate`).
Item {
    id: root

    property color color: "#f2c75c"
    property color glowColor: color
    property real line: Math.max(1.5, width / 40)
    property bool ring: true                // the circle round it (and a second, thin one)
    property bool inverted: true            // a point down, as hell draws it
    property bool glow: true
    property bool spin: false
    property bool animate: true
    property real pulse: 0

    implicitWidth: 64
    implicitHeight: 64

    SequentialAnimation on pulse {
        running: root.glow && root.animate && root.visible
        loops: Animation.Infinite
        NumberAnimation {
            to: 1
            duration: 1400
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: 0
            duration: 1400
            easing.type: Easing.InOutSine
        }
    }
    RotationAnimation on rotation {
        running: root.spin && root.animate && root.visible
        loops: Animation.Infinite
        from: 0
        to: 360
        duration: 24000
    }

    // the halo: the same drawing, wide and faint
    Canvas {
        id: halo
        anchors.fill: parent
        visible: root.glow
        opacity: 0.18 + root.pulse * 0.32
        renderStrategy: Canvas.Cooperative
        onPaint: root.draw(getContext("2d"), width, height, root.line * 3.2, root.glowColor)
    }
    Canvas {
        id: lines
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: root.draw(getContext("2d"), width, height, root.line, root.color)
    }
    onColorChanged: repaint()
    onGlowColorChanged: repaint()
    onLineChanged: repaint()
    onWidthChanged: repaint()
    onHeightChanged: repaint()
    function repaint() {
        halo.requestPaint();
        lines.requestPaint();
    }

    function draw(ctx, w, h, lw, col) {
        ctx.reset();
        const cx = w / 2, cy = h / 2;
        const r = Math.min(w, h) / 2 - lw * 1.2;
        ctx.strokeStyle = col;
        ctx.lineWidth = lw;
        ctx.lineJoin = "miter";
        ctx.lineCap = "round";
        if (ring) {
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, Math.PI * 2);
            ctx.stroke();
            ctx.lineWidth = Math.max(1, lw / 2.4);
            ctx.beginPath();
            ctx.arc(cx, cy, r * 0.86, 0, Math.PI * 2);
            ctx.stroke();
            ctx.lineWidth = lw;
        }
        const sr = ring ? r * 0.86 : r;
        const start = inverted ? Math.PI / 2 : -Math.PI / 2;
        const pts = [];
        for (let i = 0; i < 5; i++) {
            const a = start + i * 2 * Math.PI * 2 / 5;
            pts.push([cx + sr * Math.cos(a), cy + sr * Math.sin(a)]);
        }
        ctx.beginPath();
        ctx.moveTo(pts[0][0], pts[0][1]);
        for (let i = 1; i <= 5; i++)
            ctx.lineTo(pts[i % 5][0], pts[i % 5][1]);
        ctx.closePath();
        ctx.stroke();
    }
}
