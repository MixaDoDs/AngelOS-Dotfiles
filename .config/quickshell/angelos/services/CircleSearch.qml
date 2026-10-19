pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../plugins/web-search/Engines.js" as Engines
import "Links.js" as Links
import "CircleLearn.js" as Learn

// The screenshot, Pixel-like (modules/circle/CircleOverlay + CircleCanvas, scripts/circle.py): the
// screenshot key / `angelos capture` freezes the focused screen (grim, with the pointer when
// Config.capture.shotCursor), the areas on it light up (windows, pictures, blocks of text:
// scripts/capture_regions.py) and the words (the whole frame is read at once: Live Text).
// Three ways to pick (mode): auto — a tap picks a line of text or an area, a loop picks a piece;
// rect — a rectangle (Shift-drag in any mode); text — words, a tap one word, a drag a run of them.
// The bar at the bottom: save / copy the picture (Capture), copy / translate the text, search it
// or the picture in the island (Island.search / Island.lens), send it nearby (QuickShare), save
// the whole screen or a window. Nothing picked: the picture is the whole screen, the text all
// of it. Esc steps back, Enter / Ctrl+C copy, Ctrl+S saves, (the pick's text when it has any, else the picture).
// A tap where nothing is puts a frame there to drag about; every frame has 8 grips and moves.
// It learns (CircleLearn.js, per app): frames moved after tapping an area, how much text a tap
// takes, areas let go of, words fixed in the card; when unsure it asks after closing.
Singleton {
    id: root

    property bool open: false
    property bool fading: false              // closed, the overlay still fading away
    property string screenName: ""
    property string frame: ""                // the frozen frame (.ppm)
    property string frameUrl: ""
    property real frameW: 1
    property real frameH: 1
    property real scale: 1                   // frame pixels per logical pixel of that screen

    property var words: []                   // the whole frame: [{x,y,w,h,t,line}] in frame pixels, reading order
    property var regions: []                 // areas found on it: [{x,y,w,h,kind,score,label}], frame pixels
    property var windowsHere: []             // the windows on that screen's workspace, frame pixels
    property var tiles: []                   // the same as niri gives them (tiled ones without a place)
    property bool reading: false             // the whole frame is being read
    property bool finding: false             // the areas are being looked for

    property string mode: "auto"             // auto | rect | text
    readonly property var modes: ["auto", "rect", "text"]
    property var picked: []                  // the words of the pick
    property var pickedKeys: ({})            // "x,y" of each picked word: the marks look it up (not picked.some per word)
    property string pickKind: ""             // line | words | region | rect | loop ("" = nothing picked)
    property string text: ""                 // what was picked (the user may edit it)
    property var box: null                   // {x,y,w,h} of the pick, frame pixels
    property var poly: []                    // the loop, frame pixels
    property bool pickBusy: false
    property string translation: ""
    property string translateError: ""
    property bool translating: false
    property string error: ""
    // learning: the area tapped as it was found ({kind, box, app}), the line tapped (its words),
    // the picked words' text before any edit, the questions for after closing
    property var origin: null
    property var tapped: []
    property string readText: ""
    property bool acted: false
    property var learned: Learn.fresh()
    readonly property int learnedCount: Learn.count(learned)
    readonly property string learnFile: Config.stateDir + "/circle-learn.json"
    // a picture was taken (saved / copied): the overlay's shutter; rect null = the whole frame
    signal shot(var rect)
    // a word for the overlay's hint a moment (copied, kept open)
    signal told(string t)
    // the picks before this one (Ctrl+Z), newest last
    property var history: []
    // links, mail and phones on the frame (services/Links.js over each line): [{kind, url, text, box}]
    property var screenLinks: []

    readonly property string runtimeDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/angelos"
    readonly property string script: Quickshell.shellPath("scripts/circle.py")
    readonly property bool hasText: text.trim() !== ""
    readonly property bool textPick: pickKind === "line" || pickKind === "words"
    // every link, mail and phone in the text (services/Links.js): the chips under it
    readonly property var links: Links.find(text, 6)
    // the text is one of them and nothing else: "Open" instead of the web search
    readonly property string kind: links.length === 1 && links[0].text === text.trim() ? links[0].kind : "text"

    // wait: seconds before the picture, so a menu that started it has gone from the screen
    function start(screen, wait) {
        if (open || grab.running)
            return;
        screenName = screen || Niri.focusedOutput || Shell.primaryName;
        const sc = Shell.screenByName(screenName);
        if (!sc)
            return;
        scale = sc.devicePixelRatio > 0 ? sc.devicePixelRatio : 1;
        reset();
        history = [];
        nearDone = false;
        mode = "auto";
        words = [];
        screenLinks = [];
        regions = [];
        tiles = windowsOn(screenName);
        windowsHere = tiles.filter(w => w.x !== null);
        // a frame of its own each time: a copy or save of the last one may still be reading its file
        frame = runtimeDir + "/circle-" + Date.now() + ".ppm";
        grab.command = grabCommand(screenName, frame, wait);
        grab.running = true;
    }
    // grim → the frame; the second line of its PPM header is "W H" (the size before any view loads)
    function grabCommand(name, out, wait) {
        return ["sh", "-c", 'sleep "$4"; mkdir -p "$1" && find "$1" -maxdepth 1 -name "circle*.ppm" -mmin +2 -delete; grim $5 -o "$2" -t ppm "$3" && head -c 64 "$3" | sed -n 2p', "sh", runtimeDir, name, out, String(wait || 0), Config.capture.shotCursor ? "-c" : ""];
    }
    function toggle(screen) {
        open ? close() : start(screen);
    }
    function close() {
        if (open && !acted)
            letGo();
        if (open) {
            fading = true;
            fader.restart();
        }
        open = false;
        reader.running = false;
        nearReader.running = false;
        finder.running = false;
        picker.running = false;
        translator.running = false;
    }
    Timer {
        id: fader
        interval: 480
        onTriggered: root.fading = false
    }
    function reset() {
        keepPick();
        origin = null;
        tapped = [];
        acted = false;
        picked = [];
        pickedKeys = {};
        pickKind = "";
        text = "";
        box = null;
        poly = [];
        translation = "";
        translateError = "";
        error = "";
        picker.running = false;
        pickBusy = false;
        translator.running = false;
        translating = false;
    }
    // ---- Ctrl+Z: the pick as it was (a new pick, Esc and a tap beside it all keep the last one)
    function keepPick() {
        if (!box && !picked.length)
            return;
        const top = history[history.length - 1];
        if (top && JSON.stringify(top.box) === JSON.stringify(box) && top.text === text)
            return;
        history = history.concat([{
                "box": box,
                "poly": poly,
                "pickKind": pickKind,
                "picked": picked,
                "pickedKeys": pickedKeys,
                "text": text,
                "readText": readText
            }]).slice(-30);
    }
    function undo() {
        if (!history.length)
            return false;
        const h = history[history.length - 1];
        // the pick it replaces is not remembered again (Ctrl+Z twice steps back twice)
        history = history.slice(0, -1);
        picker.running = false;
        pickBusy = false;
        translator.running = false;
        translating = false;
        translation = "";
        translateError = "";
        origin = null;
        tapped = [];
        box = h.box;
        poly = h.poly;
        pickKind = h.pickKind;
        picked = h.picked;
        pickedKeys = h.pickedKeys;
        text = h.text;
        readText = h.readText;
        return true;
    }
    // the arrows: the pick moved by a pixel (Shift: ten), kept on the frame
    function nudge(dx, dy) {
        if (!box || pickKind === "words" || pickKind === "line" && !poly.length)
            return false;
        const ddx = Math.max(-box.x, Math.min(frameW - box.x - box.w, dx * scale)), ddy = Math.max(-box.y, Math.min(frameH - box.y - box.h, dy * scale));
        if (pickKind === "loop") {
            pickLoop(poly.map(p => ({
                        "x": p.x + ddx,
                        "y": p.y + ddy
                    })));
            return true;
        }
        return adjustTo({
            "x": box.x + ddx,
            "y": box.y + ddy,
            "w": box.w,
            "h": box.h
        }, pickKind === "region" || pickKind === "line" ? "rect" : pickKind);
    }
    function setMode(m) {
        if (modes.indexOf(m) >= 0)
            mode = m;
    }
    function nextMode() {
        mode = modes[(modes.indexOf(mode) + 1) % modes.length];
    }

    // the windows niri shows on that screen now, in frame pixels (the frame is physical pixels);
    // a tiled one has no place from niri (26.04: tile_pos_in_workspace_view is null) — x/y null,
    // its column and row: capture_regions.py finds it on the frame and hands it back
    function windowsOn(name) {
        const sc = Shell.screenByName(name);
        const ws = Niri.activeWorkspace(name);
        if (!sc || !ws)
            return [];
        const k = sc.devicePixelRatio > 0 ? sc.devicePixelRatio : 1;
        return Niri.windowsOn(ws.id).filter(w => w.layout && (w.layout.tile_pos_in_workspace_view || w.layout.pos_in_scrolling_layout)).map(w => {
            const pos = w.layout.tile_pos_in_workspace_view, off = w.layout.window_offset_in_tile || [0, 0], size = w.layout.window_size;
            const cell = w.layout.pos_in_scrolling_layout || [0, 0];
            return {
                "x": pos ? Math.round((pos[0] + off[0]) * k) : null,
                "y": pos ? Math.round((pos[1] + off[1]) * k) : null,
                "col": cell[0],
                "row": cell[1],
                "w": Math.round(size[0] * k),
                "h": Math.round(size[1] * k),
                "title": w.title || "",
                "app_id": w.app_id || "",
                "focused": w.id === Niri.focusedWindowId
            };
        });
    }
    // the smallest of the rects under a point (a picture in a window wins over the window)
    function smallestAt(list, x, y) {
        let best = null;
        for (const r of list)
            if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h && (!best || r.w * r.h < best.w * best.h))
                best = r;
        return best;
    }
    function regionAt(x, y) {
        return smallestAt(regions, x, y);
    }
    // what a tap takes: the smallest area under it that is not a window, else a window when the tap
    // is by its edge (an empty place inside a window is no reason to take all of it: a frame goes
    // there instead), else null
    function areaAt(x, y) {
        const r = smallestAt(regions.filter(q => q.kind !== "window"), x, y);
        if (r)
            return r;
        const w = windowAt(x, y), band = 24 * scale;
        return w && (x - w.x < band || w.x + w.w - x < band || y - w.y < band || w.y + w.h - y < band) ? w : null;
    }
    function windowAt(x, y) {
        return smallestAt(windowsHere, x, y) || smallestAt(regions.filter(r => r.kind === "window"), x, y);
    }
    // what "Window" takes: the one under the pointer, else the focused one (null: none here)
    function targetWindow(x, y) {
        const w = x === undefined || x < 0 ? null : windowAt(x, y);
        return w || windowsHere.find(v => v.focused) || null;
    }
    // a rect inside the frame (a window half off the screen: its visible part)
    function clampRect(r) {
        if (!r)
            return null;
        const x0 = Math.max(0, Math.round(r.x)), y0 = Math.max(0, Math.round(r.y));
        const x1 = Math.min(Math.round(frameW), Math.round(r.x + r.w)), y1 = Math.min(Math.round(frameH), Math.round(r.y + r.h));
        return x1 - x0 < 1 || y1 - y0 < 1 ? null : {
            "x": x0,
            "y": y0,
            "w": x1 - x0,
            "h": y1 - y0
        };
    }
    // a rect as the pick (an area tapped, a rectangle drawn): its corners are the loop
    function pickRect(r, how) {
        if (!r || r.w < 4 || r.h < 4)
            return false;
        pickLoop([{
                "x": r.x,
                "y": r.y
            }, {
                "x": r.x + r.w,
                "y": r.y
            }, {
                "x": r.x + r.w,
                "y": r.y + r.h
            }, {
                "x": r.x,
                "y": r.y + r.h
            }], 0);
        pickKind = how || "rect";
        return true;
    }
    // a tap (frame pixels): text mode — the word under it; else the line under it, else the
    // area under it; nothing there lets go of the pick. Returns what was picked.
    // (a word before an area: capture_regions cuts lines of text into "text" areas of half a line
    // or a whole block, and an area is a picture — Ctrl+C copied the picture of a word)
    function tapAt(x, y) {
        if (mode === "text") {
            const i = wordIndexAt(x, y);
            if (i < 0) {
                reset();
                return "";
            }
            selectWords(i, i);
            return "word";
        }
        const had = !!box || picked.length > 0;
        letGo();
        if (mode === "auto" && wordIndexAt(x, y) >= 0 && pickLineAt(x, y))
            return "line";
        // the words not read yet: the area; its words fill in when they come (repick)
        const r = areaAt(x, y);
        if (r) {
            // as the user takes this kind of area here, once that is sure
            const app = appAt(r.x + r.w / 2, r.y + r.h / 2), habit = Learn.edgeFor(learned, app, r.kind || "window");
            pickRect(habit && habit.sure ? Learn.moved(r, habit.d, scale, frameW, frameH) : r, "region");
            origin = {
                "kind": r.kind || "window",
                "box": r,
                "app": app
            };
            return "region";
        }
        // nothing there with a pick: it lets go of it (as a click beside a selection does)
        if (had) {
            reset();
            return "";
        }
        // nothing there and nothing picked: a frame round the tap to drag into place (Lens)
        const fw = Math.min(frameW, 300 * scale), fh = Math.min(frameH, 200 * scale);
        pickRect({
            "x": Math.max(0, Math.min(frameW - fw, x - fw / 2)),
            "y": Math.max(0, Math.min(frameH - fh, y - fh / 2)),
            "w": fw,
            "h": fh
        }, "rect");
        return "rect";
    }
    // the frame changed by its grips: the pick, what it was tapped as kept for learning
    function adjustTo(r, how) {
        const o = origin, t = tapped;
        if (!pickRect(r, how))
            return false;
        origin = o;
        tapped = t;
        return true;
    }
    // the app (niri app_id) of the window under a point, "" for none
    function appAt(x, y) {
        const w = windowAt(x, y);
        return w && w.app_id ? w.app_id : "";
    }

    // a loop drawn on the overlay, in frame pixels
    function pickLoop(points, padding) {
        reset();
        if (points.length < 3)
            return;
        let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
        for (const p of points) {
            x0 = Math.min(x0, p.x);
            y0 = Math.min(y0, p.y);
            x1 = Math.max(x1, p.x);
            y1 = Math.max(y1, p.y);
        }
        const pad = padding === undefined ? 6 : padding;
        box = {
            "x": Math.max(0, x0 - pad),
            "y": Math.max(0, y0 - pad),
            "w": Math.min(frameW, x1 + pad) - Math.max(0, x0 - pad),
            "h": Math.min(frameH, y1 + pad) - Math.max(0, y0 - pad)
        };
        poly = points;
        pickKind = "loop";
        // the whole frame's words inside, whole: a closer read of the piece cut the words at its edge
        // ("Sear", "5‹") and moved them a pixel, so their marks went dark; read closer only when
        // the whole frame found nothing there (not read yet, or too small for it)
        const inside = words.filter(w => within(w.x + w.w / 2, w.y + w.h / 2, points));
        setPicked(inside);
        if (inside.length)
            return;
        const p = points.map(q => Math.round(q.x) + "," + Math.round(q.y)).join(";");
        picker.command = ["python3", script, "ocr", frame, String(Math.round(box.x)), String(Math.round(box.y)), String(Math.round(box.w)), String(Math.round(box.h)), "--poly", p];
        pickBusy = true;
        picker.running = true;
    }
    // the words came after the pick was made: its words from them (not over the user's edit)
    // (a line or words picked from the words near the pointer: the same ones from the whole read)
    function repick() {
        if (!box || text !== readText)
            return;
        const b = box, inside = words.filter(w => {
            const cx = w.x + w.w / 2, cy = w.y + w.h / 2;
            return poly.length > 2 ? within(cx, cy, poly) : cx >= b.x && cx <= b.x + b.w && cy >= b.y && cy <= b.y + b.h;
        });
        if (!inside.length)
            return;
        picker.running = false;
        pickBusy = false;
        const keep = pickKind;
        setPicked(inside);
        pickKind = keep;
    }
    // the links on the frame: each line's text (as joinWords makes it) through Links.scan, back to its words
    function findLinks(list) {
        const out = [], lines = {};
        for (const w of list)
            (lines[w.line] = lines[w.line] || []).push(w);
        for (const k in lines) {
            const ws = lines[k];
            let t = "";
            const at = ws.map(w => {
                const a = t.length;
                t += (a ? " " : "") + w.t;
                return [a + (a ? 1 : 0), t.length];
            });
            for (const l of Links.scan(t)) {
                const hit = ws.filter((w, i) => at[i][0] < l.end && l.start < at[i][1]);
                if (hit.length)
                    out.push({
                        "kind": l.kind,
                        "url": l.url,
                        "text": l.text,
                        "box": boundsOf(hit)
                    });
            }
        }
        return out.slice(0, 200);
    }
    function linkAt(x, y) {
        return screenLinks.find(l => x >= l.box.x - 2 && x <= l.box.x + l.box.w + 2 && y >= l.box.y - 2 && y <= l.box.y + l.box.h + 2) || null;
    }
    // while the whole frame is read (1.5-7 s): the piece round the pointer first, so its words
    // light up and a tap there takes a line at once
    function readNear(x, y) {
        if (!reading || nearReader.running || nearDone || words.length)
            return;
        nearDone = true;
        const w = Math.min(frameW, 1400 * scale), h = Math.min(frameH, 420 * scale);
        const bx = Math.round(Math.max(0, Math.min(frameW - w, x - w / 2))), by = Math.round(Math.max(0, Math.min(frameH - h, y - h / 2)));
        // under the overlay and niri, over the whole read: the pointer never waits for tesseract
        nearReader.command = ["nice", "-n", "10", "python3", script, "ocr", frame, String(bx), String(by), String(Math.round(w)), String(Math.round(h)), "--background"];
        nearReader.running = true;
    }
    property bool nearDone: false
    // a click on a word: its whole line
    function pickLineAt(x, y) {
        const i = wordIndexAt(x, y);
        reset();
        if (i < 0)
            return false;
        const hit = words[i];
        const line = words.filter(w => w.line === hit.line && Math.abs(w.y - hit.y) < hit.h * 1.5);
        // as much as the user takes here: the line, its paragraph or its block
        const g = Learn.grainFor(learned, appAt(hit.x + hit.w / 2, hit.y + hit.h / 2));
        const take = hit.block === undefined || !g || g === "line" ? line : words.filter(w => w.block === hit.block && (g === "block" || w.para === hit.para));
        setPicked(take);
        box = boundsOf(take);
        pickKind = "line";
        tapped = line;
        return true;
    }
    // ---- Live Text: words
    function wordIndexAt(x, y) {
        return words.findIndex(w => x >= w.x - 2 && x <= w.x + w.w + 2 && y >= w.y - 2 && y <= w.y + w.h + 2);
    }
    // the word a drag is over: under it, else the nearest one on that line (past its end), else -1
    function wordNear(x, y) {
        const i = wordIndexAt(x, y);
        if (i >= 0)
            return i;
        let best = -1, bd = 1e9;
        words.forEach((w, j) => {
            if (y < w.y - w.h * 0.3 || y > w.y + w.h * 1.3)
                return;
            const d = x < w.x ? w.x - x : x > w.x + w.w ? x - w.x - w.w : 0;
            if (d < bd) {
                bd = d;
                best = j;
            }
        });
        return best;
    }
    // the words from one to another in reading order (either way round), as Live Text selects
    function selectWords(a, b) {
        if (a < 0 || b < 0 || a >= words.length || b >= words.length)
            return false;
        const run = words.slice(Math.min(a, b), Math.max(a, b) + 1);
        // a drag over words changes only the run, not all the pick's state on every word
        if (pickKind !== "words")
            reset();
        else {
            translation = "";
            translateError = "";
            translator.running = false;
            translating = false;
        }
        setPicked(run);
        box = boundsOf(run);
        pickKind = "words";
        return true;
    }
    function selectAll() {
        return selectWords(0, words.length - 1);
    }
    // the words whose middles are in a rect (a text-mode drag from an empty place)
    function selectWordsIn(r) {
        const inside = words.filter(w => w.x + w.w / 2 >= r.x && w.x + w.w / 2 <= r.x + r.w && w.y + w.h / 2 >= r.y && w.y + w.h / 2 <= r.y + r.h);
        reset();
        if (!inside.length)
            return false;
        setPicked(inside);
        box = boundsOf(inside);
        pickKind = "words";
        return true;
    }
    function boundsOf(list) {
        const x0 = Math.min(...list.map(w => w.x)), y0 = Math.min(...list.map(w => w.y));
        return {
            "x": x0,
            "y": y0,
            "w": Math.max(...list.map(w => w.x + w.w)) - x0,
            "h": Math.max(...list.map(w => w.y + w.h)) - y0
        };
    }
    function joinWords(list) {
        let out = [], last = null;
        for (const w of list) {
            if (w.line !== last || !out.length) {
                out.push([]);
                last = w.line;
            }
            out[out.length - 1].push(w.t);
        }
        return out.map(l => l.join(" ")).join("\n");
    }
    function setPicked(list) {
        const m = {};
        for (const w of list)
            m[w.x + "," + w.y] = true;
        pickedKeys = m;
        picked = list;
        text = joinWords(list);
        readText = text;
    }
    // all the text on the screen (nothing picked: "Text" and "Translate" take it)
    function allText() {
        return joinWords(words);
    }
    function within(px, py, poly) {
        let hit = false;
        for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
            const a = poly[i], b = poly[j];
            if ((a.y > py) !== (b.y > py) && px < (b.x - a.x) * (py - a.y) / ((b.y - a.y) || 1e-9) + a.x)
                hit = !hit;
        }
        return hit;
    }

    // ---- learning (CircleLearn.js)
    // an area tapped and let go of with nothing done: that kind is wanted less here
    function letGo() {
        if (origin && !acted) {
            Learn.addDrop(learned, origin.app, origin.kind, true);
            origin = null;
            keep();
        }
    }
    // an action on the pick: what it teaches; the unsure parts asked after closing
    function learnNow() {
        if (acted)
            return;
        acted = true;
        const ask = [], app = origin ? origin.app : box ? appAt(box.x + box.w / 2, box.y + box.h / 2) : "";
        if (origin && box) {
            Learn.addDrop(learned, origin.app, origin.kind, false);
            const d = Learn.edgeDelta(origin.box, box, scale) || [0, 0, 0, 0];
            if (d.some(v => v !== 0) && Learn.edgeUnsure(learned, app, origin.kind, d))
                ask.push({
                    "edge": d,
                    "kind": origin.kind,
                    "app": app
                });
            else
                Learn.addEdge(learned, app, origin.kind, d);
        }
        if (tapped.length && textPick) {
            const g = Learn.grainOf(tapped, picked);
            if (g)
                Learn.addGrain(learned, app, g);
        }
        if (readText && text !== readText)
            for (const [a, b] of Learn.wordFixes(readText, text)) {
                if (Learn.fixUnsure(learned, app, a, b))
                    ask.push({
                        "fix": [a, b],
                        "app": app
                    });
                Learn.addFix(learned, app, a, b);
            }
        keep();
        if (ask.length)
            askLater(ask);
    }
    function appName(app) {
        return app ? app.split(".").pop() : I18n.t("всех приложений", "every app");
    }
    function askLater(items) {
        const kinds = {
            "window": I18n.t("окна", "a window"),
            "image": I18n.t("картинки", "a picture"),
            "text": I18n.t("текста", "text"),
            "ui": I18n.t("элемента", "an element")
        };
        const lines = items.map(q => q.edge ? I18n.t("рамку ", "the frame of ") + (kinds[q.kind] || q.kind) + I18n.t(" в ", " in ") + appName(q.app) + I18n.t(" — так же, как сейчас", " — as now") : "«" + q.fix[0] + "» → «" + q.fix[1] + "»" + I18n.t(" в ", " in ") + appName(q.app));
        asker.items = items;
        asker.command = ["notify-send", "-a", "angelOS", "-i", "edit-select-all", "--wait", "-t", "30000", "-A", "yes=" + I18n.t("Запомнить", "Remember"), "-A", "no=" + I18n.t("Разово", "Just this once"), I18n.t("Скриншот: запомнить?", "Screenshot: remember?"), lines.join("\n")];
        asker.running = true;
    }
    function remember(items) {
        for (const q of items) {
            if (q.edge)
                Learn.addEdge(learned, q.app, q.kind, q.edge, true);
            else if (q.fix)
                Learn.addFix(learned, q.app, q.fix[0], q.fix[1], true);
        }
        keep();
    }
    function forget() {
        learned = Learn.fresh();
        keep();
    }
    function keep() {
        learnStore.setText(JSON.stringify(learned) + "\n");
        learnedChanged();
    }
    FileView {
        id: learnStore
        path: root.learnFile
        blockWrites: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                const j = JSON.parse(text());
                if (j && j.apps)
                    root.learned = j;
            } catch (e) {}
        }
    }
    Process {
        id: asker
        property var items: []
        stdout: SplitParser {
            onRead: line => {
                if (line.trim() === "yes")
                    root.remember(asker.items);
            }
        }
    }

    // ---- the keys (modules/circle/CircleCanvas): Esc — back a step, then away
    function back() {
        if (box || picked.length || translation !== "" || translateError !== "") {
            letGo();
            reset();
        } else
            close();
    }
    // Enter: copied, as Ctrl+C (the clipboard is what a shot is mostly for; Ctrl+S saves)
    function enter() {
        ctrlC();
    }
    // Ctrl+C: the pick's text when it has any (the card shows it), else the picture;
    // keep (Ctrl+Shift+C): the overlay stays for the next piece
    function ctrlC(keep) {
        if (hasText)
            copyText(keep);
        else
            copyShot(keep);
    }

    // ---- what the bar does
    function copy(t) {
        const s = t === undefined ? text : t;
        // a type of its own: guessed, "From: …\nSubject: …" read off a screen went as a mail
        Quickshell.execDetached(["wl-copy", "--type", "text/plain;charset=utf-8", "--", s]);
        // on air: how much, not what (16.10 a copied word went out on stream)
        say(I18n.t("Скопировано", "Copied"), StreamMode.onAir ? I18n.t("знаков: ", "characters: ") + s.length : s.slice(0, 200));
    }
    // "Text": the picked text, else all of the screen's
    function copyText(keep) {
        if (!open)   // a second click while it fades
            return false;
        learnNow();
        const t = hasText ? text : allText();
        if (!t.trim())
            return false;
        copy(t);
        if (keep) {
            acted = false;
            told(I18n.t("Скопировано — выделяйте следующее, Esc — закрыть", "Copied — pick the next piece, Esc closes"));
        } else
            close();
        return true;
    }
    // ---- the picture: Capture saves and copies it (its folders, its notification, its settings)
    function rectOf(r) {
        return clampRect(r);
    }
    function save(r) {
        if (!open)
            return;
        if (r === undefined)
            learnNow();
        const rect = rectOf(r === undefined ? box : r);
        // the file only: the clipboard keeps what was copied (a text, then Enter, lost it)
        Capture.saveShot(frame, rect, {
            "copy": false
        });
        shot(rect);
        close();
    }
    function saveFull() {
        save(null);
    }
    // the window under the pointer (x, y in frame pixels), else the focused one, else the screen
    function saveWindow(x, y) {
        save(targetWindow(x, y));
    }
    function copyShot(keep) {
        if (!open)
            return;
        learnNow();
        const rect = rectOf(box);
        // on the clipboard and in the screenshots folder too (every shot is kept there); told once it
        // is there — a paste right after the overlay closes got the old clipboard. Kept, it waits in
        // the corner as a saved one does (ShotEdit, from Capture.shotSaved)
        Capture.saveShot(frame, rect, {
            "copy": true,
            "quiet": true
        }, r => say(r.copied ? I18n.t("Картинка скопирована", "Picture copied") : I18n.t("Картинка не скопировалась", "Picture not copied"), r.path ? I18n.t("и сохранена в папку снимков", "and kept in the screenshots folder") : r.error || ""));
        if (keep) {
            acted = false;
            told(I18n.t("Картинка скопирована — выделяйте следующее", "Picture copied — pick the next piece"));
            return;
        }
        shot(rect);
        close();
    }
    function translate() {
        learnNow();
        const t = hasText ? text : allText();
        if (!t.trim() || translator.running)
            return false;
        translation = "";
        translateError = "";
        translating = true;
        translator.command = ["python3", script, "translate", t, "--to", Config.circle.translateTo];
        translator.running = true;
        return true;
    }
    function engine() {
        return Engines.engines[Config.circle.engine] || Engines.engines.google;
    }
    // "Search": the text in the island (a link: opened); a pick with no text: by its picture
    function search() {
        if (!open)
            return;
        learnNow();
        const t = text.trim();
        if (!t) {
            if (box)
                searchPicture();
            return;
        }
        if (kind !== "text")
            return openLink(links[0]);
        // the island: a popup that the "↗" moves into the browser
        Island.search(t.replace(/\s+/g, " "));
        close();
    }
    // a link into the mini island, mail and phones to their apps
    function openLink(l) {
        // a YouTube id off the screen may have I/l/1 or O/0 wrong: checked (circle.py fixlink) first
        if (l.kind === "url" && /(youtube\.com|youtu\.be)\//i.test(l.url)) {
            fixer.url = l.url;
            fixer.command = ["python3", script, "fixlink", l.url];
            fixer.running = true;
        } else if (l.kind === "url")
            Island.open(l.url);
        else
            Qt.openUrlExternally(l.url);
        close();
    }
    // the picked piece (or the whole screen) to Google Lens, in the island
    function searchPicture() {
        if (!open)
            return;
        learnNow();
        // the piece is kept in the screenshots folder like every shot, and that file goes to Lens
        Capture.saveShot(frame, rectOf(box), {
            "copy": false,
            "quiet": true,
            "noThumb": true
        }, r => {
            if (r.path)
                Island.lens(r.path);
        });
        close();
    }
    // to a phone nearby (Quick Share): a text pick's text, else the picture (the pick or the screen)
    function shareNearby() {
        if (!open)
            return;
        learnNow();
        if (textPick && hasText)
            QuickShare.share([], text.trim());
        else
            Capture.saveShot(frame, rectOf(box), {
                "copy": false,
                "quiet": true,
                "noThumb": true
            }, r => {
                if (r.path)
                    QuickShare.share([r.path], "");
            });
        close();
    }
    function say(title, body) {
        Quickshell.execDetached(["notify-send", "-a", "angelOS", "-i", "edit-copy", "-h", "string:x-canonical-private-synchronous:angelos-circle", "--", title, body]);
    }

    Process {
        id: grab
        stdout: StdioCollector {
            id: grabOut
        }
        onExited: code => {
            if (code !== 0)
                return;
            const m = /^(\d+)\s+(\d+)/.exec(grabOut.text.trim());
            if (m) {
                root.frameW = +m[1];
                root.frameH = +m[2];
            }
            root.frameUrl = "file://" + root.frame + "?" + Date.now();
            // the windows as they were when the picture was taken (after the wait)
            const now = root.windowsOn(root.screenName);
            if (now.length) {
                root.tiles = now;
                root.windowsHere = now.filter(w => w.x !== null);
            }
            root.fading = false;
            root.open = true;
            root.finding = true;
            finder.command = ["python3", Quickshell.shellPath("scripts/capture_regions.py"), root.frame, "--windows", JSON.stringify(root.tiles.map(w => ({
                            "x": w.x === null ? null : w.x / root.scale,
                            "y": w.y === null ? null : w.y / root.scale,
                            "w": w.w / root.scale,
                            "h": w.h / root.scale,
                            "col": w.col,
                            "row": w.row,
                            "title": w.title,
                            "app_id": w.app_id,
                            "focused": w.focused
                        }))), "--scale", String(root.scale)];
            finder.running = true;
            if (Config.circle.liveText) {
                root.reading = true;
                // the lowest priority: up to 8 tesseracts side by side took the cores the
                // pointer needed for the first seconds (20.10)
                reader.command = ["nice", "-n", "19", "python3", root.script, "ocr", root.frame, "--background"];
                reader.running = true;
            }
        }
    }
    // the areas (scripts/capture_regions.py); none if it is not there or fails
    Process {
        id: finder
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    root.regions = (j.regions || []).filter(r => r.w > 8 && r.h > 8);
                    // the windows as placed on the frame (tiled ones included)
                    if ((j.windows || []).length)
                        root.windowsHere = j.windows;
                    // kinds the user lets go of every time here are not lit (text always is: a
                    // glance and Esc counted as "let go", and the text went dark everywhere)
                    root.regions = root.regions.filter(r => r.kind === "window" || r.kind === "text" || !Learn.unwanted(root.learned, root.appAt(r.x + r.w / 2, r.y + r.h / 2), r.kind));
                } catch (e) {
                    root.regions = [];
                }
            }
        }
        onExited: root.finding = false
    }
    Process {
        id: reader
        stdout: StdioCollector {
            onStreamFinished: {
                root.reading = false;
                try {
                    const j = JSON.parse(text);
                    if (j.error)
                        root.error = j.error;
                    else {
                        nearReader.running = false;
                        root.words = Learn.fixWords(root.learned, j.words || [], w => root.appAt(w.x + w.w / 2, w.y + w.h / 2));
                        root.screenLinks = root.findLinks(root.words);
                        root.repick();
                    }
                } catch (e) {}
            }
        }
        onExited: root.reading = false
    }
    Process {
        id: nearReader
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    // the whole read may have come first: it wins
                    if (root.reading && !j.error && (j.words || []).length) {
                        root.words = Learn.fixWords(root.learned, j.words, w => root.appAt(w.x + w.w / 2, w.y + w.h / 2));
                        root.screenLinks = root.findLinks(root.words);
                        root.repick();
                    }
                } catch (e) {}
            }
        }
    }
    Process {
        id: picker
        stdout: StdioCollector {
            onStreamFinished: {
                root.pickBusy = false;
                try {
                    const j = JSON.parse(text);
                    // (only asked when the whole frame had no words there) — not over the user's edit
                    if (!j.error && (j.words || []).length && root.text === root.readText)
                        root.setPicked(Learn.fixWords(root.learned, j.words, w => root.appAt(w.x + w.w / 2, w.y + w.h / 2)));
                    else if (j.error)
                        root.error = j.error;
                } catch (e) {}
            }
        }
        onExited: root.pickBusy = false
    }
    Process {
        id: translator
        stdout: StdioCollector {
            onStreamFinished: {
                root.translating = false;
                try {
                    const j = JSON.parse(text);
                    if (j.error)
                        root.translateError = j.error === "trans" ? I18n.t("Нужен translate-shell: sudo pacman -S translate-shell", "Needs translate-shell: sudo pacman -S translate-shell") : j.error;
                    else
                        root.translation = j.text;
                } catch (e) {
                    root.translateError = I18n.t("Не перевелось", "Could not translate");
                }
            }
        }
        onExited: root.translating = false
    }
    Process {
        id: fixer
        property string url
        stdout: StdioCollector {
            onStreamFinished: {
                let u = fixer.url;
                try {
                    u = JSON.parse(text).url || u;
                } catch (e) {}
                Island.open(u);
            }
        }
    }
}
