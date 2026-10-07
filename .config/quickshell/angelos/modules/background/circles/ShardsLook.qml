pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.config
import qs.services
import qs.widgets

// The look of RadialMenu in the circle of treachery: an ice crystal grows from the pointer —
// six arms with their side branches; the entries are hexagons of ice, six at the arms' ends,
// six more between them, and further out along the arms the rest. Opening, the crystal grows
// and freezes them in place. The one you're on takes the accent's cold light.
// The toy (CircleToy): betray the entries — a right click on an ice tile hits it, three hits
// and it shatters (it's gone from the menu till the next opening; the keys still reach it); a
// click on the bare ice cracks it there, and the cracks hurt the tiles they reach. Break them
// all and the ice grows back. The words are story/toys.json → treachery.
Item {
    id: look

    required property var menu
    readonly property real k: menu.k
    readonly property int n: menu.slots.length
    readonly property real slotSize: Math.round(Theme.u * 20 * k)
    readonly property real labelRoom: menu.labels ? Theme.sizeTiny + Theme.u * 3 : 0
    readonly property real r1: Math.max(Theme.u * 50 * k, slotSize * 2.5)
    readonly property real gap: slotSize + labelRoom + Theme.u * 8 * k
    // ring 0: on the arms · ring 1: between the arms, further out · ring 2+: out along the
    // arms and between them by turns
    function placeOf(i) {
        const ring = Math.floor(i / 6), j = i % 6;
        const between = ring % 2 === 1;
        const r = r1 + ring * gap * 0.6;
        return {
            "a": -Math.PI / 2 + (j + (between ? 0.5 : 0)) * Math.PI / 3,
            "r": r
        };
    }
    readonly property real outer: {
        let m = r1;
        for (let i = 0; i < n; i++)
            m = Math.max(m, placeOf(i).r);
        return m;
    }
    readonly property real reach: outer + slotSize / 2 + labelRoom + Theme.u * 6
    readonly property Item blurItem: null
    readonly property real grow: menu.reveal
    function pointOf(i, extra) {
        const p = placeOf(i), r = p.r * grow + (extra || 0);
        return Qt.point(menu.cx + Math.cos(p.a) * r, menu.cy + Math.sin(p.a) * r);
    }
    // the toy: the cracks in the ice ({lines: [[x1, y1, x2, y2]…], t}), the shudder, the
    // hits each entry took (3 = broken)
    property var cracks: []
    property real shudder: 0
    property var damage: []
    readonly property int broken: damage.filter(d => d >= 3).length
    function hurt(i, by) {
        const d = damage.slice();
        while (d.length < n)
            d.push(0);
        if (d[i] >= 3)
            return;
        d[i] = Math.min(3, d[i] + by);
        damage = d;
        const p = pointOf(i);
        if (d[i] < 3) {
            Sounds.playSoft("crack", 0.35);
            return;
        }
        // shattered: betrayed
        chips.burst(p.x, p.y, {
            "n": 22,
            "colors": [Theme.hellText, Qt.alpha(Theme.hellText, 0.6), Theme.hellAccent],
            "size": 2.5,
            "speed": 180,
            "up": 60,
            "life": 900
        });
        if (menu.current === i)
            menu.current = -1;
        const t = HellToys.part("treachery"), e = DeskMenu.entry(menu.slots[i]);
        if (d.filter(x => x >= 3).length >= n) {
            talk.at = Qt.point(menu.cx, menu.cy - slotSize);
            talk.say("", HellToys.t(t.allBroken[0]), [], 1200);
            shudderAnim.restart();
            regrow.restart();
        } else {
            talk.at = Qt.point(p.x, p.y - slotSize / 2);
            talk.say("", HellToys.t(HellToys.pick(t.broken), e ? (e.short || e.label) : ""), [], 900);
        }
        Sounds.play(Motion.calm ? "crack" : "shatter");
    }
    // the tile under (x, y)
    function tileAt(x, y) {
        for (let i = 0; i < n; i++) {
            const p = pointOf(i);
            if (Math.hypot(p.x - x, p.y - y) < slotSize * 0.55)
                return i;
        }
        return -1;
    }
    Timer {
        id: regrow
        interval: 1800
        onTriggered: {
            look.damage = [];
            Sounds.playSoft("crack", 0.3);
        }
    }
    function knock(x, y, big) {
        const lines = [], u = Theme.u;
        const arms = 4 + Math.floor(Math.random() * 3);
        for (let i = 0; i < arms; i++) {
            let a = Math.random() * 2 * Math.PI, px = x, py = y;
            const len = u * (14 + Math.random() * 22) * k;
            // each arm a few kinked steps, a branch off the middle one
            for (let j = 0; j < 3; j++) {
                a += (Math.random() - 0.5) * 0.7;
                const nx = px + Math.cos(a) * len / 3, ny = py + Math.sin(a) * len / 3;
                lines.push([px, py, nx, ny]);
                if (j === 1 && Math.random() < 0.6) {
                    const b = a + (Math.random() < 0.5 ? -1 : 1) * 0.8;
                    lines.push([nx, ny, nx + Math.cos(b) * len / 4, ny + Math.sin(b) * len / 4]);
                }
                px = nx;
                py = ny;
            }
        }
        cracks = cracks.filter(c => Date.now() - c.t < 8000).concat([{
                "lines": lines,
                "t": Date.now()
            }]);
        chips.burst(x, y, {
            "n": 8,
            "colors": [Theme.hellText, Qt.alpha(Theme.hellText, 0.6), Theme.hellAccent],
            "size": 1.5,
            "speed": 110,
            "up": 50,
            "life": 600
        });
        Sounds.playSoft("crack", 0.45);
        frost.requestPaint();
        // the tiles the cracks run into
        const reach = Theme.u * 30 * k * (big ? 1.5 : 1);
        for (let i = 0; i < n; i++) {
            const p = pointOf(i);
            if (Math.hypot(p.x - x, p.y - y) < reach)
                hurt(i, 1);
        }
    }
    function nav(e) {
        if (e.key === Qt.Key_Escape && talk.open) {
            talk.hide();
            return true;
        }
        return menu.walk(e);
    }
    anchors.fill: parent
    readonly property bool talking: talk.open
    Connections {
        target: look.menu && look.menu.opened ? look.menu : null
        ignoreUnknownSignals: true
        function onOpened() {
            regrow.stop();
            look.damage = [];
            look.cracks = [];
        }
    }

    NumberAnimation {
        id: shudderAnim
        target: look
        property: "shudder"
        from: 1
        to: 0
        duration: Motion.ms(450)
    }
    CircleToy {
        menu: look.menu
        radius: look.reach
        cursorShape: Qt.CrossCursor
        hoverEnabled: on
        onDown: (x, y, right) => {
            const i = right ? look.tileAt(x, y) : -1;
            if (i >= 0)
                look.hurt(i, 1);
            else
                look.knock(x, y, right);
        }
    }
    // the cracks, fading as the ice heals over
    Canvas {
        id: frost
        x: look.menu.cx - look.reach
        y: look.menu.cy - look.reach
        width: look.reach * 2
        height: width
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.translate(-x, -y);
            const now = Date.now();
            ctx.lineWidth = Math.max(1, Theme.u * 0.75);
            for (const c of look.cracks) {
                const a = Math.max(0, 1 - (now - c.t) / 8000);
                ctx.strokeStyle = Qt.alpha(Theme.hellText, 0.75 * a).toString();
                ctx.beginPath();
                for (const l of c.lines) {
                    ctx.moveTo(l[0], l[1]);
                    ctx.lineTo(l[2], l[3]);
                }
                ctx.stroke();
            }
        }
        Timer {
            interval: 400
            repeat: true
            running: look.cracks.length > 0 && look.menu.visible
            onTriggered: {
                look.cracks = look.cracks.filter(c => Date.now() - c.t < 8000);
                frost.requestPaint();
            }
        }
    }

    // the arms and their side branches
    Repeater {
        model: 6
        Item {
            id: arm
            required property int index
            readonly property real len: (look.outer + look.slotSize * 0.2) * look.grow
            x: look.menu.cx
            y: look.menu.cy - height / 2
            width: len
            height: Math.max(2, Theme.u * 2)
            transformOrigin: Item.Left
            rotation: -90 + index * 60 + Math.sin(look.shudder * 30) * look.shudder * 3
            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Theme.hellText, 0.55)
            }
            // two pairs of branches, at 40 % and 70 % of the arm
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    readonly property real at: index < 2 ? 0.4 : 0.7
                    x: arm.len * at
                    y: (arm.height - height) / 2
                    width: look.slotSize * (index < 2 ? 0.9 : 0.6)
                    height: Math.max(1, Theme.u)
                    transformOrigin: Item.Left
                    rotation: index % 2 ? -45 : 45
                    color: Qt.alpha(Theme.hellText, 0.4)
                }
            }
        }
    }

    CircleHub {
        menu: look.menu
        size: Math.round(look.slotSize * 1.15)
        corner: Theme.u
        tilt: 45
        color: Qt.alpha(Theme.hellBody, 0.9)
        hover: Theme.hellFaceAlt
        rim: Theme.hellText
        nameGap: Theme.u * 3
    }

    Repeater {
        model: look.menu.slots
        CircleEntry {
            id: shard
            menu: look.menu
            readonly property point at: look.pointOf(index)
            readonly property int hits: look.damage[index] || 0
            width: look.slotSize
            height: look.slotSize + look.labelRoom
            x: at.x - width / 2
            y: at.y - look.slotSize / 2
            enabled: hits < 3
            opacity: hits >= 3 ? 0 : Math.max(0, Math.min(1, look.menu.reveal * 1.6 - Math.floor(index / 6) * 0.2))
            // a hexagon of ice
            Shape {
                id: hex
                width: look.slotSize
                height: look.slotSize
                scale: shard.hot ? 1.15 : 1
                preferredRendererType: Shape.CurveRenderer
                readonly property real s: width / 2
                ShapePath {
                    strokeWidth: Math.max(1, Theme.u / 2)
                    strokeColor: shard.hot ? Theme.hellAccent : Qt.alpha(Theme.hellText, 0.7)
                    fillColor: shard.hot ? Theme.hellFaceAlt : Qt.alpha(Theme.hellPlate, 0.92)
                    startX: hex.s
                    startY: 0
                    PathLine {
                        x: hex.s + hex.s * 0.866
                        y: hex.s * 0.5
                    }
                    PathLine {
                        x: hex.s + hex.s * 0.866
                        y: hex.s * 1.5
                    }
                    PathLine {
                        x: hex.s
                        y: hex.s * 2
                    }
                    PathLine {
                        x: hex.s - hex.s * 0.866
                        y: hex.s * 1.5
                    }
                    PathLine {
                        x: hex.s - hex.s * 0.866
                        y: hex.s * 0.5
                    }
                    PathLine {
                        x: hex.s
                        y: 0
                    }
                }
            }
            // a glint of frost on the upper edge
            Rectangle {
                x: hex.width * 0.3
                y: hex.height * 0.2
                width: Math.max(1, Theme.u)
                height: Math.max(1, Theme.u)
                color: Theme.hellText
                opacity: 0.8
            }
            // the hits it took: cracks across the tile
            PxIcon {
                visible: shard.hits > 0
                anchors.centerIn: hex
                bitmap: shard.hits > 1 ? ["....#.....", "...#......", "...#...#..", "..#...#...", "..##.#....", ".#..#.....", ".#..##....", "#....#....", ".....#.#..", "......#..."] : ["..........", "....#.....", "...#......", "...#......", "..#.#.....", "..#..#....", ".#........", "..........", "..........", ".........."]
                pixel: Math.max(1, Math.round(look.slotSize / 10))
                ink: Qt.alpha(Theme.hellText, 0.85)
                z: 2
            }
            CircleIcon {
                anchors.centerIn: hex
                hot: shard.hot
                name: shard.icon
                pixel: Math.max(1, Math.round(Theme.u * look.k * 0.8))
            }
            CircleLabel {
                visible: look.menu.labels
                hot: shard.hot
                anchors.horizontalCenter: hex.horizontalCenter
                y: look.slotSize + Theme.u * 2
                text: shard.label
            }
        }
    }

    CircleBits {
        id: chips
    }
    CircleHint {
        menu: look.menu
        rule: "shards"
        below: look.reach
        status: look.broken ? HellToys.t(HellToys.part("treachery").back) : ""
    }
    CircleTalk {
        id: talk
        menu: look.menu
    }

    CircleFly {
        menu: look.menu
        reach: look.reach
        at: look.menu.flyIndex >= 0 ? look.pointOf(look.menu.flyIndex, look.slotSize / 2) : Qt.point(look.menu.cx, look.menu.cy)
    }
}
