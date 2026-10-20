pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets

// osu!mini: pixel hearts instead of circles. Hit each heart when its shrinking
// outline meets it — click or press Z / X with the cursor on it.
Item {
    id: game

    property var plugin
    signal quitRequested
    signal modeRequested(string mode)      // ♡ hearts | ♪ rhythm (Rhythm.qml)

    readonly property var levels: ({
            "easy": {
                "ar": 1200,
                "size": 34,
                "od": [90, 150, 200],
                "bpm": 110,
                "spacing": 120,
                "drain": 0.010
            },
            "normal": {
                "ar": 900,
                "size": 29,
                "od": [70, 125, 180],
                "bpm": 140,
                "spacing": 170,
                "drain": 0.018
            },
            "hard": {
                "ar": 700,
                "size": 24,
                "od": [55, 105, 160],
                "bpm": 165,
                "spacing": 220,
                "drain": 0.028
            },
            "insane": {
                "ar": 520,
                "size": 20,
                "od": [45, 90, 140],
                "bpm": 185,
                "spacing": 260,
                "drain": 0.036
            }
        })
    property string level: plugin ? plugin.get("level", "normal") : "normal"
    property int seconds: plugin ? plugin.get("seconds", 45) : 45
    readonly property var lv: levels[level] || levels.normal
    readonly property real radius: lv.size * Theme.u      // hit radius in pixels

    property string phase: "menu"       // menu | play | results
    property real startAt: 0
    property real now: 0
    property var queue: []
    property int score: 0
    property int combo: 0
    property int maxCombo: 0
    property int n300: 0
    property int n100: 0
    property int n50: 0
    property int nMiss: 0
    property real hp: 1
    property bool failed: false
    property bool autoplay: false       // demo: the game plays itself (no records)
    property bool newBest: false
    readonly property int judged: n300 + n100 + n50 + nMiss
    readonly property real accuracy: judged ? (300 * n300 + 100 * n100 + 50 * n50) / (300 * judged) : 1
    readonly property string rank: failed ? "F" : accuracy >= 0.9999 ? "SS" : accuracy > 0.95 && nMiss === 0 ? "S" : accuracy > 0.9 ? "A" : accuracy > 0.8 ? "B" : accuracy > 0.7 ? "C" : "D"

    function bestKey() {
        return "best_" + level + "_" + seconds + (musical ? "_" + music : "");
    }

    // ---- map generation: a random walk of jumps over the playfield ----
    function newWalker() {
        return {
            "x": field.width / 2,
            "y": field.height / 2,
            "angle": Math.random() * Math.PI * 2,
            "n": 0,
            "set": 0
        };
    }
    // the heart at time t, then a jump sized for the gap `s` (in beats) to the next one
    function place(w, t, s) {
        const m = radius * 1.4;
        if (w.n % (4 + Math.floor(Math.random() * 4)) === 0)
            w.set++, w.n = 0;
        w.n++;
        const o = {
            "x": w.x,
            "y": w.y,
            "t": t,
            "n": w.n,
            "set": w.set % 3
        };
        const dist = lv.spacing * Theme.u / 2 * Math.min(1.6, s);
        w.angle += (Math.random() - 0.5) * 2.2;
        w.x += Math.cos(w.angle) * dist;
        w.y += Math.sin(w.angle) * dist;
        if (w.x < m || w.x > field.width - m) {
            w.angle = Math.PI - w.angle;
            w.x = Math.max(m, Math.min(field.width - m, w.x));
        }
        if (w.y < m || w.y > field.height - m) {
            w.angle = -w.angle;
            w.y = Math.max(m, Math.min(field.height - m, w.y));
        }
        return o;
    }
    // without music: beats at the level's BPM
    function generate() {
        const beat = 60000 / lv.bpm;
        const out = [];
        const w = newWalker();
        let t = 1800;
        const end = seconds * 1000 + 1800;
        while (t < end) {
            const r = Math.random();
            // mostly single beats, sometimes a triple burst, now and then a rest
            const steps = r < 0.12 ? [0.5, 0.5, 1] : r < 0.2 ? [2] : [1];
            for (const st of steps) {
                out.push(place(w, t, st));
                t += beat * st;
            }
        }
        return out;
    }

    // ---- music mode: hearts on the beat of what plays (scripts/osu-beats.py) ----
    property string music: plugin ? plugin.get("music", "off") : "off"   // off | spotify | system
    readonly property bool musical: music !== "off"
    property int musicOffset: plugin ? plugin.get("offset", 0) : 0      // ms; + = hearts later
    property real bpm: 0
    property real beatAt: 0               // game time (ms) of a detected beat
    property real loudness: 0
    property bool musicIdle: true
    property string idleWhy: ""
    property real lastNoteT: -1e9
    property var walker: null
    readonly property real endT: seconds * 1000 + 1800
    function onBeats(msg) {
        if (msg.idle) {
            musicIdle = true;
            idleWhy = msg.why || "";
            return;
        }
        musicIdle = false;
        bpm = msg.bpm;
        loudness = msg.level || 0;
        beatAt = msg.beat - startAt + musicOffset;
    }
    // queue the beats whose hearts have to start showing now
    function scheduleMusic() {
        if (!musical || musicIdle || bpm <= 0 || !walker)
            return;
        const P = 60000 / bpm;
        const every = level === "easy" ? 2 : 1;
        const halves = level === "insane" ? 0.55 : level === "hard" ? 0.25 : 0;
        let k = Math.ceil((Math.max(lastNoteT, now) - beatAt) / P);
        for (let t = beatAt + k * P; t <= now + lv.ar + 60 && t < endT; k++, t = beatAt + k * P) {
            if (t < now + lv.ar * 0.6 || t < lastNoteT + P * 0.6 || k % every !== 0)
                continue;
            queue.push(place(walker, t, every));
            lastNoteT = t;
            // loud parts get an extra heart on the half beat
            if (halves && loudness > 0.05 && Math.random() < halves && t + P / 2 < endT) {
                queue.push(place(walker, t + P / 2, 0.5));
                lastNoteT = t + P / 2;
            }
        }
        queue.sort((a, b) => a.t - b.t);
    }
    Process {
        running: game.phase === "play" && game.musical
        command: ["python3", Quickshell.shellDir + "/scripts/osu-beats.py", game.music]
        stdout: SplitParser {
            onRead: line => {
                try {
                    game.onBeats(JSON.parse(line));
                } catch (e) {}
            }
        }
    }
    function start(demo) {
        autoplay = !!demo;
        circles.clear();
        popups.clear();
        score = combo = maxCombo = n300 = n100 = n50 = nMiss = 0;
        hp = 1;
        failed = newBest = false;
        musicIdle = true;
        bpm = 0;
        lastNoteT = -1e9;
        walker = newWalker();
        queue = musical ? [] : generate();
        startAt = Date.now();
        now = 0;
        phase = "play";
        keys.forceActiveFocus();
    }
    function finish(fail) {
        failed = fail;
        phase = "results";
        sfx(fail ? breakSfx : perfectSfx);
        if (!fail && plugin && !autoplay) {
            const best = plugin.get(bestKey(), 0);
            if (score > best) {
                plugin.set(bestKey(), score);
                newBest = true;
            }
        }
    }
    function sfx(effect) {
        if (!plugin || plugin.get("sound", true))
            effect.play();
    }
    function judge(i, result) {
        const c = circles.get(i);
        circles.setProperty(i, "state", result === "miss" ? 2 : 1);
        circles.setProperty(i, "at", now);
        popups.append({
            "x": c.x,
            "y": c.y,
            "text": result === "miss" ? "✕" : result,
            "at": now,
            "miss": result === "miss"
        });
        if (result === "miss") {
            nMiss++;
            if (combo >= 10)
                sfx(breakSfx);
            else
                sfx(missSfx);
            combo = 0;
            hp = Math.max(0, hp - 0.12);
            return;
        }
        const base = result === "300" ? 300 : result === "100" ? 100 : 50;
        if (base === 300)
            n300++;
        else if (base === 100)
            n100++;
        else
            n50++;
        combo++;
        maxCombo = Math.max(maxCombo, combo);
        score += Math.round(base * (1 + combo / 25));
        hp = Math.min(1, hp + (base === 300 ? 0.06 : base === 100 ? 0.025 : 0.01));
        sfx(base === 300 && combo % 10 === 0 ? perfectSfx : hitSfx);
    }
    function hit() {
        if (phase !== "play")
            return;
        // the earliest heart still alive; clicking a later one does nothing (note lock)
        for (let i = 0; i < circles.count; i++) {
            const c = circles.get(i);
            if (c.state !== 0)
                continue;
            const dx = cursor.px - c.x, dy = cursor.py - c.y;
            if (dx * dx + dy * dy > radius * radius * 1.15)
                return;
            const delta = Math.abs(now - c.t);
            if (delta <= lv.od[0])
                judge(i, "300");
            else if (delta <= lv.od[1])
                judge(i, "100");
            else if (delta <= lv.od[2])
                judge(i, "50");
            else if (c.t - now < lv.ar * 0.6)
                judge(i, "miss");   // way too early
            return;
        }
    }

    FrameAnimation {
        running: game.phase === "play" && game.visible
        onTriggered: {
            const dt = frameTime;
            game.now = Date.now() - game.startAt;
            game.scheduleMusic();
            // spawn
            while (game.queue.length && game.queue[0].t - game.lv.ar <= game.now) {
                const o = game.queue.shift();
                circles.append({
                    "x": o.x,
                    "y": o.y,
                    "t": o.t,
                    "n": o.n,
                    "set": o.set,
                    "state": 0,
                    "at": 0
                });
            }
            // late → miss, finished → removed
            for (let i = circles.count - 1; i >= 0; i--) {
                const c = circles.get(i);
                if (c.state === 0 && game.now > c.t + game.lv.od[2])
                    game.judge(i, "miss");
                else if (c.state !== 0 && game.now - c.at > 320)
                    circles.remove(i);
            }
            for (let i = popups.count - 1; i >= 0; i--)
                if (game.now - popups.get(i).at > 600)
                    popups.remove(i);
            if (game.autoplay)
                for (let i = 0; i < circles.count; i++) {
                    const c = circles.get(i);
                    if (c.state === 0 && Math.abs(game.now - c.t) < 12) {
                        cursor.px = c.x;
                        cursor.py = c.y;
                        game.hit();
                        break;
                    }
                }
            // silence in music mode doesn't drain the hearts
            if (!(game.musical && game.musicIdle))
                game.hp = Math.max(0, game.hp - game.lv.drain * dt);
            if (game.hp <= 0)
                game.finish(true);
            else if (!game.queue.length && circles.count === 0 && (!game.musical || game.now > game.endT))
                game.finish(false);
        }
    }

    ListModel {
        id: circles
    }
    ListModel {
        id: popups
    }
    SoundEffect {
        id: hitSfx
        source: game.plugin ? game.plugin.url("sfx/hit.wav") : ""
        volume: 0.6
    }
    SoundEffect {
        id: perfectSfx
        source: game.plugin ? game.plugin.url("sfx/perfect.wav") : ""
        volume: 0.6
    }
    SoundEffect {
        id: missSfx
        source: game.plugin ? game.plugin.url("sfx/miss.wav") : ""
        volume: 0.6
    }
    SoundEffect {
        id: breakSfx
        source: game.plugin ? game.plugin.url("sfx/break.wav") : ""
        volume: 0.6
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.mix(Theme.desk, Qt.color("#000000"), 0.35)
    }
    FloatingHearts {
        anchors.fill: parent
        count: 12
        maxOpacity: 0.18
    }

    // ---- playfield ----
    Item {
        id: field
        anchors.fill: parent
        anchors.margins: Theme.u * 20
        anchors.topMargin: Theme.u * 26

        Repeater {
            model: circles
            Item {
                id: obj
                required property var model
                readonly property real remaining: model.t - game.now      // ms until the hit
                readonly property real appear: 1 - Math.max(0, Math.min(1, (remaining - game.lv.ar * 0.6) / (game.lv.ar * 0.4)))
                readonly property color tint: [Theme.accent, Theme.accent2, Theme.accent3][model.set] || Theme.accent
                x: model.x - width / 2
                y: model.y - height / 2
                width: game.radius * 2
                height: game.radius * 2
                z: 10000 - model.t / 10
                opacity: model.state === 0 ? appear : Math.max(0, 1 - (game.now - model.at) / 320)
                scale: model.state === 1 ? 1 + (game.now - model.at) / 900 : 1

                // approach outline: a hollow heart shrinking onto the target
                PxIcon {
                    visible: obj.model.state === 0
                    anchors.centerIn: parent
                    name: "heart"
                    hollow: true
                    ink: obj.tint
                    pixel: Math.max(1, Math.round(game.radius / 4 * (1 + 2.2 * Math.max(0, obj.remaining / game.lv.ar))))
                }
                PxIcon {
                    anchors.centerIn: parent
                    name: obj.model.state === 2 ? "heartBroken" : "heart"
                    pixel: Math.max(1, Math.round(game.radius / 4))
                    fill: obj.model.state === 2 ? Theme.danger : obj.tint
                }
                PxText {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -game.radius * 0.15
                    visible: obj.model.state === 0
                    text: obj.model.n
                    kind: "title"
                    color: "#ffffff"
                    style: Text.Outline
                    styleColor: Theme.edge
                }
            }
        }
        Repeater {
            model: popups
            PxText {
                id: pop
                required property var model
                x: model.x - width / 2
                y: model.y - game.radius - Theme.u * 6 - (game.now - model.at) / 25
                opacity: 1 - (game.now - model.at) / 600
                text: model.text
                kind: "title"
                font.bold: true
                color: model.miss ? Theme.danger : model.text === "300" ? Theme.accent3 : model.text === "100" ? Theme.ok : Theme.textDim
                style: Text.Outline
                styleColor: Theme.edge
            }
        }
    }

    // ---- cursor: a pixel heart with a short trail ----
    property var trail: []
    QtObject {
        id: cursor
        property real px: 0
        property real py: 0
    }
    Repeater {
        model: game.phase === "play" ? game.trail : []
        PxIcon {
            required property var modelData
            required property int index
            x: modelData.x - width / 2
            y: modelData.y - height / 2
            name: "heartSmall"
            pixel: Theme.u
            opacity: (index + 1) / (game.trail.length + 1) * 0.6
        }
    }
    PxIcon {
        visible: game.phase === "play"
        x: cursor.px - width / 2 + field.x
        y: cursor.py - height / 2 + field.y
        name: "heart"
        pixel: Theme.u
        fill: "#ffffff"
    }
    Timer {
        interval: 33
        repeat: true
        running: game.phase === "play"
        onTriggered: {
            const list = game.trail.concat([{
                    "x": cursor.px + field.x,
                    "y": cursor.py + field.y
                }]);
            game.trail = list.slice(-8);
        }
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: game.phase === "play" ? Qt.BlankCursor : Qt.ArrowCursor
        enabled: game.phase === "play"
        onPositionChanged: m => {
            cursor.px = m.x - field.x;
            cursor.py = m.y - field.y;
        }
        onPressed: m => {
            cursor.px = m.x - field.x;
            cursor.py = m.y - field.y;
            game.hit();
        }
    }
    Item {
        id: keys
        focus: true
        Keys.onPressed: e => {
            if (e.isAutoRepeat)
                return;
            if (e.key === Qt.Key_Escape) {
                if (game.phase === "play")
                    game.phase = "menu";
                else
                    game.quitRequested();
            } else if ([Qt.Key_Z, Qt.Key_X, Qt.Key_C, Qt.Key_V].includes(e.key) || e.text.toLowerCase() === "я" || e.text.toLowerCase() === "ч") {
                game.hit();
            } else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Space) && game.phase !== "play") {
                game.start(false);
            } else
                return;
            e.accepted = true;
        }
    }

    // ---- HUD ----
    Row {
        visible: game.phase === "play"
        x: Theme.u * 8
        y: Theme.u * 6
        spacing: Theme.u * 6
        PxHearts {
            anchors.verticalCenter: parent.verticalCenter
            value: game.hp
            count: 10
            pixel: Theme.u
            fill: game.hp < 0.3 ? Theme.danger : Theme.accent
        }
        PxBox {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.u * 80
            height: Theme.u * 4
            sunken: true
            color: Theme.sunken
            Rectangle {
                height: parent.height - Theme.u * 2
                width: (parent.width - Theme.u * 2) * Math.min(1, game.now / (game.seconds * 1000 + 1800))
                color: Theme.accent2
            }
        }
    }
    Column {
        visible: game.phase === "play"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.u * 6
        PxText {
            anchors.right: parent.right
            text: String(game.score).padStart(7, "0")
            kind: "big"
            color: "#ffffff"
            style: Text.Outline
            styleColor: Theme.edge
        }
        PxText {
            anchors.right: parent.right
            text: (game.accuracy * 100).toFixed(2) + "%"
            color: Theme.textDim
        }
    }
    PxText {
        visible: game.phase === "play" && game.musical
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.u * 18
        text: game.musicIdle ? (game.idleWhy === "no-spotify" ? I18n.t("Spotify не играет — включи трек ♪", "Spotify isn't playing — start a track ♪") : game.idleWhy === "" ? I18n.t("слушаю ритм… ♪", "listening for the beat… ♪") : I18n.t("Тишина… включи музыку ♪", "Silence… put some music on ♪")) : "♪ " + (game.music === "spotify" ? "Spotify" : I18n.t("звук системы", "system audio")) + " · " + Math.round(game.bpm) + " BPM"
        color: game.musicIdle ? Theme.accent3 : Theme.textDim
        style: Text.Outline
        styleColor: Theme.edge
    }
    PxText {
        visible: game.phase === "play" && game.combo > 1
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Theme.u * 8
        text: game.combo + "x"
        kind: "huge"
        color: "#ffffff"
        style: Text.Outline
        styleColor: Theme.edge
    }

    // ---- menu ----
    Column {
        visible: game.phase === "menu"
        anchors.centerIn: parent
        spacing: Theme.u * 8
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.u * 4
            PxIcon {
                name: "heart"
                pixel: Theme.u * 3
                anchors.verticalCenter: parent.verticalCenter
            }
            PxText {
                text: "osu!mini"
                kind: "huge"
                color: Theme.accent
                style: Text.Outline
                styleColor: Theme.edge
            }
        }
        PxSegmented {
            anchors.horizontalCenter: parent.horizontalCenter
            model: [
                {
                    "label": I18n.t("♡ Сердечки", "♡ Hearts"),
                    "value": "hearts"
                },
                {
                    "label": I18n.t("♪ Ритм", "♪ Rhythm"),
                    "value": "rhythm"
                }
            ]
            currentValue: "hearts"
            onActivated: v => game.modeRequested(v)
        }
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.t("кликай по сердечкам в такт ♡", "click the hearts on the beat ♡")
            dim: true
        }
        PxSegmented {
            anchors.horizontalCenter: parent.horizontalCenter
            model: [
                {
                    "label": I18n.t("Легко", "Easy"),
                    "value": "easy"
                },
                {
                    "label": I18n.t("Норм", "Normal"),
                    "value": "normal"
                },
                {
                    "label": I18n.t("Сложно", "Hard"),
                    "value": "hard"
                },
                {
                    "label": "Insane",
                    "value": "insane"
                }
            ]
            currentValue: game.level
            onActivated: v => {
                game.level = v;
                if (game.plugin)
                    game.plugin.set("level", v);
            }
        }
        PxSegmented {
            anchors.horizontalCenter: parent.horizontalCenter
            model: [30, 45, 90].map(s => ({
                        "label": s + I18n.t(" с", " s"),
                        "value": s
                    }))
            currentValue: game.seconds
            onActivated: v => {
                game.seconds = v;
                if (game.plugin)
                    game.plugin.set("seconds", v);
            }
        }
        PxSegmented {
            anchors.horizontalCenter: parent.horizontalCenter
            model: [
                {
                    "label": I18n.t("Свой ритм", "Own beat"),
                    "value": "off"
                },
                {
                    "label": "♪ Spotify",
                    "value": "spotify"
                },
                {
                    "label": I18n.t("♪ Звук системы", "♪ System audio"),
                    "value": "system"
                }
            ]
            currentValue: game.music
            onActivated: v => {
                game.music = v;
                if (game.plugin)
                    game.plugin.set("music", v);
            }
        }
        PxText {
            visible: game.musical
            anchors.horizontalCenter: parent.horizontalCenter
            text: game.music === "spotify" ? I18n.t("сердечки встанут в такт тому, что играет в Spotify", "hearts follow the beat of what Spotify plays") : I18n.t("сердечки встанут в такт всему, что играет на компьютере", "hearts follow the beat of everything the computer plays")
            kind: "tiny"
            dim: true
        }
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.t("рекорд: ", "best: ") + (game.plugin ? game.plugin.get(game.bestKey(), 0) : 0)
            color: Theme.accent3
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.u * 4
            PxButton {
                text: I18n.t("Играть ♡", "Play ♡")
                icon: "play"
                accent: true
                onClicked: game.start(false)
            }
            PxButton {
                text: I18n.t("Демо", "Demo")
                icon: "sparkle"
                onClicked: game.start(true)
            }
        }
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.t("клик или Z / X — попадание · Esc — меню / выход", "click or Z / X to hit · Esc for menu / quit")
            kind: "tiny"
            dim: true
        }
    }

    // ---- results ----
    Column {
        visible: game.phase === "results"
        anchors.centerIn: parent
        spacing: Theme.u * 6
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: game.rank
            font.pixelSize: Theme.sizeHuge * 3
            font.family: Theme.fontTitle
            color: game.failed ? Theme.danger : game.rank.startsWith("S") ? Theme.accent3 : Theme.accent
            style: Text.Outline
            styleColor: Theme.edge
        }
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: game.failed ? I18n.t("сердечки кончились… ещё раз?", "out of hearts… again?") : game.newBest ? I18n.t("новый рекорд!! ♡", "new best!! ♡") : I18n.t("ты молодец ♡", "well played ♡")
            kind: "title"
        }
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.t("очки ", "score ") + game.score + " · " + (game.accuracy * 100).toFixed(2) + "% · " + I18n.t("комбо ", "combo ") + game.maxCombo + "x"
        }
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "300 × " + game.n300 + "   100 × " + game.n100 + "   50 × " + game.n50 + "   ✕ × " + game.nMiss
            dim: true
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.u * 4
            PxButton {
                text: I18n.t("Ещё раз", "Retry")
                icon: "refresh"
                accent: true
                onClicked: game.start(game.autoplay)
            }
            PxButton {
                text: I18n.t("Меню", "Menu")
                onClicked: game.phase = "menu"
            }
        }
    }
}
