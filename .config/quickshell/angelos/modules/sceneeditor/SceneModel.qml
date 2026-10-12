pragma ComponentBehavior: Bound


import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// The scene editor's state and its talk with the server (scene-editor.py, started here with
// --no-open): one picture at a time — its painted layers (one cell = one art pixel of
// live-wall.py's mask), effects, event places, rings, and the requests to Claude. Everything
// is saved through PUT /api/scene (scene_core.save: history, the change log, the shell told
// to look again); a change made elsewhere (Claude over MCP) is picked up by asking /api/state.
Item {
    id: ed
    visible: false

    // false: the server is stopped (the window is closed)
    property bool running: false
    property string url: ""             // the server's address once it has said it
    property var meta: null             // {first, layers: [{id, key, name, what, rgb}], effects, points}
    property var pics: []               // [{path, where, scene}]
    property string pic: ""
    property int gw: 0                  // the grid: one cell an art pixel
    property int gh: 0
    property var paint: null            // Int8Array, -1 = as found
    property var found: null            // Int8Array: what a look finds by itself
    property var scene: ({})            // the scene file without its paint
    property var places: ({})           // rims / eyes / ponds a look found
    property var info: ({})
    property string mtime: "0"
    property int rev: 0                 // the scene's values and marks changed
    property int paintRev: 0            // the whole grid changed
    signal rowsChanged(int y0, int y1)  // these rows of the grid changed
    signal flashed                      // Claude changed the scene

    property string tool: "brush"       // brush | rect | lasso | fill | pick | points | ring | region
    property int inLayer: 1             // the layer painted with; -1: back to what was found
    property string view: "final"       // final | found | paint | picture
    property real overlay: 0.55
    property real zoom: 1
    property int brush: 6
    property int tolerance: 8
    property int ringT: 8
    property string pointKind: "eyes"
    property var regions: []            // [{rect: [x0, y0, x1, y1]}] for a request
    property var undoStack: []
    property var redoStack: []
    property bool dirty: false
    property bool saving: false
    property bool autosave: true
    property string lastWhat: ""
    property string saveState: ""
    property string status: ""
    property string banner: ""          // someone else changed the scene under unsaved changes
    property var requests: []
    property string reqMtime: ""
    property bool busy: false           // a picture is being looked at
    readonly property int openRequests: requests.filter(q => q.status !== "done").length

    onRunningChanged: if (!running) {
        url = "";
        wantFirst = false;
        pic = "";
        gw = 0;
        gh = 0;
        paint = null;
        found = null;
        undoStack = [];
        redoStack = [];
        dirty = false;
        banner = "";
        paintRev++;
    }

    Process {
        id: server
        running: ed.running
        command: ["python3", SceneEditor.dir + "/scene-editor.py", "--no-open", "--stay", "--port", "0"]
        stdout: SplitParser {
            onRead: line => {
                if (ed.url === "" && line.startsWith("http")) {
                    ed.url = line.split("#")[0];
                    ed.boot();
                }
            }
        }
        onExited: if (ed.running && ed.url === "")
            ed.status = I18n.t("✕ сервер редактора не запустился (python3, numpy, Pillow?)", "✕ the editor's server did not start (python3, numpy, Pillow?)")
    }

    function api(method, path, body, done) {
        if (!url)
            return;
        const x = new XMLHttpRequest();
        const base = url;
        x.open(method, base + path);
        x.setRequestHeader("Content-Type", "application/json");
        x.onreadystatechange = () => {
            // (the window may be gone by the time the answer comes)
            if (x.readyState !== XMLHttpRequest.DONE || !ed || base !== ed.url)
                return;
            let j = {};
            try {
                j = JSON.parse(x.responseText);
            } catch (e) {}
            if (done)
                done(x.status, j || {});
        };
        x.send(body === undefined || body === null ? undefined : JSON.stringify(body));
    }
    function q(path) {
        return encodeURIComponent(path);
    }
    function pictureUrl(path, w) {
        return url && path ? url + "api/picture?pic=" + q(path) + (w ? "&w=" + w : "") : "";
    }

    // ---- start-up ----
    function boot() {
        api("GET", "api/meta", null, (code, j) => {
            if (code !== 200)
                return;
            meta = j;
            loadList();
            refreshRequests();
            const want = SceneEditor.picture || onScreen() || j.first || "";
            if (want)
                openPic(want);
            else
                wantFirst = true;
        });
    }
    // nothing asked for and nothing on a screen: the first of the list (what the settings show)
    property bool wantFirst: false
    // the picture of the focused screen (its own file, not a pixel copy of it)
    function onScreen() {
        const scr = Shell.focusedScreen ? Shell.focusedScreen.name : "";
        if (!scr)
            return "";
        const ws = Niri.activeWorkspace(scr);
        return Wallpapers.pick(Wallpapers.raw(scr, ws ? ws.idx : 1), scr);
    }
    function loadList() {
        api("GET", "api/list", null, (code, j) => {
            if (code !== 200)
                return;
            pics = j.pictures || [];
            if (wantFirst && !pic && !busy && pics.length)
                openPic(pics[0].path);
            wantFirst = false;
        });
    }

    // ---- one picture ----
    function openPic(path) {
        if (!url || !path)
            return;
        if (dirty && pic && pic !== path)
            save();
        busy = true;
        status = I18n.t("смотрю на картинку…", "looking at the picture…");
        api("GET", "api/scene?fmt=rle&pic=" + q(path), null, (code, j) => {
            busy = false;
            if (code !== 200) {
                status = "✕ " + (j.error || code);
                return;
            }
            pic = j.picture;
            undoStack = [];
            redoStack = [];
            regions = [];
            applyScene(j);
            status = "";
        });
    }
    function unrle(runs, n) {
        const a = new Int8Array(n);
        let i = 0;
        for (let k = 0; k + 1 < runs.length; k += 2) {
            const v = runs[k], c = runs[k + 1];
            if (v !== 0)
                a.fill(v, i, i + c);
            i += c;
        }
        return a;
    }
    function rle(a) {
        const out = [];
        let v = a[0], c = 0;
        for (let i = 0; i < a.length; i++) {
            if (a[i] === v) {
                c++;
            } else {
                out.push(v, c);
                v = a[i];
                c = 1;
            }
        }
        if (c)
            out.push(v, c);
        return out;
    }
    function applyScene(j) {
        gw = j.grid[0];
        gh = j.grid[1];
        paint = unrle(j.paint, gw * gh);
        found = unrle(j.auto, gw * gh);
        scene = j.scene || {};
        places = j.found || {};
        info = j.info || {};
        mtime = j.mtime;
        dirty = false;
        saveState = "";
        banner = "";
        rev++;
        paintRev++;
    }

    // ---- editing ----
    function snapshot() {
        const u = undoStack;
        u.push({
            "paint": paint.slice(),
            "scene": JSON.parse(JSON.stringify(scene))
        });
        if (u.length > 30)
            u.shift();
        undoStack = u;
        redoStack = [];
    }
    function restore(back) {
        const from = back ? undoStack : redoStack, to = back ? redoStack : undoStack;
        const st = from.pop();
        if (!st)
            return;
        to.push({
            "paint": paint.slice(),
            "scene": JSON.parse(JSON.stringify(scene))
        });
        undoStack = undoStack;
        redoStack = redoStack;
        paint = st.paint;
        scene = st.scene;
        paintRev++;
        changed(back ? I18n.t("шаг назад", "a step back") : I18n.t("шаг вперёд", "a step forward"));
    }
    function changed(what) {
        dirty = true;
        lastWhat = what || I18n.t("правка в редакторе", "an edit in the editor");
        saveState = I18n.t("не сохранено", "not saved");
        rev++;
        if (autosave)
            saveTimer.restart();
    }
    Timer {
        id: saveTimer
        interval: 1100
        onTriggered: ed.save()
    }
    function setScene(key, value) {
        const s = Object.assign({}, scene);
        if (value === undefined || value === null)
            delete s[key];
        else
            s[key] = value;
        scene = s;
    }
    function cell(x, y) {
        return [Math.min(gw - 1, Math.max(0, Math.floor(x * gw))), Math.min(gh - 1, Math.max(0, Math.floor(y * gh)))];
    }
    function layerAt(x, y) {
        const c = cell(x, y), k = c[1] * gw + c[0];
        return paint[k] >= 0 ? paint[k] : found[k];
    }
    function stamp(x, y, r) {
        const c = cell(x, y), cx = c[0], cy = c[1];
        const rr = Math.max(0.5, r), v = inLayer, W = gw, H = gh, P = paint;
        const j0 = Math.max(0, Math.floor(cy - rr)), j1 = Math.min(H - 1, Math.ceil(cy + rr));
        const i0 = Math.max(0, Math.floor(cx - rr)), i1 = Math.min(W - 1, Math.ceil(cx + rr));
        for (let j = j0; j <= j1; j++)
            for (let i = i0; i <= i1; i++)
                if ((i - cx) * (i - cx) + (j - cy) * (j - cy) <= rr * rr)
                    P[j * W + i] = v;
        return [j0, j1];
    }
    function strokeTo(a, b, r) {
        const steps = Math.max(1, Math.ceil(Math.hypot((b[0] - a[0]) * gw, (b[1] - a[1]) * gh) / Math.max(1, r / 2)));
        let y0 = gh, y1 = -1;
        for (let k = 0; k <= steps; k++) {
            const rows = stamp(a[0] + (b[0] - a[0]) * k / steps, a[1] + (b[1] - a[1]) * k / steps, r);
            y0 = Math.min(y0, rows[0]);
            y1 = Math.max(y1, rows[1]);
        }
        rowsChanged(y0, y1);
    }
    function fillRect(rc) {
        const a = cell(Math.min(rc[0], rc[2]), Math.min(rc[1], rc[3])), b = cell(Math.max(rc[0], rc[2]), Math.max(rc[1], rc[3]));
        for (let j = a[1]; j <= b[1]; j++)
            paint.fill(inLayer, j * gw + a[0], j * gw + b[0] + 1);
        rowsChanged(a[1], b[1]);
    }
    function fillPoly(pts) {
        const P = pts.map(p => [p[0] * gw, p[1] * gh]);
        for (let j = 0; j < gh; j++) {
            const yy = j + 0.5, xs = [];
            for (let k = 0; k < P.length; k++) {
                const x1 = P[k][0], y1 = P[k][1], x2 = P[(k + 1) % P.length][0], y2 = P[(k + 1) % P.length][1];
                if ((y1 <= yy && y2 > yy) || (y2 <= yy && y1 > yy))
                    xs.push(x1 + (yy - y1) / (y2 - y1) * (x2 - x1));
            }
            xs.sort((a, b) => a - b);
            for (let k = 0; k + 1 < xs.length; k += 2) {
                const i0 = Math.max(0, Math.ceil(xs[k] - 0.5)), i1 = Math.min(gw - 1, Math.floor(xs[k + 1] - 0.5));
                if (i1 >= i0)
                    paint.fill(inLayer, j * gw + i0, j * gw + i1 + 1);
            }
        }
        rowsChanged(0, gh - 1);
    }
    // alike colour touching the cell: the server looks at the picture (numpy), the cells come back
    function flood(x, y) {
        const forPic = pic, v = inLayer;
        status = I18n.t("заливаю…", "filling…");
        api("GET", "api/flood?pic=" + q(pic) + "&x=" + x.toFixed(4) + "&y=" + y.toFixed(4) + "&tol=" + (tolerance / 100).toFixed(2), null, (code, j) => {
            if (code !== 200 || forPic !== pic) {
                status = code !== 200 ? "✕ " + (j.error || code) : "";
                return;
            }
            snapshot();
            for (const r of j.runs || [])
                paint.fill(v, r[0] * gw + r[1], r[0] * gw + r[2] + 1);
            status = I18n.t("залито клеток: ", "cells filled: ") + (j.n || 0);
            rowsChanged(0, gh - 1);
            changed(I18n.t("заливка", "a fill"));
        });
    }
    function foundToLayer(from) {
        snapshot();
        let n = 0;
        const P = paint, A = found;
        for (let i = 0; i < P.length; i++)
            if (A[i] === from) {
                P[i] = inLayer;
                n++;
            }
        paintRev++;
        changed(I18n.t("найденное → слой", "what was found → a layer"));
        status = I18n.t("перекрашено клеток: ", "cells repainted: ") + n;
    }
    function clearPaint() {
        snapshot();
        paint.fill(-1);
        paintRev++;
        changed(I18n.t("рисунок стёрт", "the painting wiped"));
    }
    function addPoint(p) {
        snapshot();
        const list = Array.isArray(scene[pointKind]) ? scene[pointKind].slice() : [];
        list.push([+p[0].toFixed(4), +p[1].toFixed(4)]);
        setScene(pointKind, list);
        changed(I18n.t("место: ", "a place: ") + pointKind);
    }
    function nearest(list, p) {
        let best = -1, bd = 1e9;
        (list || []).forEach((c, i) => {
            const d = Math.hypot(c[0] - p[0], (c[1] - p[1]) * gh / gw);
            if (d < bd) {
                bd = d;
                best = i;
            }
        });
        return bd < 0.03 ? best : -1;
    }
    // a right click: the nearest own point of the chosen kind, a ring, a request's region goes
    function removeAt(p) {
        if (tool === "ring") {
            const rings = (scene.rings || []).slice();
            const i = nearest(rings.map(r => [r[0], r[1]]), p);
            if (i >= 0) {
                snapshot();
                rings.splice(i, 1);
                setScene("rings", rings.length ? rings : undefined);
                changed(I18n.t("кольцо убрано", "a ring removed"));
            }
        } else if (tool === "points") {
            if (!Array.isArray(scene[pointKind]))
                return;
            const list = scene[pointKind].slice();
            const i = nearest(list, p);
            if (i >= 0) {
                snapshot();
                list.splice(i, 1);
                setScene(pointKind, list);
                changed(I18n.t("место убрано", "a place removed"));
            }
        } else if (tool === "region") {
            const i = regions.findIndex(r => p[0] >= r.rect[0] && p[0] <= r.rect[2] && p[1] >= r.rect[1] && p[1] <= r.rect[3]);
            if (i >= 0) {
                const r = regions.slice();
                r.splice(i, 1);
                regions = r;
            }
        }
    }
    function addRing(cx, cy, rx, ry) {
        snapshot();
        setScene("rings", (scene.rings || []).concat([[cx, cy, rx, ry, ringT / 100].map(v => +v.toFixed(4))]));
        changed(I18n.t("кольцо", "a ring"));
    }
    function addRegion(rc) {
        regions = regions.concat([{
                "rect": [Math.min(rc[0], rc[2]), Math.min(rc[1], rc[3]), Math.max(rc[0], rc[2]), Math.max(rc[1], rc[3])].map(v => +v.toFixed(4))
            }]);
    }
    function setEffect(key, on) {
        snapshot();
        const fx = Object.assign({}, scene.effects || {});
        if (on)
            delete fx[key];
        else
            fx[key] = false;
        setScene("effects", Object.keys(fx).length ? fx : undefined);
        changed(I18n.t("эффекты", "the effects"));
    }
    function setValue(key, value, what) {
        snapshot();
        setScene(key, value);
        changed(what);
    }

    // ---- saving, and changes from elsewhere ----
    function save(force, then) {
        if (!pic || !dirty || saving) {
            if (then)
                then();
            return;
        }
        saveTimer.stop();
        saving = true;
        saveState = I18n.t("сохраняю…", "saving…");
        const body = {
            "base": force ? null : mtime,
            "force": !!force,
            "what": lastWhat,
            "paintRle": rle(paint)
        };
        for (const k of ["effects", "rings", "night", "axis", "mirror", "rims", "eyes", "ponds", "lights"])
            body[k] = scene[k] === undefined ? null : scene[k];
        const forPic = pic;
        api("PUT", "api/scene?pic=" + q(pic), body, (code, j) => {
            saving = false;
            if (code === 409) {
                banner = (j.who === "claude" ? "Claude" : j.who || "?") + I18n.t(" только что поменял сцену, а у тебя несохранённые правки.", " has just changed the scene, and you have unsaved changes.");
                saveState = I18n.t("конфликт", "a conflict");
            } else if (code === 200) {
                if (forPic === pic) {
                    mtime = j.mtime;
                    dirty = false;
                    saveState = I18n.t("сохранено ✓ — рабочий стол подхватит", "saved ✓: the desktop takes it");
                }
                const p = pics.find(x => x.path === forPic);
                if (p && !p.scene)
                    pics = pics.map(x => x.path === forPic ? Object.assign({}, x, {
                            "scene": true
                        }) : x);
            } else {
                saveState = "✕ " + (j.error || code);
            }
            if (then)
                then();
        });
    }
    function reload(why) {
        banner = "";
        const forPic = pic;
        api("GET", "api/scene?fmt=rle&pic=" + q(pic), null, (code, j) => {
            if (code !== 200 || forPic !== pic)
                return;
            applyScene(j);
            if (why)
                status = why;
        });
    }
    function revertFile() {
        if (!pic)
            return;
        api("POST", "api/undo?pic=" + q(pic), null, () => reload(I18n.t("откатил файл", "the file is back")));
    }
    Timer {
        interval: 1500
        running: ed.url !== ""
        repeat: true
        onTriggered: ed.poll()
    }
    function poll() {
        api("GET", "api/state?pic=" + q(pic || ""), null, (code, st) => {
            if (code !== 200)
                return;
            if (pic && st.mtime !== mtime && !saving) {
                const who = st.last && st.last.picture === pic ? st.last.who : "?";
                if (!dirty) {
                    reload(who === "claude" ? "✦ " + I18n.t("Claude поменял сцену: ", "Claude changed the scene: ") + (st.last.what || "") : I18n.t("сцена изменилась снаружи — загрузил", "the scene changed outside: loaded"));
                    if (who === "claude")
                        flashed();
                } else if (!banner) {
                    banner = (who === "claude" ? "Claude" : I18n.t("Кто-то", "Someone")) + I18n.t(" поменял эту сцену, а у тебя несохранённые правки.", " changed this scene, and you have unsaved changes.");
                }
            }
            if (st.requests !== reqMtime) {
                reqMtime = st.requests;
                refreshRequests();
            }
        });
    }

    // ---- Claude ----
    function sendRequest(note, done) {
        note = (note || "").trim();
        if (!pic)
            return;
        if (!note && !regions.length) {
            status = I18n.t("напиши, что сделать, или обведи место", "write what to do, or mark a place");
            return;
        }
        save(false, () => api("POST", "api/requests", {
                "pic": pic,
                "note": note,
                "regions": regions
            }, code => {
                if (code !== 200)
                    return;
                regions = [];
                status = I18n.t("✓ отдано Claude — скажи ему в терминале «посмотри запросы сцены» (или он увидит их сам через MCP)", "✓ handed to Claude: tell it in the terminal to look at the scene requests (or it sees them itself over MCP)");
                refreshRequests();
                if (done)
                    done();
            }));
    }
    function refreshRequests() {
        api("GET", "api/requests", null, (code, j) => {
            if (code === 200)
                requests = (j.requests || []).slice(0, 20);
        });
    }
    function closeRequest(id) {
        api("POST", "api/requests/" + id, {
            "status": "done"
        }, () => refreshRequests());
    }
    function openRequest(r) {
        if (r.picture === pic) {
            regions = (r.regions || []).slice();
            return;
        }
        openPic(r.picture);
        regionsLater.regions = (r.regions || []).slice();
        regionsLater.picture = r.picture;
    }
    Connections {
        id: regionsLater
        property var regions: []
        property string picture: ""
        target: ed
        function onPicChanged() {
            if (regionsLater.picture && ed.pic === regionsLater.picture)
                ed.regions = regionsLater.regions;
            regionsLater.picture = "";
        }
    }

    // ---- on the desktop ----
    function poke(kind) {
        api("POST", "api/poke?kind=" + kind, null, null);
    }
    function showOn(screen) {
        api("POST", "api/show?pic=" + q(pic) + "&screen=" + q(screen), null, (code, j) => {
            status = j.ok ? I18n.t("поставил на ", "put on ") + screen : "✕ " + (j.out || j.error || code);
        });
    }
    function openFolder() {
        api("POST", "api/open?pic=" + q(pic), null, null);
    }
}
