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
    property bool quiet: false               // our own "save into the folder": no new thumbnail for it
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
            // our own save of a copied shot: from now on it is that file
            if (root.quiet) {
                root.quiet = false;
                root.moved(root.path, p);
                return;
            }
            root.shown(p, CircleSearch.screenName || Niri.focusedOutput, false);
        }
    }
    // a shot saved (or only copied: temp) on that screen: its picture in the corner
    function shown(p, screen, isTemp) {
        // not while privacy on stream hides apps: the picture may have them in it
        if (!wanted || Privacy.hiddenNow.length)
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
    }
    // the work on a shot, kept (the editor writes it on every change)
    function keep(p, s) {
        const all = Object.assign({}, sessions);
        all[p] = s;
        // a handful of shots' work, the oldest goes
        const keys = Object.keys(all);
        if (keys.length > 12)
            delete all[keys[0]];
        sessions = all;
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
    function saveFile(file) {
        if (temp) {
            quiet = true;
            Capture.saveShot(file, null, {
                "copy": false
            });
            return;
        }
        saver.command = ["sh", "-c", 'cp -- "$1" "$2.part" && mv -f -- "$2.part" "$2"', "sh", file, path];
        saver.running = true;
    }
    Process {
        id: saver
        onExited: code => {
            if (code !== 0) {
                root.error = I18n.t("Не сохранилось", "Not saved");
                return;
            }
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
