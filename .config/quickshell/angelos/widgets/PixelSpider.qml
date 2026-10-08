import QtQuick
import qs.config

// The cobweb's spider (modules/cobweb/CobwebView, widgets/CobwebBadge): 9 × 7 art pixels, a dark
// body with a pale rim so it shows on black pages and on white ones, pink eyes. Two leg frames:
// `step` flips them while it walks. Its centre is its body's centre.
Canvas {
    id: root

    property int pixel: Theme.u
    property bool step: false
    property real rim: 0.6

    readonly property var frames: [["o.......o", ".o.o.o.o.", "..ooooo..", "ooooeoooo", "..ooooo..", ".o.o.o.o.", "o.......o"], [".o.....o.", "o..o.o..o", ".oooooo..", "..ooeoooo", ".oooooo..", "o..o.o..o", ".o.....o."]]
    readonly property var art: frames[step ? 1 : 0]

    width: 11 * pixel
    height: 9 * pixel
    antialiasing: false
    renderTarget: Canvas.Image
    onArtChanged: requestPaint()
    onPixelChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const p = pixel, a = art;
        const body = (x, y) => y >= 0 && y < a.length && x >= 0 && x < a[y].length && a[y][x] !== ".";
        // the rim: every empty pixel next to the body
        ctx.fillStyle = Qt.rgba(0.92, 0.9, 1, rim);
        for (let y = -1; y <= a.length; y++)
            for (let x = -1; x <= a[0].length; x++) {
                if (body(x, y))
                    continue;
                if (body(x - 1, y) || body(x + 1, y) || body(x, y - 1) || body(x, y + 1))
                    ctx.fillRect((x + 1) * p, (y + 1) * p, p, p);
            }
        for (let y = 0; y < a.length; y++)
            for (let x = 0; x < a[y].length; x++) {
                const c = a[y][x];
                if (c === ".")
                    continue;
                ctx.fillStyle = c === "e" ? "#ff5cad" : (y + x) % 5 === 0 ? "#3d3149" : "#241c2b";
                ctx.fillRect((x + 1) * p, (y + 1) * p, p, p);
            }
    }
}
