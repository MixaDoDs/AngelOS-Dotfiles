// the cobweb's geometry, growth and the windows' places (services/CobwebWeb.js, CobwebLayout.js)
import assert from "node:assert/strict";
import { load, W } from "./load.mjs";
const L = load("CobwebLayout.js");
const finite = p => Number.isFinite(p.x) && Number.isFinite(p.y);

// a web: the same seed, the same web; corners, then drapes, then the cocoon; every id once
for (const [w, h] of [[40, 30], [120, 90], [225, 473], [960, 540], [1280, 700]]) {
    const a = W.generate(7, w, h), b = W.generate(7, w, h);
    assert.deepEqual(a, b, "a seed makes one web");
    const order = { corner: 0, drape: 1, cocoon: 2 };
    let last = 0;
    const ids = new Set();
    for (const st of a) {
        assert.ok(order[st.phase] >= last, "the spider works inwards: " + st.phase);
        last = order[st.phase];
        assert.ok(st.threads.length > 0, "no empty step");
        for (const t of st.threads) {
            assert.ok(!ids.has(t.id), "thread ids are unique");
            ids.add(t.id);
            const s = W.restShape(t, w, h);
            for (const p of [s.a, s.b, s.c])
                assert.ok(finite(p) && p.x >= 0 && p.y >= 0 && p.x <= w - 1 && p.y <= h - 1, `inside the window ${w}×${h}: ${JSON.stringify(p)}`);
            assert.ok(W.curvePoints(s).every(finite));
        }
    }
    assert.ok(a.some(s => s.phase === "cocoon"), "a cocoon at the end");
    assert.ok(a.filter(s => s.phase === "cocoon").reduce((n, s) => n + s.threads.length, 0) >= 20, "the cocoon wraps the window");
}

// growth: nothing before t0, all at t1, monotone, stepAge the way back
const t0 = 30, t1 = 240, n = 60;
assert.equal(W.stepsDue(0, n, t0, t1), 0);
assert.equal(W.stepsDue(t0 - 1, n, t0, t1), 0);
assert.equal(W.stepsDue(t0, n, t0, t1), 1);
assert.equal(W.stepsDue(t1, n, t0, t1), n);
assert.equal(W.stepsDue(t1 * 5, n, t0, t1), n);
let prev = 0;
for (let age = 0; age < 300; age += 0.5) {
    const k = W.stepsDue(age, n, t0, t1);
    assert.ok(k >= prev);
    prev = k;
}
for (let i = 0; i < n; i++)
    assert.equal(W.stepsDue(W.stepAge(i, n, t0, t1), n, t0, t1), i + 1, "stepAge(i) makes step i due");

// the hit cells: marks land in their cell, rows merge
const g = W.hitGrid(64, 32, 8);
g.mark(1, 1, "a");
g.mark(9, 2, "b");
g.mark(30, 20, "c");
g.mark(-3, 2, "x");
assert.deepEqual(g.at(3, 3), ["a"]);
assert.deepEqual(g.at(12, 5), ["b"]);
assert.deepEqual(g.rects(), [{ x: 0, y: 0, w: 16, h: 8 }, { x: 24, y: 16, w: 8, h: 8 }]);

// physics settle: a kicked thread comes to rest, a piece falls and goes
const o = { x: 0, y: 0, vx: 80, vy: -40 };
let steps = 0;
while (W.wobbleStep(o, 1 / 30) && steps < 1000)
    steps++;
assert.ok(steps < 300, "a swing dies down in seconds");
const pc = W.piece([{ x: 0, y: 0 }, { x: 10, y: 0 }, { x: 20, y: 0 }], -1, 0, 0);
steps = 0;
while (W.pieceStep(pc, 1 / 30, 90) && steps < 1000)
    steps++;
assert.ok(steps < 100 && pc.pts[1].y > 0, "a loose piece falls and fades");
const [l, r] = W.breakAt(W.restShape({ a: { fx: 0, fy: 0.5 }, b: { fx: 1, fy: 0.5 }, kind: "drape" }, 100, 100), null, 0.5);
assert.equal(l.pin, 0);
assert.equal(r.pin, 0);

// niri's layout: the config read, the focused column centred, floating windows where niri says
const cfg = L.parseLayout('layout {\n    gaps 10 // the gaps\n    center-focused-column "always"\n    struts {\n        left 4\n    }\n}');
assert.deepEqual(cfg, { gaps: 10, center: "always", struts: { left: 4, right: 0, top: 0, bottom: 0 } });
const win = (id, col, w, h, focus, extra) => Object.assign({
    id, workspace_id: 1, is_floating: false, focus_timestamp: { secs: focus, nanos: 0 },
    layout: { pos_in_scrolling_layout: [col, 1], tile_size: [w, h], window_size: [w, h], window_offset_in_tile: [0, 0] }
}, extra || {});
const list = [win(1, 1, 400, 1000, 1), win(2, 2, 600, 1000, 2), {
    id: 3, workspace_id: 1, is_floating: true, focus_timestamp: { secs: 3, nanos: 0 },
    layout: { window_size: [300, 200], tile_pos_in_workspace_view: [50, 60], window_offset_in_tile: [0, 0] }
}];
const zone = { top: 0, bottom: 40, left: 0, right: 0 };
const rs = L.rects(list, { id: 1, active_window_id: 2 }, 1920, 1080, zone, cfg);
const by = Object.fromEntries(rs.map(r => [r.id, r]));
assert.equal(by[2].x, Math.round(4 + (1916 - 600) / 2), "the focused column is centred in the working area");
assert.equal(by[1].x, by[2].x - 10 - 400, "its neighbour beside it, a gap apart");
assert.equal(by[2].y, 10, "tiles start a gap below the top");
assert.deepEqual([by[3].x, by[3].y, by[3].floating], [50, 60, true]);
assert.equal(rs[rs.length - 1].id, 3, "floating windows on top");
assert.deepEqual(L.zoneEdges({ a: { screen: "DP-1", edge: "bottom", px: 40 }, b: { screen: "HDMI", edge: "top", px: 30 } }, "DP-1"), zone);

// a move: another column (same count), another place when floating — not a neighbour closing
assert.ok(L.moved(list[0], win(1, 2, 400, 1000, 1), 2, 2));
assert.ok(!L.moved(list[1], win(2, 1, 600, 1000, 2), 2, 1), "a column closed beside it");
assert.ok(L.moved(list[2], Object.assign({}, list[2], { layout: Object.assign({}, list[2].layout, { tile_pos_in_workspace_view: [90, 60] }) })));
assert.ok(!L.moved(list[2], list[2]));
assert.ok(L.moved(list[0], Object.assign({}, list[0], { workspace_id: 2 })), "to another desk");
// niri's animations: read from its config, run the way niri runs them
const A = L.parseAnims(`animations {
    // softer
    slowdown 1.2
    workspace-switch {
        duration-ms 345
        curve "cubic-bezier" 0.22 1 0.36 1
    }
    horizontal-view-movement {
        spring damping-ratio=0.85 stiffness=600 epsilon=0.0001
    }
    window-resize {
        off
    }
}`);
assert.equal(A.slowdown, 1.2);
assert.deepEqual(A.view, { kind: "spring", ratio: 0.85, k: 600, eps: 0.0001 });
assert.deepEqual(A.ws, { kind: "curve", ms: 345, curve: "cubic-bezier", bez: [0.22, 1, 0.36, 1] });
assert.equal(A.resize.kind, "off");
assert.equal(A.move.k, 800, "what the config leaves out: niri's default");
assert.equal(L.parseAnims("animations {\n    off\n}").view.kind, "off");
assert.equal(L.parseAnims("").slowdown, 1);
assert.ok(L.animAt(A.resize, 0, 1).done, "off: there at once");
assert.equal(L.animAt(A.ws, 0, A.slowdown).p, 0);
assert.ok(!L.animAt(A.ws, 400, A.slowdown).done && L.animAt(A.ws, 415, A.slowdown).done, "345 ms × slowdown 1.2");
let over = 0, sprung = null;
for (let ms = 0; ms < 3000; ms += 5) {
    sprung = L.animAt(A.view, ms, A.slowdown);
    over = Math.max(over, sprung.p);
    if (sprung.done)
        break;
}
assert.ok(sprung.done && sprung.p === 1, "a spring settles");
assert.ok(over > 1 && over < 1.05, "an underdamped spring overshoots a little");
assert.ok(L.animAt({ kind: "spring", ratio: 1.3, k: 800, eps: 0.0001 }, 2000, 1).done, "an overdamped one settles too");
console.log("cobweb: web, growth, hits, physics, layout, niri's animations — ok");
