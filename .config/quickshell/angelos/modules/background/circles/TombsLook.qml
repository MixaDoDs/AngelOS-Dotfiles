pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// The look of RadialMenu in the circle of heresy: a graveyard of the city of Dis at the
// pointer — the entries are headstones in rows, the far rows smaller, each with the embers of
// its open tomb at its foot; the one you're on burns. Opening, the stones rise out of the
// ground row by row. The logo stands at the gate, above the graves.
// The toy (CircleToy): set the heretics' fire going — hold the button down on the graveyard
// and flames climb out of the ground after the pointer, the tombs near it flare up; a right
// click and every open tomb erupts at once.
Item {
    id: look

    required property var menu
    readonly property real k: menu.k
    readonly property int n: menu.slots.length
    readonly property int cols: Math.min(5, Math.max(1, Math.ceil(Math.sqrt(n * 1.6))))
    readonly property int rows: Math.max(1, Math.ceil(n / cols))
    readonly property real stoneW: Math.round(Theme.u * 22 * k)
    readonly property real stoneH: Math.round(Theme.u * 28 * k)
    readonly property real labelRoom: menu.labels ? Theme.sizeTiny + Theme.u * 4 : Theme.u * 2
    readonly property real colW: stoneW + (menu.labels ? Theme.u * 22 : Theme.u * 8) * k
    readonly property real rowH: stoneH + labelRoom + Theme.u * 6 * k
    readonly property real gateH: Math.round(Theme.u * 26 * k)
    readonly property real gridW: cols * colW
    readonly property real gridH: gateH + rows * rowH
    readonly property real reach: Math.max(gridW, gridH) / 2 + Theme.u * 6
    readonly property Item blurItem: null
    readonly property real y0: menu.cy - gridH / 2
    // the far rows smaller: the front one full size
    function scaleOf(row) {
        return rows < 2 ? 1 : 0.82 + 0.18 * row / (rows - 1);
    }
    function centreOf(i) {
        const row = Math.floor(i / cols), col = i % cols;
        const inRow = row === rows - 1 ? n - row * cols : cols;
        return Qt.point(menu.cx + (col - (inRow - 1) / 2) * colW * scaleOf(row), y0 + gateH + row * rowH + stoneH / 2);
    }
    // the toy: a flame out of the ground at (x, y); the graves near it flare up
    property real lastFire: 0
    function fire(x, y, quiet) {
        flame.createObject(fireLayer, {
            "x0": x,
            "y0": y
        });
        embers.burst(x, y, {
            "n": 4,
            "colors": [Theme.hellFlame, Theme.hellEmber, Theme.hellGold],
            "size": 1.5,
            "speed": 40,
            "up": 70,
            "spread": 1.2,
            "gravity": -60,
            "life": 900
        });
        for (let i = 0; i < graves.count; i++) {
            const g = graves.itemAt(i);
            if (g && Math.hypot(g.x + g.width / 2 - x, g.y + g.height / 2 - y) < colW)
                g.flare();
        }
        if (!quiet)
            Sounds.playSoft("key", 0.5);
    }
    function erupt() {
        Sounds.play("demon");
        for (let i = 0; i < graves.count; i++) {
            const g = graves.itemAt(i);
            if (!g)
                continue;
            g.flare();
            embers.burst(g.x + g.width / 2, g.y + stoneH * g.s, {
                "n": 6,
                "colors": [Theme.hellFlame, Theme.hellEmber, Theme.hellGold],
                "size": 2,
                "speed": 50,
                "up": 140,
                "spread": 0.8,
                "gravity": -40,
                "life": 1100
            });
        }
    }
    function nav(e) {
        return menu.walk(e);
    }
    anchors.fill: parent

    // a tongue of the heretics' fire: climbs, flickers, burns out
    Component {
        id: flame
        PxIcon {
            id: fl
            property real x0
            property real y0
            property real f: 0
            bitmap: ["..r..", ".rr..", ".ryr.", "ryyr.", "ryyyr", ".ryr."]
            pixel: Math.max(1, Math.round(Theme.u * look.k * (1.2 - f * 0.5)))
            bad: Theme.hellFlame
            fill3: Theme.hellGold
            x: x0 - width / 2 + Math.sin(f * 14) * Theme.u * 2
            y: y0 - height - f * Theme.u * 26
            opacity: 1 - f * f
            NumberAnimation on f {
                from: 0
                to: 1
                duration: Math.max(300, Motion.ms(800))
                onFinished: fl.destroy()
            }
        }
    }

    // the gate of Dis: the logo between two posts
    CircleHub {
        menu: look.menu
        size: Math.round(look.stoneW * 1.05)
        corner: Theme.u * 2
        color: Theme.hellFace
        x: look.menu.cx - size / 2
        y: look.y0
        nameGap: Theme.u * 2
    }
    Repeater {
        model: 2
        Rectangle {
            required property int index
            width: Theme.u * 4 * look.k
            height: look.gateH - Theme.u * 4
            x: look.menu.cx + (index ? 1 : -1) * look.stoneW * 0.9 - width / 2
            y: look.y0
            color: Theme.hellPlate
            border.width: Math.max(1, Theme.u / 2)
            border.color: Theme.hellRim
            opacity: look.menu.reveal
        }
    }
    // the ground of each row
    Repeater {
        model: look.rows
        Rectangle {
            required property int index
            readonly property real s: look.scaleOf(index)
            x: look.menu.cx - width / 2
            y: look.y0 + look.gateH + index * look.rowH + look.stoneH - Theme.u
            width: look.gridW * s
            height: Theme.u * 2
            color: Qt.alpha(Theme.hellBody, 0.8 * look.menu.reveal)
        }
    }

    CircleToy {
        id: toy
        menu: look.menu
        zone: Qt.rect(look.menu.cx - look.gridW / 2, look.y0 + look.gateH - Theme.u * 4, look.gridW, look.gridH - look.gateH + Theme.u * 4)
        cursorShape: Qt.CrossCursor
        hoverEnabled: on
        onDown: (x, y, right) => {
            if (right) {
                look.erupt();
                held = false;
                return;
            }
            look.lastFire = Date.now();
            look.fire(x, y);
        }
        onDrag: (x, y) => {
            if (Date.now() - look.lastFire < 70)
                return;
            look.lastFire = Date.now();
            look.fire(x, y, true);
        }
    }

    Repeater {
        id: graves
        model: look.menu.slots
        CircleEntry {
            id: grave
            menu: look.menu
            // set alight by the toy for a moment
            property bool burning: false
            function flare() {
                burning = true;
                burnOut.restart();
            }
            Timer {
                id: burnOut
                interval: 900
                onTriggered: grave.burning = false
            }
            readonly property int row: Math.floor(index / look.cols)
            readonly property real s: look.scaleOf(row)
            readonly property point c: look.centreOf(index)
            readonly property real lit: Math.max(0, Math.min(1, look.menu.reveal * 1.7 - row * 0.25 - (index % look.cols) * 0.04))
            width: look.colW * s
            height: (look.stoneH + look.labelRoom) * s
            x: c.x - width / 2
            y: c.y + look.stoneH / 2 - look.stoneH * s
            opacity: lit
            // the stone rises out of the ground; nothing shows below it
            Item {
                id: plot
                anchors.horizontalCenter: parent.horizontalCenter
                width: look.stoneW * grave.s
                height: look.stoneH * grave.s
                clip: true
                Rectangle {
                    id: stone
                    width: parent.width
                    height: parent.height
                    y: (1 - grave.lit) * height
                    topLeftRadius: width / 2
                    topRightRadius: width / 2
                    color: grave.hot ? Theme.hellFaceAlt : Theme.hellPlate
                    border.width: Math.max(1, Theme.u / 2)
                    border.color: grave.hot ? Theme.hellAccent : Theme.hellRim
                    CircleIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height * 0.32
                        hot: grave.hot
                        name: grave.icon
                        pixel: Math.max(1, Math.round(Theme.u * look.k * 0.8 * grave.s))
                    }
                    // the embers of the open tomb at its foot
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: parent.border.width
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width * 0.6
                        height: Math.max(1, Theme.u)
                        color: grave.hot || grave.burning ? Theme.hellFlame : Qt.alpha(Theme.hellEmber, 0.7)
                    }
                }
            }
            // the one you're on burns: a flame on the stone
            PxIcon {
                visible: grave.hot || grave.burning
                bitmap: ["..r..", ".rr..", ".ryr.", "ryyr.", "ryyyr", ".ryr."]
                pixel: Math.max(1, Math.round(Theme.u * look.k * 0.75))
                bad: Theme.hellFlame
                fill3: Theme.hellGold
                anchors.horizontalCenter: plot.horizontalCenter
                y: -height + Theme.u
            }
            CircleLabel {
                visible: look.menu.labels
                hot: grave.hot
                anchors.horizontalCenter: plot.horizontalCenter
                y: plot.height + Theme.u * 2
                width: Math.min(implicitWidth, look.colW * grave.s)
                elide: Text.ElideRight
                text: grave.label
            }
        }
    }

    Item {
        id: fireLayer
        anchors.fill: parent
    }
    CircleBits {
        id: embers
    }

    CircleHint {
        menu: look.menu
        rule: "tombs"
        below: look.gridH / 2
    }

    CircleFly {
        menu: look.menu
        reach: look.gridW / 2 + Theme.u * 4
        at: look.menu.flyIndex >= 0 ? look.centreOf(look.menu.flyIndex) : Qt.point(look.menu.cx, look.menu.cy)
    }
}
