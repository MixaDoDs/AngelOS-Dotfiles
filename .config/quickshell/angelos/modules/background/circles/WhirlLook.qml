pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// The look of RadialMenu in the circle of lust: the entries are petals caught in the
// whirlwind — strung along a spiral that winds out from the pointer, each petal turned along
// the wind; opening, the wind turns them into place. The middle is the eye of the storm.
// The toy (CircleToy): stir the wind round the eye and it carries the petals with it — the
// faster, the further out they're flung and the more of them tear off; a right click is a
// gust. Let go and the storm calms down, the petals where it left them.
Item {
    id: look

    required property var menu
    readonly property real k: menu.k
    readonly property int n: menu.slots.length
    readonly property real slotSize: Math.round(Theme.u * 20 * k)
    readonly property real labelRoom: menu.labels ? Theme.sizeTiny + Theme.u * 3 : 0
    // the spiral r = a + b·θ: one turn further out is a petal and its name
    readonly property real a: Theme.u * 30 * k
    readonly property real b: (slotSize + labelRoom + Theme.u * 6 * k) / (2 * Math.PI)
    readonly property var pts: {
        const out = [];
        let t = 0;
        for (let i = 0; i < n; i++) {
            const r = a + b * t;
            out.push({
                "t": t,
                "r": r
            });
            t += (slotSize + Theme.u * (menu.labels ? 16 : 8) * k) / r;
        }
        return out;
    }
    readonly property real outer: n ? pts[n - 1].r : a
    readonly property real reach: outer + slotSize / 2 + labelRoom + Theme.u * 4
    readonly property Item blurItem: null
    // the wind's turn while it opens: everything comes in from further round the spiral
    readonly property real spin: (1 - menu.reveal) * -2.2 + turn
    // the toy: the wind's turn by hand and its speed (rad/s); fast wind flings the petals out
    property real turn: 0
    property real vel: 0
    property real lastA: 0
    property real lastT: 0
    readonly property real fling: 1 + Math.min(0.3, Math.abs(vel) * 0.03)
    function angleOf(i) {
        return -Math.PI / 2 + pts[i].t + spin;
    }
    function radiusOf(i) {
        return pts[i].r * (0.35 + 0.65 * menu.reveal) * fling;
    }
    // petals torn off by the wind, off the outer end of the spiral
    function tear(n) {
        const a = -Math.PI / 2 + (look.n ? pts[look.n - 1].t : 0) + spin, r = outer * fling;
        bits.burst(menu.cx + Math.cos(a) * r, menu.cy + Math.sin(a) * r, {
            "n": n || 3,
            "colors": [Theme.hellAccent, Theme.hellFaceAlt, Theme.hellRim],
            "size": 2,
            "speed": 60 + Math.abs(vel) * 12,
            "dir": a + Math.PI / 2 * Math.sign(vel || 1),
            "spread": 1.2,
            "gravity": 40,
            "life": 1100
        });
    }
    function nav(e) {
        return menu.walk(e);
    }
    anchors.fill: parent

    FrameAnimation {
        running: look.vel !== 0 && !toy.held
        onTriggered: {
            const dt = Math.min(0.05, frameTime);
            look.turn += look.vel * dt;
            look.vel *= Math.pow(0.35, dt);
            if (Math.abs(look.vel) > 6 && Math.random() < dt * Math.abs(look.vel) * 0.4)
                look.tear(2);
            if (Math.abs(look.vel) < 0.05 || Motion.still)
                look.vel = 0;
        }
    }

    // the wind: the spiral's path in dotted streaks, turning with the petals
    Canvas {
        id: wind
        readonly property real d: (look.reach + Theme.u * 6) * 2
        x: look.menu.cx - d / 2
        y: look.menu.cy - d / 2
        width: d
        height: d
        rotation: look.spin * 180 / Math.PI
        opacity: 0.8 * look.menu.reveal
        onWidthChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const u = Theme.u, c = width / 2;
            ctx.fillStyle = Theme.hellRim.toString();
            // a dot every few pixels along the spiral, from the eye to past the last petal
            const end = look.n ? look.pts[look.n - 1].t + 1.2 : 6;
            for (let t = 0; t < end; t += 0.05) {
                const r = look.a * 0.6 + look.b * t;
                if (Math.floor(t * 20) % 3 === 2)
                    continue;
                const x = c + Math.cos(-Math.PI / 2 + t - 0.35) * r, y = c + Math.sin(-Math.PI / 2 + t - 0.35) * r;
                ctx.fillRect(Math.round(x / u) * u, Math.round(y / u) * u, u, u);
            }
        }
    }

    CircleToy {
        id: toy
        menu: look.menu
        radius: look.reach
        cursorShape: held ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        hoverEnabled: on
        onDown: (x, y, right) => {
            if (right) {
                look.vel += (look.vel < 0 ? -1 : 1) * 10;
                Sounds.playSoft("circleSoft", 0.7);
                look.tear(10);
                held = false;
                return;
            }
            look.lastA = Math.atan2(y - look.menu.cy, x - look.menu.cx);
            look.lastT = Date.now();
        }
        onDrag: (x, y) => {
            const a = Math.atan2(y - look.menu.cy, x - look.menu.cx);
            let d = a - look.lastA;
            if (d > Math.PI)
                d -= 2 * Math.PI;
            if (d < -Math.PI)
                d += 2 * Math.PI;
            const now = Date.now(), dt = Math.max(1, now - look.lastT) / 1000;
            look.turn += d;
            look.vel = Math.max(-30, Math.min(30, look.vel * 0.6 + (d / dt) * 0.4));
            look.lastA = a;
            look.lastT = now;
            if (Math.abs(look.vel) > 6 && Math.random() < 0.15)
                look.tear(2);
        }
        onUp: (x, y) => {
            if (Date.now() - look.lastT > 150)
                look.vel = 0;
        }
    }

    CircleHub {
        menu: look.menu
        size: Math.round(look.slotSize * 1.1)
        color: Theme.hellBody
        nameGap: Theme.u * 2
    }

    // the petals
    Repeater {
        model: look.menu.slots
        CircleEntry {
            id: petal
            menu: look.menu
            readonly property real ang: look.angleOf(index)
            readonly property real r: look.radiusOf(index)
            readonly property real lit: Math.max(0, Math.min(1, look.menu.reveal * 1.5 - index * 0.04))
            width: look.slotSize
            height: look.slotSize + look.labelRoom
            x: look.menu.cx + Math.cos(ang) * r - width / 2
            y: look.menu.cy + Math.sin(ang) * r - look.slotSize / 2
            opacity: lit
            // a petal: two round corners, turned along the wind
            Rectangle {
                id: leaf
                width: look.slotSize
                height: look.slotSize
                rotation: petal.ang * 180 / Math.PI + 45
                topLeftRadius: width / 2
                bottomRightRadius: width / 2
                scale: petal.hot ? 1.15 : 1
                Behavior on scale {
                    NumberAnimation {
                        duration: Motion.ms(90)
                    }
                }
                color: petal.hot ? Theme.hellFaceAlt : Theme.hellPlate
                border.width: Math.max(1, Theme.u / 2)
                border.color: petal.hot ? Theme.hellAccent : Theme.hellRim
            }
            CircleIcon {
                anchors.centerIn: leaf
                hot: petal.hot
                name: petal.icon
                pixel: Math.max(1, Math.round(Theme.u * look.k * 0.85))
            }
            CircleLabel {
                visible: look.menu.labels
                hot: petal.hot
                anchors.horizontalCenter: leaf.horizontalCenter
                y: look.slotSize + Theme.u * 2
                text: petal.label
            }
        }
    }

    CircleBits {
        id: bits
    }

    CircleHint {
        menu: look.menu
        rule: "whirl"
        below: look.reach
    }

    CircleFly {
        menu: look.menu
        reach: look.reach
        at: look.menu.flyIndex >= 0 ? Qt.point(look.menu.cx + Math.cos(look.angleOf(look.menu.flyIndex)) * (look.radiusOf(look.menu.flyIndex) + look.slotSize / 2), look.menu.cy + Math.sin(look.angleOf(look.menu.flyIndex)) * (look.radiusOf(look.menu.flyIndex) + look.slotSize / 2)) : Qt.point(look.menu.cx, look.menu.cy)
    }
}
