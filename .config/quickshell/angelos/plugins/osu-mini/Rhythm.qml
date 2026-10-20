pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets
import "RhythmCore.js" as Core
import "../../modules/halo/HaloCat.js" as Kitty

// osu!mini's rhythm mode: two drums under the track that plays now, no maps, nothing
// downloaded. D (left) on the sung words — services/Lyrics' synced lines, each word when the
// lyrics have their times — K (right) on the beat scripts/osu-beats.py hears (RhythmCore holds
// it on one grid); a track without lyrics plays on the beat alone, D and K in turn; one with
// neither is turned down. The Halo's RunCat cat drums along, a paw a hit. The best of each
// track: ~/.local/state/angelos/rhythm.json — your library is the list of levels.
Item {
    id: game

    property var plugin
    signal quitRequested
    signal modeRequested(string mode)

    // ---- what plays (the tests put their own) ----
    property var lines: Lyrics.status === "ok" ? Lyrics.lines : []
    property string trackKey: Lyrics.trackKey
    property string title: Lyrics.title
    property string artist: Lyrics.artist
    property bool playing: Lyrics.playing
    property real trackLength: Lyrics.length        // s, 0 = unknown
    property var readPosition: function () {
        const p = Lyrics.player;
        if (!p)
            return -1;
        p.positionChanged();
        return p.position + (Config.lyrics.offsetMs || 0) / 1000;
    }
    // Spotify's own stream when it is the player, else everything the computer plays
    property var beatCommand: ["python3", Quickshell.shellDir + "/scripts/osu-beats.py", Lyrics.player && /spotify/i.test((Lyrics.player.identity || "") + " " + (Lyrics.player.desktopEntry || "")) ? "spotify" : "system"]
    property int roundMs: 150000
    property string recordsPath: Config.stateDir + "/rhythm.json"

    readonly property bool hasTrack: playing && trackKey !== "\u0001"
    readonly property var voice: Core.voiceNotes(lines, level === "easy" ? 400 : level === "normal" ? 250 : 150)
    readonly property bool sung: voice.length > 0
    readonly property bool byWord: lines.some(l => !!l.w)
    property string level: plugin ? plugin.get("level", "normal") : "normal"
    property int offset: plugin ? plugin.get("offset", 0) : 0     // ms; + = notes later (Settings → «Сдвиг нот»)
    readonly property int travel: ({
            "easy": 1800,
            "normal": 1450,
            "hard": 1200,
            "insane": 1000
        })[level] || 1450

    property string phase: "menu"       // menu | play | results | refused | calibrate
    property bool autoplay: false
    property real startAt: 0             // epoch ms
    property real now: 0                 // ms since startAt
    property real endAt: 0
    property int score: 0
    property int combo: 0
    property int maxCombo: 0
    property var n: ({
            "perfect": 0,
            "good": 0,
            "miss": 0
        })
    readonly property real accuracy: Core.accuracy(n)
    readonly property string rank: accuracy >= 0.9999 && n.miss === 0 ? "SS" : accuracy > 0.95 && n.miss === 0 ? "S" : accuracy > 0.9 ? "A" : accuracy > 0.8 ? "B" : accuracy > 0.7 ? "C" : "D"
    property bool newBest: false
    property string ended: ""            // why the round ended early: "" | "stopped" | "track"
    property string roundKey: ""
    property string roundTitle: ""
    property string roundArtist: ""

    property var clock: Core.newClock()
    property var beat: Core.newBeat()
    property bool beatIdle: true
    property string beatWhy: ""
    property var voiceQueue: []          // track ms still to come
    property int voiceJumps: -1          // the clock's jumps the queue was made for
    property real lastBeat: 0            // epoch ms of the last beat given a note
    property int beatN: 0                // beats passed: easy plays every other, no words D and K in turn
    property real stillSince: 0

    readonly property var best: (save.tracks || {})[trackKey] || null

    function start(demo) {
        if (!hasTrack)
            return;
        autoplay = !!demo;
        notes.clear();
        score = combo = maxCombo = 0;
        n = {
            "perfect": 0,
            "good": 0,
            "miss": 0
        };
        newBest = false;
        ended = "";
        clock = Core.newClock();
        beat = Core.newBeat();
        beatIdle = true;
        beatWhy = "";
        voiceQueue = [];
        voiceJumps = -1;
        lastBeat = 0;
        beatN = 0;
        stillSince = 0;
        judged = "";
        roundKey = trackKey;
        roundTitle = title;
        roundArtist = artist;
        startAt = Date.now();
        now = 0;
        const pos = readPosition();
        const left = trackLength > 0 && pos >= 0 ? (trackLength - pos) * 1000 - 500 : roundMs;
        endAt = Math.max(5000, Math.min(roundMs, left));
        phase = "play";
        sample();
        keys.forceActiveFocus();
    }
    function finish(why) {
        ended = why || "";
        phase = "results";
        sfx(perfectSfx);
        if (autoplay || score <= 0)
            return;
        const r = Core.record(save.tracks, roundKey, {
            "score": score,
            "acc": accuracy,
            "combo": maxCombo,
            "title": roundTitle,
            "artist": roundArtist,
            "at": Date.now()
        });
        if (!r.best)
            return;
        save.tracks = r.tracks;
        newBest = true;
        if (plugin && plugin.achieve) {
            plugin.achieve("rhythm-record");
            if (r.first)
                plugin.progress("rhythm-library");
        }
    }

    // the player's position four times a second → our clock
    function sample() {
        const pos = readPosition();
        if (pos >= 0)
            Core.clockFeed(clock, pos, Date.now());
    }
    Timer {
        interval: 250
        repeat: true
        running: game.phase === "play"
        onTriggered: game.sample()
    }
    function onBeats(msg) {
        if (msg.idle) {
            beatIdle = true;
            beatWhy = msg.why || "";
            return;
        }
        beatIdle = false;
        Core.beatFeed(beat, msg, Date.now());
        beatChanged();
    }
    Process {
        running: game.phase === "play"
        command: game.beatCommand
        stdout: SplitParser {
            onRead: line => {
                try {
                    game.onBeats(JSON.parse(line));
                } catch (e) {}
            }
        }
    }

    // a track time (ms) → our time, and an epoch time → ours; both heard `offset` later
    function fromTrack(t) {
        return t - clock.off - startAt + offset;
    }
    function fromEpoch(t) {
        return t - startAt + offset;
    }
    function spawn(t, lane, src) {
        notes.append({
            "t": t,
            "lane": lane,
            "src": src,
            "state": 0,
            "at": 0
        });
    }
    // the notes that start their way in from the right now
    function schedule() {
        // the words: once the player's clock holds; anew after a seek
        if (sung && clock.settled && voiceJumps !== clock.jumps) {
            const from = readPosition() * 1000;
            voiceQueue = voice.filter(t => t > from);
            voiceJumps = clock.jumps;
        }
        while (voiceQueue.length && fromTrack(voiceQueue[0]) - travel <= now) {
            const t = fromTrack(voiceQueue.shift());
            if (t >= now + travel * 0.5)
                spawn(t, 0, "voice");
        }
        // the beat: only while it holds; never on top of a word
        if (!beat.locked)
            return;
        const ahead = Date.now() + travel - offset;
        for (const b of Core.beatsBetween(beat, Math.max(lastBeat, Date.now() + travel * 0.6 - offset), ahead)) {
            lastBeat = b;
            const k = beatN++;
            if (level === "easy" && k % 2)
                continue;
            const t = fromEpoch(b);
            let near = false;
            for (let i = 0; i < notes.count && !near; i++)
                near = Math.abs(notes.get(i).t - t) < 110;
            if (!near)
                spawn(t, sung ? 1 : (level === "easy" ? k / 2 : k) % 2, "beat");
        }
    }

    property string judged: ""           // the last verdict, at the hit line
    property real judgedAt: 0
    function judge(i, result) {
        notes.setProperty(i, "state", result === "miss" ? 2 : 1);
        notes.setProperty(i, "at", now);
        judged = result;
        judgedAt = now;
        const c = Object.assign({}, n);
        c[result]++;
        n = c;
        if (result === "miss") {
            if (combo >= 10)
                sfx(breakSfx);
            combo = 0;
            return;
        }
        combo++;
        maxCombo = Math.max(maxCombo, combo);
        score += Core.points(result, combo);
        sfx(result === "perfect" && combo % 25 === 0 ? perfectSfx : hitSfx);
        paw(notes.get(i).lane);
    }
    // a drum: the earliest live note of the lane close enough takes it
    function press(lane) {
        if (phase === "calibrate")
            return tap();
        if (phase !== "play")
            return;
        lit[lane] = now;
        litChanged();
        for (let i = 0; i < notes.count; i++) {
            const o = notes.get(i);
            if (o.state !== 0 || o.lane !== lane)
                continue;
            const r = Core.judge(now - o.t);
            if (r !== "")
                judge(i, r);
            return;
        }
    }
    property var lit: [-1e9, -1e9]      // when each drum was last struck

    FrameAnimation {
        running: game.phase === "play" && game.visible
        onTriggered: {
            game.now = Date.now() - game.startAt;
            game.schedule();
            for (let i = game.notes.count - 1; i >= 0; i--) {
                const o = game.notes.get(i);
                if (o.state === 0 && game.now > o.t + Core.MISS)
                    game.judge(i, "miss");
                else if (o.state !== 0 && game.now - o.at > 300)
                    game.notes.remove(i);
            }
            if (game.autoplay)
                for (let i = 0; i < game.notes.count; i++) {
                    const o = game.notes.get(i);
                    if (o.state === 0 && Math.abs(game.now - o.t) < 12)
                        game.press(o.lane);
                }
            // no words and no beat to hold on to: this track isn't one to play
            if (!game.sung && Core.beatHopeless(game.beat, Date.now(), game.startAt))
                game.phase = "refused";
            else if (game.trackKey !== game.roundKey)
                game.finish("track");
            else if (!game.playing) {
                game.stillSince = game.stillSince || game.now;
                if (game.now - game.stillSince > 1500)
                    game.finish("stopped");
            } else {
                game.stillSince = 0;
                if (game.now >= game.endAt)
                    game.finish("");
            }
        }
    }
    property alias notes: notes
    ListModel {
        id: notes
    }

    // ---- the cat's paws: left for D, right for K, both when struck together ----
    property string pawNow: ""
    property real pawAt: -1e9
    function paw(lane) {
        const side = lane === 0 ? "left" : "right";
        pawNow = pawNow !== "" && pawNow !== side && pawNow !== "both" && now - pawAt < 70 ? "both" : side;
        pawAt = now;
        pawUp.restart();
    }
    Timer {
        id: pawUp
        interval: 120
        onTriggered: game.pawNow = ""
    }

    // ---- calibration: tap along a metronome; the median lateness becomes the offset ----
    property var ticks: []
    property var taps: []
    property int calResult: 0
    function calibrate() {
        ticks = [];
        taps = [];
        calResult = 0;
        phase = "calibrate";
        metronome.n = 0;
        metronome.start();
        keys.forceActiveFocus();
    }
    function tap() {
        const t = Date.now();
        if (!ticks.length)
            return;
        const near = ticks.reduce((a, b) => Math.abs(b - t) < Math.abs(a - t) ? b : a);
        taps = taps.concat([t - near]);
    }
    Timer {
        id: metronome
        property int n: 0
        interval: 600
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (n >= 20) {
                stop();
                // the first four taps find the beat; the rest count
                const d = game.taps.slice(4).filter(x => Math.abs(x) < 300);
                if (d.length >= 6) {
                    game.calResult = Math.max(-200, Math.min(200, Math.round(Core.median(d) / 5) * 5));
                    game.offset = game.calResult;
                    if (game.plugin)
                        game.plugin.set("offset", game.calResult);
                }
                game.phase = "menu";
                return;
            }
            n++;
            hitSfx.play();
            game.ticks = game.ticks.concat([Date.now()]);
        }
    }

    // ---- the best of each track ----
    FileView {
        path: game.recordsPath
        printErrors: false
        onAdapterUpdated: writeAdapter()
        JsonAdapter {
            id: save
            property var tracks: ({})
        }
    }

    function sfx(effect) {
        if (!plugin || plugin.get("sound", true))
            effect.play();
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
        id: breakSfx
        source: game.plugin ? game.plugin.url("sfx/break.wav") : ""
        volume: 0.6
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.mix(Theme.desk, Qt.color("#000000"), 0.35)
    }

    // ---- the drums: two lanes, the notes come in from the right ----
    Item {
        id: field
        visible: game.phase === "play"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -Theme.u * 10
        anchors.margins: Theme.u * 12
        height: lane * 2 + Theme.u * 4
        readonly property int lane: Theme.u * 26
        readonly property real hitX: Theme.u * 34

        Repeater {
            model: 2
            PxBox {
                id: laneBox
                required property int index
                y: index * (field.lane + Theme.u * 4)
                width: field.width
                height: field.lane
                sunken: true
                color: Theme.mix(Theme.sunken, index ? Theme.accent2 : Theme.accent, game.now - game.lit[index] < 90 ? 0.35 : 0.08)
                // where a note is struck: its outline and its key
                PxIcon {
                    x: field.hitX - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    name: "heart"
                    hollow: true
                    pixel: Theme.u * 2
                    ink: laneBox.index ? Theme.accent2 : Theme.accent
                }
                PxText {
                    x: Theme.u * 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: laneBox.index ? "K" : "D"
                    kind: "title"
                    color: Theme.textDim
                }
            }
        }
        Repeater {
            model: notes
            PxIcon {
                id: note
                required property var model
                // a struck note stays on the line while it fades, a missed one goes on by
                readonly property real ahead: model.state === 1 ? 0 : model.t - game.now
                x: field.hitX + ahead / game.travel * (field.width - field.hitX) - width / 2
                y: model.lane * (field.lane + Theme.u * 4) + (field.lane - height) / 2 - (model.state === 1 ? (game.now - model.at) / 8 : 0)
                visible: x < field.width
                opacity: model.state === 0 ? 1 : Math.max(0, 1 - (game.now - model.at) / 300)
                name: model.state === 2 ? "heartBroken" : "heart"
                pixel: Theme.u * 2
                fill: model.state === 2 ? Theme.danger : model.lane ? Theme.accent2 : Theme.accent
            }
        }
        PxText {
            x: field.hitX - width / 2
            y: -height - Theme.u * 3
            visible: game.judged !== "" && game.now - game.judgedAt < 500
            text: game.judged === "perfect" ? "Perfect" : game.judged === "good" ? "Good" : "Miss"
            kind: "title"
            font.bold: true
            color: game.judged === "miss" ? Theme.danger : game.judged === "perfect" ? Theme.accent3 : Theme.ok
            style: Text.Outline
            styleColor: Theme.edge
        }
    }
    // the cat at its desk under the drums, big
    PxIcon {
        visible: game.phase === "play" || game.phase === "calibrate"
        x: game.phase === "play" ? field.x + field.hitX - width / 2 : (parent.width - width) / 2
        y: game.phase === "play" ? field.y + field.height + Theme.u * 6 : parent.height / 2 + Theme.u * 4
        bitmap: Kitty.bongo[game.pawNow || "up"]
        pixel: Theme.u * 3
        ink: Theme.text
    }

    // ---- HUD ----
    Column {
        visible: game.phase === "play"
        x: Theme.u * 8
        y: Theme.u * 6
        spacing: Theme.u * 2
        PxText {
            text: "♪ " + game.roundTitle + (game.roundArtist ? " — " + game.roundArtist : "")
            width: Math.min(implicitWidth, game.width * 0.6)
            elide: Text.ElideRight
        }
        PxText {
            kind: "tiny"
            color: game.beat.locked ? Theme.textDim : Theme.accent3
            text: (game.sung ? (game.byWord ? I18n.t("D — слова", "D — words") : I18n.t("D — строки", "D — lines")) + " · " : "") + (game.beat.locked ? Math.round(60000 / game.beat.P) + " BPM" : game.beatIdle && game.beatWhy === "silence" ? I18n.t("тишина…", "silence…") : game.beat.ever ? I18n.t("бит потерян, ищу…", "lost the beat, listening…") : I18n.t("слушаю бит…", "listening for the beat…"))
        }
        PxBox {
            width: Theme.u * 80
            height: Theme.u * 4
            sunken: true
            color: Theme.sunken
            Rectangle {
                height: parent.height - Theme.u * 2
                width: (parent.width - Theme.u * 2) * Math.min(1, game.now / Math.max(1, game.endAt))
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
        visible: game.phase === "play" && game.combo > 1
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.u * 8
        text: game.combo + "x"
        kind: "huge"
        color: "#ffffff"
        style: Text.Outline
        styleColor: Theme.edge
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: e => {
            if (e.isAutoRepeat)
                return;
            const ch = e.text.toLowerCase();
            if (e.key === Qt.Key_Escape) {
                if (game.phase === "play" || game.phase === "calibrate") {
                    metronome.stop();
                    game.phase = "menu";
                } else
                    game.quitRequested();
            } else if ([Qt.Key_D, Qt.Key_F].includes(e.key) || ["d", "f", "в", "а"].includes(ch)) {
                game.press(0);
            } else if ([Qt.Key_J, Qt.Key_K].includes(e.key) || ["j", "k", "о", "л"].includes(ch)) {
                game.press(1);
            } else if (e.key === Qt.Key_Space && game.phase === "calibrate") {
                game.tap();
            } else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Space) && game.phase !== "play") {
                game.start(false);
            } else
                return;
            e.accepted = true;
        }
    }

    // ---- menu ----
    Column {
        visible: game.phase === "menu"
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.u * 24, Theme.u * 260)
        spacing: Theme.u * 7
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.u * 4
            PxIcon {
                name: "music"
                pixel: Theme.u * 3
                anchors.verticalCenter: parent.verticalCenter
            }
            PxText {
                text: I18n.t("Ритм", "Rhythm")
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
            currentValue: "rhythm"
            onActivated: v => game.modeRequested(v)
        }
        PxText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: game.hasTrack ? "♪ " + game.title + (game.artist ? " — " + game.artist : "") : I18n.t("Ничего не играет — включи трек ♪", "Nothing is playing — put a track on ♪")
            color: game.hasTrack ? Theme.text : Theme.accent3
        }
        PxText {
            visible: game.hasTrack
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            kind: "tiny"
            dim: true
            text: game.sung ? (game.byWord ? I18n.t("D — по словам песни, K — по биту", "D on the song's words, K on the beat") : I18n.t("D — по строкам песни, K — по биту", "D on the song's lines, K on the beat")) : I18n.t("текста с таймкодами нет — D и K по биту по очереди", "no synced lyrics — D and K take turns on the beat")
        }
        PxText {
            visible: game.hasTrack
            anchors.horizontalCenter: parent.horizontalCenter
            text: game.best ? I18n.t("рекорд трека: ", "this track's best: ") + game.best.score + " · " + game.best.acc + "%" : I18n.t("рекорда на этом треке ещё нет", "no best on this track yet")
            color: Theme.accent3
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
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.u * 4
            PxButton {
                text: I18n.t("Играть ♪", "Play ♪")
                icon: "play"
                accent: true
                enabled: game.hasTrack
                onClicked: game.start(false)
            }
            PxButton {
                text: I18n.t("Калибровка", "Calibrate")
                icon: "gauge"
                onClicked: game.calibrate()
            }
            PxButton {
                text: I18n.t("Демо", "Demo")
                icon: "sparkle"
                enabled: game.hasTrack
                onClicked: game.start(true)
            }
        }
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.t("сдвиг нот: ", "note offset: ") + game.offset + I18n.t(" мс", " ms") + (game.calResult ? I18n.t(" (откалибровано)", " (calibrated)") : "")
            kind: "tiny"
            dim: true
        }
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.t("D / K — удар · Esc — меню / выход", "D / K to strike · Esc for menu / quit")
            kind: "tiny"
            dim: true
        }
    }

    // ---- calibration ----
    Column {
        visible: game.phase === "calibrate"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        spacing: Theme.u * 4
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.t("Стучи D, K или пробелом в такт щелчкам", "Tap D, K or Space along the clicks")
            kind: "title"
        }
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: metronome.n + " / 20"
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
            color: game.rank.startsWith("S") ? Theme.accent3 : Theme.accent
            style: Text.Outline
            styleColor: Theme.edge
        }
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: game.newBest ? I18n.t("новый рекорд трека!! ♪", "a new best for this track!! ♪") : game.ended === "stopped" ? I18n.t("музыка остановилась", "the music stopped") : game.ended === "track" ? I18n.t("трек сменился", "the track changed") : I18n.t("ты молодец ♡", "well played ♡")
            kind: "title"
        }
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "♪ " + game.roundTitle + (game.roundArtist ? " — " + game.roundArtist : "")
            dim: true
        }
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.t("очки ", "score ") + game.score + " · " + (game.accuracy * 100).toFixed(2) + "% · " + I18n.t("комбо ", "combo ") + game.maxCombo + "x"
        }
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Perfect × " + game.n.perfect + "   Good × " + game.n.good + "   Miss × " + game.n.miss
            dim: true
        }
        PxText {
            readonly property var b: (save.tracks || {})[game.roundKey]
            visible: !!b && !game.newBest
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.t("рекорд трека: ", "this track's best: ") + (b ? b.score : 0)
            color: Theme.accent3
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.u * 4
            PxButton {
                text: I18n.t("Ещё раз", "Retry")
                icon: "refresh"
                accent: true
                enabled: game.hasTrack
                onClicked: game.start(game.autoplay)
            }
            PxButton {
                text: I18n.t("Меню", "Menu")
                onClicked: game.phase = "menu"
            }
        }
    }

    // ---- turned down ----
    Column {
        visible: game.phase === "refused"
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.u * 24, Theme.u * 240)
        spacing: Theme.u * 6
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.t("Этот трек не подходит", "This track won't do")
            kind: "big"
            color: Theme.accent3
        }
        PxText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            dim: true
            text: game.beatWhy === "silence" ? I18n.t("Тишина: ни текста с таймкодами, ни звука. Включи музыку и попробуй ещё раз.", "Silence: no synced lyrics and no sound. Put music on and try again.") : I18n.t("У него нет текста с таймкодами, а ровного бита я не слышу. Придумывать ноты не стану — возьми трек с чётким ритмом.", "It has no synced lyrics and I can't hear a steady beat. I won't make the notes up — pick a track with a clear rhythm.")
        }
        PxButton {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.t("Меню", "Menu")
            onClicked: game.phase = "menu"
        }
    }
}
