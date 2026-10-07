pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// The look of RadialMenu in the circle of wrath: a stone dropped into the Styx at the
// pointer. Ripples run out from it, and the entries are stones on them — six on the first
// ring, the rest on the next ones, each ring turned half a step; the one you're on rings the
// water round itself. Opening, the ripples spread out to their places.
// The toy (CircleToy): the Styx is the swamp of the wrathful, and the sullen ones sulk under
// its water — their sighs come up as bubbles. Throw a stone (a click; a right click throws a
// big one) and the ripples rock every stone they reach; hit the bubbles and a soul surfaces
// to swear at you, a third hit and it leaps out in a rage and sends a wave over everything.
// The words are story/toys.json → wrath.
Item {
    id: look

    required property var menu
    readonly property real k: menu.k
    readonly property int n: menu.slots.length
    readonly property real slotSize: Math.round(Theme.u * 20 * k)
    readonly property real labelRoom: menu.labels ? Theme.sizeTiny + Theme.u * 3 : 0
    readonly property real gap: slotSize + labelRoom + Theme.u * 10 * k
    // how many stones each ring holds: 6, then 10, then the rest
    readonly property var rings: {
        const out = [];
        let left = n, cap = 6;
        while (left > 0) {
            out.push(Math.min(left, cap));
            left -= cap;
            cap += 4;
        }
        return out;
    }
    readonly property real r0: Theme.u * 40 * k
    readonly property real outer: r0 + Math.max(0, rings.length - 1) * gap
    readonly property real reach: outer + slotSize / 2 + labelRoom + Theme.u * 6
    readonly property Item blurItem: null
    function ringOf(i) {
        let j = i;
        for (let r = 0; r < rings.length; r++) {
            if (j < rings[r])
                return {
                    "ring": r,
                    "at": j,
                    "of": rings[r]
                };
            j -= rings[r];
        }
        return {
            "ring": 0,
            "at": 0,
            "of": 1
        };
    }
    function angleOf(i) {
        const p = ringOf(i);
        return -Math.PI / 2 + (p.at + (p.ring % 2 ? 0.5 : 0)) * 2 * Math.PI / p.of;
    }
    function radiusOf(i) {
        return (r0 + ringOf(i).ring * gap) * (0.4 + 0.6 * menu.reveal);
    }
    readonly property real waterR: (outer + gap * 0.7) * (0.4 + 0.6 * menu.reveal)
    // the toy: the souls under the water, how many you've enraged, a miss explained once
    property int enraged: 0
    property bool missTold: false
    // a place under the water away from the stones (relative to the middle)
    function freeSpot() {
        for (let tries = 0; tries < 40; tries++) {
            const a = Math.random() * 2 * Math.PI, r = r0 * 0.55 + Math.random() * (outer + gap * 0.45 - r0 * 0.55);
            const x = Math.cos(a) * r, y = Math.sin(a) * r;
            let ok = true;
            for (let i = 0; i < n && ok; i++)
                ok = Math.hypot(Math.cos(angleOf(i)) * (r0 + ringOf(i).ring * gap) - x, Math.sin(angleOf(i)) * (r0 + ringOf(i).ring * gap) - y) > slotSize * 1.3;
            if (ok)
                return Qt.point(x, y);
        }
        return Qt.point(0, r0 * 0.5);
    }
    // where a soul is and how angry (the self-test)
    function soulSpot(i) {
        const so = souls.itemAt(i);
        return so ? Qt.point(menu.cx + so.at.x, menu.cy + so.at.y) : Qt.point(0, 0);
    }
    function angerOf(i) {
        const so = souls.itemAt(i);
        return so ? so.anger : -1;
    }
    // a stone in at (x, y): which soul's bubbles it hit
    function throwAt(x, y, big) {
        let best = null, bd = slotSize * (big ? 1.3 : 0.95);
        for (let i = 0; i < souls.count; i++) {
            const so = souls.itemAt(i);
            if (!so || so.busy)
                continue;
            const d = Math.hypot(menu.cx + so.at.x - x, menu.cy + so.at.y - y);
            if (d < bd) {
                bd = d;
                best = so;
            }
        }
        splash(x, y, big);
        if (best) {
            best.hit();
        } else if (!missTold) {
            missTold = true;
            talk.at = Qt.point(x, y);
            talk.say("", HellToys.t(HellToys.part("wrath").miss[0]), [], 1400);
        }
    }
    // a stone into the water at (x, y)
    function splash(x, y, big) {
        const reach = waterR * (big ? 1.6 : 1.1);
        for (let i = 0; i < (big ? 3 : 2); i++)
            ripple.createObject(rippleLayer, {
                "x0": x,
                "y0": y,
                "to": reach * (1 - i * 0.25),
                "wait": i * 140
            });
        Sounds.playSoft("rocks", big ? 1 : 0.55);
        drops.burst(x, y, {
            "n": big ? 16 : 8,
            "colors": [Theme.hellText, Theme.hellRim, Qt.alpha(Theme.hellText, 0.6)],
            "size": big ? 2 : 1.5,
            "speed": big ? 130 : 80,
            "up": big ? 160 : 100,
            "spread": 1.6,
            "life": 650
        });
        // the stones rock as the ripple reaches them
        for (let i = 0; i < stones.count; i++) {
            const st = stones.itemAt(i);
            if (!st)
                continue;
            const d = Math.hypot(st.x + st.width / 2 - x, st.y + slotSize / 2 - y);
            if (d < reach)
                st.rock(d / reach * 900, (big ? 1.6 : 1) * (1 - d / reach));
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
            look.missTold = false;
            for (let i = 0; i < souls.count; i++)
                souls.itemAt(i).reset();
        }
    }

    // a bubble: a sullen soul's sigh, up and pop
    Component {
        id: bubbleC
        Rectangle {
            id: bb
            property real x0
            property real y0
            property bool red: false
            property real f: 0
            readonly property real d: Math.max(2, Theme.u * (2 + f * 2.5))
            x: x0 - d / 2
            y: y0 - d / 2 - f * Theme.u * 3
            width: d
            height: d
            radius: d / 2
            color: "transparent"
            border.width: Math.max(1, Theme.u / 2)
            border.color: Qt.alpha(red ? Theme.hellAccent : Theme.hellText, 0.7 * (1 - f * f))
            NumberAnimation on f {
                from: 0
                to: 1
                duration: Math.max(300, Motion.ms(700))
                onFinished: bb.destroy()
            }
        }
    }

    // a ripple from a stone thrown in
    Component {
        id: ripple
        Rectangle {
            id: rp
            property real x0
            property real y0
            property real to: 100
            property int wait: 0
            property real f: 0
            x: x0 - width / 2
            y: y0 - height / 2
            width: Math.max(2, to * 2 * f)
            height: width
            radius: width / 2
            color: "transparent"
            border.width: Math.max(1, Theme.u)
            border.color: Qt.alpha(Theme.hellText, 0.55 * (1 - f))
            visible: f > 0
            SequentialAnimation {
                running: true
                PauseAnimation {
                    duration: rp.wait
                }
                NumberAnimation {
                    target: rp
                    property: "f"
                    from: 0.02
                    to: 1
                    duration: Math.max(300, Motion.ms(900))
                    easing.type: Easing.OutQuad
                }
                ScriptAction {
                    script: rp.destroy()
                }
            }
        }
    }

    // the dark water they run over
    Rectangle {
        readonly property real r: look.waterR
        x: look.menu.cx - r
        y: look.menu.cy - r
        width: r * 2
        height: width
        radius: r
        color: Qt.alpha(Theme.hellBody, 0.55 * look.menu.reveal)
    }
    // the ripples: each ring of stones, a ring between them, and two fading ones beyond
    Repeater {
        model: (look.rings.length + 2) * 2
        Rectangle {
            required property int index
            readonly property real r: (look.r0 * 0.5 + index * look.gap / 2) * (0.4 + 0.6 * look.menu.reveal)
            visible: index % 2 === 0
            x: look.menu.cx - r
            y: look.menu.cy - r
            width: r * 2
            height: width
            radius: r
            color: "transparent"
            border.width: Math.max(1, Theme.u / 2)
            border.color: Qt.alpha(Theme.hellText, Math.max(0.08, 0.3 - index * 0.04) * look.menu.reveal)
        }
    }
    Repeater {
        model: look.rings.length + 2
        Rectangle {
            required property int index
            readonly property real r: (look.r0 + index * look.gap) * (0.4 + 0.6 * look.menu.reveal)
            x: look.menu.cx - r
            y: look.menu.cy - r
            width: r * 2
            height: width
            radius: r
            color: "transparent"
            border.width: Math.max(1, Theme.u)
            border.color: Qt.alpha(Theme.hellRim, Math.max(0.2, 0.9 - index * 0.2) * look.menu.reveal)
        }
    }
    // the thrown stones' ripples, on the water under the stones
    Item {
        id: rippleLayer
        anchors.fill: parent
    }
    CircleToy {
        menu: look.menu
        radius: look.waterR
        cursorShape: Qt.CrossCursor
        hoverEnabled: on
        onDown: (x, y, right) => look.throwAt(x, y, right)
    }

    // the sullen souls under the water: bubbles where they are; hit, a head comes up to swear
    Repeater {
        id: souls
        model: 3
        Item {
            id: soul
            required property int index
            property point at: Qt.point(0, 0)
            Component.onCompleted: at = look.freeSpot()
            property int anger: 0
            property bool busy: false           // up and swearing, or leaping
            property real rise: 0               // how far out of the water, 0 … 1
            property real leap: 0               // the rage's jump
            readonly property real hx: look.menu.cx + at.x
            readonly property real hy: look.menu.cy + at.y
            function reset() {
                anger = 0;
                busy = false;
                rise = 0;
                leap = 0;
                at = look.freeSpot();
            }
            function hit() {
                anger++;
                busy = true;
                const w = HellToys.part("wrath");
                if (anger < 3) {
                    talk.at = Qt.point(hx, hy - Theme.u * 12);
                    talk.say(I18n.t("Угрюмая душа", "A sullen soul"), HellToys.t(HellToys.pick(w.hit[anger - 1])), [], 1500, anger > 1);
                    surface.restart();
                } else {
                    talk.at = Qt.point(hx, hy - Theme.u * 30);
                    talk.say(I18n.t("Гневная душа", "A wrathful soul"), HellToys.t(HellToys.pick(w.rage)), [], 1700, true);
                    rage.restart();
                }
            }
            // her sighs: more of them, and redder, the angrier she is
            Timer {
                running: look.menu.visible !== false && look.menu.reveal > 0.8 && !soul.busy && Config.desktop.menuToys !== false
                repeat: true
                interval: 1300 - soul.anger * 350 + soul.index * 170
                onTriggered: bubbleC.createObject(rippleLayer, {
                    "x0": soul.hx + (Math.random() - 0.5) * Theme.u * 6,
                    "y0": soul.hy + (Math.random() - 0.5) * Theme.u * 4,
                    "red": soul.anger > 0
                })
            }
            // up, a beat of swearing, back down
            SequentialAnimation {
                id: surface
                NumberAnimation {
                    target: soul
                    property: "rise"
                    to: 0.65
                    duration: Motion.ms(220)
                    easing.type: Easing.OutBack
                }
                PauseAnimation {
                    duration: 1500
                }
                NumberAnimation {
                    target: soul
                    property: "rise"
                    to: 0
                    duration: Motion.ms(300)
                }
                ScriptAction {
                    script: soul.busy = false
                }
            }
            // the rage: out of the water, a wave over everything, and off somewhere else
            SequentialAnimation {
                id: rage
                NumberAnimation {
                    target: soul
                    property: "rise"
                    to: 1
                    duration: Motion.ms(160)
                }
                NumberAnimation {
                    target: soul
                    property: "leap"
                    to: 1
                    duration: Motion.ms(260)
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: soul
                    property: "leap"
                    to: 0
                    duration: Motion.ms(220)
                    easing.type: Easing.InQuad
                }
                ScriptAction {
                    script: {
                        look.enraged++;
                        look.splash(soul.hx, soul.hy, true);
                        drops.burst(soul.hx, soul.hy, {
                            "n": 30,
                            "colors": [Theme.hellText, Theme.hellRim, Theme.hellAccent],
                            "size": 2,
                            "speed": 260,
                            "up": 120,
                            "life": 900
                        });
                    }
                }
                PauseAnimation {
                    duration: 900
                }
                NumberAnimation {
                    target: soul
                    property: "rise"
                    to: 0
                    duration: Motion.ms(300)
                }
                ScriptAction {
                    script: {
                        soul.anger = 0;
                        soul.at = look.freeSpot();
                        soul.busy = false;
                    }
                }
            }
            // the head out of the water: only what's above the waterline shows
            Item {
                readonly property real h: head.height
                x: soul.hx - head.width / 2
                y: soul.hy - h * soul.rise - soul.leap * Theme.u * 18
                width: head.width
                height: h * soul.rise
                clip: true
                visible: soul.rise > 0
                PxIcon {
                    id: head
                    bitmap: soul.anger >= 3 ? [".#.##.#.", "#ffffff#", "#bbffbb#", "#r#ff#r#", "#ffffff#", "#f####f#", "#f#rr#f#", ".######."] : [".######.", "#ffffff#", "#ffffff#", "#r#ff#r#", "#ffffff#", "#ff##ff#", "#ffffff#", ".######."]
                    pixel: Math.max(1, Math.round(Theme.u * look.k * 1.5))
                    ink: Theme.hellEdge
                    body: Theme.mix(Theme.hellTextDim, "#5a6a4a", 0.5)
                    bad: Theme.hellAccent
                    palette: ({
                            "b": Theme.hex(Theme.hellEdge)
                        })
                }
            }
            // the ring of water round the head
            Rectangle {
                visible: soul.rise > 0
                x: soul.hx - width / 2
                y: soul.hy - height / 2
                width: head.width * 1.5
                height: Theme.u * 3
                radius: height / 2
                color: "transparent"
                border.width: Math.max(1, Theme.u / 2)
                border.color: Qt.alpha(Theme.hellText, 0.5)
            }
        }
    }

    // the stone that fell: the middle
    CircleHub {
        menu: look.menu
        size: Math.round(look.slotSize * 1.1)
        corner: size * 0.35
        color: Theme.hellFace
    }

    Repeater {
        id: stones
        model: look.menu.slots
        CircleEntry {
            id: stone
            menu: look.menu
            readonly property real ang: look.angleOf(index)
            // rocked by a ripple: up, and settling back
            property real bob: 0
            property real strength: 1
            function rock(after, s) {
                bobAnim.stop();
                strength = s;
                bobWait.duration = after;
                bobAnim.restart();
            }
            SequentialAnimation {
                id: bobAnim
                PauseAnimation {
                    id: bobWait
                }
                NumberAnimation {
                    target: stone
                    property: "bob"
                    to: -Theme.u * 4 * stone.strength
                    duration: Motion.ms(110)
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: stone
                    property: "bob"
                    to: 0
                    duration: Motion.ms(500)
                    easing.type: Easing.OutElastic
                }
            }
            width: look.slotSize
            height: look.slotSize + look.labelRoom
            x: look.menu.cx + Math.cos(ang) * look.radiusOf(index) - width / 2
            y: look.menu.cy + Math.sin(ang) * look.radiusOf(index) - look.slotSize / 2 + bob
            opacity: Math.max(0, Math.min(1, look.menu.reveal * 1.6 - look.ringOf(index).ring * 0.25))
            // the water rung round the one you're on
            Rectangle {
                visible: stone.hot
                anchors.centerIn: rock
                width: look.slotSize * 1.6
                height: width
                radius: width / 2
                color: "transparent"
                border.width: Math.max(1, Theme.u / 2)
                border.color: Qt.alpha(Theme.hellAccent, 0.7)
            }
            Rectangle {
                id: rock
                width: look.slotSize
                height: look.slotSize
                radius: width * 0.35
                color: stone.hot ? Theme.hellFaceAlt : Theme.hellPlate
                border.width: Math.max(1, Theme.u / 2)
                border.color: stone.hot ? Theme.hellAccent : Theme.hellRim
                // the waterline: the lower third under the Styx
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: parent.border.width
                    x: parent.border.width
                    width: parent.width - parent.border.width * 2
                    height: Math.round(parent.height / 3)
                    bottomLeftRadius: parent.radius
                    bottomRightRadius: parent.radius
                    color: Qt.alpha(Theme.hellRim, 0.55)
                }
            }
            CircleIcon {
                anchors.centerIn: rock
                hot: stone.hot
                name: stone.icon
                pixel: Math.max(1, Math.round(Theme.u * look.k * 0.85))
            }
            CircleLabel {
                visible: look.menu.labels
                hot: stone.hot
                anchors.horizontalCenter: rock.horizontalCenter
                y: look.slotSize + Theme.u * 2
                text: stone.label
            }
        }
    }

    CircleBits {
        id: drops
    }
    CircleHint {
        menu: look.menu
        rule: "ripples"
        below: look.waterR
        status: look.enraged ? HellToys.t(HellToys.part("wrath").count, look.enraged) : ""
    }
    CircleTalk {
        id: talk
        menu: look.menu
    }

    CircleFly {
        menu: look.menu
        reach: look.reach
        at: look.menu.flyIndex >= 0 ? Qt.point(look.menu.cx + Math.cos(look.angleOf(look.menu.flyIndex)) * (look.radiusOf(look.menu.flyIndex) + look.slotSize / 2), look.menu.cy + Math.sin(look.angleOf(look.menu.flyIndex)) * (look.radiusOf(look.menu.flyIndex) + look.slotSize / 2)) : Qt.point(look.menu.cx, look.menu.cy)
    }
}
