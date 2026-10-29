pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../widgets/Place.js" as Place

// A screenshot just saved or copied, as phones keep it (modules/capture/ShotPreview): its picture
// waits a few seconds in the corner of the screen it was taken on — a click opens the editor, a
// drag takes the file out, a right click sends it away. The editor (modules/capture/ShotEditor)
// is a window of its own, ShareX / Flameshot-like: pen, marker, arrows, boxes, numbers, text,
// stickers, hidden parts, a Telegram-like crop; its recent shots down the side. Drawings stay
// shapes until the picture is copied or saved; crop / turn / flip / hide are steps of
// scripts/shot_edit.py, each a file of its own in the runtime dir. Each shot's work (its picture,
// its shapes, its undo) is kept here while the shell runs: closed and opened again, it is all there.
// Settings → Screenshots → «Миниатюра в углу» (capture.shotPreview); the Halo's own thumbnail
// stays for when it is off.
Singleton {
    id: root

    property string path: ""                 // the shot in the corner / in the editor
    property string screenName: ""
    property bool temp: false                // only copied: the PNG is ours (shotsDir), not in the folders
    property bool thumb: false               // the corner's picture is up
    property string at: "bottom-right"       // where it is (widgets/Place.js names): capture.shotPreviewAt, or a free place
    property bool editing: false             // the editor's window is open
    property var sessions: ({})              // path → {base, items, undo, redo, temp}: the work on each shot
    property var recentShots: []             // newest first: the folder's and the copied ones
    property string error: ""
    readonly property bool wanted: Config.capture.shotPreview !== false
    readonly property string shotsDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/angelos/shots"
    readonly property string dir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/angelos/shot-edit"
    readonly property string script: Quickshell.shellPath("scripts/shot_edit.py")
    readonly property string folder: (Config.capture.shotDir || "~/Pictures/Screenshots").replace(/^~/, Quickshell.env("HOME"))
    // a new picture in the editor's window (the editor loads its session)
    signal opened(string path)
    property int made: 0
    property bool wantNewest: false

    // the last shell's steps are gone with it
    Component.onCompleted: Quickshell.execDetached(["sh", "-c", 'rm -rf -- "$1" && mkdir -p -- "$1" "$2"', "sh", dir, shotsDir])

    Connections {
        target: Capture
        function onShotSaved(p) {
            // (Ctrl+Shift+C: the overlay stays for the next piece, no picture over it)
            if (!CircleHost.open)
                root.shown(p, CircleHost.screenName || Niri.focusedOutput, false);
        }
    }
    // a shot saved (or only copied: temp) on that screen: its picture in the corner
    function shown(p, screen, isTemp) {
        // privacy on stream too: the owner wants the picture always (19.10)
        if (!wanted)
            return;
        // copied shots of an hour ago go (the runtime dir is memory)
        if (isTemp)
            Quickshell.execDetached(["find", shotsDir, "-maxdepth", "1", "-name", "shot-*.png", "-mmin", "+60", "-delete"]);
        path = p;
        temp = !!isTemp;
        screenName = screen || "";
        at = placeOn(screenName);
        thumb = false;
        thumb = true;
    }
    // where the picture goes: the place picked in Settings, or ("auto") the first of the corners
    // and sides that the angel, the desktop widgets and the notifications' corner leave free
    // (it sat on the angel in the bottom-right corner); all taken: the least covered one
    function placeOn(name) {
        const pick = Config.capture.shotPreviewAt || "auto";
        const sc = Shell.screenByName(name);
        if (pick !== "auto" || !sc)
            return pick === "auto" ? "bottom-right" : pick;
        const W = sc.width, H = sc.height, u = Theme.u, tw = u * 104, th = u * 84, m = u * 10, busy = [];
        // the window keeps clear of the bar by itself: the places are measured inside it
        const bar = Theme.barHeight, e = BarLayout.edge;
        const t = e === "top" ? bar : 0, b = e === "bottom" ? bar : 0, l = e === "left" ? bar : 0, r = e === "right" ? bar : 0;
        // the angel in her corner (her sprite up to half the screen high)
        if (Angel.present && Angel.screenName === name)
            busy.push(Angel.streamer && Config.stream.streamerSide === "left" ? [0, H * 0.45, u * 190, H * 0.55] : [W - u * 190, H * 0.45, u * 190, H * 0.55]);
        const faces = DesktopWidgets.faces;
        for (const w of DesktopWidgets.widgets) {
            const f = faces[w.uid];
            if (f && DesktopWidgets.screenOf(w) === name && f.width > 0)
                busy.push([f.x, f.y, f.width, f.height]);
        }
        const notifs = Config.notifications.position || "top-right";
        const box = p => [Place.left(p) ? l + m : Place.right(p) ? W - r - tw - m : (W - tw) / 2, Place.top(p) ? t + m : Place.bottom(p) ? H - b - th - m : (H - th) / 2, tw, th];
        const overlap = (a, b) => Math.max(0, Math.min(a[0] + a[2], b[0] + b[2]) - Math.max(a[0], b[0])) * Math.max(0, Math.min(a[1] + a[3], b[1] + b[3]) - Math.max(a[1], b[1]));
        let best = "bottom-right", bestArea = Infinity;
        for (const p of ["bottom-right", "bottom-left", "top-right", "top-left", "right", "left", "bottom-center", "top-center"]) {
            const r = box(p), area = busy.reduce((s, b) => s + overlap(r, b), 0) + (p === notifs ? tw * th : 0);
            if (area < bestArea) {
                bestArea = area;
                best = p;
            }
        }
        return best;
    }
    function dismiss() {
        thumb = false;
    }
    // the editor on a shot (none: the last one, else the newest in the folder); its window comes
    // up, or the open one takes it
    function edit(p) {
        Achievements.note("explore", "shotedit");
        if (p) {
            path = p;
            temp = p.indexOf(shotsDir + "/") === 0;
        }
        if (!path) {
            // no shot yet this time: the newest one, once the folder is looked through
            wantNewest = true;
            loadRecent();
            return;
        }
        thumb = false;
        error = "";
        editing = true;
        loadRecent();
        opened(path);
    }
    function close() {
        editing = false;
        sweep();
    }
    // the work on a shot, kept (the editor writes it on every change)
    function keep(p, s) {
        const all = Object.assign({}, sessions);
        // the one at work is the newest: it never goes as "the oldest" under the editor
        delete all[p];
        all[p] = s;
        for (const f of filesOf(s))
            owned[f] = true;
        // a handful of shots' work, the oldest goes
        const keys = Object.keys(all);
        if (keys.length > 12)
            delete all[keys[0]];
        sessions = all;
        if (keys.length > 12)
            sweep();
    }
    // the step files a session holds (its picture, its undo and redo); only ours, never the shot
    function filesOf(s) {
        return [s.base].concat((s.undo || []).map(u => u.base), (s.redo || []).map(u => u.base)).filter(f => f && f.indexOf(dir + "/") === 0);
    }
    // step files that were a session's and are no one's now (a shot's work gone, an undo past
    // its 80, a redo cut off) leave the runtime dir: it is memory, and they piled up
    property var owned: ({})                 // file → true: every step file a session held
    function sweep() {
        const used = {};
        for (const k in sessions)
            for (const f of filesOf(sessions[k]))
                used[f] = true;
        const gone = Object.keys(owned).filter(f => !used[f]);
        for (const f of gone)
            delete owned[f];
        if (gone.length)
            Quickshell.execDetached(["rm", "-f", "--"].concat(gone));
    }
    // a copied shot saved into the folder: its work goes with it
    function moved(from, to) {
        const s = sessions[from];
        const all = Object.assign({}, sessions);
        delete all[from];
        if (s)
            all[to] = s;
        sessions = all;
        if (path === from) {
            path = to;
            temp = false;
        }
        loadRecent();
    }
    function newFile() {
        made++;
        return dir + "/" + Date.now() + "-" + made + ".png";
    }
    // a picture under the shot's own name (<dir>/share-N/<name>.png): done(its path); for Quick
    // Share, which sends the file's name along
    function named(file, done) {
        made++;
        const to = dir + "/share-" + made + "/" + (path.split("/").pop().replace(/\.[^.]*$/, "") || "shot") + ".png";
        const p = namer.createObject(root, {
            "to": to,
            "done": done,
            "command": ["sh", "-c", 'mkdir -p -- "${2%/*}" && cp -- "$1" "$2"', "sh", file, to]
        });
        p.running = true;
    }
    Component {
        id: namer
        Process {
            id: nm
            property string to
            property var done
            onExited: code => {
                if (code === 0)
                    nm.done(nm.to);
                else
                    root.error = I18n.t("Не получилось", "Did not work");
                Qt.callLater(nm.destroy);
            }
        }
    }
    // one step of scripts/shot_edit.py on a picture: done(file of the result) or done("") on failure
    function run(src, op, arg, done) {
        const out = newFile();
        const p = stepper.createObject(root, {
            "out": out,
            "done": done,
            "command": ["sh", "-c", 'mkdir -p "$1" && shift && exec python3 "$@"', "sh", dir, script, src, out, op, arg]
        });
        p.running = true;
    }
    Component {
        id: stepper
        Process {
            id: st
            property string out
            property var done
            stdout: StdioCollector {
                onStreamFinished: {
                    let ok = false;
                    try {
                        const j = JSON.parse(text);
                        ok = !j.error;
                        if (j.error)
                            root.error = j.error;
                    } catch (e) {
                        root.error = I18n.t("Не получилось", "Did not work");
                    }
                    st.done(ok ? st.out : "");
                    Qt.callLater(st.destroy);
                }
            }
        }
    }
    // the finished picture on the clipboard
    function copyFile(file) {
        Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png < "$1"', "sh", file]);
        say(I18n.t("Картинка скопирована", "Picture copied"));
    }
    // the finished picture kept: over the shot, or a copied one into the folder (as a new screenshot)
    // silent: no notification of its own (the editor's Copy saves its changes too, and says "copied")
    function saveFile(file, silent) {
        if (temp) {
            // our own save of a copied shot: no new thumbnail for it, and from now on it is that
            // file — told by its own answer (a flag waiting for the next shotSaved stuck when the
            // save failed, and took the next real screenshot for this one)
            const from = path;
            Capture.saveShot(file, null, {
                "copy": false,
                "quiet": !!silent,
                "noThumb": true
            }, r => {
                if (r.path)
                    root.moved(from, r.path);
            });
            return;
        }
        saver.silent = !!silent;
        saver.command = ["sh", "-c", 'cp -- "$1" "$2.part" && mv -f -- "$2.part" "$2"', "sh", file, path];
        saver.running = true;
    }
    Process {
        id: saver
        property bool silent: false
        onExited: code => {
            if (code !== 0) {
                root.error = I18n.t("Не сохранилось", "Not saved");
                return;
            }
            if (!saver.silent)
                root.say(I18n.t("Снимок сохранён", "Screenshot saved"));
            root.loadRecent();
        }
    }
    function loadRecent() {
        if (!lister.running) {
            lister.command = ["python3", script, "recent", folder, shotsDir];
            lister.running = true;
        }
    }
    Process {
        id: lister
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.recentShots = JSON.parse(text);
                } catch (e) {}
                if (root.wantNewest) {
                    root.wantNewest = false;
                    if (root.recentShots.length)
                        root.edit(root.recentShots[0]);
                }
            }
        }
    }
    function say(t) {
        Quickshell.execDetached(["notify-send", "-a", "angelOS", "-i", "image-x-generic", "-h", "string:x-canonical-private-synchronous:angelos-shot-edit", "--", t, path.split("/").pop()]);
    }
}
