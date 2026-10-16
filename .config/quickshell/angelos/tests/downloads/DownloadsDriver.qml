import QtQuick
import Quickshell
import qs.config
import qs.services

// Browser downloads, offscreen (started by tests/downloads/run.sh). With BROWSER_GET set, a real
// headless Helium fetches from tests/downloads/serve.py into the stand-in ~/Downloads; without it
// the same files are made by hand. A slow one: its capsule while it runs, ahead of a timer (the
// Halo's order: downloads before timers, the music last), then on the shelf. A small one, done
// before any half-file is seen: on the shelf too. A cancelled one and a file there before the
// shell: nothing. Firefox's way (the empty «name» beside its .part): done once the .part goes.
Scope {
    id: root

    property int step: 0
    readonly property string get: Quickshell.env("BROWSER_GET")
    readonly property string dl: Config.home + "/Downloads"
    Component.onCompleted: Quickshell.watchFiles = false

    property int waited: 0
    function hold(cond) {
        if (cond || waited >= 40) {
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
    function sh(script) {
        Quickshell.execDetached(["sh", "-c", script, "sh", dl]);
    }
    function onShelf(name) {
        return Shelf.items.some(i => i.path === dl + "/" + name);
    }
    // every name that was `finished`, in order
    property var done: []
    Connections {
        target: Downloads
        function onFinishedChanged() {
            if (Downloads.finished)
                root.done = root.done.concat([Downloads.finished]);
        }
    }

    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            root.step++;
            const D = Downloads;
            if (root.step === 1) {
                Config.halo.enabled = true;
                Config.halo.showTimers = true;
            } else if (root.step === 4) {
                // the file there before says nothing
                root.ok("old-quiet", !root.done.length && !root.onShelf("old.txt"), JSON.stringify(root.done));
                root.ok("order", Halo.rank({
                    "kind": "dl"
                }) < Halo.rank({
                    "kind": "timer"
                }) && Halo.rank({
                    "kind": "timer"
                }) < Halo.rank({
                    "kind": "music"
                }) && Halo.rank({
                    "kind": "dlDone"
                }) < Halo.rank({
                    "kind": "music"
                }), Halo.order.join(" "));
                Timers.add("5m чай");
            } else if (root.step === 5) {
                // the slow one: 3 MB over ~4 s
                if (root.get)
                    Quickshell.execDetached([root.get, "slow.bin"]);
                else
                    root.sh('for i in 1 2 3 4 5 6 7 8; do head -c 300000 /dev/zero >>"$1/slow.bin.crdownload"; sleep 0.5; done; mv "$1/slow.bin.crdownload" "$1/slow.bin"');
            } else if (root.step === 6) {
                // with the browser's extension: wait for its word on the size too
                if (root.hold(D.active.length === 1 && D.active[0].size > 0 && (!root.get || D.active[0].total > 0)))
                    return;
                const d = D.active[0];
                const it = Halo.items;
                root.ok("slow-seen", !!d && d.name === "slow.bin", JSON.stringify(D.active));
                if (root.get) {
                    const f = D.fraction(d);
                    root.ok("percent", !!d && d.total === 3000000 && f > 0 && f < 1 && D.overall === f, JSON.stringify(d) + " " + D.overall);
                }
                // the download is the pill's, the timer only a bubble beside it
                root.ok("slow-first", it.length > 1 && it[0].kind === "dl" && it.some(i => i.kind === "timer"), JSON.stringify(it.map(i => i.kind)));
            } else if (root.step === 7) {
                if (root.hold(root.done.includes("slow.bin")))
                    return;
                root.ok("slow-done", root.done.includes("slow.bin") && root.onShelf("slow.bin") && !D.active.length, JSON.stringify(root.done) + " " + JSON.stringify(D.active));
                root.ok("slow-flash", Halo.items.some(i => i.kind === "dlDone" && i.name === "slow.bin"), JSON.stringify(Halo.items.map(i => i.kind)));
                // the small one: done at once
                if (root.get)
                    Quickshell.execDetached([root.get, "tiny.txt"]);
                else
                    root.sh('head -c 7000 /dev/zero >"$1/tiny.txt"');
            } else if (root.step === 8) {
                if (root.hold(root.done.includes("tiny.txt")))
                    return;
                root.ok("tiny-done", root.done.includes("tiny.txt") && root.onShelf("tiny.txt"), JSON.stringify(root.done));
                // a cancelled one: the half-file grows, then goes alone
                root.sh('head -c 50000 /dev/zero >"$1/gone.iso.crdownload"');
            } else if (root.step === 9) {
                if (root.hold(D.active.some(d => d.name === "gone.iso")))
                    return;
                root.ok("cancel-seen", D.active.some(d => d.name === "gone.iso"), JSON.stringify(D.active));
                root.sh('rm "$1/gone.iso.crdownload"');
            } else if (root.step === 13) {
                root.ok("cancel-quiet", !root.done.includes("gone.iso") && !root.onShelf("gone.iso") && !D.active.length, JSON.stringify(root.done) + " " + JSON.stringify(D.active));
                // Firefox: the empty name and its .part at the start
                root.sh(': >"$1/fox.pdf.part"; : >"$1/fox.pdf"; head -c 80000 /dev/zero >>"$1/fox.pdf.part"');
            } else if (root.step === 14) {
                if (root.hold(D.active.some(d => d.name === "fox.pdf")))
                    return;
                root.ok("fox-wait", !root.done.includes("fox.pdf"), JSON.stringify(root.done));
                root.sh('mv "$1/fox.pdf.part" "$1/fox.pdf"');
            } else if (root.step === 15) {
                if (root.hold(root.done.includes("fox.pdf")))
                    return;
                root.ok("fox-done", root.done.includes("fox.pdf") && root.onShelf("fox.pdf") && !root.done.includes("fox.pdf.part"), JSON.stringify(root.done));
                // wget, curl, Telegram: the whole name from the start, growing
                root.sh('for i in 1 2 3 4 5 6; do head -c 200000 /dev/zero >>"$1/wget.tar"; sleep 0.6; done');
            } else if (root.step === 16) {
                if (root.hold(D.active.some(d => d.name === "wget.tar")))
                    return;
                const d = D.active.find(x => x.name === "wget.tar");
                root.ok("grow-seen", !!d && d.total === 0 && D.overall === -1 && !root.done.includes("wget.tar"), JSON.stringify(D.active));
            } else if (root.step === 17) {
                if (root.hold(root.done.includes("wget.tar")))
                    return;
                root.ok("grow-done", root.done.includes("wget.tar") && root.onShelf("wget.tar") && !D.active.length, JSON.stringify(root.done) + " " + JSON.stringify(D.active));
                root.ok("old-still", !root.onShelf("old.txt") && !root.done.includes("old.txt"), JSON.stringify(root.done));
                console.log("TEST DONE");
                Qt.quit();
            }
        }
    }
}
