pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import QtQuick.Effects
import "../../services/CobwebWeb.js" as Web
import "../../services/CobwebLayout.js" as Lay

// One window's cobweb (modules/cobweb/CobwebOverlay): the threads as 1-px lines in canvases of
// the window's size in art pixels, scaled up crisp; the spider on top. The threads hang (a curve
// with a sag), swing when touched (a damped spring on each), and what breaks or is shaken off
// hangs from its end or falls (short chains). Two layers: the threads at rest are drawn once
// when the web changes; only what moves (a swinging thread, the one being woven, falling bits)
// is drawn again each frame. Nothing moves without a reason: the frame clock runs only while
// something swings, falls or the spider walks, and never while the overlay is hidden.
// `hits`: where the pointer touches a thread (the overlay's input region, cells of 8 art px).
Item {
    id: view

    required property int winId
    // its window's place on the screen as niri will have it: {x, y, w, h, ws (niri's idx of its
    // desk), active (that desk in view), cause (view | move), occl (floating windows over it)}
    property var rect: null
    property bool shown: true               // the overlay is up (not under a fullscreen game)
    property real wsPos: 0                  // the desk in view, while niri slides between desks
    property real screenH: 0
    readonly property int u: Theme.u
    // drawn at the size the window rests at; while niri resizes it the drawing stretches with it
    property real pw: 0
    property real ph: 0
    readonly property int aw: Math.max(1, Math.floor(pw / u))
    readonly property int ah: Math.max(1, Math.floor(ph / u))
    readonly property real sx: width / aw   // screen px a art px, across and down
    readonly property real sy: height / ah
    readonly property int cell: 8

    // ---- moving with its window: niri tells where a window ends up, not where it is on the way,
    // so the web goes there the way niri takes the window — the same spring or curve, the same
    // slowdown (services/CobwebLayout.animAt, Cobweb.anims from niri's config) ----
    property bool settled: false            // it has a place (drawn)
    property bool moving: false
    property real cx: 0
    property real cy: 0
    x: cx
    // niri stacks desks a tenth of the screen apart
    y: cy + ((rect ? rect.ws : 0) - wsPos) * Math.round(screenH * 1.1)
    property var _from: null
    property var _to: null
    property double _t0: 0
    property var _posAnim: null
    onRectChanged: {
        const r = rect;
        if (!r)
            return;
        const to = {
            "x": r.x,
            "y": r.y,
            "w": r.w,
            "h": r.h
        };
        const l = _to;
        if (l && l.x === to.x && l.y === to.y && l.w === to.w && l.h === to.h)
            return;
        _to = to;
        if (!settled) {
            cx = to.x;
            cy = to.y;
            width = to.w;
            height = to.h;
            pw = to.w;
            ph = to.h;
            settled = true;
            paint();
            return;
        }
        _from = {
            "x": cx,
            "y": cy,
            "w": width,
            "h": height
        };
        _posAnim = r.cause === "view" ? Cobweb.anims.view : Cobweb.anims.move;
        // niri started a frame or two before its event got here: a head start to keep up
        _t0 = Date.now() - Cobweb.lagMs;
        moving = true;
        moveStep();
    }
    function moveStep() {
        const ms = Date.now() - _t0, sd = Cobweb.anims.slowdown;
        const a = Lay.animAt(_posAnim, ms, sd), b = Lay.animAt(Cobweb.anims.resize, ms, sd);
        const f = _from, t = _to;
        if (a.done && b.done) {
            cx = t.x;
            cy = t.y;
            width = t.w;
            height = t.h;
            moving = false;
            // at rest at a new size: drawn anew for it
            if (pw !== t.w || ph !== t.h) {
                pw = t.w;
                ph = t.h;
            }
            return;
        }
        cx = f.x + (t.x - f.x) * a.p;
        cy = f.y + (t.y - f.y) * a.p;
        width = f.w + (t.w - f.w) * b.p;
        height = f.h + (t.h - f.h) * b.p;
    }
    FrameAnimation {
        running: view.moving
        onTriggered: view.moveStep()
    }
    onMovingChanged: if (!moving)
        hitsLater.restart()

    // the window you work in: its cocoon faint (its menus open over it, the threads stay out of
    // the way); the others in full
    readonly property bool focused: Niri.focusedWindowId === winId
    property real ink: focused ? 0.35 : 1
    Behavior on ink {
        NumberAnimation {
            duration: Motion.ms(260)
        }
    }
    opacity: settled ? 1 : 0
    visible: opacity > 0
    Behavior on opacity {
        NumberAnimation {
            duration: Motion.ms(220)
        }
    }

    // the parts of it under floating windows (niri keeps them over the tiles): cut out
    readonly property var holes: (rect && rect.occl || []).map(o => ({
                "x": o.x - rect.x,
                "y": o.y - rect.y,
                "w": o.w,
                "h": o.h
            }))
    onHolesChanged: {
        holeMask.requestPaint();
        updateHits();
    }

    // ---- the web as the service has it ----
    readonly property var steps: (Cobweb.rev, Cobweb.steps(winId))
    readonly property int due: (Cobweb.rev, Cobweb.due(winId))
    readonly property var broken: (Cobweb.rev, (Cobweb.web(winId) || {}).broken || ({}))
    readonly property bool here: (Cobweb.rev, Cobweb.now, Cobweb.spiderHere(winId))

    property var shapes: []                 // per step: [{id, s, pts, dew}] (pts: the curve at rest)
    property var phases: []                 // per step: corner | drape | cocoon
    function rebuild() {
        const out = [];
        phases = steps.map(st => st.phase);
        for (const st of steps)
            out.push(st.threads.map(t => {
                const sh = Web.restShape(t, aw, ah);
                return {
                    "id": t.id,
                    "s": sh,
                    "pts": Web.curvePoints(sh),
                    "wrap": t.kind === "wrap",
                    "dew": !!t.dew
                };
            }));
        shapes = out;
    }
    onStepsChanged: {
        rebuild();
        paint();
    }
    onAwChanged: {
        rebuild();
        paint();
    }
    onAhChanged: {
        rebuild();
        paint();
    }
    onDueChanged: {
        // shaken off or cleared: no weaving of what is gone
        if (weave && weave.step >= due) {
            weave = null;
            weaveQ = [];
        }
        weaveQ = weaveQ.filter(k => k < due);
        if (!weave && !weaveQ.length)
            placeSpider();
        paint();
        hitsLater.restart();
        wake();
    }
    // what the pointer can touch changes with these (hitsLater); what is drawn too (paint)
    onBrokenChanged: {
        paint();
        hitsLater.restart();
    }
    // a step woven goes over to the still layer; one torn off by a swipe leaves it
    onWeaveQChanged: {
        paint();
        hitsLater.restart();
    }
    onWeaveChanged: {
        paint();
        hitsLater.restart();
    }
    onHiddenChanged: {
        paint();
        hitsLater.restart();
    }
    onShapesChanged: hitsLater.restart()
    onCoolingChanged: hitsLater.restart()
    onSettledChanged: hitsLater.restart()
    Timer {
        id: hitsLater
        interval: 120
        onTriggered: view.computeHits()
    }
    onHereChanged: {
        if (here && spider.mode === "gone")
            dropIn();
    }

    // ---- what moves ----
    property var wob: ({})                  // thread id -> {x, y, vx, vy}
    property var pieces: []                 // broken off: Web.piece chains
    property var hidden: ({})               // torn off by a QTE swipe (back if the QTE is lost)
    property var cooling: ({})              // thread id -> ms: just touched, not touchable
    property var weaveQ: []                 // steps to weave, in order
    property var weave: null                // {step, ti, t}
    property var spider: ({
            "x": 0,
            "y": 0,
            "mode": "gone",
            "tx": 0,
            "ty": 0,
            "sx": 0,
            "legs": 0
        })
    property bool legs: false
    property var lastTouch: null
    property string lastSwipe: ""
    property bool active: false
    function wake() {
        if (!active) {
            active = true;
            last = Date.now();
        }
    }
    property double last: 0

    function shape(id) {
        for (const st of shapes)
            for (const t of st)
                if (t.id === id)
                    return t;
        return null;
    }
    // the steps still to weave (queued, or being woven): not drawn whole yet
    function pending() {
        const p = {};
        for (const k of weaveQ)
            p[k] = true;
        if (weave)
            p[weave.step] = true;
        return p;
    }
    function drawnThreads() {
        const out = [];
        const todo = pending();
        for (let i = 0; i < Math.min(due, shapes.length); i++)
            if (!todo[i])
                for (const t of shapes[i])
                    if (!broken[t.id] && !hidden[t.id])
                        out.push(t);
        return out;
    }
    function endOf(t) {
        return Web.bezier(t.s, 1, wob[t.id]);
    }
    // where the spider rests: the end of the last thread there is, else where the first will start
    function restPoint() {
        const upto = Math.min(due, shapes.length);
        for (let i = upto - 1; i >= 0; i--)
            for (let j = shapes[i].length - 1; j >= 0; j--)
                if (!broken[shapes[i][j].id])
                    return endOf(shapes[i][j]);
        const first = shapes.length ? shapes[0][0] : null;
        return first ? first.s.a : {
            "x": 4,
            "y": 4
        };
    }
    function placeSpider() {
        if (!here) {
            if (spider.mode !== "flee")
                spider = Object.assign({}, spider, {
                    "mode": "gone"
                });
            return;
        }
        if (spider.mode === "gone") {
            dropIn();
            return;
        }
        const p = restPoint();
        spider = Object.assign({}, spider, {
            "mode": "walk",
            "tx": p.x,
            "ty": p.y
        });
        wake();
    }
    function dropIn() {
        if (!here)
            return;
        const p = weaveQ.length || weave ? startOfStep(weave ? weave.step : weaveQ[0]) : restPoint();
        spider = {
            "x": p.x,
            "y": -8,
            "mode": "drop",
            "tx": p.x,
            "ty": p.y,
            "sx": p.x,
            "legs": 0
        };
        wake();
    }
    function startOfStep(k) {
        const st = shapes[k];
        return st && st.length ? st[0].s.a : restPoint();
    }
    function fleeOut() {
        if (spider.mode === "gone")
            return;
        // to the nearest edge, and behind the window
        const d = [
            {
                "x": -8,
                "y": spider.y,
                "d": spider.x
            },
            {
                "x": aw + 8,
                "y": spider.y,
                "d": aw - spider.x
            },
            {
                "x": spider.x,
                "y": -8,
                "d": spider.y
            },
            {
                "x": spider.x,
                "y": ah + 8,
                "d": ah - spider.y
            }
        ].sort((a, b) => a.d - b.d)[0];
        spider = Object.assign({}, spider, {
            "mode": "flee",
            "tx": d.x,
            "ty": d.y
        });
        weave = null;
        weaveQ = [];
        wake();
    }
    function startWeave() {
        if (weave || !weaveQ.length || !here)
            return;
        const k = weaveQ[0];
        weaveQ = weaveQ.slice(1);
        if (k >= shapes.length)
            return;
        weave = {
            "step": k,
            "ti": 0,
            "t": 0
        };
        const a = shapes[k][0].s.a;
        if (spider.mode === "gone")
            dropIn();
        else
            spider = Object.assign({}, spider, {
                "mode": "walk",
                "tx": a.x,
                "ty": a.y
            });
        wake();
    }
    function kick(id, vx, vy) {
        if (!wob[id])
            _stillDirty = true;
        const o = wob[id] && !wob[id].still ? wob[id] : {
            "x": 0,
            "y": 0,
            "vx": 0,
            "vy": 0
        };
        o.vx += vx;
        o.vy += vy;
        wob[id] = o;
        wake();
    }
    function throwOff(list, vx, vy) {
        const add = [];
        for (const t of list) {
            const pts = Web.curvePoints(t.s, wob[t.id]);
            add.push(Web.piece(pts, -1, vx + (Math.random() - 0.5) * 60, vy + (Math.random() - 0.5) * 60 - 20));
        }
        pieces = pieces.concat(add).slice(-160);
        wake();
    }

    // ---- the frame clock ----
    Timer {
        interval: 33
        repeat: true
        running: view.active && view.settled && view.shown
        onTriggered: view.frame()
    }
    function frame() {
        const t = Date.now();
        const dt = Math.min(0.05, (t - last) / 1000);
        last = t;
        let busy = false;
        for (const id in wob)
            if (!wob[id].still && Web.wobbleStep(wob[id], dt))
                busy = true;
            else
                wob[id] = {
                    "x": 0,
                    "y": 0,
                    "vx": 0,
                    "vy": 0,
                    "still": true
                };
        if (pieces.length) {
            pieces = pieces.filter(p => Web.pieceStep(p, dt, 90));
            busy = busy || pieces.length > 0;
        }
        busy = moveSpider(dt) || busy;
        if (!busy) {
            // all at rest: what swung goes back to the still layer
            active = false;
            if (Object.keys(wob).length) {
                wob = ({});
                _stillDirty = true;
            }
        }
        if (_stillDirty)
            paint();
        else
            liveCanvas.requestPaint();
    }
    property real _legT: 0
    function moveSpider(dt) {
        const sp = spider;
        if (sp.mode === "gone" || sp.mode === "idle")
            return false;
        _legT += dt;
        if (_legT > 0.11) {
            _legT = 0;
            legs = !legs;
        }
        if (sp.mode === "weave" && weave) {
            const th = shapes[weave.step][weave.ti];
            const speed = 38;
            weave.t += speed * dt / Math.max(4, th.s.len);
            if (weave.t >= 1) {
                weave.t = 0;
                weave.ti++;
                if (weave.ti >= shapes[weave.step].length) {
                    weave = null;
                    spider = Object.assign({}, sp, {
                        "mode": "idle"
                    });
                    if (weaveQ.length)
                        startWeave();
                    return true;
                }
                // the next thread of the step starts where this one ends, or the spider walks there
                const nx = shapes[weave.step][weave.ti].s.a;
                const p = Web.bezier(th.s, 1);
                if (Math.hypot(nx.x - p.x, nx.y - p.y) > 2) {
                    spider = Object.assign({}, sp, {
                        "mode": "walk",
                        "tx": nx.x,
                        "ty": nx.y
                    });
                    return true;
                }
            }
            const cur = shapes[weave.step][weave.ti];
            const p = Web.bezier(cur.s, weave.t, wob[cur.id]);
            spider = Object.assign({}, sp, {
                "x": p.x,
                "y": p.y
            });
            return true;
        }
        const speed = sp.mode === "flee" ? 150 : sp.mode === "drop" ? 70 : 60;
        const dx = sp.tx - sp.x, dy = sp.ty - sp.y, d = Math.hypot(dx, dy);
        const stepLen = speed * dt;
        if (d <= stepLen) {
            const at = Object.assign({}, sp, {
                "x": sp.tx,
                "y": sp.ty
            });
            if (sp.mode === "flee")
                at.mode = "gone";
            else if (weave)
                at.mode = "weave";
            else
                at.mode = "idle";
            spider = at;
            if (at.mode === "idle" && weaveQ.length)
                startWeave();
            return at.mode !== "idle" && at.mode !== "gone";
        }
        spider = Object.assign({}, sp, {
            "x": sp.x + dx / d * stepLen,
            "y": sp.y + dy / d * stepLen
        });
        return true;
    }

    // ---- painting ----
    property var grid: null
    property bool _stillDirty: false
    // the web changed: both layers (the frame clock draws only the live one)
    function paint() {
        if (!settled)
            return;
        _stillDirty = false;
        stillCanvas.requestPaint();
        liveCanvas.requestPaint();
    }
    // 1-px threads, a dark shadow one pixel down-right under the silk: they read on white pages
    // and on black ones. `polys`: lists of points in art px
    function stroke(ctx, polys, fade) {
        for (const pass of [0, 1]) {
            const d = pass ? 0.5 : 1.5;
            ctx.strokeStyle = pass ? Qt.rgba(236 / 255, 232 / 255, 250 / 255, 0.82 * fade) : Qt.rgba(12 / 255, 8 / 255, 24 / 255, 0.55 * fade);
            ctx.beginPath();
            for (const pts of polys) {
                if (pts.length < 2)
                    continue;
                ctx.moveTo(Math.round(pts[0].x) + d, Math.round(pts[0].y) + d);
                for (let k = 1; k < pts.length; k++)
                    ctx.lineTo(Math.round(pts[k].x) + d, Math.round(pts[k].y) + d);
            }
            ctx.stroke();
        }
    }
    // the threads at rest that are there to see
    function restingThreads() {
        const out = [];
        const todo = pending();
        for (let i = 0; i < Math.min(due, shapes.length); i++)
            if (!todo[i])
                for (const t of shapes[i])
                    if (!broken[t.id] && !hidden[t.id])
                        out.push(t);
        return out;
    }
    component Layer: Canvas {
        width: view.aw
        height: view.ah
        transform: Scale {
            xScale: view.sx
            yScale: view.sy
        }
        smooth: false
        antialiasing: false
        renderTarget: Canvas.Image
    }
    // how far the cocoon is wound (0…1): its silk haze thickens over the window
    function cocooned() {
        const todo = pending();
        let all = 0, done = 0;
        for (let i = 0; i < shapes.length; i++)
            if (phases[i] === "cocoon")
                for (const t of shapes[i]) {
                    all++;
                    if (i < due && !todo[i] && !broken[t.id] && !hidden[t.id])
                        done++;
                }
        return all ? done / all : 0;
    }
    // what is drawn: the two layers and the spider, with the holes cut out
    Item {
        id: content
        anchors.fill: parent
        layer.enabled: view.holes.length > 0
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: holeMask
            maskThresholdMin: 0.5
        }
        Layer {
            id: stillCanvas
            opacity: view.ink
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                // the haze: a sparse pixel dither of silk, thickest at the edges, closer as the
                // cocoon closes; the middle stays readable
                const c = view.cocooned(), W = view.aw, H = view.ah, S = Math.min(W, H);
                const silk = Qt.rgba(0.93, 0.91, 0.98, 0.45);
                // a frame of the dither from inset a to inset b
                const rim = (a, b, pattern) => {
                    a = Math.round(a);
                    b = Math.round(b);
                    if (b <= a || 2 * b >= S)
                        return;
                    ctx.fillStyle = ctx.createPattern(silk, pattern);
                    ctx.fillRect(a, a, W - 2 * a, b - a);
                    ctx.fillRect(a, H - b, W - 2 * a, b - a);
                    ctx.fillRect(a, b, b - a, H - 2 * b);
                    ctx.fillRect(W - b, b, b - a, H - 2 * b);
                };
                if (c > 0.25)
                    rim(c > 0.45 ? S * 0.05 : 0, S * (0.08 + 0.08 * c), Qt.Dense7Pattern);
                if (c > 0.45)
                    rim(c > 0.75 ? S * 0.02 : 0, S * 0.05, Qt.Dense6Pattern);
                if (c > 0.75)
                    rim(0, S * 0.02, Qt.Dense5Pattern);
                ctx.lineWidth = 1;
                const list = view.restingThreads().filter(t => !view.wob[t.id]);
                // the frame of the web brighter, the cocoon's windings softer
                view.stroke(ctx, list.filter(t => !t.wrap).map(t => t.pts), 1);
                view.stroke(ctx, list.filter(t => t.wrap).map(t => t.pts), 0.5);
                for (const t of list)
                    if (t.dew) {
                        const m = Web.bezier(t.s, 0.5);
                        ctx.fillStyle = Qt.rgba(12 / 255, 8 / 255, 24 / 255, 0.6);
                        ctx.fillRect(Math.round(m.x) + 1, Math.round(m.y) + 1, 1, 1);
                        ctx.fillStyle = "#ffffff";
                        ctx.fillRect(Math.round(m.x), Math.round(m.y), 1, 1);
                    }
            }
        }
        Layer {
            id: liveCanvas
            opacity: view.ink
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.lineWidth = 1;
                const todo = view.pending();
                const polys = [], wraps = [];
                for (const id in view.wob) {
                    const t = view.shape(id);
                    if (t && !view.broken[id] && !view.hidden[id] && !todo[t.id.split(".")[0]])
                        (t.wrap ? wraps : polys).push(Web.curvePoints(t.s, view.wob[id]));
                }
                // the step being woven: as far as the spider has got
                const w = view.weave;
                if (w && w.step < view.shapes.length) {
                    const st = view.shapes[w.step];
                    for (let j = 0; j <= w.ti && j < st.length; j++)
                        if (!view.broken[st[j].id])
                            (st[j].wrap ? wraps : polys).push(j < w.ti ? st[j].pts : Web.curvePoints(st[j].s, view.wob[st[j].id], view.spider.mode === "weave" ? w.t : 0));
                }
                // the dragline it comes down on
                if (view.spider.mode === "drop")
                    polys.push([
                        {
                            "x": view.spider.sx,
                            "y": 0
                        },
                        {
                            "x": view.spider.x,
                            "y": view.spider.y
                        }
                    ]);
                view.stroke(ctx, polys, 1);
                view.stroke(ctx, wraps, 0.5);
                for (const pc of view.pieces)
                    view.stroke(ctx, [pc.pts], Web.pieceFade(pc));
            }
        }

        PixelSpider {
            visible: view.spider.mode !== "gone" && view.settled
            pixel: view.u
            step: view.legs
            opacity: Math.max(0.6, view.ink)
            x: view.spider.x * view.sx - width / 2
            y: view.spider.y * view.sy - height / 2
        }
    }
    Canvas {
        id: holeMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = "#ffffff";
            ctx.fillRect(0, 0, width, height);
            for (const h of view.holes)
                ctx.clearRect(h.x, h.y, h.w, h.h);
        }
    }

    // a miss in the QTE: the window flashes red, like taking damage
    Rectangle {
        id: hurt
        anchors.fill: parent
        color: Qt.rgba(1, 0.1, 0.2, 0.18)
        border.width: view.u * 3
        border.color: "#ff2e4d"
        opacity: 0
        SequentialAnimation {
            id: hurtAnim
            NumberAnimation {
                target: hurt
                property: "opacity"
                to: 1
                duration: 60
            }
            NumberAnimation {
                target: hurt
                property: "opacity"
                to: 0
                duration: Motion.calm ? 500 : 380
                easing.type: Easing.InQuad
            }
        }
    }

    // ---- the pointer ----
    property var hits: []
    // the cells the threads pass through (of `cell` art px), the threads in each
    // the window's top strip (its title bar, a browser's tabs) is left to the window: it is
    // dragged by it, and a press there must reach it
    readonly property int topFree: Math.ceil(Theme.u * 18 / u / cell) * cell
    function computeHits() {
        const g = Web.hitGrid(aw, ah, cell);
        const now = Date.now(), step = cell / 2, top = topFree;
        for (const t of restingThreads()) {
            if (cooling[t.id] > now)
                continue;
            const p = t.pts;
            for (let k = 0; k + 1 < p.length; k++) {
                const dx = p[k + 1].x - p[k].x, dy = p[k + 1].y - p[k].y;
                const n = Math.max(1, Math.ceil(Math.hypot(dx, dy) / step));
                for (let i = 0; i <= n; i++) {
                    const y = Math.round(p[k].y + dy * i / n);
                    if (y >= top)
                        g.mark(Math.round(p[k].x + dx * i / n), y, t.id);
                }
            }
        }
        grid = g;
        updateHits();
    }
    // the cells in screen px — only on the desk in view, never under a floating window
    function updateHits() {
        const g = grid;
        const out = [];
        if (g && settled && rect && rect.active)
            for (const r of g.rects()) {
                const c = {
                    "x": r.x * u,
                    "y": r.y * u,
                    "w": r.w * u,
                    "h": r.h * u
                };
                if (holes.some(h => c.x < h.x + h.w && c.x + c.w > h.x && c.y < h.y + h.h && c.y + c.h > h.y))
                    continue;
                out.push({
                    "x": rect.x + c.x,
                    "y": rect.y + c.y,
                    "w": c.w,
                    "h": c.h
                });
            }
        hits = out;
    }
    // the pointer came over a thread at (px, py) in the view
    function touchAt(px, py) {
        if (!grid || Cobweb.qte)
            return;
        const ax = px / u, ay = py / u;
        const now = Date.now();
        let best = null;
        for (const id of grid.at(ax, ay)) {
            const t = shape(id);
            if (!t || broken[id] || hidden[id] || cooling[id] > now)
                continue;
            const n = Web.nearest(t.s, wob[id], ax, ay);
            if (!best || n.d < best.n.d)
                best = {
                    "t": t,
                    "n": n
                };
        }
        if (!best)
            return;
        lastTouch = {
            "x": ax,
            "y": ay,
            "t": best.n.t
        };
        const c = Object.assign({}, cooling);
        c[best.t.id] = now + 3000;
        cooling = c;
        coolEnd.restart();
        const res = Cobweb.touch(winId, best.t.id);
        if (res !== "break")
            kick(best.t.id, (Math.random() - 0.5) * 140, 60 + Math.random() * 60);
        paint();
    }
    Timer {
        id: coolEnd
        interval: 3100
        onTriggered: view.cooling = ({})
    }

    // ---- what the service says happened ----
    Connections {
        target: Cobweb
        function onWoven(id, from, to) {
            if (id !== view.winId)
                return;
            const q = view.weaveQ.slice();
            for (let k = from; k < to; k++)
                q.push(k);
            view.weaveQ = q;
            view.startWeave();
        }
        function onBroke(id, thread) {
            if (id !== view.winId)
                return;
            const t = view.shape(thread);
            if (t) {
                const at = view.lastTouch ? view.lastTouch.t : 0.5;
                view.pieces = view.pieces.concat(Web.breakAt(t.s, view.wob[thread], at));
                view.wake();
            }
        }
        function onFled(id) {
            if (id === view.winId)
                view.fleeOut();
        }
        function onReturned(id) {
            if (id === view.winId)
                view.dropIn();
        }
        function onCleared(id, why) {
            if (id !== view.winId)
                return;
            const dir = {
                "left": [-220, -40],
                "right": [220, -40],
                "up": [0, -240],
                "down": [0, 160]
            }[view.lastSwipe] || [0, 40];
            view.throwOff(view.drawnThreads(), why === "qte" ? dir[0] : 0, why === "qte" ? dir[1] : 30);
            view.hidden = ({});
            view.weave = null;
            view.weaveQ = [];
            view.fleeOut();
        }
        function onShaken(id, from, to) {
            if (id !== view.winId)
                return;
            const list = [];
            for (let i = from; i < Math.min(to, view.shapes.length); i++)
                for (const t of view.shapes[i])
                    if (!view.broken[t.id] && !view.hidden[t.id])
                        list.push(t);
            view.throwOff(list, 0, 30);
            for (const t of view.drawnThreads())
                view.kick(t.id, (Math.random() - 0.5) * 160, (Math.random() - 0.5) * 120);
        }
        function onSwiped(id, dir) {
            if (id !== view.winId)
                return;
            view.lastSwipe = dir;
            const q = Cobweb.qte;
            const left = q ? q.seq.length - q.i + 1 : 1;
            const list = view.drawnThreads();
            const n = Math.max(1, Math.ceil(list.length / left));
            const pick = list.sort(() => Math.random() - 0.5).slice(0, n);
            const h = Object.assign({}, view.hidden);
            for (const t of pick)
                h[t.id] = true;
            view.hidden = h;
            const v = {
                "left": [-260, -30],
                "right": [260, -30],
                "up": [0, -280],
                "down": [0, 200]
            }[dir];
            view.throwOff(pick, v[0], v[1]);
            for (const t of list)
                view.kick(t.id, v[0] * 0.3, v[1] * 0.3);
        }
        function onDamaged(id) {
            if (id === view.winId)
                hurtAnim.restart();
        }
        function onQteChanged() {
            // a QTE lost or let go: what it tore off grows back
            if (!Cobweb.qte || Cobweb.qte.phase === "lost")
                if (Object.keys(view.hidden).length && (!Cobweb.qte || Cobweb.qte.id === view.winId)) {
                    view.hidden = ({});
                    view.paint();
                }
        }
    }

    // now and then, at rest, a leg moves
    Timer {
        interval: 3000 + Math.random() * 6000
        repeat: true
        running: view.settled && view.spider.mode === "idle"
        onTriggered: {
            interval = 3000 + Math.random() * 6000;
            view.legs = !view.legs;
            twitchBack.start();
        }
    }
    Timer {
        id: twitchBack
        interval: 180
        onTriggered: view.legs = !view.legs
    }

    Component.onCompleted: {
        rebuild();
        if (here)
            spider = Object.assign({}, spider, restPoint(), {
                "mode": "idle"
            });
    }
}
