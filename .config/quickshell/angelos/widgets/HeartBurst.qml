import QtQuick
import qs.config

// Pool of pixel hearts thrown from a point: burst(x, y, n, spread) for a
// firework, pop(x, y) for a single heart floating away.
Item {
    id: root

    property int poolSize: 48
    property real gravity: 0.35
    // other pieces than hearts (icon names) and their colours; empty = hearts in the accents
    property var shapes: []
    property var colors: []
    readonly property bool busy: live > 0
    property int live: 0

    function spawn(x, y, vx, vy, big, broken) {
        for (let i = 0; i < rep.count; i++) {
            const p = rep.itemAt(i);
            if (p && !p.alive) {
                p.x = x - p.width / 2;
                p.y = y - p.height / 2;
                p.fx = p.x;
                p.fy = p.y;
                p.vx = vx;
                p.vy = vy;
                p.life = 1;
                p.name = broken ? "heartBroken" : shapes.length ? shapes[Math.floor(Math.random() * shapes.length)] : big ? "heart" : (Math.random() < 0.5 ? "heartSmall" : "heart");
                p.pixel = Math.max(1, Theme.u * (big ? 2 : 1));
                p.fill = colors.length ? colors[Math.floor(Math.random() * colors.length)] : Math.random() < 0.7 ? Theme.accent : Theme.accent2;
                p.alive = true;
                live++;
                ticker.start();
                return;
            }
        }
    }
    function burst(x, y, n, spread) {
        for (let i = 0; i < n; i++) {
            const a = Math.random() * Math.PI * 2;
            const v = (0.4 + Math.random()) * (spread || Theme.u * 6);
            spawn(x, y, Math.cos(a) * v, Math.sin(a) * v - Theme.u * 2, Math.random() < 0.3, false);
        }
    }
    function pop(x, y) {
        spawn(x, y, (Math.random() - 0.5) * Theme.u * 2, -Theme.u * (2 + Math.random() * 2), false, false);
    }
    function drop(x, y) {
        spawn(x, y, (Math.random() - 0.5) * Theme.u, Theme.u, false, true);
    }

    Repeater {
        id: rep
        model: root.poolSize
        PxIcon {
            required property int index
            property bool alive: false
            property real vx: 0
            property real vy: 0
            property real fx: 0                // where it is between pixels
            property real fy: 0
            property real life: 0
            visible: alive
            opacity: Math.min(1, life * 1.6)
        }
    }
    // every frame of the screen; the steps were tuned for 25 a second, `k` keeps their speed
    FrameAnimation {
        id: ticker
        onTriggered: {
            const k = Math.min(frameTime, 0.1) / 0.04;
            let n = 0;
            for (let i = 0; i < rep.count; i++) {
                const p = rep.itemAt(i);
                if (!p || !p.alive)
                    continue;
                p.fx += p.vx * k;
                p.fy += p.vy * k;
                p.x = Math.round(p.fx);
                p.y = Math.round(p.fy);
                p.vy += root.gravity * (p.name === "heartBroken" ? 2 : 0.4) * k;
                p.vx *= Math.pow(0.97, k);
                p.life -= 0.022 * k;
                if (p.life <= 0) {
                    p.alive = false;
                    continue;
                }
                n++;
            }
            root.live = n;
            if (n === 0)
                stop();
        }
    }
}
