pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// Heaven Raid, the phone's second game (PhoneScreen → Games): a little angel flies on the
// left and shoots hearts by herself; imps come from the right, faster as the score grows, and
// every fifteenth kill brings their big boss. 2 8 (or the arrows) fly up and down, 5 starts and
// pauses. Three lives. The best score is the save's (PhoneLine.stats.raid), 30 is an
// achievement, and it opens pieces of the tuning. Runs only while the lid is up.
Item {
    id: root

    required property var phone
    readonly property int k: Theme.u
    readonly property color ink: phone.screenInk
    readonly property int px: Math.max(1, k)               // one art pixel
    readonly property real fieldH: height - k * 10

    // the art: w wings, f skin, o pink, y halo, r imp, k eyes, p heart
    readonly property var shipArt: ["..yy....", "w.......", "ww.ff...", "wwwffo..", "ww.ff...", "w......."]
    readonly property var impArt: ["r...r", ".rrr.", "rkrkr", ".rrr.", "r.r.r"]
    readonly property var bossArt: ["r.......r", "rr.....rr", ".rrrrrrr.", "rrkrrrkrr", "rrrrrrrrr", ".rr.r.rr.", "r..r.r..r"]
    readonly property var heartArt: ["p.p", "ppp", ".p."]
    readonly property var colours: ({
            "w": "#ffffff",
            "f": "#ffd9c7",
            "o": Theme.accent,
            "y": "#ffe07a",
            "r": "#e8344e",
            "k": "#1a0a14",
            "p": "#ff6fa8"
        })

    property real shipY: 0
    property var shots: []                 // [x, y]
    property var imps: []                  // {x, y, phase, hp, boss}
    property int score: 0
    property int lives: 3
    property int kills: 0
    property int tick: 0
    property int hurt: 0                   // ticks of blinking after a hit
    property string state: "ready"         // ready | play | pause | over
    readonly property int best: PhoneLine.stats.raid || 0
    readonly property var soft: ["", state === "play" ? I18n.t("Пауза", "Pause") : I18n.t("Играть", "Play"), I18n.t("Выход", "Exit")]

    function reset() {
        shipY = fieldH / 2;
        shots = [];
        imps = [];
        score = 0;
        lives = 3;
        kills = 0;
        hurt = 0;
    }
    function key(k) {
        if (k === "2" || k === "up") {
            shipY = Math.max(0, shipY - px * 4);
            return true;
        }
        if (k === "8" || k === "down") {
            shipY = Math.min(fieldH - px * 6, shipY + px * 4);
            return true;
        }
        if (k === "5" || k === "ok" || k === "call") {
            if (state === "ready" || state === "over") {
                reset();
                state = "play";
            } else
                state = state === "play" ? "pause" : "play";
            return true;
        }
        return false;
    }
    Component.onCompleted: reset()
    Timer {
        interval: 50
        running: root.state === "play" && root.visible && Sidebar.open
        repeat: true
        onTriggered: root.step()
    }
    function hit(a, b, aw, ah, bw, bh) {
        return a[0] < b[0] + bw && b[0] < a[0] + aw && a[1] < b[1] + bh && b[1] < a[1] + ah;
    }
    function step() {
        tick++;
        const W = canvas.width, speed = px * (1.2 + Math.min(2.5, score / 25));
        // her hearts, every few ticks
        let s = shots.map(p => [p[0] + px * 4, p[1]]).filter(p => p[0] < W);
        if (tick % 6 === 0)
            s.push([px * 9, shipY + px * 2]);
        // the imps: in from the right, wobbling; the boss when it is time
        let im = imps.map(e => Object.assign({}, e, {
                "x": e.x - (e.boss ? speed * 0.4 : speed),
                "y": e.boss ? fieldH / 2 - px * 4 + Math.sin((tick + e.phase) / 14) * fieldH * 0.35 : e.y + Math.sin((tick + e.phase) / 6) * px * 0.6
            }));
        const bossOn = im.some(e => e.boss);
        if (!bossOn && kills > 0 && kills % 15 === 0 && !im.length)
            im.push({
                "x": W,
                "y": fieldH / 2,
                "phase": 0,
                "hp": 8,
                "boss": true
            });
        else if (!bossOn && tick % Math.max(10, 28 - Math.floor(score / 6)) === 0)
            im.push({
                "x": W,
                "y": Math.random() * (fieldH - px * 5),
                "phase": Math.random() * 60,
                "hp": 1,
                "boss": false
            });
        // hearts into imps
        const left = [];
        for (const p of s) {
            let used = false;
            for (const e of im) {
                const ew = e.boss ? px * 9 : px * 5, eh = e.boss ? px * 7 : px * 5;
                if (e.hp > 0 && hit([p[0], p[1]], [e.x, e.y], px * 3, px * 3, ew, eh)) {
                    e.hp--;
                    used = true;
                    if (e.hp <= 0) {
                        score += e.boss ? 10 : 1;
                        kills++;
                        PhoneLine.play("eat", 0.4);
                    }
                    break;
                }
            }
            if (!used)
                left.push(p);
        }
        // imps into her, or past her
        const ship = [px * 1, shipY];
        const alive = [];
        for (const e of im) {
            if (e.hp <= 0)
                continue;
            const ew = e.boss ? px * 9 : px * 5, eh = e.boss ? px * 7 : px * 5;
            if (hurt === 0 && hit(ship, [e.x, e.y], px * 8, px * 6, ew, eh)) {
                lives--;
                hurt = 30;
                PhoneLine.play("die", 0.4);
                if (!e.boss)
                    continue;
            }
            if (e.x > -ew)
                alive.push(e);
        }
        if (hurt > 0)
            hurt--;
        shots = left;
        imps = alive;
        if (lives <= 0) {
            state = "over";
            PhoneLine.bump("raid", score);
            if (score >= 30)
                Achievements.note("phone.raid30");
        }
        canvas.requestPaint();
    }

    Row {
        id: bar
        width: parent.width
        PxText {
            width: parent.width / 3
            text: "♡".repeat(Math.max(0, root.lives))
            kind: "tiny"
            color: root.phone.trim
        }
        PxText {
            width: parent.width / 3
            horizontalAlignment: Text.AlignHCenter
            text: root.score
            kind: "tiny"
            color: root.ink
        }
        PxText {
            width: parent.width / 3
            horizontalAlignment: Text.AlignRight
            text: I18n.t("Рекорд ", "Best ") + root.best
            kind: "tiny"
            color: root.phone.trim
        }
    }
    Canvas {
        id: canvas
        y: bar.height + root.k
        width: parent.width
        height: root.fieldH
        renderStrategy: Canvas.Cooperative
        function sprite(c, art, x, y) {
            const p = root.px;
            for (let r = 0; r < art.length; r++)
                for (let i = 0; i < art[r].length; i++) {
                    const col = root.colours[art[r][i]];
                    if (!col)
                        continue;
                    c.fillStyle = col;
                    c.fillRect(Math.round(x + i * p), Math.round(y + r * p), p, p);
                }
        }
        onPaint: {
            const c = getContext("2d");
            c.reset();
            c.fillStyle = Qt.alpha(root.phone.trim, 0.1);
            c.fillRect(0, 0, width, height);
            // the sky going by
            c.fillStyle = Qt.alpha(root.ink, 0.35);
            for (let i = 0; i < 12; i++)
                c.fillRect(Math.round((i * 53 - root.tick * (1 + i % 3)) % width + width) % width, (i * 37) % height, root.px, root.px);
            for (const p of root.shots)
                sprite(c, root.heartArt, p[0], p[1]);
            for (const e of root.imps)
                sprite(c, e.boss ? root.bossArt : root.impArt, e.x, e.y);
            if (root.hurt % 4 < 2)
                sprite(c, root.shipArt, root.px, root.shipY);
        }
        Component.onCompleted: requestPaint()
    }
    PxText {
        visible: root.state !== "play"
        anchors.centerIn: canvas
        horizontalAlignment: Text.AlignHCenter
        text: root.state === "over" ? I18n.t("Конец рейда\nСчёт: ", "Raid over\nScore: ") + root.score + "\n" + I18n.t("5 — ещё раз", "5 to fly again") : root.state === "pause" ? I18n.t("Пауза", "Paused") : I18n.t("НЕБЕСНЫЙ РЕЙД\n5 — взлёт\n2 8 — вверх / вниз", "HEAVEN RAID\n5 to take off\n2 8 up / down")
        kind: "tiny"
        color: root.ink
        style: Text.Outline
        styleColor: root.phone.hell ? Theme.hellBody : Theme.face
    }
}
