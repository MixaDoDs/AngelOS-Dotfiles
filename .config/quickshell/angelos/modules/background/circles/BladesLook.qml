pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// The look of RadialMenu in the circle of violence: a fan of blades from a hilt at the
// pointer — up to nine fanned out above it, more all the way round, long and short by turns;
// the entries sit at their points. Opening, the fan snaps open from one blade; the one you're
// on is bloodied at the edge.
// The toy (CircleToy): slash the air — a drag leaves a bloody streak, and every blade it cuts
// across rings and shivers; a right click snaps the fan shut and open again.
Item {
    id: look

    required property var menu
    readonly property real k: menu.k
    readonly property int n: Math.max(1, menu.slots.length)
    readonly property bool round: n > 9
    readonly property real slotSize: Math.round(Theme.u * 18 * k)
    readonly property real labelRoom: menu.labels ? Theme.sizeTiny + Theme.u * 3 : 0
    readonly property real span: round ? 2 * Math.PI : Math.PI * 1.25
    readonly property real step: round ? span / n : span / Math.max(1, n - 1)
    // all the way round, long and short by turns: the short ones keep the room between points
    readonly property real stagger: round ? slotSize + labelRoom + Theme.u * 6 * k : 0
    readonly property real shortR: Math.max(Theme.u * 58 * k, (slotSize + labelRoom + Theme.u * 10 * k) / Math.max(0.2, step * (round ? 2 : 1)))
    readonly property real longR: shortR + stagger
    readonly property real reach: longR + slotSize / 2 + labelRoom + Theme.u * 6
    readonly property Item blurItem: null
    // above the pointer, centred; the fan opens from its middle blade
    readonly property real mid: -Math.PI / 2
    function angleOf(i) {
        const a = round ? mid + i * step : mid - span / 2 + i * step;
        return mid + (a - mid) * menu.reveal * (1 - fold);
    }
    // the toy: the fan snapping shut (0 open … 1 shut), the slash, the blades it has cut
    property real fold: 0
    property var trail: []                  // [[x, y, t]…]
    property var cut: ({})
    function slashTo(x, y) {
        const now = Date.now();
        const last = trail.length ? trail[trail.length - 1] : null;
        trail = trail.filter(p => now - p[2] < 450).concat([[x, y, now]]);
        if (!last)
            return;
        // every blade the stroke crosses: near its line, between the guard and the point
        for (let i = 0; i < menu.slots.length; i++) {
            if (cut[i])
                continue;
            const a = angleOf(i), dx = Math.cos(a), dy = Math.sin(a);
            const px = x - menu.cx, py = y - menu.cy;
            const along = px * dx + py * dy, off = Math.abs(px * dy - py * dx);
            if (along > Theme.u * 10 * k && along < radiusOf(i) && off < Theme.u * 6) {
                cut[i] = true;
                const b = blades.itemAt(i);
                if (b)
                    b.ring();
                Sounds.playSoft("chestTick", 0.8);
            }
        }
    }
    function nav(e) {
        return menu.walk(e);
    }
    function radiusOf(i) {
        return round && i % 2 ? shortR : longR;
    }
    anchors.fill: parent

    SequentialAnimation {
        id: snapAnim
        NumberAnimation {
            target: look
            property: "fold"
            to: 1
            duration: Motion.ms(140)
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: look
            property: "fold"
            to: 0
            duration: Motion.ms(260)
            easing.type: Easing.OutBack
        }
    }
    CircleToy {
        menu: look.menu
        radius: look.reach
        cursorShape: Qt.CrossCursor
        hoverEnabled: on
        onDown: (x, y, right) => {
            if (right) {
                snapAnim.restart();
                Sounds.playSoft("clickRight", 1);
                held = false;
                return;
            }
            look.cut = {};
            look.trail = [];
            look.slashTo(x, y);
        }
        onDrag: (x, y) => look.slashTo(x, y)
        onUp: (x, y) => {
            const t = look.trail;
            if (t.length > 3)
                drops.burst(x, y, {
                    "n": 6,
                    "colors": [Theme.hellAccent, Theme.hellBlood],
                    "size": 1.5,
                    "speed": 50,
                    "spread": 1,
                    "dir": Math.PI / 2,
                    "life": 700
                });
        }
    }
    // the slash: a streak of blood that dries away
    Canvas {
        id: streak
        x: look.menu.cx - look.reach
        y: look.menu.cy - look.reach
        width: look.reach * 2
        height: width
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.translate(-x, -y);
            const t = look.trail, now = Date.now();
            for (let i = 1; i < t.length; i++) {
                const a = Math.max(0, 1 - (now - t[i][2]) / 450);
                ctx.strokeStyle = Qt.alpha(Theme.hellAccent, 0.9 * a).toString();
                ctx.lineWidth = Math.max(1, Theme.u * 2.5 * a);
                ctx.beginPath();
                ctx.moveTo(t[i - 1][0], t[i - 1][1]);
                ctx.lineTo(t[i][0], t[i][1]);
                ctx.stroke();
            }
        }
        FrameAnimation {
            running: look.trail.length > 0 && look.menu.visible
            onTriggered: {
                look.trail = look.trail.filter(p => Date.now() - p[2] < 450);
                streak.requestPaint();
            }
        }
    }

    // the blades: steel from the hilt to the point
    Repeater {
        id: blades
        model: look.menu.slots
        Item {
            id: blade
            required property int index
            // cut across: it rings, shivering
            property real shiver: 0
            function ring() {
                shiverAnim.restart();
            }
            NumberAnimation {
                id: shiverAnim
                target: blade
                property: "shiver"
                from: 1
                to: 0
                duration: Motion.ms(500)
            }
            readonly property bool hot: look.menu.current === index || look.menu.fly === look.menu.slots[index]
            readonly property real len: look.radiusOf(index) - look.slotSize / 2 - Theme.u * 2
            x: look.menu.cx
            y: look.menu.cy - height / 2
            width: len
            height: Math.max(2, Math.round(Theme.u * 4 * look.k))
            transformOrigin: Item.Left
            rotation: look.angleOf(index) * 180 / Math.PI + Math.sin(shiver * 40) * shiver * 4
            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: Theme.u * 10 * look.k
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop {
                        position: 0
                        color: Theme.hellText
                    }
                    GradientStop {
                        position: 0.5
                        color: Theme.hellTextDim
                    }
                    GradientStop {
                        position: 1
                        color: Theme.hellFaceAlt
                    }
                }
                border.width: Math.max(1, Theme.u / 2)
                border.color: Theme.hellEdge
            }
            // the bloodied edge of the one you're on
            Rectangle {
                visible: blade.hot
                x: parent.width * 0.45
                width: parent.width * 0.55
                height: Math.max(1, Theme.u)
                color: Theme.hellAccent
            }
            // the guard
            Rectangle {
                x: Theme.u * 9 * look.k
                y: (parent.height - height) / 2
                width: Math.max(2, Theme.u * 2)
                height: parent.height * 2.4
                color: Theme.hellGold
            }
        }
    }

    // the hilt's pommel: the middle
    CircleHub {
        menu: look.menu
        size: Math.round(look.slotSize * 1.15)
        corner: Theme.u * 2
        tilt: 45
        color: Theme.hellFace
        rim: Theme.hellGold
        showName: !look.round
        nameGap: -look.slotSize * 2.2
    }

    Repeater {
        model: look.menu.slots
        CircleEntry {
            id: point
            menu: look.menu
            readonly property real ang: look.angleOf(index)
            width: look.slotSize
            height: look.slotSize + look.labelRoom
            x: look.menu.cx + Math.cos(ang) * look.radiusOf(index) - width / 2
            y: look.menu.cy + Math.sin(ang) * look.radiusOf(index) - look.slotSize / 2
            opacity: Math.min(1, look.menu.reveal * 1.5)
            Rectangle {
                id: tip
                width: look.slotSize
                height: look.slotSize
                rotation: 45
                scale: point.hot ? 1.12 : 1
                color: point.hot ? Theme.hellFaceAlt : Theme.hellPlate
                border.width: Math.max(1, Theme.u / 2)
                border.color: point.hot ? Theme.hellAccent : Theme.hellRim
            }
            CircleIcon {
                anchors.centerIn: tip
                hot: point.hot
                name: point.icon
                pixel: Math.max(1, Math.round(Theme.u * look.k * 0.8))
            }
            // a drop falls from the one you're on
            Rectangle {
                visible: point.hot
                anchors.horizontalCenter: tip.horizontalCenter
                y: look.slotSize + Theme.u
                width: Theme.u * 2
                height: Theme.u * 3
                radius: Theme.u
                color: Theme.hellAccent
            }
            CircleLabel {
                visible: look.menu.labels
                hot: point.hot
                anchors.horizontalCenter: tip.horizontalCenter
                y: look.slotSize + Theme.u * (point.hot ? 5 : 2)
                text: point.label
            }
        }
    }

    CircleBits {
        id: drops
    }

    CircleHint {
        menu: look.menu
        rule: "blades"
        below: look.reach
    }

    CircleFly {
        menu: look.menu
        reach: look.reach
        at: look.menu.flyIndex >= 0 ? Qt.point(look.menu.cx + Math.cos(look.angleOf(look.menu.flyIndex)) * (look.radiusOf(look.menu.flyIndex) + look.slotSize / 2), look.menu.cy + Math.sin(look.angleOf(look.menu.flyIndex)) * (look.radiusOf(look.menu.flyIndex) + look.slotSize / 2)) : Qt.point(look.menu.cx, look.menu.cy)
    }
}
