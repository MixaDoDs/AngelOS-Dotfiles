.pragma library

// The cobweb's geometry, growth, physics and hit cells (services/Cobweb, modules/cobweb). Pure
// functions on plain objects, so tests/cobweb/test_web.mjs runs them in node.
//
// Everything is in art pixels of the window (its logical size / Theme.u), origin top-left.
// A web is a list of STEPS in the order the spider weaves them; a step is a few threads.
//   1. corners: in each corner a little triangle web — a bridge across the corner, radials from
//      the corner to it, rings between them (top corners first: the spider comes from above)
//   2. drapes: long sagging threads along the edges from one corner web to the next
//   3. the cocoon: bands of silk wound round the whole window — round its edges first, then
//      slanting one way, the other way across them, closer each layer — at the last step the
//      window is wrapped up (a haze of silk over it, thickest at the edges: modules/cobweb)
// Points are kept relative to a corner (art px inward) or as fractions of the window, so a web
// survives a resize: corner webs stay the size they were, the cocoon stretches.

function rng(seed) {
    let a = seed >>> 0;
    return function () {
        a = (a + 0x6D2B79F5) | 0;
        let t = Math.imul(a ^ (a >>> 15), 1 | a);
        t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
}

function hash(text) {
    let h = 2166136261;
    const s = String(text);
    for (let i = 0; i < s.length; i++) {
        h ^= s.charCodeAt(i);
        h = Math.imul(h, 16777619);
    }
    return h >>> 0;
}

// p: {c: "tl"|"tr"|"bl"|"br", x, y} (art px inward from that corner) or {fx, fy} (0…1)
function resolve(p, W, H) {
    if (p.c !== undefined) {
        const x = Math.min(p.x, W - 1), y = Math.min(p.y, H - 1);
        return {
            "x": p.c[1] === "r" ? W - 1 - x : x,
            "y": p.c[0] === "b" ? H - 1 - y : y
        };
    }
    return {
        "x": p.fx * (W - 1),
        "y": p.fy * (H - 1)
    };
}

function cornerPoint(c, u, v) {
    return {
        "c": c,
        "x": Math.max(0, u),
        "y": Math.max(0, v)
    };
}

// the steps of a web for a window of W × H art px (the size it had when the spider began)
function generate(seed, W, H) {
    const r = rng(seed);
    const steps = [];
    const short = Math.min(W, H);
    const R = Math.max(12, Math.min(110, short * (0.22 + r() * 0.08)));
    const corners = ["tl", "tr", "bl", "br"];
    const size = {};
    for (const c of corners) {
        const ra = R * (0.8 + r() * 0.45), rb = R * (0.8 + r() * 0.45);
        size[c] = {
            "a": ra,
            "b": rb
        };
        // bridge: from the horizontal edge to the vertical one
        steps.push({
            "phase": "corner",
            "corner": c,
            "threads": [
                {
                    "a": cornerPoint(c, ra, 0),
                    "b": cornerPoint(c, 0, rb),
                    "kind": "frame"
                }
            ]
        });
        const m = 3 + Math.floor(r() * 2);
        const ts = [];
        for (let k = 1; k <= m; k++)
            ts.push(k / (m + 1) + (r() - 0.5) * 0.08);
        for (const t of ts)
            steps.push({
                "phase": "corner",
                "corner": c,
                "threads": [
                    {
                        "a": cornerPoint(c, 0, 0),
                        "b": cornerPoint(c, ra * (1 - t), rb * t),
                        "kind": "radial"
                    }
                ]
            });
        const n = 3 + Math.floor(r() * 3);
        for (let i = n; i >= 1; i--) {
            const s = i / (n + 1) * (0.92 + r() * 0.1);
            // the ring crosses: the horizontal edge, each radial, the vertical edge
            const pts = [cornerPoint(c, ra * s, 0)];
            for (const t of ts)
                pts.push(cornerPoint(c, ra * (1 - t) * s, rb * t * s));
            pts.push(cornerPoint(c, 0, rb * s));
            const threads = [];
            for (let j = 0; j + 1 < pts.length; j++)
                threads.push({
                    "a": pts[j],
                    "b": pts[j + 1],
                    "kind": "ring",
                    "hub": cornerPoint(c, 0, 0),
                    "dew": r() < 0.18
                });
            steps.push({
                "phase": "corner",
                "corner": c,
                "threads": threads
            });
        }
    }
    // drapes along the edges, corner web to corner web
    const drapes = [[cornerPoint("tl", size.tl.a, 0), cornerPoint("tr", size.tr.a, 0)], [cornerPoint("tl", 0, size.tl.b), cornerPoint("bl", 0, size.bl.b)], [cornerPoint("tr", 0, size.tr.b), cornerPoint("br", 0, size.br.b)], [cornerPoint("bl", size.bl.a, 0), cornerPoint("br", size.br.a, 0)]];
    for (const d of drapes)
        steps.push({
            "phase": "drape",
            "threads": [
                {
                    "a": d[0],
                    "b": d[1],
                    "kind": "drape"
                }
            ]
        });
    // the cocoon: the spider winds silk round the whole window in bands — a few strands side by
    // side, like a wrapped-up fly. First round the edges, then slanting bands one way, the other
    // way across them, closer each layer; the middle stays thinnest (the page shows through)
    const ws = Math.max(1, W - 1), hs = Math.max(1, H - 1);
    const fr = (x, y) => ({
            "fx": Math.max(0, Math.min(1, x / ws)),
            "fy": Math.max(0, Math.min(1, y / hs))
        });
    // a band along the line y = c - k·x across the window: `n` strands `sp` px apart
    const band = (c, k, n, sp) => {
        const out = [];
        const norm = Math.sqrt(1 + k * k);
        for (let m = 0; m < n; m++) {
            const cc = c + (m - (n - 1) / 2) * sp * norm + (r() - 0.5) * 0.8;
            const kk = k * (1 + (r() - 0.5) * 0.06);
            const pts = [];
            const y0 = cc, y1 = cc - kk * ws;
            if (y0 >= 0 && y0 <= hs)
                pts.push([0, y0]);
            if (y1 >= 0 && y1 <= hs)
                pts.push([ws, y1]);
            if (Math.abs(kk) > 1e-6)
                for (const yy of [0, hs]) {
                    const x = (cc - yy) / kk;
                    if (x > 0 && x < ws)
                        pts.push([x, yy]);
                }
            if (pts.length < 2)
                continue;
            pts.sort((a, b) => a[0] - b[0]);
            let a = pts[0], b = pts[pts.length - 1];
            if (Math.hypot(b[0] - a[0], b[1] - a[1]) < short * 0.12)
                continue;
            if (m % 2) {
                const x = a;
                a = b;
                b = x;
            }
            out.push({
                "a": fr(a[0], a[1]),
                "b": fr(b[0], b[1]),
                "kind": "wrap"
            });
        }
        return out;
    };
    // round the edges: a band along each side, just inside it
    const inset = Math.max(3, short * 0.04);
    const edge = (x0, y0, x1, y1) => {
        const out = [];
        const n = 2 + Math.floor(r() * 2);
        for (let m = 0; m < n; m++) {
            const d = inset + m * 2.5 + r();
            const nx = y1 - y0, ny = x0 - x1, nl = Math.hypot(nx, ny) || 1;
            const ox = nx / nl * d, oy = ny / nl * d;
            out.push({
                "a": fr(x0 + ox, y0 + oy),
                "b": fr(x1 + ox, y1 + oy),
                "kind": "wrap"
            });
        }
        return out;
    };
    for (const e of [[0, 0, ws, 0], [ws, 0, ws, hs], [ws, hs, 0, hs], [0, hs, 0, 0]])
        steps.push({
            "phase": "cocoon",
            "threads": edge(e[0], e[1], e[2], e[3])
        });
    // the slanting layers: the bands of a layer spread over the window, the next layer across
    const layers = [[1, 0.45, 2], [-1, 0.45, 2], [1, 0.32, 3], [-1, 0.32, 3]];
    for (const L of layers) {
        const k = L[0] * (0.45 + r() * 0.3);
        const gap = short * L[1] * (0.9 + r() * 0.2);
        const dc = gap * Math.sqrt(1 + k * k);
        const lo = Math.min(0, -k * ws), hi = Math.max(hs, hs - k * ws);
        for (let c = lo + dc * (0.35 + r() * 0.3); c < hi; c += dc) {
            const th = band(c + (r() - 0.5) * dc * 0.25, k, L[2] + Math.floor(r() * 2), 2.2 + r() * 1.2);
            if (th.length)
                steps.push({
                    "phase": "cocoon",
                    "threads": th
                });
        }
    }
    // number every thread: "step.thread"
    steps.forEach((s, i) => s.threads.forEach((t, j) => t.id = i + "." + j));
    return steps;
}

// growth: step i is due at t0 + (t1 - t0) · i / (n - 1), age = ms of the spider's work
function stepsDue(age, n, t0, t1) {
    if (age < t0 || n <= 0)
        return 0;
    if (n === 1)
        return 1;
    // (a step's own age makes it due: no float crumb below it)
    return Math.min(n, Math.floor((age - t0) / ((t1 - t0) / (n - 1)) + 1e-9) + 1);
}
function stepAge(i, n, t0, t1) {
    if (n <= 1)
        return t0;
    return t0 + (t1 - t0) * i / (n - 1);
}

// a thread at rest: its two ends and the control point of a quadratic curve that hangs it
const SAG = {
    "frame": 0.03,
    "radial": 0.015,
    "ring": 0.05,
    "drape": 0.09,
    "wrap": 0.035
};
function restShape(t, W, H) {
    const A = resolve(t.a, W, H), B = resolve(t.b, W, H);
    const dx = B.x - A.x, dy = B.y - A.y;
    const len = Math.hypot(dx, dy);
    const flat = len > 0 ? Math.abs(dx) / len : 0;
    const sag = (SAG[t.kind] || 0.04) * len * (0.35 + 0.65 * flat);
    let cx = (A.x + B.x) / 2, cy = (A.y + B.y) / 2;
    // a ring's segment bows in toward its hub, like the capture spiral of a real web
    if (t.hub) {
        const hub = resolve(t.hub, W, H);
        const hx = hub.x - cx, hy = hub.y - cy, hd = Math.hypot(hx, hy) || 1;
        const pull = Math.min(len * 0.14, hd * 0.5);
        cx += hx / hd * pull;
        cy += hy / hd * pull;
    }
    return {
        "a": A,
        "b": B,
        "c": {
            "x": Math.max(0, Math.min(W - 1, cx)),
            "y": Math.max(0, Math.min(H - 1, cy + sag * (t.hub ? 0.5 : 1)))
        },
        "len": len
    };
}

function bezier(s, t, off) {
    const cx = s.c.x + (off ? off.x : 0), cy = s.c.y + (off ? off.y : 0);
    const u = 1 - t;
    return {
        "x": u * u * s.a.x + 2 * u * t * cx + t * t * s.b.x,
        "y": u * u * s.a.y + 2 * u * t * cy + t * t * s.b.y
    };
}

// the points of a curve from t = 0 to `upto` (a thread being woven is drawn as far as the spider)
function curvePoints(s, off, upto) {
    const end = upto === undefined ? 1 : Math.max(0, Math.min(1, upto));
    const n = Math.max(2, Math.ceil(s.len * end / 3) + 1);
    const out = [];
    for (let i = 0; i <= n; i++)
        out.push(bezier(s, end * i / n, off));
    return out;
}

// where the pointer can touch threads: cells of `size` art px that a thread passes through,
// each with the threads in it; rects() merges a row's neighbours into one rectangle
function hitGrid(W, H, size) {
    const cols = Math.ceil(W / size);
    const map = {};
    return {
        "size": size,
        "mark": function (x, y, id) {
            if (x < 0 || y < 0 || x >= W || y >= H || !id)
                return;
            const k = Math.floor(y / size) * cols + Math.floor(x / size);
            const list = map[k] || (map[k] = []);
            if (list[list.length - 1] !== id && !list.includes(id))
                list.push(id);
        },
        "at": function (x, y) {
            return map[Math.floor(y / size) * cols + Math.floor(x / size)] || [];
        },
        "rects": function () {
            const keys = Object.keys(map).map(Number).sort((a, b) => a - b);
            const out = [];
            let cur = null;
            for (const k of keys) {
                const row = Math.floor(k / cols), col = k % cols;
                if (cur && cur.row === row && cur.col + cur.n === col) {
                    cur.n++;
                    continue;
                }
                cur = {
                    "row": row,
                    "col": col,
                    "n": 1
                };
                out.push(cur);
            }
            return out.map(c => ({
                        "x": c.col * size,
                        "y": c.row * size,
                        "w": c.n * size,
                        "h": size
                    }));
        }
    };
}

// ---- physics: a thread swings on its control point (a damped spring); a piece that broke off
// hangs from one end or falls free as a short chain ----
function wobbleStep(o, dt) {
    const k = 60, damp = 5.5;
    o.vx += (-k * o.x - damp * o.vx) * dt;
    o.vy += (-k * o.y - damp * o.vy) * dt;
    o.x += o.vx * dt;
    o.y += o.vy * dt;
    return Math.abs(o.x) + Math.abs(o.y) + 0.1 * (Math.abs(o.vx) + Math.abs(o.vy)) > 0.08;
}

// a chain of points from `pts`; pinned: index of the end that holds (-1: falls free)
function piece(pts, pinned, vx, vy) {
    const n = Math.max(2, Math.min(7, pts.length));
    const chain = [];
    for (let i = 0; i < n; i++) {
        const p = pts[Math.round(i / (n - 1) * (pts.length - 1))];
        chain.push({
            "x": p.x,
            "y": p.y,
            "px": p.x - (vx || 0) / 30,
            "py": p.y - (vy || 0) / 30
        });
    }
    let rest = 0;
    for (let i = 0; i + 1 < n; i++)
        rest += Math.hypot(chain[i + 1].x - chain[i].x, chain[i + 1].y - chain[i].y);
    return {
        "pts": chain,
        "pin": pinned === undefined ? -1 : (pinned === 0 ? 0 : n - 1),
        "rest": rest / (n - 1),
        "age": 0,
        "life": pinned === undefined || pinned < 0 ? 1.6 : 14
    };
}

function pieceStep(pc, dt, gravity) {
    pc.age += dt;
    const g = (gravity === undefined ? 90 : gravity) * dt * dt;
    for (let i = 0; i < pc.pts.length; i++) {
        if (i === pc.pin)
            continue;
        const p = pc.pts[i];
        const vx = (p.x - p.px) * 0.985, vy = (p.y - p.py) * 0.985;
        p.px = p.x;
        p.py = p.y;
        p.x += vx;
        p.y += vy + g;
    }
    for (let it = 0; it < 3; it++)
        for (let i = 0; i + 1 < pc.pts.length; i++) {
            const a = pc.pts[i], b = pc.pts[i + 1];
            const dx = b.x - a.x, dy = b.y - a.y;
            const d = Math.hypot(dx, dy) || 1e-6;
            const diff = (d - pc.rest) / d;
            const wa = i === pc.pin ? 0 : (i + 1 === pc.pin ? 1 : 0.5);
            const wb = i + 1 === pc.pin ? 0 : (i === pc.pin ? 1 : 0.5);
            a.x += dx * diff * wa;
            a.y += dy * diff * wa;
            b.x -= dx * diff * wb;
            b.y -= dy * diff * wb;
        }
    return pc.age < pc.life;
}

function pieceFade(pc) {
    const left = pc.life - pc.age;
    return Math.max(0, Math.min(1, left / (pc.pin < 0 ? 0.8 : 4)));
}

// nearest point of a shape to (x, y): {t, d}
function nearest(s, off, x, y) {
    let best = {
        "t": 0.5,
        "d": Infinity
    };
    const n = Math.max(4, Math.ceil(s.len / 4));
    for (let i = 0; i <= n; i++) {
        const p = bezier(s, i / n, off);
        const d = Math.hypot(p.x - x, p.y - y);
        if (d < best.d)
            best = {
                "t": i / n,
                "d": d
            };
    }
    return best;
}

// split a thread's curve at t into the two pieces that hang from its ends
function breakAt(s, off, t) {
    const all = curvePoints(s, off);
    const cut = Math.max(1, Math.min(all.length - 2, Math.round(t * (all.length - 1))));
    return [piece(all.slice(0, cut + 1), 0), piece(all.slice(cut).reverse(), 0)];
}
