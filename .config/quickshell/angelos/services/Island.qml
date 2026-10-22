pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../plugins/web-search/Engines.js" as Engines

// The mini island: a link opens in a small browser window of its own (scripts/island,
// qml6 + QtWebEngine: Chromium can't live in the shell, and a page that falls over takes
// only that window). niri places it (a rule: floating, bottom right, round corners), the
// shell moves it: to any edge (niri animates the way), full screen; clicks can go through it
// (Mod+Alt+I brings them back). It never leaves the screen: dragged past an edge, it comes back.
// Links come from Circle, the clipboard and notifications; a search (Island.search) and a
// search by picture (Island.lens) open their results here too — off, all goes to the browser.
Singleton {
    id: root

    readonly property bool running: proc.running
    property bool through: false
    // the screen's free part (no bars) per output, {l, t, r, b} in niri's floating coordinates:
    // the right and bottom from where niri's rule first puts it (24 px off the corner), the
    // size from a probe that the bars push aside (modules/island/IslandProbe)
    property var areas: ({})
    property var corner: ({})               // output → [r, b] seen on opening
    property size free: Qt.size(0, 0)       // the probe's size (modules/island/IslandProbe)
    readonly property bool probing: proc.running && output !== ""
    property int seq: 0
    property string first: ""               // the link it started with: to the browser if no window came
    property bool shown: false
    onWinChanged: if (win)
        shown = true
    readonly property string output: {
        const ws = win ? Niri.workspaceById(win.workspace_id) : null;
        return ws ? ws.output : "";
    }
    // where it is now: [x, y, w, h] (null in full screen)
    readonly property var box: win && win.layout && win.layout.tile_pos_in_workspace_view ? win.layout.tile_pos_in_workspace_view.concat(win.layout.tile_size) : null
    onBoxChanged: {
        if (!box || !output)
            return;
        if (!corner[output]) {
            const c = Object.assign({}, corner);
            c[output] = [box[0] + box[2] + 24, box[1] + box[3] + 24];
            corner = c;
        }
        keepIn.restart();
        keepSize.restart();
    }
    function area() {
        const sc = Shell.screenByName(output);
        const full = {
            "l": 0,
            "t": 0,
            "r": sc ? sc.width : 100000,
            "b": sc ? sc.height : 100000
        };
        const c = corner[output];
        if (!c || free.width <= 0 || free.height <= 0)
            return full;
        return {
            "l": c[0] - free.width,
            "t": c[1] - free.height,
            "r": c[0],
            "b": c[1]
        };
    }

    readonly property string cmdFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/angelos-island.json"
    readonly property var win: Niri.windows.find(w => w.title === (Shell.dev ? "angelOS · Остров [dev]" : "angelOS · Остров")) || null

    // "github.com/x" → "https://github.com/x"; mail and phones as their own schemes
    function normalize(u) {
        const s = String(u || "").trim();
        if (!s)
            return "";
        if (/^[a-z][\w+.-]*:/i.test(s))
            return s;
        if (/^[\w.+-]+@[\w-]+\.[\w.-]+$/.test(s))
            return "mailto:" + s;
        return "https://" + s;
    }
    function open(url) {
        const u = normalize(url);
        if (!u)
            return;
        // the island is for pages (and our own Lens page): mail, phones and the like go to their apps
        if (!Config.island.enabled || !(/^https?:/i.test(u) || u === "file://" + lensFile)) {
            Quickshell.execDetached(["xdg-open", u]);
            return;
        }
        if (proc.running) {
            send({
                "cmd": "open",
                "url": u
            });
            if (win)
                Niri.focusWindow(win.id);
            return;
        }
        through = false;
        shown = false;
        first = u;
        send({
            "cmd": "open",
            "url": u
        });
        const s = startSize();
        opened = s;
        fitted = false;
        proc.command = ["qml6", Quickshell.shellPath("scripts/island/Island.qml"), "--", u, cmdFile, String(s[0]), String(s[1])].concat(Shell.dev ? ["dev"] : [], ["shell-opens"]);
        proc.running = true;
    }
    // landscape, like a window: the portrait "phone" (460×720) confused people (20.10); the user's
    // own size once they resized it (Config.island.size); never more than the screen's free part
    property var opened: []
    property bool fitted: false             // niri gave it the size asked for (an older rule may not)
    function startSize() {
        const sc = Shell.screenByName(Niri.focusedOutput) || Shell.primaryScreen;
        const W = sc ? sc.width : 1920, H = sc ? sc.height : 1080;
        const s = Config.island.size || [];
        const w = s.length === 2 ? s[0] : 960, h = s.length === 2 ? s[1] : 640;
        return [Math.round(Math.max(360, Math.min(w, W * 0.9))), Math.round(Math.max(300, Math.min(h, H * 0.85)))];
    }
    // resized by hand: kept for the next time (moves and full screen don't change it)
    Timer {
        id: keepSize
        interval: 800
        onTriggered: {
            const b = root.box, o = root.opened;
            if (!b || o.length !== 2)
                return;
            // a size niri set itself (a rule of before) is no choice of the user's
            if (Math.abs(b[2] - o[0]) < 8 && Math.abs(b[3] - o[1]) < 8) {
                root.fitted = true;
                return;
            }
            if (!root.fitted)
                return;
            root.opened = [Math.round(b[2]), Math.round(b[3])];
            Config.island.size = root.opened;
        }
    }

    // the search engine's results for the words (Settings → Screenshots: Config.circle.engine)
    function searchUrl(text, engine) {
        const e = Engines.engines[engine || Config.circle.engine] || Engines.engines.google;
        return e.url.replace("%s", encodeURIComponent(String(text || "").trim().replace(/\s+/g, " ")));
    }
    function search(text) {
        if (String(text || "").trim())
            open(searchUrl(text));
    }
    // a picture to Google Lens: a page of ours posts it (the PNG inline), the results come back here
    readonly property string lensFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/angelos-island-lens.html"
    function lensPage(b64, ts, mime) {
        return '<!doctype html><meta charset="utf-8"><title>Google Lens…</title>' + '<body style="background:#16141c;color:#d8d0ea;font:16px sans-serif;display:grid;place-items:center;height:100vh;margin:0">' + '<form id="f" method="post" enctype="multipart/form-data" action="https://lens.google.com/v3/upload?ep=ccm&amp;hl=' + Qt.locale().name.split("_")[0] + '&amp;st=' + ts + '">' + '<input type="file" name="encoded_image" id="i" hidden></form><p>Google Lens…</p><script>' + 'const b = atob("' + b64 + '"), a = new Uint8Array(b.length);' + 'for (let k = 0; k < b.length; k++) a[k] = b.charCodeAt(k);' + 'const dt = new DataTransfer(); dt.items.add(new File([a], "circle.png", {type: "' + mime + '"}));' + 'document.getElementById("i").files = dt.files; document.getElementById("f").submit();</script>';
    }
    // a picture asked for while the last one is still read goes next (it was dropped); nothing to
    // send is said, not silent
    property string lensNext: ""
    function lens(png) {
        if (!png) {
            lensFailed();
            return;
        }
        // the results in angelOS's own window (services/LensSearch); off: Google's page here
        if (Config.circle.lensWindow) {
            LensSearch.search(png);
            return;
        }
        if (lensReader.running) {
            lensNext = png;
            return;
        }
        lensReader.png = png;
        lensReader.command = ["base64", "-w0", png];
        lensReader.running = true;
    }
    function lensFailed() {
        Quickshell.execDetached(["notify-send", "-a", "angelOS", "-i", "dialog-warning", "-t", "5000", I18n.t("Поиск по картинке не открылся", "Search by picture didn't open"), I18n.t("Снимок не сохранился — попробуйте ещё раз", "The shot wasn't saved — try again")]);
    }
    Process {
        id: lensReader
        property string png: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (!/^[A-Za-z0-9+\/=]+$/.test(text)) {
                    root.lensFailed();
                    return;
                }
                // Settings → Screenshots may keep JPEGs (capture.shotFormat)
                lensOut.setText(root.lensPage(text, Date.now(), /\.jpe?g$/i.test(lensReader.png) ? "image/jpeg" : "image/png"));
                root.open("file://" + root.lensFile);
            }
        }
        onExited: {
            if (!root.lensNext)
                return;
            const next = root.lensNext;
            root.lensNext = "";
            Qt.callLater(root.lens, next);
        }
    }
    FileView {
        id: lensOut
        path: root.lensFile
        blockWrites: true       // on disk before the island is told to load it
        blockLoading: false
        printErrors: false
    }

    // the island's ↗: its page now to the default browser (never back into the island)
    function toBrowser(url) {
        const u = String(url || "");
        if (/^https?:/i.test(u) || u === "file://" + lensFile)
            Quickshell.execDetached(["xdg-open", u]);
    }
    function close() {
        send({
            "cmd": "quit"
        });
    }
    function send(c) {
        seq++;
        c.seq = seq;
        cmd.setText(JSON.stringify(c));
    }

    // to an edge, whole: the other way it stays where it is
    function tuck(side) {
        if (!win || !box)
            return;
        const a = area(), m = 16;
        const x = side === "left" ? a.l + m : side === "right" ? a.r - box[2] - m : box[0];
        const y = side === "top" ? a.t + m : side === "bottom" ? a.b - box[3] - m : box[1];
        move(Math.max(a.l, Math.min(x, a.r - box[2])), Math.max(a.t, Math.min(y, a.b - box[3])));
    }
    // dragged past an edge: back onto the screen (once the drag has settled)
    Timer {
        id: keepIn
        interval: 350
        onTriggered: {
            if (!root.win || !root.box)
                return;
            const a = root.area(), bx = root.box;
            const x = Math.max(a.l, Math.min(bx[0], a.r - bx[2]));
            const y = Math.max(a.t, Math.min(bx[1], a.b - bx[3]));
            if (Math.abs(x - bx[0]) > 0.5 || Math.abs(y - bx[1]) > 0.5)
                root.move(x, y);
        }
    }
    function move(x, y) {
        Niri.action("MoveFloatingWindow", {
            "id": win.id,
            "x": x === null ? {
                "AdjustFixed": 0
            } : {
                "SetFixed": x
            },
            "y": y === null ? {
                "AdjustFixed": 0
            } : {
                "SetFixed": y
            }
        });
    }
    function fullscreen() {
        if (!win)
            return;
        Niri.action("FullscreenWindow", {
            "id": win.id
        });
    }
    function setThrough(on) {
        if (!proc.running)
            return;
        through = on;
        send({
            "cmd": "through",
            "on": on
        });
        Quickshell.execDetached(["notify-send", "-a", "angelOS", "-t", "2500", "-i", "web-browser", on ? I18n.t("Остров пропускает клики", "The island lets clicks through") : I18n.t("Остров снова кликается", "The island takes clicks again"), on ? I18n.t("Вернуть: Mod+Alt+I", "Back: Mod+Alt+I") : ""]);
    }

    FileView {
        id: cmd
        path: root.cmdFile
        blockLoading: false
        printErrors: false
    }

    Process {
        id: proc
        environment: ({
                "QML_XHR_ALLOW_FILE_READ": "1",
                "QT_FORCE_STDERR_LOGGING": "1"
            })
        stderr: SplitParser {
            onRead: line => {
                const i = line.indexOf("ISLAND {");
                if (i < 0)
                    return;
                let ev;
                try {
                    ev = JSON.parse(line.slice(i + 7));
                } catch (e) {
                    return;
                }
                if (ev.ev === "tuck")
                    root.tuck(ev.side);
                else if (ev.ev === "fullscreen")
                    root.fullscreen();
                else if (ev.ev === "through")
                    root.setThrough(!root.through);
                else if (ev.ev === "browser")
                    root.toBrowser(ev.url);
            }
        }
        onExited: {
            // no qml6 or no QtWebEngine: the link still opens
            if (!root.shown)
                Quickshell.execDetached(["xdg-open", root.first]);
            root.through = false;
        }
    }

}
