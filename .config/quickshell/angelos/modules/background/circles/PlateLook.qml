pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// The look of RadialMenu in the circle of gluttony: a dinner plate laid at the pointer, a
// fork on its left and a knife on its right; the entries are small dishes served round its
// rim (more than the rim holds go into the well), the logo is the main course. Opening, the
// plate is set down and the dishes are served one by one.
// The toy (CircleToy): dinner is served in the well round the main course — an apple, a
// drumstick, a cake (story/toys.json → gluttony.foods). Pick up the fork (or just click the
// food: the fork comes to hand) and poke it: each poke is a bite out of it, the knife takes a
// bigger one; eaten up, the next course comes at once — gluttony never has enough. Pokes on
// the bare plate leave the tines' marks, the knife cuts it as you drag; a right click or Esc
// lays them back. The dishes on the rim are the entries, clicked as always.
Item {
    id: look

    required property var menu
    readonly property real k: menu.k
    readonly property int n: menu.slots.length
    readonly property real slotSize: Math.round(Theme.u * 20 * k)
    readonly property real labelRoom: menu.labels ? Theme.sizeTiny + Theme.u * 3 : 0
    readonly property int onRim: n > 12 ? 12 : n
    readonly property int inWell: n - onRim
    readonly property real step: slotSize + (menu.labels ? Theme.u * 26 : Theme.u * 10) * k
    readonly property real rimR: Math.max(Theme.u * 50 * k, onRim * step / (2 * Math.PI))
    readonly property real wellR: rimR * 0.5
    readonly property real plateR: rimR + slotSize / 2 + labelRoom + Theme.u * 5 * k
    readonly property real reach: plateR + Theme.u * 24 * k
    readonly property Item blurItem: null
    function angleOf(i) {
        return i < onRim ? -Math.PI / 2 + i * 2 * Math.PI / onRim : -Math.PI / 2 + (i - onRim + 0.5) * 2 * Math.PI / Math.max(1, inWell);
    }
    function radiusOf(i) {
        return i < onRim ? rimR : wellR;
    }
    // the toy: what's in hand ("" | fork | knife), where the hand is, what's on the plate
    property string held: ""
    property point hand: Qt.point(menu.cx, menu.cy)
    property real dip: 0                    // the fork going in
    property var marks: []                  // {kind: poke | cut, pts: [[x, y]…], t}
    readonly property real px: Math.max(1, Math.round(Theme.u * k * 2))
    readonly property var forkBits: ["#.#.#", "#.#.#", "#.#.#", "#####", ".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###.", ".###.", ".###.", "..#.."]
    readonly property var knifeBits: [".#.", "##.", "##.", "###", "###", "###", "###", "###", ".#.", ".#.", "###", "###", "###", ".#."]
    // the courses in the well, eaten this opening
    property int eaten: 0
    readonly property real foodPx: Math.max(1, Math.round(Theme.u * k * 1.5))
    readonly property real seatR: (slotSize * 0.65 + rimR - slotSize / 2 - Theme.u * 4) / 2 + Theme.u * 2
    // a bite out of the food under (x, y), if there's one: true when there was
    function eatAt(x, y, big) {
        for (let i = 0; i < seats.count; i++) {
            const st = seats.itemAt(i);
            if (st && st.food && st.contains(st.mapFromItem(look, x, y)))
                return st.bite(x, y, big);
        }
        return false;
    }
    // every seat served at once (the self-test)
    function serveAll() {
        for (let i = 0; i < seats.count; i++)
            seats.itemAt(i).bring();
    }
    // where a seat's course is (the self-test)
    function seatAt(i) {
        const st = seats.itemAt(i);
        return st ? Qt.point(st.x + st.width / 2, st.y + st.height / 2) : Qt.point(0, 0);
    }
    function served(seat) {
        eaten++;
        const g = HellToys.part("gluttony");
        const words = eaten % 5 === 0 ? HellToys.pick(g.five) : HellToys.pick(g.eaten);
        if (eaten % 5 === 0) {
            talk.at = Qt.point(menu.cx, menu.cy - slotSize);
            talk.say(I18n.t("Обжорство", "Gluttony"), HellToys.t(words), [], 1500);
        } else {
            yum.createObject(look, {
                "x0": seat.x + seat.width / 2,
                "y0": seat.y,
                "text": HellToys.t(words)
            });
        }
    }
    function take(what) {
        held = held === what ? "" : what;
        Sounds.playSoft("click", 0.7);
    }
    function poke(x, y) {
        dipAnim.restart();
        marks = marks.filter(m => Date.now() - m.t < 6000).slice(-40).concat([{
                "kind": "poke",
                "pts": [[x, y]],
                "t": Date.now()
            }]);
        Sounds.playSoft("key", 1);
        crumbs.burst(x, y, {
            "n": 7,
            "colors": [Theme.hellEmber, Theme.hellGold, Theme.hellTextDim],
            "size": 1.5,
            "speed": 90,
            "up": 60,
            "life": 550
        });
        stains.requestPaint();
    }
    function nav(e) {
        if (e.key === Qt.Key_Escape && talk.open) {
            talk.hide();
            return true;
        }
        if (e.key === Qt.Key_Escape && held) {
            held = "";
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
            look.held = "";
            look.marks = [];
            look.eaten = 0;
            for (let i = 0; i < seats.count; i++)
                seats.itemAt(i).serve(i * 250);
        }
    }
    // "Yum! More!" floating up off a finished course
    Component {
        id: yum
        PxText {
            id: yt
            property real x0
            property real y0
            property real f: 0
            x: x0 - implicitWidth / 2
            y: y0 - implicitHeight - f * Theme.u * 16
            z: 15
            kind: "tiny"
            font.bold: true
            color: Theme.hellGold
            style: Text.Outline
            styleColor: Theme.hellBody
            opacity: 1 - f * f
            NumberAnimation on f {
                from: 0
                to: 1
                duration: Math.max(500, Motion.ms(1100))
                onFinished: yt.destroy()
            }
        }
    }
    HoverHandler {
        onPointChanged: look.hand = point.position
    }
    NumberAnimation {
        id: dipAnim
        target: look
        property: "dip"
        from: 1
        to: 0
        duration: Motion.ms(220)
        easing.type: Easing.OutQuad
    }

    // the plate: its rim, the glaze line, the well
    Item {
        id: plate
        x: look.menu.cx - look.plateR
        y: look.menu.cy - look.plateR
        width: look.plateR * 2
        height: width
        scale: 0.7 + 0.3 * look.menu.reveal
        opacity: look.menu.reveal
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.hellFace
            border.width: Math.max(1, Theme.u)
            border.color: Theme.hellRim
        }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - Theme.u * 6
            height: width
            radius: width / 2
            color: "transparent"
            border.width: Math.max(1, Theme.u / 2)
            border.color: Qt.alpha(Theme.hellText, 0.18)
        }
        Rectangle {
            anchors.centerIn: parent
            width: (look.rimR - look.slotSize / 2 - Theme.u * 4) * 2
            height: width
            radius: width / 2
            color: Theme.hellPlate
            border.width: Math.max(1, Theme.u / 2)
            border.color: Qt.alpha(Theme.hellRim, 0.7)
        }
    }

    // what's been done to the plate: the fork's marks, the knife's cuts — they fade
    Canvas {
        id: stains
        x: look.menu.cx - look.plateR
        y: look.menu.cy - look.plateR
        width: look.plateR * 2
        height: width
        opacity: look.menu.reveal
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.translate(-x, -y);
            const u = Theme.u, now = Date.now();
            for (const m of look.marks) {
                const a = Math.max(0, 1 - (now - m.t) / 6000);
                if (m.kind === "poke") {
                    // three tines, a pixel apart
                    ctx.fillStyle = Qt.alpha(Theme.hellBody, 0.85 * a).toString();
                    const [x, y] = m.pts[0];
                    for (let i = 0; i < 3; i++)
                        ctx.fillRect(Math.round(x - u * 2 + i * u * 2), Math.round(y), Math.max(1, u), Math.max(1, u) * 1.5);
                } else if (m.pts.length > 1) {
                    ctx.strokeStyle = Qt.alpha(Theme.hellBody, 0.8 * a).toString();
                    ctx.lineWidth = Math.max(1, u);
                    ctx.beginPath();
                    ctx.moveTo(m.pts[0][0], m.pts[0][1]);
                    for (const p of m.pts)
                        ctx.lineTo(p[0], p[1]);
                    ctx.stroke();
                    // the sauce in the cut
                    ctx.strokeStyle = Qt.alpha(Theme.hellBlood, 0.5 * a).toString();
                    ctx.lineWidth = Math.max(1, u / 2);
                    ctx.stroke();
                }
            }
        }
        Timer {
            interval: 120
            repeat: true
            running: look.marks.length > 0 && look.menu.visible
            onTriggered: {
                look.marks = look.marks.filter(m => Date.now() - m.t < 6000);
                stains.requestPaint();
            }
        }
    }

    // the plate plays: the fork pokes, the knife cuts
    CircleToy {
        menu: look.menu
        radius: look.plateR
        cursorShape: look.held ? Qt.BlankCursor : Qt.PointingHandCursor
        onDown: (x, y, right) => {
            if (right) {
                look.held = "";
                held = false;
                return;
            }
            if (!look.held)
                look.held = "fork";
            if (look.eatAt(x, y, look.held === "knife")) {
                dipAnim.restart();
                return;
            }
            if (look.held === "fork") {
                look.poke(x, y);
            } else {
                look.marks = look.marks.slice(-40).concat([{
                        "kind": "cut",
                        "pts": [[x, y]],
                        "t": Date.now()
                    }]);
            }
        }
        onDrag: (x, y) => {
            if (look.held !== "knife" || !look.marks.length)
                return;
            const m = look.marks[look.marks.length - 1], last = m.pts[m.pts.length - 1];
            if (Math.hypot(x - last[0], y - last[1]) < Theme.u * 2)
                return;
            m.pts.push([x, y]);
            m.t = Date.now();
            if (m.pts.length % 6 === 0)
                Sounds.playSoft("key", 0.6);
            stains.requestPaint();
        }
    }

    // the fork and the knife, laid either side — click to take one (it fades here while in hand)
    Repeater {
        model: ["fork", "knife"]
        PxIcon {
            id: tool
            required property string modelData
            required property int index
            bitmap: index ? look.knifeBits : look.forkBits
            pixel: look.px
            ink: rest.containsMouse ? Theme.hellText : Theme.hellTextDim
            x: index ? look.menu.cx + look.plateR + Theme.u * 6 : look.menu.cx - look.plateR - width - Theme.u * 6
            y: look.menu.cy - height / 2
            opacity: look.menu.reveal * (look.held === modelData ? 0.25 : 1)
            MouseArea {
                id: rest
                enabled: Config.desktop.menuToys !== false
                anchors.fill: parent
                anchors.margins: -Theme.u * 3
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: look.take(tool.modelData)
            }
        }
    }

    CircleHub {
        menu: look.menu
        size: Math.round(look.slotSize * 1.3)
        color: Theme.hellFaceAlt
        hover: Theme.mix(Theme.hellFaceAlt, Theme.hellAccent, 0.3)
    }

    // the courses, three round the main course in the well
    Repeater {
        id: seats
        model: 3
        Item {
            id: seat
            required property int index
            property var food: null             // story/toys.json → gluttony.foods[…]
            property var rows: []               // what's left of it
            property int full: 1
            property real pop: 0
            readonly property real ang: -Math.PI / 2 + Math.PI / 3 + index * 2 * Math.PI / 3
            width: 8 * look.foodPx
            height: width
            x: look.menu.cx + Math.cos(ang) * look.seatR - width / 2
            y: look.menu.cy + Math.sin(ang) * look.seatR - height / 2
            opacity: look.menu.reveal
            visible: Config.desktop.menuToys !== false
            function remaining(r) {
                return r.join("").replace(/\./g, "").length;
            }
            function serve(after) {
                food = null;
                nextCourse.interval = after || 1;
                nextCourse.restart();
            }
            function bite(x, y, big) {
                const p = mapFromItem(look, x, y);
                const cols = rows[0].length, n = rows.length;
                let bx = Math.max(0, Math.min(cols - 1, Math.floor(p.x / look.foodPx)));
                let by = Math.max(0, Math.min(n - 1, Math.floor(p.y / look.foodPx)));
                // the nearest bit of food to where the fork went in
                let bd = 1e9;
                for (let r = 0; r < n; r++)
                    for (let c = 0; c < cols; c++)
                        if (rows[r][c] !== "." && Math.hypot(c - bx, r - by) < bd) {
                            bd = Math.hypot(c - bx, r - by);
                            bx = c;
                            by = r;
                        }
                if (bd === 1e9)
                    return false;
                const rad = big ? 2.3 : 1.6;
                const out = rows.map((row, r) => row.split("").map((ch, c) => Math.hypot(c - bx, r - by) <= rad ? "." : ch).join(""));
                rows = out;
                Sounds.playSoft("chestTick", 0.9);
                crumbs.burst(x, y, {
                    "n": 6,
                    "colors": Object.values(food.colors || {}),
                    "size": 1.5,
                    "speed": 80,
                    "up": 70,
                    "life": 600
                });
                if (remaining(out) <= full * 0.2) {
                    food = null;
                    Sounds.playSoft("chestPrize", 0.5);
                    look.served(seat);
                    serve(350);
                }
                return true;
            }
            function bring() {
                const f = HellToys.pick(HellToys.part("gluttony").foods || []);
                if (!f)
                    return;
                rows = f.rows.slice();
                full = remaining(f.rows);
                food = f;
                popIn.restart();
            }
            Timer {
                id: nextCourse
                onTriggered: seat.bring()
            }
            NumberAnimation {
                id: popIn
                target: seat
                property: "pop"
                from: 0
                to: 1
                duration: Motion.ms(260)
                easing.type: Easing.OutBack
            }
            Component.onCompleted: serve(200 + index * 250)
            PxIcon {
                visible: !!seat.food && seat.rows.length > 0
                anchors.centerIn: parent
                scale: Motion.still ? 1 : seat.pop
                bitmap: seat.rows
                pixel: look.foodPx
                palette: seat.food ? seat.food.colors : ({})
            }
        }
    }

    // the dishes
    Repeater {
        model: look.menu.slots
        CircleEntry {
            id: dish
            menu: look.menu
            readonly property real ang: look.angleOf(index)
            readonly property real lit: Math.max(0, Math.min(1, look.menu.reveal * 1.8 - 0.3 - index * 0.06))
            width: look.slotSize
            height: look.slotSize + look.labelRoom
            x: look.menu.cx + Math.cos(ang) * look.radiusOf(index) - width / 2
            y: look.menu.cy + Math.sin(ang) * look.radiusOf(index) - look.slotSize / 2 - (1 - lit) * Theme.u * 8
            opacity: lit
            // a small plate with its own rim; the one you're on is lifted
            Rectangle {
                id: saucer
                width: look.slotSize
                height: look.slotSize
                radius: width / 2
                scale: dish.hot ? 1.15 : 1
                Behavior on scale {
                    NumberAnimation {
                        duration: Motion.ms(90)
                    }
                }
                color: dish.hot ? Theme.hellFaceAlt : Theme.hellPlate
                border.width: Math.max(1, Theme.u / 2)
                border.color: dish.hot ? Theme.hellAccent : Theme.hellRim
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - Theme.u * 5
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: Math.max(1, Theme.u / 2)
                    border.color: Qt.alpha(Theme.hellText, dish.hot ? 0.3 : 0.12)
                }
            }
            CircleIcon {
                anchors.centerIn: saucer
                hot: dish.hot
                name: dish.icon
                pixel: Math.max(1, Math.round(Theme.u * look.k * 0.85))
            }
            CircleLabel {
                visible: look.menu.labels
                hot: dish.hot
                anchors.horizontalCenter: saucer.horizontalCenter
                y: look.slotSize + Theme.u * 2
                text: dish.label
            }
        }
    }

    CircleBits {
        id: crumbs
    }
    CircleHint {
        menu: look.menu
        rule: "plate"
        below: look.plateR
        status: look.eaten ? HellToys.t(HellToys.part("gluttony").count, look.eaten) : ""
    }
    // the one in hand: its point at the pointer, tilted like it's held
    PxIcon {
        visible: !!look.held && look.menu.reveal > 0.6
        bitmap: look.held === "knife" ? look.knifeBits : look.forkBits
        pixel: look.px
        ink: Theme.hellText
        x: look.hand.x - width / 2
        y: look.hand.y - look.px * (1 - look.dip * 2)
        transformOrigin: Item.Top
        rotation: look.held === "knife" ? -35 : -25 + look.dip * 10
    }

    CircleTalk {
        id: talk
        menu: look.menu
    }

    CircleFly {
        menu: look.menu
        reach: look.reach
        at: look.menu.flyIndex >= 0 ? Qt.point(look.menu.cx + Math.cos(look.angleOf(look.menu.flyIndex)) * look.plateR, look.menu.cy + Math.sin(look.angleOf(look.menu.flyIndex)) * look.plateR) : Qt.point(look.menu.cx, look.menu.cy)
    }
}
