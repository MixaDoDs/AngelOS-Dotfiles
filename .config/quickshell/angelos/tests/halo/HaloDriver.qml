import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// The Halo's sources, offscreen (started by tests/halo/run.sh). Recording: a stand-in recorder
// (sleep) with niri-record-region's pid file is seen, its start time and file read; the real
// script's --stop stops it and the shell notices; a recorder that dies by itself is noticed too.
// Then where the lyrics go (Lyrics.placeOn, Halo.on) and the capsules (Halo.items): a timer, a
// timer's end (ring, first), our recording. Then a paused recording (no recorder, the pieces'
// time), a picked colour's capsule, a browser download (a half-file growing, then whole: on the
// shelf, a moment's capsule).
Scope {
    id: root

    property int step: 0
    readonly property string rt: Quickshell.env("XDG_RUNTIME_DIR")
    readonly property string fake: Quickshell.env("FAKE_DIR")
    Component.onCompleted: Quickshell.watchFiles = false

    // a busy machine (the whole test-ui at once): a check waits for its state up to 15 s instead
    // of failing at its step — hold() keeps the step until cond holds or the time is out
    property int waited: 0
    property double hideAt: 0
    function hold(cond) {
        if (cond || waited >= 30) {
            waited = 0;
            return false;
        }
        waited++;
        step--;
        return true;
    }
    function ok(name, cond, detail) {
        console.log("TEST " + name + " " + (cond ? "PASS" : "FAIL") + " " + (detail || ""));
    }
    // a stand-in recorder: its pid into the pid file, the file name into .out (exec: a background
    // job of sh would ignore the script's SIGINT)
    function fakeRecorder() {
        Quickshell.execDetached(["sh", "-c", 'echo $$ >"$1/niri-record-region.pid"; echo /videos/niri-test.mp4 >"$1/niri-record-region.out"; exec sleep 60', "sh", rt]);
    }
    FileView {
        id: notify
        watchChanges: true
        onFileChanged: reload()
        path: root.fake + "/notify"
        blockLoading: true
        printErrors: false
    }

    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            root.step++;
            const C = Capture;
            if (root.step === 2) {
                root.ok("rec-idle", !C.recording && !C.recSince, C.recording);
                root.fakeRecorder();
            } else if (root.step === 3) {
                C.recCheck();
            } else if (root.step === 4) {
                root.ok("rec-seen", C.recording && Math.abs(C.recSince - Date.now()) < 5000 && C.recFile === "/videos/niri-test.mp4", C.recording + " " + C.recSince + " " + C.recFile);
                C.stopRecord();
            } else if (root.step === 13) {
                if (root.hold(!C.recording && String(notify.text() || "").includes("Screen record")))
                    return;
                // the script stopped it (its notification), the 3 s look saw it go
                root.ok("rec-stop", !C.recording && !C.recSince && String(notify.text() || "").includes("Screen record"), C.recording + " " + notify.text());
                root.fakeRecorder();
            } else if (root.step === 14) {
                C.recCheck();
            } else if (root.step === 15) {
                root.ok("rec-again", C.recording, C.recording);
                Quickshell.execDetached(["sh", "-c", 'kill "$(cat "$1/niri-record-region.pid")"', "sh", root.rt]);
            } else if (root.step === 23) {
                if (root.hold(!C.recording))
                    return;
                root.ok("rec-died", !C.recording, C.recording);
                // where the lyrics go: the bar, the Halo, nowhere
                const L = Config.lyrics, H = Config.halo;
                L.screens = [];
                L.haloScreens = [];
                H.enabled = true;
                H.screens = [];
                root.ok("place-bar", Lyrics.placeOn("A") === "bar" && Halo.on("A"), Lyrics.placeOn("A"));
                L.haloScreens = ["A"];
                root.ok("place-halo", Lyrics.placeOn("A") === "halo" && Lyrics.placeOn("B") === "bar", Lyrics.placeOn("A") + " " + Lyrics.placeOn("B"));
                H.screens = ["B"];
                root.ok("place-no-halo-there", !Halo.on("A") && Halo.on("B") && Lyrics.placeOn("A") === "bar", Lyrics.placeOn("A"));
                H.screens = [];
                H.enabled = false;
                root.ok("place-halo-off", !Halo.on("A") && Lyrics.placeOn("A") === "bar", Lyrics.placeOn("A"));
                H.enabled = true;
                L.screens = ["B"];
                root.ok("place-nowhere", Lyrics.placeOn("A") === "" && Lyrics.placeOn("B") === "bar", Lyrics.placeOn("A"));
                L.screens = [];
                L.haloScreens = [];
                // the capsules: a timer, then a short one that rings
                Timers.add(Timers.parse("10m"));
                Timers.add(Timers.parse("1s"));
            } else if (root.step === 24) {
                root.ok("items-timer", Halo.items.filter(i => i.kind === "timer").length >= 1, JSON.stringify(Halo.items));
            } else if (root.step === 29) {
                if (root.hold(!!Halo.rang))
                    return;
                root.ok("items-ring", !!Halo.rang && Halo.items.length > 0 && Halo.items[0].kind === "ring" && Halo.items.filter(i => i.kind === "timer").length === 1, JSON.stringify(Halo.rang) + " " + JSON.stringify(Halo.items));
                root.fakeRecorder();
            } else if (root.step === 30) {
                C.recCheck();
            } else if (root.step === 31) {
                const r = Halo.items.find(i => i.kind === "rec");
                root.ok("items-rec", C.recording && !!r && r.own === true && r.since === C.recSince, JSON.stringify(Halo.items));
                // what gets a capsule: the filters (the ring of a timer's end always does)
                const H = Config.halo;
                H.showRec = false;
                root.ok("filter-rec", !Halo.items.some(i => i.kind === "rec"), JSON.stringify(Halo.items));
                H.showRec = true;
                H.showTimers = false;
                root.ok("filter-timers", !Halo.items.some(i => i.kind === "timer") && Halo.items.some(i => i.kind === "ring"), JSON.stringify(Halo.items));
                H.showTimers = true;
                Quickshell.execDetached(["sh", "-c", 'kill "$(cat "$1/niri-record-region.pid")"', "sh", root.rt]);
                // the size
                H.size = "s";
                const sS = Halo.scale;
                H.size = "l";
                const sL = Halo.scale;
                H.size = "m";
                root.ok("scale", sS < 1 && sL > 1 && Halo.scale === 1, sS + " " + Halo.scale + " " + sL);
                // the weather is asked for while the Halo is on
                H.enabled = false;
                const wOff = Halo.weatherWanted;
                H.enabled = true;
                root.ok("weather-wanted", !wOff && Halo.weatherWanted, wOff + " " + Halo.weatherWanted);
                // no MPRIS here: no music, and no pinned player breaks the choice
                Lyrics.pinned = null;
                root.ok("music-none", !Halo.music && !Halo.items.some(i => i.kind === "music") && Lyrics.player === null, Halo.music + " " + Lyrics.player);
                // hiding: shown again at once; for a while, then back by itself
                Halo.hideFor(60000);
                const hS = Halo.hidden;
                Halo.show();
                root.ok("hide-show", hS && !Halo.hidden, hS + " " + Halo.hidden);
                Halo.hideFor(1500);
                root.hideAt = Date.now();
                root.ok("hide-for", Halo.hidden, Halo.hidden);
            } else if (root.step === 32) {
                if (root.hold(!Halo.hidden))
                    return;
                const took = Date.now() - root.hideAt;
                root.ok("hide-for-back", !Halo.hidden && took >= 1400 && took < 4000, took + " ms");
                // paused: no recorder, the paused mark and the time recorded so far
                Quickshell.execDetached(["sh", "-c", 'echo /videos/p.mp4 >"$1/niri-record-region.out"; touch "$1/niri-record-region.paused"; echo 4000 >"$1/niri-record-region.acc"', "sh", root.rt]);
                ColorPicker.picked("#ff0000");
                root.ok("flash-pick", Halo.items.some(i => i.kind === "pick" && i.hex === "#ff0000"), JSON.stringify(Halo.items));
                Quickshell.execDetached(["sh", "-c", 'head -c 3000 /dev/zero >"$1/Downloads/a.zip.crdownload"', "sh", Config.home]);
            } else if (root.step === 33) {
                Capture.recCheck();
            } else if (root.step === 34) {
                const C = Capture;
                root.ok("rec-paused", C.recording && C.recPaused && C.recAcc === 4000 && C.recElapsed(Date.now()) === 4000 && C.recFile === "/videos/p.mp4", C.recording + " " + C.recPaused + " " + C.recAcc);
                Quickshell.execDetached(["sh", "-c", 'rm -f "$1"/niri-record-region.*', "sh", root.rt]);
            } else if (root.step === 36) {
                if (root.hold(Downloads.active.length === 1))
                    return;
                const d = Downloads.active[0];
                root.ok("dl-seen", !!d && d.name === "a.zip" && d.size === 3000 && Halo.items.some(i => i.kind === "dl"), JSON.stringify(Downloads.active));
                Quickshell.execDetached(["sh", "-c", 'mv "$1/Downloads/a.zip.crdownload" "$1/Downloads/a.zip"', "sh", Config.home]);
            } else if (root.step === 38) {
                if (root.hold(Downloads.finished === "a.zip"))
                    return;
                root.ok("dl-done", !Downloads.active.length && Downloads.finished === "a.zip" && Shelf.items.some(i => i.path === Config.home + "/Downloads/a.zip") && Halo.items.some(i => i.kind === "dlDone"), JSON.stringify(Shelf.items));
                console.log("TEST DONE");
                Qt.quit();
            }
        }
    }
}
