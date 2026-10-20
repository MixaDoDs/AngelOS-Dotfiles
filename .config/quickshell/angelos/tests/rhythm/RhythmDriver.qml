pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import "../../plugins/osu-mini"

// tests/rhythm/run.sh, offscreen: Lyrics keeps a TTML's word times, then three rounds of
// osu!mini's rhythm mode at once, each in its own window, a stand-in player and beat each:
//   words   a song with word times, no beat: D notes on the words, played to the end; the best
//           written to its file, the achievements asked for
//   beat    no lyrics, a steady 120 BPM from the stand-in tracker: locks, D and K in turn on its grid
//   none    no lyrics, no beat: turned down
// A stand-in player strikes each note on time. ANGELOS_RHYTHM_SHOTS=dir: a picture of each screen.
Scope {
    id: root

    readonly property string shots: Quickshell.env("ANGELOS_RHYTHM_SHOTS") || ""
    readonly property string state: Quickshell.env("ANGELOS_RHYTHM_STATE") || "/tmp"
    readonly property real t0: Date.now()
    property int step: 0

    function report(name, ok, detail) {
        console.log("TEST " + name + " " + (ok ? "PASS" : "FAIL") + " " + (detail || ""));
    }
    function shot(item, name) {
        if (shots)
            item.grabToImage(r => r.saveToFile(shots + "/" + name + ".png"));
    }
    // a plugin context as services/Plugins hands out: settings in memory, achievements noted
    function fakePlugin() {
        const store = {
            "sound": false,
            "level": "normal",
            "offset": 0
        };
        return {
            "asked": [],
            "get": (k, d) => store[k] === undefined ? d : store[k],
            "set": (k, v) => store[k] = v,
            "url": rel => "file://" + Quickshell.shellDir + "/plugins/osu-mini/" + rel,
            "achieve": function (id) {
                this.asked.push("achieve:" + id);
            },
            "progress": function (id) {
                this.asked.push("progress:" + id);
            }
        };
    }
    // a word every 400 ms from 0 s, eight to a line
    readonly property var song: {
        const out = [];
        for (let l = 0; l < 30; l++) {
            const t = l * 3.2;
            out.push({
                "t": t,
                "text": "la la la la la la la la",
                "w": [0, 1, 2, 3, 4, 5, 6, 7].map(i => t + i * 0.4)
            });
        }
        return out;
    }

    component Round: FloatingWindow {
        id: w
        property alias game: g
        property bool striking: true
        implicitWidth: 900
        implicitHeight: 600
        visible: true
        Rhythm {
            id: g
            anchors.fill: parent
            plugin: root.fakePlugin()
            playing: true
            trackLength: 300
            beatCommand: ["true"]
            readPosition: () => (Date.now() - root.t0) / 1000 + 5
        }
        // the stand-in player: each live note struck on time
        FrameAnimation {
            running: g.phase === "play" && w.striking
            onTriggered: {
                for (let i = 0; i < g.notes.count; i++) {
                    const o = g.notes.get(i);
                    if (o.state === 0 && Math.abs(g.now - o.t) < 15)
                        g.press(o.lane);
                }
            }
        }
    }

    Round {
        id: words
        game.trackKey: "Tester\u0001Words"
        game.title: "Words"
        game.artist: "Tester"
        game.lines: root.song
        game.roundMs: 7000
        game.recordsPath: root.state + "/words.json"
    }
    Round {
        id: beat
        game.trackKey: "Tester\u0001Beat"
        game.title: "Beat"
        game.lines: []
        game.roundMs: 11000
        game.recordsPath: root.state + "/beat.json"
    }
    Round {
        id: none
        striking: false
        game.trackKey: "Tester\u0001None"
        game.title: "None"
        game.lines: []
        game.roundMs: 30000
        game.recordsPath: root.state + "/none.json"
    }
    // the plugin's own window (Main.qml), opened the way the Halo's «Ритм» and `angelos rhythm` do
    Main {
        id: main
        plugin: root.fakePlugin()
    }
    function mainGame() {
        let found = null;
        const walk = it => {
            if (!it || found)
                return;
            if (it.modeRequested !== undefined && it.phase !== undefined)
                found = it;
            for (const c of it.children || [])
                walk(c);
        };
        // Main's LazyLoader → its window
        for (const o of main.data)
            if (o && o.active !== undefined && o.item)
                walk(o.item.contentItem);
        return found;
    }
    // the stand-in tracker for `beat`: 120 BPM on the driver's clock, as osu-beats.py reports it
    Timer {
        interval: 250
        repeat: true
        running: beat.game.phase === "play"
        onTriggered: {
            const now = Date.now();
            beat.game.onBeats({
                "bpm": 120,
                "beat": root.t0 + Math.floor((now - root.t0) / 500) * 500,
                "conf": 1,
                "fit": 9
            });
        }
    }
    // what each round has seen: the lanes, the paws, the beat notes' places on the grid
    property var lanes: ({})
    property bool pawLeft: false
    property real worstGrid: 0
    property var order: []          // the beat round's lanes in turn
    property var seen: ({})
    Timer {
        interval: 16
        repeat: true
        running: true
        onTriggered: {
            if (words.game.pawNow === "left")
                root.pawLeft = true;
            const g = beat.game;
            for (let i = 0; i < g.notes.count; i++) {
                const o = g.notes.get(i);
                const id = Math.round(o.t);
                if (root.seen[id])
                    continue;
                root.seen[id] = true;
                root.lanes[o.lane] = true;
                root.order.push(o.lane);
                // back to the driver's clock: on the 500 ms grid
                const x = (o.t + g.startAt - g.offset - root.t0) / 500;
                root.worstGrid = Math.max(root.worstGrid, Math.abs(x - Math.round(x)) * 500);
            }
        }
    }

    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: {
            root.step++;
            const s = root.step;
            if (s === 1) {
                // TTML → enhanced LRC → lines with the words' times (the role spans left out)
                const xml = '<tt><body><div><p begin="00:01.000" end="00:03.000"><span begin="00:01.000" end="00:01.400">Hello</span> <span begin="00:01.500" end="00:02.000">world</span><span ttm:role="x-bg" begin="00:02.100"><span begin="00:02.100">ooh</span></span></p><p begin="00:04.000"><span begin="00:04.000">again</span></p></div></body></tt>';
                const lrc = Lyrics.ttmlToLrc(xml);
                root.report("ttml-words", lrc === "[00:01.00]<00:01.00>Hello <00:01.50>world\n[00:04.00]<00:04.00>again", JSON.stringify(lrc));
                const l = Lyrics.parseLrc(lrc);
                root.report("lrc-words", l.length === 2 && l[0].text === "Hello world" && JSON.stringify(l[0].w) === "[1,1.5]" && l[1].text === "again", JSON.stringify(l));
                const plain = Lyrics.parseLrc("[00:02.00]plain line\n[00:03.00][00:05.00]twice");
                root.report("lrc-plain", plain.length === 3 && plain[0].text === "plain line" && !plain[0].w && plain[2].t === 5, JSON.stringify(plain));
                root.report("menu", words.game.phase === "menu" && words.game.sung && words.game.byWord && !beat.game.sung, "");
                root.shot(words.game, "menu");
            } else if (s === 2) {
                words.game.start(false);
                beat.game.start(false);
                none.game.start(false);
                root.report("start", words.game.phase === "play" && beat.game.phase === "play" && none.game.phase === "play", "");
            } else if (s === 14) {
                root.shot(words.game, "words-play");
                root.report("words-notes", words.game.notes.count > 0, "count " + words.game.notes.count);
            } else if (s === 34) {
                const g = words.game;
                root.report("words-results", g.phase === "results" && g.n.perfect >= 8 && g.n.miss === 0 && g.score > 0, JSON.stringify(g.n) + " " + g.phase);
                root.report("words-paw", root.pawLeft, "");
                root.report("words-best", g.newBest && g.best && g.best.score === g.score, JSON.stringify(g.best));
                root.report("words-achievements", JSON.stringify(g.plugin.asked) === '["achieve:rhythm-record","progress:rhythm-library"]', JSON.stringify(g.plugin.asked));
                root.shot(words.game, "words-results");
            } else if (s === 36) {
                // the file the best went to
                const x = new XMLHttpRequest();
                x.open("GET", "file://" + root.state + "/words.json", false);
                x.send();
                let ok = false;
                try {
                    ok = JSON.parse(x.responseText).tracks["Tester\u0001Words"].score === words.game.score;
                } catch (e) {}
                root.report("words-file", ok, x.responseText.slice(0, 160));
            } else if (s === 38) {
                root.shot(beat.game, "beat-play");
                root.report("beat-locked", beat.game.beat.locked && Math.abs(60000 / beat.game.beat.P - 120) < 1, "P " + beat.game.beat.P);
            } else if (s === 40) {
                Shell.gameAsk = "rhythm";
                Shell.gameOpen = true;
            } else if (s === 42) {
                const g = root.mainGame();
                // no player here: the rhythm mode waits in its menu, «nothing is playing»
                root.report("main-rhythm", !!g && g.beatN !== undefined && g.phase === "menu" && !g.hasTrack && Shell.gameAsk === "" && main.plugin.get("mode") === "rhythm", g ? g.phase : "no window");
                if (g)
                    g.modeRequested("hearts");
            } else if (s === 44) {
                const g = root.mainGame();
                root.report("main-hearts", !!g && g.beatN === undefined && g.level !== undefined && main.plugin.get("mode") === "hearts", "");
                Shell.gameOpen = false;
            } else if (s === 50) {
                const g = beat.game;
                root.report("beat-lanes", root.lanes[0] && root.lanes[1] && root.order.every((l, i) => !i || l !== root.order[i - 1]), JSON.stringify(root.order));
                root.report("beat-grid", root.worstGrid < 25, "worst " + root.worstGrid.toFixed(1) + " ms");
                root.report("beat-results", g.phase === "results" && g.n.perfect >= 4 && g.n.miss === 0, JSON.stringify(g.n) + " " + g.phase);
            } else if (s === 58) {
                root.report("none-refused", none.game.phase === "refused" && none.game.notes.count === 0, none.game.phase);
                root.shot(none.game, "refused");
            } else if (s === 60) {
                console.log("TEST DONE");
                Qt.quit();
            }
        }
    }
}
