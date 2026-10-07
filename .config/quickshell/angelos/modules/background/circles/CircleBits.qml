import QtQuick
import qs.config

// Bits flying off a circle's toy (CircleToy): coins off the wheel, crumbs off the plate,
// drops off the Styx, embers, chips of ice. burst(x, y, opts) throws `n` square bits out of
// (x, y) — opts: n, colors, size (in Theme.u), speed (px/s), up (px/s upwards), spread
// (radians round `dir`, which is up by default), gravity (px/s²), life (ms). Nothing flies
// with motion off; a calmer few with calm.
Item {
    id: bits

    readonly property int cap: 160
    anchors.fill: parent

    function burst(x, y, o) {
        o = o || {};
        if (Motion.still)
            return;
        const n = Math.min(Math.round((o.n || 10) * (Motion.calm ? 0.5 : 1)), cap - children.length);
        const colors = o.colors || [Theme.hellAccent];
        const spread = o.spread === undefined ? Math.PI * 2 : o.spread;
        const dir = o.dir === undefined ? -Math.PI / 2 : o.dir;
        for (let i = 0; i < n; i++) {
            const a = dir + (Math.random() - 0.5) * spread;
            const v = (o.speed || 120) * (0.4 + Math.random() * 0.8);
            piece.createObject(bits, {
                "x0": x,
                "y0": y,
                "vx": Math.cos(a) * v,
                "vy": Math.sin(a) * v - (o.up || 0),
                "g": o.gravity === undefined ? 420 : o.gravity,
                "life": (o.life || 700) * (0.7 + Math.random() * 0.6),
                "side": Math.max(1, Math.round(Theme.u * (o.size || 2) * (0.6 + Math.random() * 0.7))),
                "color": colors[Math.floor(Math.random() * colors.length)],
                "spin": (Math.random() - 0.5) * 720
            });
        }
    }

    Component {
        id: piece
        Rectangle {
            id: p
            property real x0
            property real y0
            property real vx
            property real vy
            property real g
            property real life: 700
            property real side: 2
            property real spin: 0
            property real t: 0
            readonly property real s: t * life / 1000
            x: x0 + vx * s - side / 2
            y: y0 + vy * s + g * s * s / 2 - side / 2
            width: side
            height: side
            rotation: spin * s
            opacity: 1 - t * t
            NumberAnimation on t {
                from: 0
                to: 1
                duration: p.life
                running: true
                onFinished: p.destroy()
            }
        }
    }
}
