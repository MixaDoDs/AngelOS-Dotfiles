import QtQuick
import qs.config
import qs.services
import "."

// Speedometer, log-ish scale up to 1 Gbit/s. Pixel look: blocks along a half circle and a
// stepped needle. Mac look (Skin.mac): a smooth arc with round ends, the filled part in the
// accent, a thin needle and hub — like an Activity-style gauge. Painted only when the value or
// a colour changes (no loop).
Canvas {
    id: root

    property real value: 0           // Mbit/s
    property real maxValue: 1000
    readonly property real frac: Speed.running && (Speed.phase === "download" || Speed.phase === "upload" || Speed.phase === "ping") ? Speed.wobble : Math.min(1, Math.log10(1 + value) / Math.log10(1 + maxValue))
    property real shown: frac
    Behavior on shown {
        NumberAnimation {
            duration: Skin.ms(180)
            easing.type: Easing.OutCubic
        }
    }
    readonly property bool mac: Skin.mac && !Skin.hell
    readonly property int b: Theme.u * 3        // block size (pixel look)
    property color on: Speed.phase === "upload" ? Theme.accent2 : Skin.accent
    property color off: mac ? Skin.sunken : Theme.dark ? Theme.hi : Theme.lo
    readonly property color needle: mac ? Skin.text : Theme.dark ? Theme.text : Theme.edge

    width: Skin.px(220)
    height: Skin.px(120)
    renderTarget: Canvas.Image
    antialiasing: mac

    onShownChanged: requestPaint()
    onOnChanged: requestPaint()
    onOffChanged: requestPaint()
    onMacChanged: requestPaint()
    onNeedleChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (mac) {
            const lw = Skin.px(12);
            const cx = width / 2, cy = height - lw / 2 - Skin.px(4);
            const r = Math.min(width / 2, cy) - lw / 2;
            ctx.lineCap = "round";
            ctx.lineWidth = lw;
            ctx.strokeStyle = off;
            ctx.beginPath();
            ctx.arc(cx, cy, r, Math.PI, 2 * Math.PI, false);
            ctx.stroke();
            if (shown > 0.005) {
                ctx.strokeStyle = on;
                ctx.beginPath();
                ctx.arc(cx, cy, r, Math.PI, Math.PI + shown * Math.PI, false);
                ctx.stroke();
            }
            const a = Math.PI + shown * Math.PI;
            ctx.lineWidth = Skin.px(2.5);
            ctx.strokeStyle = needle;
            ctx.beginPath();
            ctx.moveTo(cx, cy);
            ctx.lineTo(cx + Math.cos(a) * (r - lw), cy + Math.sin(a) * (r - lw));
            ctx.stroke();
            ctx.fillStyle = needle;
            ctx.beginPath();
            ctx.arc(cx, cy, Skin.px(4), 0, 2 * Math.PI, false);
            ctx.fill();
            return;
        }
        const cx = width / 2, cy = height - b;
        const r1 = width / 2 - b, r0 = r1 - b * 4;
        // arc blocks
        for (let a = 0; a <= 180; a += 4) {
            const t = a / 180;
            const rad = Math.PI - t * Math.PI;
            for (let rr = r0; rr <= r1; rr += b) {
                const x = Math.round((cx + Math.cos(rad) * rr) / b) * b;
                const y = Math.round((cy - Math.sin(rad) * rr) / b) * b;
                ctx.fillStyle = t <= shown ? on : off;
                ctx.fillRect(x, y, b, b);
            }
        }
        // needle
        const rad = Math.PI - shown * Math.PI;
        ctx.fillStyle = needle;
        for (let rr = 0; rr < r0 - b; rr += b) {
            const x = Math.round((cx + Math.cos(rad) * rr) / b) * b;
            const y = Math.round((cy - Math.sin(rad) * rr) / b) * b;
            ctx.fillRect(x, y, b, b);
        }
        ctx.fillStyle = Theme.accent3;
        ctx.fillRect(Math.round(cx / b) * b - b, cy - b, b * 2, b * 2);
    }
}
