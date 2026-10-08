import QtQuick
import qs.config
import qs.services

// A window's cobweb, small, in the top right corner of its button (modules/bar/parts/Tasks, the
// Golden Gate Dock): a corner web that grows with the big one over the window (services/Cobweb
// amount: two threads, then rings), and once it is a proper web its spider hangs from the
// corner on a thread and sways. The pointer over the button: the spider climbs up and hides.
// `ids`: the windows it is about (the Dock's app: all of its windows, the most webbed counts).
Item {
    id: root

    property var ids: []
    property bool hovered: false
    property int pixel: Theme.u
    readonly property real amount: {
        Cobweb.rev;
        let a = 0;
        for (const id of ids)
            a = Math.max(a, Cobweb.amount(id));
        return a;
    }
    readonly property bool spider: {
        Cobweb.rev;
        Cobweb.now;
        return amount > 0.12 && ids.some(id => Cobweb.spiderHere(id));
    }
    // how much of the corner is drawn: 0 none … 4 a full corner web
    readonly property int level: amount <= 0 ? 0 : amount < 0.06 ? 1 : amount < 0.2 ? 2 : amount < 0.45 ? 3 : 4
    property int art: 12

    visible: Cobweb.onBar && level > 0
    width: art * pixel
    height: art * pixel

    Canvas {
        id: canvas
        width: root.art
        height: root.art
        transformOrigin: Item.TopLeft
        scale: root.pixel
        smooth: false
        antialiasing: false
        renderTarget: Canvas.Image
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (root.level <= 0)
                return;
            // the corner: top right; radials fan from it, rings cross them
            const W = root.art, cx = W - 1, cy = 0, R = W - 2;
            const fan = root.level >= 3 ? [0.12, 0.38, 0.62, 0.88] : [0.22, 0.78];
            const end = t => ({
                    "x": cx - R * Math.cos(t * Math.PI / 2),
                    "y": cy + R * Math.sin(t * Math.PI / 2)
                });
            const lines = [[{
                        "x": cx - R,
                        "y": cy
                    }, {
                        "x": cx,
                        "y": cy + R
                    }]];
            for (const t of fan)
                lines.push([{
                            "x": cx,
                            "y": cy
                        }, end(t)]);
            const rings = [0, 0, 1, 2, 3][root.level];
            for (let k = 1; k <= rings; k++) {
                const sc = k / (rings + 1);
                const ring = [{
                        "x": cx - R * sc,
                        "y": cy
                    }];
                for (const t of fan.concat([1])) {
                    const e = end(t);
                    ring.push({
                        "x": cx + (e.x - cx) * sc,
                        "y": cy + (e.y - cy) * sc
                    });
                }
                lines.push(ring);
            }
            ctx.lineWidth = 1;
            for (const pass of [0, 1]) {
                const d = pass ? 0.5 : 1.5;
                ctx.strokeStyle = pass ? Qt.rgba(0.93, 0.91, 0.98, 0.9) : Qt.rgba(0.05, 0.03, 0.1, 0.55);
                ctx.beginPath();
                for (const pts of lines) {
                    ctx.moveTo(Math.round(pts[0].x) + d, Math.round(pts[0].y) + d);
                    for (let k = 1; k < pts.length; k++)
                        ctx.lineTo(Math.round(pts[k].x) + d, Math.round(pts[k].y) + d);
                }
                ctx.stroke();
            }
        }
    }
    onLevelChanged: canvas.requestPaint()
    onVisibleChanged: if (visible)
        canvas.requestPaint()
    Component.onCompleted: canvas.requestPaint()

    // the spider on its thread from the corner: down when nobody is near, up under the pointer
    property real drop: spider && !hovered ? (level >= 4 ? 1 : 0.6) : 0
    Behavior on drop {
        NumberAnimation {
            duration: Motion.ms(root.hovered ? 260 : 900)
            easing.type: root.hovered ? Easing.OutQuad : Easing.InOutSine
        }
    }
    property real sway: 0
    SequentialAnimation on sway {
        running: root.drop > 0.05 && !Motion.calm && root.visible
        loops: Animation.Infinite
        NumberAnimation {
            to: 1
            duration: 1400
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: -1
            duration: 1400
            easing.type: Easing.InOutSine
        }
    }
    readonly property real hang: drop * root.art * 0.8 * pixel
    Item {
        visible: root.drop > 0.05
        x: root.width - root.pixel * 3
        y: 0
        rotation: root.sway * 7
        transformOrigin: Item.Top
        Rectangle {
            x: 0
            width: Math.max(1, Math.round(root.pixel / 2))
            height: root.hang
            color: Qt.rgba(0.93, 0.91, 0.98, 0.9)
        }
        PixelSpider {
            pixel: Math.max(1, Math.round(root.pixel / 2))
            x: -width / 2
            y: root.hang - height / 3
        }
    }
}
