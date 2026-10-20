pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import qs.config

// Downloads, for the Halo — from any browser or program that saves into ~/Downloads:
//  · in progress = a half-file (Chromium/Helium/Brave «name.crdownload», Firefox «name.part»,
//    GNOME Web «name.download», qBittorrent «name.!qB») or a new whole file still growing
//    (wget, curl, Telegram…): what came and how fast;
//  · the percent where the browser tells it: its extension (scripts/browser-downloads.py puts it
//    into the browsers found) writes {file, received, total} into
//    $XDG_RUNTIME_DIR/angelos-browser-downloads.json; a file on disk alone never knows its size;
//  · done = the half-file became its whole file, or a new whole file stopped growing: onto the
//    Halo's shelf, and `finished` for a moment. A cancelled one (the half-file gone alone) says
//    nothing, nor do the files there before.
//  · told: what services/VideoGrab says of its own job (a link through yt-dlp, a video squeezed
//    for Discord), the same as a browser's word.
// shortcut: any new file there counts (a file moved in by hand too)
Singleton {
    id: root

    readonly property string dir: Config.home + "/Downloads"
    // [{path, name, size, total, speed, paused}] — bytes, bytes/s; total 0 = unknown
    property var active: []
    property string finished: ""        // the name just done, "" after a few seconds
    readonly property bool watching: Config.halo.enabled
    readonly property var halfRe: /\.(crdownload|part|download|!qB)$/i

    // the percent of one (0…1), -1 when nobody knows the size
    function fraction(d) {
        return d && d.total > 0 ? Math.min(1, d.size / d.total) : -1;
    }
    // all of them together, -1 if any size is unknown
    readonly property real overall: {
        let got = 0, all = 0;
        for (const d of active) {
            if (!(d.total > 0))
                return -1;
            got += d.size;
            all += d.total;
        }
        return all > 0 ? Math.min(1, got / all) : -1;
    }
    // seconds left, -1 unknown
    function eta(d) {
        return d && d.total > 0 && d.speed > 0 ? Math.max(0, Math.round((d.total - d.size) / d.speed)) : -1;
    }

    // ---- the folder: half-files and new whole files ----
    FolderListModel {
        id: listing
        folder: root.watching ? "file://" + root.dir : ""
        showDirs: false
        showHidden: true
        showDotAndDotDot: false
        onCountChanged: news.restart()
        onRowsInserted: news.restart()
        onRowsRemoved: news.restart()
        onStatusChanged: news.restart()
    }
    property var known: null            // whole names seen, null until the first listing
    property var halves: []             // the half-files' names now
    property var wasHalf: ({})          // whole name → true: it had a half-file (a rename = done at once)
    property var growing: ({})          // new whole names with no half-file: {size, still} (still = looks unchanged)
    Timer {
        id: news
        interval: 150
        onTriggered: root.compare()
    }
    function compare() {
        if (listing.status !== FolderListModel.Ready)
            return;
        const names = [];
        for (let i = 0; i < listing.count; i++) {
            const p = String(listing.get(i, "filePath"));
            // a folder that isn't there lists another one
            if (p.indexOf(dir + "/") === 0) {
                const n = p.slice(dir.length + 1);
                if (n[0] !== "." || halfRe.test(n))
                    names.push(n);
            }
        }
        const half = names.filter(n => halfRe.test(n));
        const halfOf = new Set(half.map(n => n.replace(halfRe, "")));
        const was = Object.assign({}, wasHalf);
        for (const n of halfOf)
            was[n] = true;
        // a whole name with its half-file beside it (Firefox's empty one) isn't one yet
        const whole = names.filter(n => !halfRe.test(n) && !halfOf.has(n));
        const grow = Object.assign({}, growing);
        if (known !== null)
            for (const n of whole)
                if (!known.has(n)) {
                    if (was[n])
                        done(n);
                    else
                        grow[n] = {
                            "size": -1,
                            "still": 0
                        };
                }
        for (const n of Object.keys(grow))
            if (!whole.includes(n))
                delete grow[n];
        // a half-file's name is kept until its whole one is there (a rename seen in two looks)
        for (const n of Object.keys(was))
            if (!halfOf.has(n) && whole.includes(n))
                delete was[n];
        known = new Set(whole);
        wasHalf = was;
        growing = grow;
        halves = half;
        look();
    }
    // path: a file elsewhere (services/VideoGrab); one here isn't counted again by the next look
    function done(name, path) {
        if (known)
            known.add(name);
        if (growing[name]) {
            const g = Object.assign({}, growing);
            delete g[name];
            growing = g;
        }
        Shelf.addDrop(["file://" + encodeURI(path || dir + "/" + name)], "", false);
        finished = "";
        finished = name;
        finishedOff.restart();
    }

    // ---- sizes: the half-files and the growing ones, once a second while there are some ----
    function look() {
        if (sizes.running)
            return;
        const paths = halves.concat(Object.keys(growing)).map(n => dir + "/" + n);
        if (!paths.length) {
            merge([]);
            return;
        }
        sizes.command = ["stat", "-c", "%s\t%n"].concat(paths);
        sizes.running = true;
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.halves.length > 0 || Object.keys(root.growing).length > 0 || root.fromBrowser.length > 0
        // the bridge's file may come only now (a watch can't see a file that wasn't there)
        onTriggered: {
            if (!root.fromBrowser.length)
                bridge.reload();
            root.look();
        }
    }
    Process {
        id: sizes
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const tab = l.indexOf("\t");
                    return {
                        "path": l.slice(tab + 1),
                        "size": Number(l.slice(0, tab)) || 0
                    };
                });
                // a growing whole file: done once it stood still two looks (~2 s)
                const grow = Object.assign({}, root.growing);
                const out = [];
                for (const s of seen) {
                    const n = s.path.slice(root.dir.length + 1);
                    if (!grow[n]) {
                        out.push(s);
                        continue;
                    }
                    const g = grow[n];
                    const still = g.size === s.size && s.size > 0 ? g.still + 1 : 0;
                    if (still >= 2 && !root.browserHas(s.path)) {
                        delete grow[n];
                        root.done(n);
                        continue;
                    }
                    grow[n] = {
                        "size": s.size,
                        "still": still
                    };
                    // one that came whole at once is no download in progress yet
                    if (g.size >= 0 && s.size !== g.size)
                        out.push(s);
                    else if (root.active.some(d => d.path === s.path))
                        out.push(s);
                }
                root.growing = grow;
                root.merge(out);
            }
        }
    }

    // ---- the browsers: their extension's word on the sizes ----
    readonly property string bridgeFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/angelos-browser-downloads.json"
    property var fromBrowser: []        // [{file, received, total, paused}], fresh ones only
    FileView {
        id: bridge
        path: root.watching ? root.bridgeFile : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.readBridge()
        onLoadFailed: root.fromBrowser = []
    }
    function readBridge() {
        let d = null;
        try {
            d = JSON.parse(bridge.text());
        } catch (e) {}
        // a browser killed mid-download leaves its last word: older than 5 s is no word
        fromBrowser = d && Array.isArray(d.list) && Date.now() - (Number(d.at) || 0) < 5000 ? d.list.filter(x => x && x.file) : [];
        look();
    }
    Timer {
        interval: 2000
        repeat: true
        running: root.fromBrowser.length > 0
        onTriggered: root.readBridge()
    }
    function browserHas(path) {
        return fromBrowser.concat(told).some(b => b.file === path);
    }
    // [{file, received, total}]: services/VideoGrab's job, about once a second
    property var told: []
    onToldChanged: look()

    // the folder's and the browsers' together
    function merge(seen) {
        const before = active;
        const now = [];
        const used = new Set();
        const words = fromBrowser.concat(told);
        for (const s of seen) {
            const whole = s.path.replace(halfRe, "");
            const b = words.find(x => x.file === whole || x.file === s.path);
            if (b)
                used.add(b.file);
            now.push(entry(whole, b ? Math.max(s.size, Number(b.received) || 0) : s.size, b ? Number(b.total) || 0 : 0, b ? !!b.paused : false, before));
        }
        // a browser's download elsewhere (not in ~/Downloads)
        for (const b of words)
            if (!used.has(b.file))
                now.push(entry(b.file, Number(b.received) || 0, Number(b.total) || 0, !!b.paused, before));
        active = now;
    }
    function entry(path, size, total, paused, before) {
        const was = before.find(d => d.path === path);
        return {
            "path": path,
            "name": path.split("/").pop(),
            "size": size,
            "total": total,
            "paused": paused,
            // smoothed a little: one slow second doesn't drop it to nothing
            "speed": paused ? 0 : was ? Math.max(0, Math.round(was.speed * 0.4 + (size - was.size) * 0.6)) : 0
        };
    }

    Timer {
        id: finishedOff
        interval: 4000
        onTriggered: root.finished = ""
    }

    // the browsers get their extension once a session (quiet, nothing if it's there already);
    // `needRestart`: browsers open since before it, so without the percent until restarted
    property var browsers: []
    readonly property var needRestart: browsers.filter(b => b.restart).map(b => b.name)
    Process {
        id: wire
        command: ["python3", Quickshell.shellDir + "/scripts/browser-downloads.py", Config.halo.browserBridge ? "ensure" : "remove"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.browsers = JSON.parse(text) || [];
                } catch (e) {
                    root.browsers = [];
                }
            }
        }
    }
    function rewire() {
        if (watching && Quickshell.env("ANGELOS_TEST") !== "1")
            wire.running = true;
    }
    Component.onCompleted: rewire()
    Connections {
        target: Config.halo
        function onBrowserBridgeChanged() {
            root.rewire();
        }
    }

    // 12.4 MB, 830 KB
    function bytes(n) {
        const ru = !I18n.english;
        if (n >= 1e9)
            return (n / 1e9).toFixed(1) + (ru ? " ГБ" : " GB");
        if (n >= 1e6)
            return (n / 1e6).toFixed(1) + (ru ? " МБ" : " MB");
        return Math.round(n / 1e3) + (ru ? " КБ" : " KB");
    }
    // 45 с, 3 мин, 1 ч 5 мин
    function seconds(s) {
        const ru = !I18n.english;
        if (s < 60)
            return s + (ru ? " с" : " s");
        if (s < 3600)
            return Math.round(s / 60) + (ru ? " мин" : " min");
        return Math.floor(s / 3600) + (ru ? " ч " : " h ") + Math.round(s % 3600 / 60) + (ru ? " мин" : " min");
    }
}
