pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "CobwebWeb.js" as Web
import "CobwebLayout.js" as Lay

// Cobwebs (Settings → Windows → Cobwebs): a window nobody has moved for a while gets a spider.
// It starts in the corners and works inwards — corner webs, drapes along the edges, then it
// winds the whole window up in a cocoon (services/CobwebWeb.js) — first threads after 30
// minutes, the whole window after 4 hours (Config.windows.cobwebSpeed). The clock is the real one, kept in
// ~/.local/state/angelos/cobweb.json, so a night asleep counts: in the morning the browser can
// be under it all. Using a window doesn't stop the spider; moving it does: a drag shakes the
// newest threads off. The rest come off:
//   - by touching a thread with the pointer: 35 % it breaks, otherwise the spider runs off
//     behind the window and comes back in 5–10 minutes (nothing grows while it is away)
//   - by shaking the window (a drag back and forth, scripts/shake-watch.py --drag; or the web
//     itself, held by a press on a thread; or the window button's menu): a quick-time
//     event, arrows to swipe; a miss is the error sound and a red flash, three misses and the
//     spider holds on for a minute more. Done, or every thread broken: the spider is gone for
//     half an hour, then starts again from the corners.
// Drawn by modules/cobweb (an overlay that takes the pointer only on the threads) and, small,
// on the window's button in the bar (widgets/CobwebBadge). Only the windows' sizes and places
// are used — never their titles or what is in them.
Singleton {
    id: root

    readonly property bool enabled: Config.ready && Config.windows.cobweb && Niri.available
    readonly property bool inside: enabled && Config.windows.cobwebInside
    readonly property bool onBar: enabled && Config.windows.cobwebBar
    // first threads → the whole window, ms; ANGELOS_COBWEB_SPEED speeds it up (the stand's tests)
    readonly property var speeds: ({
            "fast": [10, 60],
            "normal": [30, 240],
            "slow": [120, 1440]
        })
    readonly property real _boost: Math.max(1, Number(Quickshell.env("ANGELOS_COBWEB_SPEED") || 1))
    readonly property var _sp: speeds[Config.windows.cobwebSpeed] || speeds.normal
    readonly property real t0: _sp[0] * 60000 / _boost
    readonly property real t1: _sp[1] * 60000 / _boost
    readonly property real breakChance: 0.35
    readonly property int qteMisses: 3
    readonly property int holdMs: 60000             // after a lost QTE
    readonly property int goneMs: 30 * 60000        // after the last thread came off
    readonly property int minW: 160                 // smaller windows get no web inside
    readonly property int minH: 120

    // every change to a web: the views and badges read through functions, this is their trigger
    property int rev: 0
    property var webs: ({})                         // id -> {seed, w0, h0, age, at, broken, away, hold}
    property var _steps: ({})                       // id -> generated steps (from seed, w0, h0)
    property double now: Date.now()

    signal woven(int id, int from, int to)          // new steps, live (not caught up after sleep)
    signal broke(int id, string thread)
    signal fled(int id)                             // the spider runs off behind the window
    signal returned(int id)
    signal cleared(int id, string why)              // touch | qte | sweep
    signal shaken(int id, int from, int to)         // a drag shook these steps off
    signal swiped(int id, string dir)
    signal damaged(int id)

    // ---- reading ----
    function web(id) {
        return webs[id] || null;
    }
    function steps(id) {
        const w = webs[id];
        if (!w || !w.w0)
            return [];
        if (!_steps[id])
            _steps[id] = Web.generate(w.seed, w.w0, w.h0);
        return _steps[id];
    }
    function due(id) {
        const w = webs[id];
        return w ? Web.stepsDue(w.age, steps(id).length, t0, t1) : 0;
    }
    function alive(id) {
        const w = webs[id];
        if (!w)
            return 0;
        const st = steps(id), k = due(id);
        let n = 0;
        for (let i = 0; i < k; i++)
            for (const t of st[i].threads)
                if (!w.broken[t.id])
                    n++;
        return n;
    }
    // 0…1: how much of the whole web is there (the bar's badge)
    function amount(id) {
        const st = steps(id);
        if (!st.length)
            return 0;
        let total = 0;
        for (const s of st)
            total += s.threads.length;
        return total ? alive(id) / total : 0;
    }
    function spiderHere(id) {
        const w = webs[id];
        return !!w && w.age >= t0 - Math.min(60000, t0 * 0.1) && now >= w.away;
    }
    function held(id) {
        const w = webs[id];
        return w && w.hold > now ? Math.ceil((w.hold - now) / 1000) : 0;
    }

    // ---- the windows: their webs, their places on screen ----
    property var _prev: ({})                        // id -> the window as niri said last
    property var _colsBefore: ({})                  // ws id -> tiled columns
    property var _lastShake: ({})
    property var _movedAt: ({})                     // id -> when niri last showed it in a new place
    // angelOS's own windows (Settings, the novel…) are the shell: no spider there
    function _apps() {
        return Niri.windows.filter(w => w.app_id !== "org.quickshell");
    }
    property bool _hadWindows: false
    function _sync() {
        if (!enabled)
            return;
        const list = _apps();
        // right after a start niri has not told its windows yet: none of them closed
        if (!list.length && !_hadWindows && !Niri.windows.length)
            return;
        _hadWindows = true;
        const t = Date.now();
        const next = Object.assign({}, webs);
        let changed = false;
        const seen = {};
        const cols = {};
        for (const w of list)
            if (!(w.workspace_id in cols))
                cols[w.workspace_id] = Lay.columnCount(list, w.workspace_id);
        for (const w of list) {
            seen[w.id] = true;
            if (!next[w.id]) {
                next[w.id] = {
                    "seed": Web.hash(w.id + ":" + (w.app_id || "") + ":" + t),
                    "w0": 0,
                    "h0": 0,
                    "age": 0,
                    "at": t,
                    "broken": {},
                    "away": 0,
                    "hold": 0
                };
                changed = true;
            }
            const old = _prev[w.id];
            if (old && Lay.moved(old, w, _colsBefore[old.workspace_id], cols[w.workspace_id])) {
                _movedAt[w.id] = t;
                if (t - (_lastShake[w.id] || 0) > 1500) {
                    _lastShake[w.id] = t;
                    Qt.callLater(root.shakeOff, w.id);
                }
            }
        }
        for (const id in next)
            if (!seen[id]) {
                delete next[id];
                delete _steps[id];
                delete _movedAt[id];
                delete _lastShake[id];
                changed = true;
            }
        const prev = {};
        for (const w of list)
            prev[w.id] = w;
        _prev = prev;
        _colsBefore = cols;
        if (changed) {
            webs = next;
            rev++;
            _save.restart();
        }
        relayout();
    }

    // where each window is, per screen: {screen name: [{id, x, y, w, h, floating}]}
    property var rects: ({})
    property var _cfg: Lay.parseLayout("")
    function relayout() {
        if (!enabled) {
            rects = ({});
            return;
        }
        // every desk of a screen, not only the one in view: a desk switch slides them all, the way
        // niri does (modules/cobweb: one desk a screen's height below the other, by niri's idx)
        const out = {}, act = {};
        for (const s of Shell.screens) {
            const z = Lay.zoneEdges(Zones.parts, s.name);
            const all = [];
            for (const ws of Niri.workspacesOn(s.name)) {
                act[ws.id] = ws.active_window_id;
                // the desk's view jumped to another column (focus moved): niri moves it with its
                // horizontal-view-movement; otherwise its windows moved (window-movement)
                const cause = ws.id in _activeBefore && _activeBefore[ws.id] !== ws.active_window_id ? "view" : "move";
                const list = Lay.rects(_apps(), ws, s.width, s.height, z, _cfg);
                // what lies over each: the floating windows above it (niri keeps them over the tiles)
                list.forEach((r, i) => {
                    r.occl = list.slice(i + 1).filter(o => o.floating && o.x < r.x + r.w && o.x + o.w > r.x && o.y < r.y + r.h && o.y + o.h > r.y).map(o => ({
                                "x": o.x,
                                "y": o.y,
                                "w": o.w,
                                "h": o.h
                            }));
                    r.ws = ws.idx;
                    r.active = !!ws.is_active;
                    r.cause = cause;
                });
                for (const r of list)
                    if (r.w >= minW && r.h >= minH)
                        all.push(r);
            }
            out[s.name] = all;
        }
        _activeBefore = act;
        rects = out;
        // the size each web was begun at: its first place on screen
        let fresh = false;
        const u = Theme.u;
        for (const name in out)
            for (const r of out[name]) {
                const w = webs[r.id];
                if (w && !w.w0) {
                    w.w0 = Math.max(40, Math.floor(r.w / u));
                    w.h0 = Math.max(30, Math.floor(r.h / u));
                    fresh = true;
                }
            }
        if (fresh) {
            rev++;
            _save.restart();
        }
    }
    property var _activeBefore: ({})                // ws id -> its active window, as last laid out
    function rectsOn(screen) {
        return rects[screen] || [];
    }
    // where a window in view is (not one on a desk out of view)
    function rectOf(id) {
        for (const name in rects)
            for (const r of rects[name])
                if (r.id === id && r.active)
                    return Object.assign({
                        "screen": name
                    }, r);
        return null;
    }
    // nothing shows over the overview, a fullscreen window (games, video), the lock
    function hiddenOn(screen) {
        if (!inside || Niri.overviewOpen || Shell.locked)
            return true;
        const ws = Niri.activeWorkspace(screen);
        const s = Shell.screenByName(screen);
        if (!ws || !s)
            return true;
        return Niri.windows.some(w => w.workspace_id === ws.id && w.is_focused && w.layout && w.layout.window_size && w.layout.window_size[0] >= s.width && w.layout.window_size[1] >= s.height);
    }

    // ---- the clock ----
    function tick() {
        const t = Date.now();
        now = t;
        if (!enabled)
            return;
        let changed = false;
        for (const id in webs) {
            const w = webs[id];
            const dt = Math.max(0, t - (w.at || t));
            w.at = t;
            if (w.away && t >= w.away) {
                w.away = 0;
                changed = true;
                returned(Number(id));
            }
            if (w.away || !w.w0)
                continue;
            const n = steps(id).length;
            const before = Web.stepsDue(w.age, n, t0, t1);
            w.age = Math.min(t1 + 60000, w.age + dt);
            const after = Web.stepsDue(w.age, n, t0, t1);
            if (after !== before) {
                changed = true;
                // a step or two since the last tick: woven before your eyes; more: it was done
                // while you were away (sleep, a restart) and is simply there
                if (after - before <= 2)
                    woven(Number(id), before, after);
            }
        }
        if (changed) {
            rev++;
            _save.restart();
        }
    }
    Timer {
        running: root.enabled
        repeat: true
        interval: root._boost > 1 ? 1000 : 15000
        triggeredOnStart: true
        onTriggered: root.tick()
    }

    // ---- what happens to it ----
    // the pointer touched a thread: "break" | "flee" | "none"
    function touch(id, thread) {
        const w = webs[id];
        if (!w || w.broken[thread])
            return "none";
        if (Math.random() < breakChance) {
            w.broken[thread] = true;
            rev++;
            broke(id, thread);
            Sounds.play("webSnap");
            if (alive(id) === 0)
                clear(id, "touch");
            _save.restart();
            return "break";
        }
        if (spiderHere(id)) {
            w.away = Date.now() + (5 + Math.random() * 5) * 60000;
            rev++;
            fled(id);
            _save.restart();
            return "flee";
        }
        return "none";
    }
    // a drag: the newest fifth of it comes off (at least one step)
    function shakeOff(id) {
        const w = webs[id];
        if (!w)
            return;
        const n = steps(id).length, k = due(id);
        if (!k)
            return;
        const drop = Math.max(1, Math.round(k * 0.2));
        w.age = Web.stepAge(k - drop, n, t0, t1) - 1;
        rev++;
        shaken(id, k - drop, k);
        _save.restart();
    }
    function clear(id, why) {
        const w = webs[id];
        if (!w)
            return;
        w.age = t0 - 1;
        w.broken = {};
        w.away = Date.now() + goneMs;
        rev++;
        cleared(id, why);
        Sounds.play("webClear");
        _save.restart();
    }
    // Settings → "Show me" and `angelos cobweb grow`: as if `minutes` had passed for this window
    // the last few steps are woven before your eyes, the rest is simply there
    function grow(id, minutes) {
        const w = webs[id];
        if (!w || !w.w0)
            return false;
        const n = steps(id).length, before = due(id);
        w.away = 0;
        w.hold = 0;
        w.at = Date.now();
        w.age = Math.max(w.age, 0) + minutes * 60000;
        if (w.age < t0)
            w.age = t0;
        w.age = Math.min(w.age, t1 + 60000);
        const after = Web.stepsDue(w.age, n, t0, t1);
        rev++;
        if (after > before)
            woven(id, Math.max(before, after - 3), after);
        _save.restart();
        return true;
    }
    // Settings → "Show me now": the windows in view get an hour and a half of web (one with web
    // already: an hour more)
    function demo() {
        let n = 0;
        for (const name in rects)
            if (!hiddenOn(name))
                for (const r of rects[name])
                    if (r.active && grow(r.id, due(r.id) ? 60 : 90))
                        n++;
        return n;
    }
    function clearAll() {
        for (const id in webs)
            if (alive(id) > 0 || webs[id].age >= t0)
                sweep(Number(id));
    }
    // gone without a word (no QTE): the window menu's "Sweep the web", Settings, `angelos cobweb clear`
    function sweep(id) {
        const w = webs[id];
        if (!w)
            return false;
        if (qte && qte.id === id)
            qte = null;
        clear(id, "sweep");
        return true;
    }
    // windows with some web on them now (Settings)
    readonly property int webCount: {
        rev;
        let n = 0;
        for (const id in webs)
            if (alive(id) > 0)
                n++;
        return n;
    }

    // ---- the quick-time event ----
    // {id, seq: ["left", …], i, misses, phase: intro | run | won | lost, deadline}
    property var qte: null
    readonly property var dirs: ["left", "up", "right", "down"]
    readonly property int qteStepMs: Motion.calm ? 2600 : 1700
    function startQte(id) {
        if (!enabled || qte)
            return "busy";
        const w = webs[id];
        if (!w || alive(id) === 0)
            return "clean";
        if (w.hold > Date.now())
            return "held";
        const len = 3 + Math.round(amount(id) * 5);
        const seq = [];
        for (let i = 0; i < len; i++) {
            let d = dirs[Math.floor(Math.random() * 4)];
            if (i && d === seq[i - 1] && Math.random() < 0.6)
                d = dirs[(dirs.indexOf(d) + 1 + Math.floor(Math.random() * 3)) % 4];
            seq.push(d);
        }
        qte = {
            "id": id,
            "seq": seq,
            "i": 0,
            "misses": 0,
            "phase": "intro",
            "deadline": Date.now() + 1300
        };
        qteClock.restart();
        return "ok";
    }
    function swipe(dir) {
        if (!qte || qte.phase !== "run")
            return;
        if (dir === qte.seq[qte.i]) {
            const q = Object.assign({}, qte);
            q.i++;
            swiped(q.id, dir);
            Sounds.play("webSwipe");
            if (q.i >= q.seq.length) {
                q.phase = "won";
                q.deadline = Date.now() + 1400;
                qte = q;
                clear(q.id, "qte");
                return;
            }
            q.deadline = Date.now() + qteStepMs;
            qte = q;
        } else
            _miss();
    }
    function _miss() {
        const q = Object.assign({}, qte);
        q.misses++;
        Sounds.play("error");
        damaged(q.id);
        if (q.misses >= qteMisses) {
            q.phase = "lost";
            q.deadline = Date.now() + 1800;
            const w = webs[q.id];
            if (w)
                w.hold = Date.now() + holdMs;
            rev++;
            _save.restart();
        } else
            q.deadline = Date.now() + qteStepMs;
        qte = q;
    }
    function cancelQte() {
        qte = null;
    }
    Timer {
        id: qteClock
        interval: 50
        repeat: true
        running: root.qte !== null
        onTriggered: {
            const q = root.qte;
            if (!q || Date.now() < q.deadline)
                return;
            if (q.phase === "intro") {
                root.qte = Object.assign({}, q, {
                    "phase": "run",
                    "deadline": Date.now() + root.qteStepMs
                });
            } else if (q.phase === "run")
                root._miss();
            else
                root.qte = null;
        }
    }
    // the window it is about went away
    Connections {
        target: Niri
        function onWindowClosed(id) {
            if (root.qte && root.qte.id === id)
                root.qte = null;
        }
    }

    // a window shaken while dragged (scripts/shake-watch.py --drag): the focused one is the
    // dragged one (a click focuses it first)
    signal heldOn(int id, int seconds)
    property int pressId: -1                        // the window whose web the pointer holds (modules/cobweb)
    property string shakeStatus: ""                 // ready | noperm | noevdev (scripts/shake-watch.py)
    function dragShake() {
        // the web itself held and shaken (a press on a thread, modules/cobweb), or the window
        // dragged — a shake with a button held over a window that stays put (selecting text, a
        // slider) is no shaken window
        const f = Niri.focusedWindow;
        const w = pressId >= 0 ? {
            "id": pressId
        } : f;
        if (!w || !webs[w.id])
            return;
        if (pressId < 0 && Date.now() - (_movedAt[w.id] || 0) > 2500)
            return;
        const r = startQte(w.id);
        if (r === "held")
            heldOn(w.id, held(w.id));
    }
    Process {
        id: shaker
        running: root.inside
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/shake-watch.py", "--drag"]
        stdout: SplitParser {
            onRead: line => {
                if (line === "dragshake")
                    root.dragShake();
                else
                    root.shakeStatus = line;
            }
        }
        stderr: StdioCollector {}
        onExited: if (root.inside)
            shakerAgain.start()
    }
    Timer {
        id: shakerAgain
        interval: 5000
        onTriggered: if (root.inside)
            shaker.running = true
    }

    // a click that landed on a thread goes on to the window under it (scripts/vpointer.py)
    function pass(button) {
        if (hand.ok)
            hand.write("click " + button + "\n");
    }
    function wheel(dy, dx) {
        if (hand.ok)
            hand.write("wheel " + dy + " " + dx + "\n");
    }
    Process {
        id: hand
        property bool ok: false
        running: root.inside
        stdinEnabled: true
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/vpointer.py"]
        onRunningChanged: if (!running)
            ok = false
        stdout: SplitParser {
            onRead: line => hand.ok = line === "ready"
        }
        stderr: StdioCollector {}
    }

    // `angelos cobweb …` (modules/Ipc)
    function ipc(line) {
        const a = String(line || "").trim().split(/\s+/).filter(x => x);
        const cmd = a[0] || "status";
        const target = () => {
            const v = a[1];
            if (v && /^\d+$/.test(v))
                return Number(v);
            const f = Niri.focusedWindow;
            return f ? f.id : -1;
        };
        if (!enabled)
            return "cobwebs are off (Settings → Windows → Cobwebs)";
        if (cmd === "status" || cmd === "list") {
            const out = [];
            for (const id in webs) {
                const w = webs[id];
                out.push(id + ": " + Math.round(w.age / 60000) + " min, " + due(id) + "/" + steps(id).length + " steps, " + alive(id) + " threads" + (spiderHere(id) ? ", spider here" : w.away > now ? ", spider away " + Math.ceil((w.away - now) / 60000) + " min" : "") + (held(id) ? ", held " + held(id) + " s" : ""));
            }
            return (out.join("\n") || "no windows") + (qte ? "\nqte: window " + qte.id + " " + qte.phase + " " + qte.i + "/" + qte.seq.length + " misses " + qte.misses + " next " + (qte.seq[qte.i] || "-") : "");
        }
        if (cmd === "grow") {
            const id = /^\d+$/.test(a[1] || "") && a.length > 2 ? Number(a[1]) : (Niri.focusedWindow || {}).id;
            const min = Number(a.length > 2 ? a[2] : a[1] || 90);
            return grow(id, isFinite(min) ? min : 90) ? "ok" : "no such window (or not placed yet)";
        }
        if (cmd === "demo")
            return demo() + " windows";
        if (cmd === "clear")
            return a[1] === "all" ? (clearAll(), "ok") : sweep(target()) ? "ok" : "no such window";
        if (cmd === "qte")
            return startQte(target());
        if (cmd === "swipe") {
            swipe(a[1] || "");
            return qte ? qte.phase + " " + qte.i + "/" + qte.seq.length + " misses " + qte.misses : "no qte";
        }
        // as if scripts/shake-watch.py had seen a shake with a button held (the stand's tests)
        if (cmd === "dragshake") {
            dragShake();
            return qte ? "qte on " + qte.id : "nothing";
        }
        if (cmd === "touch") {
            const id = target(), st = steps(id), k = due(id);
            for (let i = k - 1; i >= 0; i--)
                for (const t of st[i].threads)
                    if (!webs[id].broken[t.id])
                        return touch(id, t.id);
            return "none";
        }
        return "usage: angelos cobweb [status | grow [id] [minutes] | demo | clear [id|all] | qte [id] | swipe left|right|up|down | touch [id] | dragshake]";
    }

    // ---- niri's layout settings (gaps, centring, struts) ----
    readonly property string _niriDir: (Quickshell.env("XDG_CONFIG_HOME") || Config.home + "/.config") + "/niri"
    property string _layoutText: ""
    property string _configText: ""
    property string _animText: ""
    // niri's animations (cfg/animation.kdl, else config.kdl): a web moves with its window's
    readonly property int lagMs: 40                 // niri's events come a frame or two after it starts moving
    readonly property var anims: Lay.parseAnims(_animText.indexOf("animations") >= 0 ? _animText : _configText)
    on_LayoutTextChanged: _cfg = Lay.parseLayout(_layoutText + "\n" + _configText)
    on_ConfigTextChanged: _cfg = Lay.parseLayout(_layoutText + "\n" + _configText)
    on_CfgChanged: relayout()
    FileView {
        path: root.enabled ? root._niriDir + "/cfg/layout.kdl" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root._layoutText = text()
        onLoadFailed: root._layoutText = ""
    }
    FileView {
        path: root.enabled ? root._niriDir + "/cfg/animation.kdl" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root._animText = text()
        onLoadFailed: root._animText = ""
    }
    FileView {
        path: root.enabled ? root._niriDir + "/config.kdl" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root._configText = text()
        onLoadFailed: root._configText = ""
    }

    // ---- keeping it ----
    // niri numbers windows anew each session: the saved webs belong to this niri only
    readonly property string session: Quickshell.env("NIRI_SOCKET") || ""
    readonly property string file: Config.stateDir + "/cobweb.json"
    property bool _loaded: false
    AsyncFile {
        id: store
        path: root.file
        blockLoading: true
        printErrors: false
        onLoaded: root._restore(text())
        onLoadFailed: root._restore("")
    }
    function _restore(text) {
        let d = null;
        try {
            d = text ? JSON.parse(text) : null;
        } catch (e) {
            d = null;
        }
        const out = {};
        if (d && d.session === session && d.webs)
            for (const id in d.webs) {
                const w = d.webs[id];
                out[id] = {
                    "seed": w.seed >>> 0,
                    "w0": w.w0 || 0,
                    "h0": w.h0 || 0,
                    "age": Number(w.age) || 0,
                    "at": Number(w.at) || Date.now(),
                    "broken": w.broken || {},
                    "away": Number(w.away) || 0,
                    "hold": Number(w.hold) || 0
                };
            }
        webs = out;
        _steps = ({});
        _loaded = true;
        rev++;
        _sync();
        tick();
    }
    Timer {
        id: _save
        interval: 2000
        onTriggered: root.save()
    }
    Timer {
        running: root.enabled && root._loaded
        repeat: true
        interval: 60000
        onTriggered: root.save()
    }
    function save() {
        if (!_loaded || Shell.dev && Quickshell.env("ANGELOS_DEV_COBWEB") !== "1")
            return;
        store.write(JSON.stringify({
            "version": 1,
            "session": session,
            "webs": webs
        }) + "\n");
    }

    Connections {
        target: Niri
        function onWindowsChanged() {
            if (root._loaded)
                root._sync();
        }
        function onWorkspacesChanged() {
            root.relayout();
        }
    }
    Connections {
        target: Zones
        function onPartsChanged() {
            root.relayout();
        }
    }
    onEnabledChanged: if (enabled && _loaded)
        _sync()
}
