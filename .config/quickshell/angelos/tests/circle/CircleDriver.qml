pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.modules.circle

// The screenshot overlay, offscreen (started by tests/circle/run.sh): a frame with known words is
// drawn here; CircleSearch.start grabs it through a stand-in grim (with the pointer or not), the
// areas come from scripts/capture_regions.py, the words from tesseract. The overlay's face
// (modules/circle/CircleCanvas) sits in a plain window here and is driven by press / move /
// release / key and its bar's buttons. Saving and copying go through Capture (capture_save.py)
// into the fake home, searching through Island into a stand-in qml6 / xdg-open, translating
// through a stand-in trans, copying through a stand-in wl-copy — no real clipboard, network or screen.
Scope {
    id: root

    property int step: 0
    property double since: Date.now()
    readonly property string fake: Quickshell.env("FAKE_DIR")
    readonly property string frame: fake + "/frame.ppm"
    readonly property bool hasTess: Quickshell.env("HAS_TESSERACT") === "1"
    readonly property string snaps: Quickshell.env("CIRCLE_SNAP_DIR")
    property bool frameReady: false
    // other files of the shell may change while this runs: no reload half way
    Component.onCompleted: Quickshell.watchFiles = false
    property var savedWords: []
    property int shots0: 0
    property string lastShot: ""

    function report(name, ok, detail) {
        console.log("TEST " + name + " " + (ok ? "PASS" : "FAIL") + " " + (detail === undefined ? "" : detail));
    }
    function until(name, cond, ms, detail) {
        let ok = false;
        try {
            ok = !!cond();
        } catch (e) {
            detail = () => String(e);
        }
        if (!ok && Date.now() - since < (ms || 5000))
            return false;
        report(name, ok, detail ? detail() : "");
        return true;
    }
    function wait(ms) {
        return Date.now() - since >= ms;
    }
    function word(t) {
        return CircleSearch.words.find(w => w.t.toLowerCase().indexOf(t) >= 0);
    }
    function wi(t) {
        return CircleSearch.words.findIndex(w => w.t.toLowerCase().indexOf(t) >= 0);
    }
    function rectIs(b, x, y, w, h) {
        return !!b && Math.abs(b.x - x) < 1.5 && Math.abs(b.y - y) < 1.5 && Math.abs(b.w - w) < 1.5 && Math.abs(b.h - h) < 1.5;
    }
    function find(item, name) {
        if (!item)
            return null;
        if (item.objectName === name)
            return item;
        for (const c of item.children) {
            const r = find(c, name);
            if (r)
                return r;
        }
        return null;
    }
    function btn(name) {
        return find(face, name);
    }
    function click(name) {
        const b = btn(name);
        if (!b || !b.visible || !b.enabled) {
            report("button-" + name + "-clickable", false, b ? "visible " + b.visible + " enabled " + b.enabled : "missing");
            return false;
        }
        b.clicked();
        return true;
    }
    function reopen() {
        CircleSearch.reset();
        CircleSearch.open = true;
    }
    property bool snapping: false
    function snap(name) {
        if (!root.snaps)
            return;
        root.snapping = true;
        face.grabToImage(r => {
            r.saveToFile(root.snaps + "/" + name + ".png");
            root.snapping = false;
        });
    }
    property double lastLook: 0
    function look() {
        if (!shots.running && Date.now() - lastLook > 250) {
            lastLook = Date.now();
            shots.running = true;
        }
    }
    // the newest saved shot is a new one and of this size
    function savedIs(size) {
        root.look();
        return shots.count > root.shots0 && shots.size === size;
    }
    function fileText(f) {
        f.reload();
        return f.text();
    }

    // the "screen": big dark text on a light page
    FloatingWindow {
        id: page
        visible: true
        implicitWidth: 900
        implicitHeight: 400
        color: "#f4f0e8"
        Rectangle {
            id: board
            width: 900
            height: 400
            color: "#f4f0e8"
            Text {
                x: 40
                y: 60
                text: "Hello angelOS world"
                font.pixelSize: 44
                color: "#16121c"
            }
            Text {
                x: 40
                y: 200
                text: "Search the second line"
                font.pixelSize: 44
                color: "#16121c"
            }
            // a "photo": colourful and grainy (capture_regions.py calls it a picture)
            Canvas {
                x: 620
                y: 40
                width: 220
                height: 150
                onPaint: {
                    const ctx = getContext("2d");
                    let seed = 7;
                    const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
                    for (let y = 0; y < height; y += 4)
                        for (let x = 0; x < width; x += 4) {
                            const r = Math.round(120 + 100 * Math.sin(x / 30) + 30 * rnd()), g = Math.round(110 + 80 * Math.cos(y / 25) + 40 * rnd()), b = Math.round(140 + 90 * Math.sin((x + y) / 40) + 30 * rnd());
                            ctx.fillStyle = "rgb(" + Math.max(0, Math.min(255, r)) + "," + Math.max(0, Math.min(255, g)) + "," + Math.max(0, Math.min(255, b)) + ")";
                            ctx.fillRect(x, y, 4, 4);
                        }
                }
            }
        }
    }
    // the overlay's face, as the layer window would hold it
    FloatingWindow {
        visible: true
        implicitWidth: 900
        implicitHeight: 400
        color: "black"
        CircleCanvas {
            id: face
            width: 900
            height: 400
        }
    }

    // the stand-ins' logs
    FileView {
        id: copied
        path: root.fake + "/clip"
        printErrors: false
        blockLoading: true
        blockWrites: true
    }
    FileView {
        id: grimLog
        path: root.fake + "/grim"
        printErrors: false
        blockLoading: true
        blockWrites: true
    }
    FileView {
        id: island
        path: root.fake + "/island"
        printErrors: false
        blockLoading: true
        blockWrites: true
    }
    FileView {
        id: browser
        path: root.fake + "/xdg"
        printErrors: false
        blockLoading: true
        blockWrites: true
    }
    FileView {
        id: notifyLog
        path: root.fake + "/notify"
        printErrors: false
        blockLoading: true
        blockWrites: true
    }
    // what the stand-in notify-send answers when asked (--wait)
    FileView {
        id: answer
        path: root.fake + "/answer"
        printErrors: false
        blockWrites: true
    }
    FileView {
        id: learnFile
        path: Quickshell.env("HOME") + "/.local/state/angelos/circle-learn.json"
        printErrors: false
        blockLoading: true
    }
    FileView {
        id: transLog
        path: root.fake + "/trans"
        printErrors: false
        blockLoading: true
        blockWrites: true
    }
    FileView {
        id: lensPage
        path: Island.lensFile
        printErrors: false
        blockLoading: true
        blockWrites: true
    }
    // the saved shots: how many, the newest one's size (from its PNG header)
    Process {
        id: shots
        property int count: 0
        property string size: ""
        command: ["python3", "-c", "import glob,os,struct\nfs=sorted(glob.glob(os.path.expanduser('~/Pictures/**/*.png'),recursive=True),key=os.path.getmtime)\nprint(len(fs), end=' ')\nif fs:\n d=open(fs[-1],'rb').read(24)\n print('%dx%d' % struct.unpack('>II', d[16:24]))"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(" ");
                shots.count = +p[0] || 0;
                shots.size = p[1] || "";
            }
        }
    }
    Process {
        id: pngSize
        property string out: ""
        property string file: ""
        command: ["python3", "-c", "import struct,sys\nd=open(sys.argv[1],'rb').read(24)\nprint('%dx%d' % struct.unpack('>II', d[16:24]))", file]
        stdout: StdioCollector {
            onStreamFinished: pngSize.out = text.trim()
        }
    }

    // a run of words when there is no tesseract: the word steps still run
    readonly property var fakeWords: [
        {
            "x": 42,
            "y": 70,
            "w": 110,
            "h": 34,
            "t": "Hello",
            "line": 1
        },
        {
            "x": 166,
            "y": 70,
            "w": 170,
            "h": 34,
            "t": "angelOS",
            "line": 1
        },
        {
            "x": 350,
            "y": 70,
            "w": 120,
            "h": 34,
            "t": "world",
            "line": 1
        },
        {
            "x": 42,
            "y": 210,
            "w": 150,
            "h": 34,
            "t": "Search",
            "line": 2
        },
        {
            "x": 205,
            "y": 210,
            "w": 70,
            "h": 34,
            "t": "the",
            "line": 2
        },
        {
            "x": 288,
            "y": 210,
            "w": 150,
            "h": 34,
            "t": "second",
            "line": 2
        },
        {
            "x": 452,
            "y": 210,
            "w": 90,
            "h": 34,
            "t": "line",
            "line": 2
        }
    ]
    readonly property var areasHere: [
        {
            "x": 10,
            "y": 10,
            "w": 860,
            "h": 380,
            "kind": "window",
            "score": 0.9,
            "label": "big"
        },
        {
            "x": 600,
            "y": 120,
            "w": 200,
            "h": 60,
            "kind": "image",
            "score": 0.8,
            "label": ""
        }
    ]
    readonly property var windowsHere: [
        {
            "x": 0,
            "y": 0,
            "w": 900,
            "h": 400,
            "title": "big",
            "app_id": "a",
            "focused": false
        },
        {
            "x": 100,
            "y": 100,
            "w": 320,
            "h": 160,
            "title": "small",
            "app_id": "b",
            "focused": true
        },
        {
            "x": 700,
            "y": 300,
            "w": 400,
            "h": 300,
            "title": "half off",
            "app_id": "c",
            "focused": false
        }
    ]

    readonly property var steps: [
        // ---- the frame, grabbed as grim would (with the pointer when asked)
        () => {
            if (!root.wait(600))
                return false;
            board.grabToImage(r => {
                root.report("frame-saved", r.saveToFile(root.frame));
                root.frameReady = true;
            });
            return true;
        },
        () => root.frameReady,
        () => {
            Config.capture.shotCursor = true;
            CircleSearch.start(Shell.screens[0].name, 0);
            return true;
        },
        () => root.until("start-freezes-the-screen-with-the-pointer", () => CircleSearch.open && CircleSearch.frameW === 900 && CircleSearch.frameH === 400 && / -c /.test(" " + root.fileText(grimLog)), 8000, () => CircleSearch.open + " " + CircleSearch.frameW + "x" + CircleSearch.frameH + " grim: " + grimLog.text()),
        () => root.until("the-areas-are-found-on-the-frame", () => !CircleSearch.finding && CircleSearch.regions.length > 0 && CircleSearch.regions.every(r => r.x >= 0 && r.y >= 0 && r.x + r.w <= 901 && r.y + r.h <= 401), 15000, () => JSON.stringify(CircleSearch.regions)),
        () => {
            // the "photo" (620,40 220×150): some area is about it (its kind is capture_regions.py's call)
            const iou = r => {
                const ix = Math.max(0, Math.min(r.x + r.w, 840) - Math.max(r.x, 620)), iy = Math.max(0, Math.min(r.y + r.h, 190) - Math.max(r.y, 40));
                return ix * iy / (r.w * r.h + 220 * 150 - ix * iy);
            };
            root.report("the-photo-is-an-area-of-its-own", CircleSearch.regions.some(r => iou(r) > 0.6), JSON.stringify(CircleSearch.regions));
            return true;
        },
        () => {
            if (!root.hasTess) {
                root.report("no-tesseract-here:-made-up-words", true);
                CircleSearch.reading = false;
                CircleSearch.words = root.fakeWords;
                return true;
            }
            return root.until("live-text-finds-the-words", () => !CircleSearch.reading && root.word("angelos") && root.word("second"), 40000, () => JSON.stringify(CircleSearch.words.map(w => w.t)));
        },
        () => {
            root.savedWords = CircleSearch.words;
            root.snap("1-opened");
            return true;
        },
        () => {
            CircleSearch.close();
            root.report("closing-fades-away", !CircleSearch.open && CircleSearch.fading);
            return true;
        },
        () => root.until("the-fade-ends", () => !CircleSearch.fading, 2000),
        () => {
            Config.capture.shotCursor = false;
            CircleSearch.start(Shell.screens[0].name, 0);
            return true;
        },
        () => root.until("no-pointer-when-it-is-off", () => {
            const l = root.fileText(grimLog).trim().split("\n");
            return CircleSearch.open && l.length === 2 && !/ -c /.test(" " + l[1] + " ");
        }, 8000, () => grimLog.text()),
        // its own areas are in before the made-up ones replace them
        () => !CircleSearch.finding || root.wait(15000),
        () => {
            // the frame is the same: its words (the second read is not waited for)
            CircleSearch.words = root.savedWords;
            CircleSearch.regions = root.areasHere;
            CircleSearch.windowsHere = root.windowsHere;
            return true;
        },
        // ---- picks: a loop, a line, words, areas
        () => {
            const w = root.word("hello");
            const p = [];
            for (let a = 0; a < 6.28; a += 0.4)
                p.push({
                    "x": w.x + w.w / 2 + Math.cos(a) * (w.w / 2 + 14),
                    "y": w.y + w.h / 2 + Math.sin(a) * (w.h / 2 + 14)
                });
            CircleSearch.pickLoop(p);
            root.report("a-loop-picks-at-once-from-live-text", /hello/i.test(CircleSearch.text) && !/second/i.test(CircleSearch.text) && CircleSearch.pickKind === "loop", CircleSearch.text);
            return true;
        },
        () => !root.hasTess || root.until("the-closer-read-keeps-the-loop's-word", () => !CircleSearch.pickBusy && /hello/i.test(CircleSearch.text) && !/world/i.test(CircleSearch.text), 25000, () => CircleSearch.text),
        () => {
            root.snap("2-loop");
            return true;
        },
        () => {
            const w = root.word("second");
            CircleSearch.setMode("auto");
            root.report("a-tap-on-a-word-picks-its-line", CircleSearch.tapAt(w.x + 2, w.y + 2) === "line" && /search the second line/i.test(CircleSearch.text) && CircleSearch.pickKind === "line", CircleSearch.text);
            const a = root.word("angelos");
            CircleSearch.setMode("text");
            root.report("text-mode:-a-tap-picks-one-word", CircleSearch.tapAt(a.x + 3, a.y + 3) === "word" && CircleSearch.text === a.t && CircleSearch.textPick, CircleSearch.text);
            const h = root.wi("hello"), s = root.wi("second");
            CircleSearch.selectWords(h, s);
            const run = CircleSearch.text;
            CircleSearch.selectWords(s, h);
            root.report("words-from-one-to-another-in-reading-order", /^hello angelos world\nsearch the second$/i.test(run) && CircleSearch.text === run, JSON.stringify(run));
            const wd = root.word("world");
            root.report("past-the-line's-end-is-its-last-word", CircleSearch.wordNear(wd.x + wd.w + 200, wd.y + wd.h / 2) === root.wi("world"), CircleSearch.wordNear(wd.x + wd.w + 200, wd.y + wd.h / 2));
            CircleSearch.selectAll();
            root.report("select-all-takes-every-word", /^hello angelos world\nsearch the second line$/i.test(CircleSearch.text), JSON.stringify(CircleSearch.text));
            const l2 = root.word("search");
            CircleSearch.selectWordsIn({
                "x": l2.x - 10,
                "y": l2.y - 10,
                "w": 860 - l2.x,
                "h": l2.h + 20
            });
            root.report("a-text-rectangle-takes-the-words-in-it", /^search the second line$/i.test(CircleSearch.text), JSON.stringify(CircleSearch.text));
            CircleSearch.setMode("auto");
            const hit = CircleSearch.tapAt(700, 150);
            root.report("a-tap-picks-the-smallest-area", hit === "region" && root.rectIs(CircleSearch.box, 600, 120, 200, 60), hit + " " + JSON.stringify(CircleSearch.box));
            // nothing there: a 300 × 200 frame round the tap (Lens), kept on the screen
            const miss = CircleSearch.tapAt(500, 330);
            root.report("a-tap-on-nothing-puts-a-frame-there", miss === "rect" && root.rectIs(CircleSearch.box, 350, 200, 300, 200) && CircleSearch.pickKind === "rect", miss + " " + JSON.stringify(CircleSearch.box));
            // by a window's edge: the window (its inside, empty, gave the frame above)
            const edge = CircleSearch.tapAt(450, 395);
            root.report("a-tap-by-a-window-edge-takes-the-window", edge === "region" && root.rectIs(CircleSearch.box, 0, 0, 900, 400), edge + " " + JSON.stringify(CircleSearch.box));
            CircleSearch.reset();
            CircleSearch.reset();
            root.report("a-rectangle-is-the-pick-as-drawn", CircleSearch.pickRect({
                "x": 40,
                "y": 50,
                "w": 300,
                "h": 90
            }) && root.rectIs(CircleSearch.box, 40, 50, 300, 90) && CircleSearch.pickKind === "rect", JSON.stringify(CircleSearch.box));
            root.report("a-tiny-rectangle-is-not-a-pick", !CircleSearch.pickRect({
                "x": 1,
                "y": 1,
                "w": 2,
                "h": 2
            }));
            root.report("the-window-under-the-pointer-else-the-focused", CircleSearch.targetWindow(150, 150).title === "small" && CircleSearch.targetWindow(50, 350).title === "big" && CircleSearch.targetWindow(-1, -1).title === "small");
            root.report("a-window-half-off-the-screen-is-cut-to-it", root.rectIs(CircleSearch.clampRect(root.windowsHere[2]), 700, 300, 200, 100), JSON.stringify(CircleSearch.clampRect(root.windowsHere[2])));
            CircleSearch.nextMode();
            const m1 = CircleSearch.mode;
            CircleSearch.nextMode();
            const m2 = CircleSearch.mode;
            CircleSearch.nextMode();
            root.report("modes-go-round", m1 === "rect" && m2 === "text" && CircleSearch.mode === "auto", m1 + " " + m2 + " " + CircleSearch.mode);
            return true;
        },
        // ---- the face: the pointer
        () => {
            root.reopen();
            face.press(40, 50, Qt.LeftButton, Qt.ShiftModifier);
            for (let i = 1; i <= 10; i++)
                face.move(40 + 30 * i, 50 + 9 * i);
            face.release(340, 140);
            root.report("face:-a-Shift-drag-is-a-rectangle", root.rectIs(CircleSearch.box, 40, 50, 300, 90) && CircleSearch.pickKind === "rect", JSON.stringify(CircleSearch.box));
            root.snap("3-rect");
            return true;
        },
        () => {
            // a corner dragged: the opposite one stays
            face.press(340, 140, Qt.LeftButton, 0);
            face.move(370, 170);
            face.move(400, 200);
            face.release(400, 200);
            root.report("face:-a-corner-drags-the-pick", root.rectIs(CircleSearch.box, 40, 50, 360, 150), JSON.stringify(CircleSearch.box));
            face.press(40, 50, Qt.LeftButton, 0);
            face.move(30, 40);
            face.move(20, 30);
            face.release(20, 30);
            root.report("face:-the-top-left-corner-too", root.rectIs(CircleSearch.box, 20, 30, 380, 170), JSON.stringify(CircleSearch.box));
            // a side: only it moves
            face.press(400, 115, Qt.LeftButton, 0);
            face.move(420, 118);
            face.move(450, 120);
            face.release(450, 120);
            root.report("face:-a-side-drags-only-itself", root.rectIs(CircleSearch.box, 20, 30, 430, 170), JSON.stringify(CircleSearch.box));
            // inside: the whole frame moves, kept on the screen
            face.press(200, 100, Qt.LeftButton, 0);
            face.move(210, 110);
            face.move(230, 120);
            face.release(230, 120);
            root.report("face:-the-frame-moves-as-a-whole", root.rectIs(CircleSearch.box, 50, 50, 430, 170), JSON.stringify(CircleSearch.box));
            face.press(300, 100, Qt.LeftButton, 0);
            face.move(-400, -400);
            face.release(-400, -400);
            root.report("face:-a-moved-frame-stays-on-the-screen", root.rectIs(CircleSearch.box, 0, 0, 430, 170), JSON.stringify(CircleSearch.box));
            // a tap inside it (no travel) is a tap: the line under it
            const hw = root.word("hello");
            face.press(hw.x + 4, hw.y + hw.h / 2, Qt.LeftButton, 0);
            face.release(hw.x + 5, hw.y + hw.h / 2);
            root.report("face:-a-tap-inside-the-frame-is-a-tap", CircleSearch.pickKind === "line" && /hello/i.test(CircleSearch.text), CircleSearch.pickKind + " " + JSON.stringify(CircleSearch.text));
            // a tap on an empty place: the frame there
            face.press(500, 330, Qt.LeftButton, 0);
            face.release(500, 330);
            root.report("face:-a-tap-on-nothing-puts-a-frame-there", CircleSearch.pickKind === "rect" && root.rectIs(CircleSearch.box, 350, 200, 300, 200), JSON.stringify(CircleSearch.box));
            face.press(500, 300, Qt.RightButton, 0);
            root.report("face:-right-click-lets-go-of-the-pick", !CircleSearch.box && CircleSearch.open);
            // text mode: a drag from a word to another selects the run
            CircleSearch.setMode("text");
            const h = root.word("hello"), s = root.word("second");
            face.press(h.x + 4, h.y + h.h / 2, Qt.LeftButton, 0);
            face.move(h.x + 60, h.y + h.h / 2 + 30);
            face.move(s.x + 10, s.y + s.h / 2);
            root.report("face:-text-drag-selects-as-it-goes", /^hello angelos world\nsearch the second$/i.test(CircleSearch.text), JSON.stringify(CircleSearch.text));
            face.release(s.x + 10, s.y + s.h / 2);
            root.report("face:-text-drag-keeps-the-run", /^hello angelos world\nsearch the second$/i.test(CircleSearch.text) && CircleSearch.pickKind === "words", JSON.stringify(CircleSearch.text));
            root.snap("4-words");
            return true;
        },
        () => {
            // auto: a loop drawn
            CircleSearch.setMode("auto");
            const w = root.word("world");
            face.press(w.x - 12, w.y - 12, Qt.LeftButton, 0);
            face.move(w.x + w.w + 12, w.y - 12);
            face.move(w.x + w.w + 12, w.y + w.h + 12);
            face.move(w.x - 12, w.y + w.h + 12);
            face.release(w.x - 12, w.y - 10);
            root.report("face:-a-loop-drawn-picks-inside", CircleSearch.pickKind === "loop" && /world/i.test(CircleSearch.text) && !/hello/i.test(CircleSearch.text), JSON.stringify(CircleSearch.text));
            // a tap on the photo area
            face.press(700, 150, Qt.LeftButton, 0);
            face.release(701, 151);
            root.report("face:-a-tap-picks-an-area", CircleSearch.pickKind === "region" && root.rectIs(CircleSearch.box, 600, 120, 200, 60), JSON.stringify(CircleSearch.box));
            return true;
        },
        // ---- learning: an area's frame fixed and "Remember" answered — the next tap takes it so;
        // a word fixed in the card and remembered; all of it on disk
        () => {
            root.reopen();
            CircleSearch.forget();
            answer.setText("yes\n");
            CircleSearch.tapAt(700, 150);
            const first = CircleSearch.box;
            CircleSearch.adjustTo({
                "x": 600,
                "y": 140,
                "w": 200,
                "h": 40
            }, "rect");
            CircleSearch.save();
            return true;
        },
        () => root.until("learn:-a-fixed-frame-is-asked-about", () => /Запомнить|Remember/.test(root.fileText(notifyLog)), 6000, () => notifyLog.text()),
        () => root.until("learn:-remembered-the-next-tap-takes-it-so", () => {
                root.reopen();
                CircleSearch.tapAt(700, 150);
                return CircleSearch.pickKind === "region" && root.rectIs(CircleSearch.box, 600, 140, 200, 40);
            }, 6000, () => JSON.stringify(CircleSearch.box) + " " + JSON.stringify(CircleSearch.learned)),
        () => {
            const w = root.word("second");
            CircleSearch.tapAt(w.x + 3, w.y + 3);
            CircleSearch.text = CircleSearch.text.replace(/second/i, "2nd");
            CircleSearch.copyText();
            return true;
        },
        () => root.until("learn:-a-fixed-word-is-remembered", () => Object.values(CircleSearch.learned.apps || {}).some(a => a.fixes && Object.keys(a.fixes).some(k => /second/i.test(k) && a.fixes[k].to === "2nd" && a.fixes[k].ok)), 6000, () => JSON.stringify(CircleSearch.learned)),
        () => root.until("learn:-kept-on-disk", () => {
                const j = JSON.parse(root.fileText(learnFile) || "{}");
                return !!j.apps && JSON.stringify(j).indexOf("2nd") >= 0;
            }, 4000, () => learnFile.text()),
        () => {
            CircleSearch.forget();
            answer.setText("");
            root.report("learn:-forget-forgets", CircleSearch.learnedCount === 0 && !CircleSearch.learned.apps["*"], JSON.stringify(CircleSearch.learned));
            return true;
        },
        // ---- the keys
        () => {
            root.reopen();
            CircleSearch.pickRect({
                "x": 40,
                "y": 50,
                "w": 300,
                "h": 90
            });
            face.key("Escape");
            const first = !CircleSearch.box && CircleSearch.open;
            face.key("Escape");
            root.report("Esc-steps-back-then-away", first && !CircleSearch.open, first + " " + CircleSearch.open);
            root.reopen();
            face.key("Tab");
            root.report("Tab-changes-the-mode", CircleSearch.mode === "rect", CircleSearch.mode);
            face.key("Ctrl+A");
            root.report("Ctrl+A-selects-all-the-text", CircleSearch.pickKind === "words" && /hello[\s\S]*line/i.test(CircleSearch.text), CircleSearch.text);
            CircleSearch.setMode("auto");
            copied.setText("");
            face.key("Ctrl+C");
            root.report("Ctrl+C-on-text-closes", !CircleSearch.open);
            return true;
        },
        () => root.until("Ctrl+C-copies-a-text-pick's-text", () => /^hello angelos world\nsearch the second line$/i.test(root.fileText(copied)), 4000, () => copied.text()),
        () => {
            root.reopen();
            CircleSearch.tapAt(700, 150);
            copied.setText("");
            face.key("Ctrl+C");
            return true;
        },
        () => root.until("Ctrl+C-copies-an-area's-picture", () => /image\/png/.test(root.fileText(copied)), 8000, () => copied.text()),
        () => {
            root.look();
            return root.wait(1500);
        },
        () => {
            root.shots0 = shots.count;
            root.reopen();
            CircleSearch.pickRect({
                "x": 40,
                "y": 50,
                "w": 300,
                "h": 90
            });
            face.key("Enter");
            root.report("Enter-saves-and-closes-with-the-shutter", !CircleSearch.open && face.leaving === "shot" && root.rectIs(face.shotRect, 40, 50, 300, 90), face.leaving + " " + JSON.stringify(face.shotRect));
            return true;
        },
        () => root.until("Enter-saves-the-picked-piece", () => root.savedIs("300x90"), 10000, () => shots.count + " " + shots.size),
        // ---- the bar
        () => {
            root.reopen();
            const names = ["act-save", "act-copy", "act-text", "act-search", "act-lens", "act-translate", "act-share", "act-full", "act-window"];
            const missing = names.filter(n => {
                const b = root.btn(n);
                return !b || !b.visible;
            });
            root.report("the-bar-has-every-action", missing.length === 0, missing.join(" "));
            root.report("the-bar-is-at-the-bottom", face.bar.visible && face.bar.y + face.bar.height > 400 * 0.75 && face.bar.y + face.bar.height <= 400, face.bar.y + " " + face.bar.height);
            root.report("nothing-picked:-search-waits-for-a-pick", !root.btn("act-search").enabled);
            CircleSearch.words = [];
            root.report("no-words:-text-and-translate-wait", !root.btn("act-text").enabled && !root.btn("act-translate").enabled);
            CircleSearch.words = root.savedWords;
            root.snap("5-bar");
            return true;
        },
        () => {
            root.shots0 = shots.count;
            CircleSearch.pickRect({
                "x": 40,
                "y": 50,
                "w": 300,
                "h": 90
            });
            root.report("a-pick:-search-is-ready", root.btn("act-search").enabled);
            root.click("act-save");
            root.report("save-closes-with-the-shutter", !CircleSearch.open && face.leaving === "shot");
            return true;
        },
        () => root.until("save-keeps-the-picked-piece", () => root.savedIs("300x90"), 10000, () => shots.count + " " + shots.size),
        () => {
            root.reopen();
            root.shots0 = shots.count;
            face.at = Qt.point(150, 150);
            face.windowPreview = true;
            root.report("Window-shows-what-it-will-take", !!face.target && face.target.title === "small", JSON.stringify(face.target));
            root.click("act-window");
            return true;
        },
        () => root.until("Window-saves-the-window-under-the-pointer", () => root.savedIs("320x160"), 10000, () => shots.count + " " + shots.size),
        () => {
            root.reopen();
            root.shots0 = shots.count;
            root.click("act-full");
            return true;
        },
        () => root.until("Whole-screen-saves-the-frame", () => root.savedIs("900x400"), 10000, () => shots.count + " " + shots.size),
        () => {
            root.reopen();
            CircleSearch.pickRect({
                "x": 40,
                "y": 50,
                "w": 300,
                "h": 90
            });
            copied.setText("");
            root.click("act-copy");
            return true;
        },
        () => root.until("Copy-puts-the-picture-on-the-clipboard", () => /image\/png/.test(root.fileText(copied)), 8000, () => copied.text()),
        () => {
            root.reopen();
            copied.setText("");
            root.click("act-text");
            return true;
        },
        () => root.until("Text-with-nothing-picked-copies-all-the-text", () => /^hello angelos world\nsearch the second line$/i.test(root.fileText(copied)), 4000, () => copied.text()),
        () => {
            root.reopen();
            CircleSearch.text = "ангел пиксель";
            root.click("act-search");
            root.report("search-closes-the-overlay", !CircleSearch.open);
            return true;
        },
        () => root.until("Search-opens-in-the-island", () => /--\s+https?:\/\/\S*%D0%B0%D0%BD%D0%B3%D0%B5%D0%BB/i.test(root.fileText(island)), 8000, () => island.text() + " | xdg: " + browser.text()),
        () => {
            Config.island.enabled = false;
            root.reopen();
            CircleSearch.text = "островок выключен";
            root.click("act-search");
            return true;
        },
        () => root.until("Search-with-the-island-off-goes-to-the-browser", () => /%D0%B2%D1%8B%D0%BA%D0%BB/i.test(root.fileText(browser)), 8000, () => browser.text()),
        () => {
            Config.island.enabled = true;
            root.reopen();
            CircleSearch.pickRect({
                "x": 600,
                "y": 120,
                "w": 200,
                "h": 60
            });
            CircleSearch.text = "";
            island.setText("");
            root.click("act-search");
            return true;
        },
        () => root.until("Search-on-a-pick-without-text-goes-to-Lens", () => root.fileText(island).indexOf(Island.lensFile) >= 0 && /lens\.google\.com/.test(root.fileText(lensPage)), 8000, () => island.text()),
        () => {
            root.reopen();
            island.setText("");
            lensPage.setText("");
            root.click("act-lens");
            return true;
        },
        () => root.until("Search-the-picture-opens-Lens-in-the-island", () => root.fileText(island).indexOf(Island.lensFile) >= 0 && /lens\.google\.com/.test(root.fileText(lensPage)), 8000, () => island.text()),
        () => {
            root.reopen();
            root.click("act-translate");
            root.report("translate-keeps-the-overlay", CircleSearch.open && CircleSearch.translating);
            return true;
        },
        () => root.until("Translate-with-nothing-picked-takes-all-the-text", () => CircleSearch.translation === "ПЕРЕВОД:ru" && /hello angelos world\s+search the second line/i.test(root.fileText(transLog)), 8000, () => CircleSearch.translation + " | " + transLog.text()),
        () => {
            root.report("the-translation-shows-on-the-card", face.card.visible && root.btn("act-copy-translation").visible);
            root.snap("6-translation");
            return true;
        },
        () => {
            copied.setText("");
            root.click("act-copy-translation");
            return true;
        },
        () => root.until("the-translation-can-be-copied", () => root.fileText(copied) === "ПЕРЕВОД:ru", 4000, () => copied.text()),
        () => {
            CircleSearch.text = "привет мир";
            CircleSearch.translate();
            return true;
        },
        () => root.until("Russian-goes-into-English-by-itself", () => CircleSearch.translation === "ПЕРЕВОД:en", 8000, () => CircleSearch.translation),
        () => {
            root.reopen();
            CircleSearch.setMode("text");
            const a = root.word("angelos");
            CircleSearch.tapAt(a.x + 3, a.y + 3);
            CircleSearch.setMode("auto");
            root.click("act-share");
            root.report("Send-nearby-sends-a-text-pick's-text", QuickShare.sheetOpen && QuickShare.payloadText === a.t && QuickShare.payload.length === 0, QuickShare.payloadText);
            QuickShare.close();
            QuickShare.payloadText = "";
            root.reopen();
            CircleSearch.pickRect({
                "x": 40,
                "y": 50,
                "w": 300,
                "h": 90
            });
            root.click("act-share");
            return true;
        },
        () => root.until("Send-nearby-sends-the-picture", () => QuickShare.sheetOpen && QuickShare.payload.length === 1 && /\.png$/.test(QuickShare.payload[0]), 8000, () => JSON.stringify(QuickShare.payload)),
        () => {
            pngSize.file = QuickShare.payload[0];
            pngSize.running = true;
            return true;
        },
        () => root.until("the-picture-sent-is-the-pick", () => pngSize.out === "300x90", 4000, () => pngSize.out),
        // ---- links
        () => {
            CircleSearch.text = "https://example.org/x";
            root.report("a-link-is-a-link", CircleSearch.kind === "url");
            CircleSearch.text = "see github.com/x, mail a@b.ru (readme.md)";
            root.report("links-in-the-text", CircleSearch.kind === "text" && CircleSearch.links.map(l => l.url).join(" ") === "https://github.com/x mailto:a@b.ru", JSON.stringify(CircleSearch.links.map(l => l.url)));
            CircleSearch.close();
            console.log("TEST DONE");
            Qt.quit();
            return true;
        }
    ]

    Timer {
        interval: 40
        running: true
        repeat: true
        onTriggered: {
            if (root.step < 0 || root.step >= root.steps.length || root.snapping)
                return;
            let done = false;
            try {
                done = root.steps[root.step]();
            } catch (e) {
                root.report("step-" + root.step, false, String(e) + " " + (e.stack || ""));
                done = true;
            }
            if (done) {
                root.step++;
                root.since = Date.now();
            }
        }
    }
}
