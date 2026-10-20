pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services

// tests/videograb/run.sh, offscreen: services/VideoGrab with a stand-in yt-dlp (it prints what the
// real one prints for videograb.py's template) — the Halo's download capsule with its percent, the
// file on the shelf, a yt-dlp failure in VideoGrab.error (the notification itself: run.sh reads
// the stand-in notify-send's log), a squeeze held while a game runs and done after it.
Scope {
    id: root

    property int step: 0
    property double since: Date.now()
    readonly property string src: Quickshell.env("VG_SRC")
    readonly property string downloads: Config.home + "/Downloads"

    function report(name, ok, detail) {
        console.log("TEST " + name + " " + (ok ? "PASS" : "FAIL") + " " + (detail || ""));
    }
    function next() {
        step++;
        since = Date.now();
    }
    function until(name, cond, ms, detail) {
        const ok = !!cond();
        if (!ok && Date.now() - since < (ms || 8000))
            return false;
        report(name, ok, detail ? detail() : "");
        next();
        return true;
    }
    function onShelf(re) {
        return Shelf.items.find(i => re.test(i.path || "")) || null;
    }

    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            const s = root.step;
            if (s === 0) {
                void Halo.items;
                // singletons come when first asked: the ring's formats load now (the shell's ring asks at start)
                void Convert.open;
                // niri-game-mode's state file is read (and found missing) first
                if (Date.now() - root.since < 1500)
                    return;
                VideoGrab.grab("https://youtu.be/ok", false);
                root.next();
            } else if (s === 1) {
                // the capsule: one download, its size known, part of the way
                root.until("grab-progress", () => {
                    const d = Downloads.active[0];
                    const f = Downloads.fraction(d);
                    return Downloads.active.length === 1 && f > 0 && f < 1 && d.name === "Тестовое видео.mp4" && Halo.items.some(i => i.kind === "dl");
                }, 8000, () => JSON.stringify(Downloads.active) + " " + JSON.stringify(Halo.items.map(i => i.kind)));
            } else if (s === 2) {
                root.until("grab-done", () => !!root.onShelf(/\/Downloads\/Тестовое видео \[ok\]\.mp4$/) && !VideoGrab.busy && !Downloads.active.length && Downloads.finished === "Тестовое видео [ok].mp4", 10000, () => JSON.stringify(Shelf.items) + " finished=" + Downloads.finished + " busy=" + VideoGrab.busy);
                if (root.step === 3)
                    VideoGrab.grab("https://youtu.be/fail", false);
            } else if (s === 3) {
                root.until("grab-error", () => VideoGrab.error.indexOf("Sign in to confirm") >= 0 && !VideoGrab.busy && !Downloads.active.length, 8000, () => "error=" + VideoGrab.error);
                if (root.step === 4) {
                    Shell.gaming = true;
                    VideoGrab.shrink(root.src, 1.5, 4.5);
                }
            } else if (s === 4) {
                root.until("held-in-game", () => VideoGrab.held.length === 1 && !VideoGrab.busy, 1000, () => "held=" + VideoGrab.held.length + " busy=" + VideoGrab.busy);
                if (root.step === 5)
                    Shell.gaming = false;
            } else if (s === 5) {
                root.until("shrink-after-game", () => !!root.onShelf(/ \(Discord\)\.mp4$/) && !VideoGrab.busy && !VideoGrab.held.length, 30000, () => JSON.stringify(Shelf.items.map(i => i.path)) + " busy=" + VideoGrab.busy + " error=" + VideoGrab.error);
                if (root.step === 6)
                    Convert.show([Config.home + "/Pictures/p.png", root.src, Config.home + "/Music/s.wav", Config.home + "/Music/notes.txt"]);
            } else if (s === 6) {
                // several kinds: the kinds' ring first (a video counts for sound too), the text skipped
                root.until("ring-kinds", () => Convert.open && Convert.level === "" && Convert.ringKinds.join() === "image,video,audio" && Convert.skipped === 1 && Convert.filesFor("audio").length === 2, 3000, () => "open=" + Convert.open + " level=" + Convert.level + " kinds=" + Convert.ringKinds + " skipped=" + Convert.skipped + " formats=" + JSON.stringify(Convert.formats).slice(0, 80));
                if (root.step === 7) {
                    Convert.level = "image";
                    Convert.run("webp");
                }
            } else if (s === 7) {
                root.until("ring-convert", () => !Convert.open && !!root.onShelf(/\/Pictures\/Сконвертировано\/p\.webp$/) && !VideoGrab.busy, 15000, () => JSON.stringify(Shelf.items.map(i => i.path)) + " error=" + VideoGrab.error);
                if (root.step === 8)
                    Convert.show([Config.home + "/Music/s.wav"]);
            } else if (s === 8) {
                // one kind: straight to its formats; Esc there goes away
                // …worked out: an estimate for each, the format it already is offered no more
                root.until("ring-one-kind", () => Convert.open && Convert.level === "audio" && Convert.sizes.mp3 > 0 && Convert.now > 0 && Convert.same.join() === "wav", 6000, () => "level=" + Convert.level + " sizes=" + JSON.stringify(Convert.sizes) + " same=" + Convert.same);
                if (root.step === 9)
                    Convert.back();
            } else if (s === 9) {
                root.until("ring-back-closes", () => !Convert.open, 1000, () => "open=" + Convert.open);
            } else {
                console.log("TEST-SHRUNK " + (root.onShelf(/ \(Discord\)\.mp4$/) || {}).path);
                console.log("TEST DONE");
                Qt.quit();
            }
        }
    }
}
