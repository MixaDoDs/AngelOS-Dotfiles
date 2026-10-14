.pragma library

// The cobweb's geometry, growth, physics and hit cells (services/Cobweb, modules/cobweb). Pure
// functions on plain objects, so tests/cobweb/test_web.mjs runs them in node.
//
// Everything is in art pixels of the window (its logical size / Theme.u), origin top-left.
// A web is a list of STEPS in the order the spider weaves them; a step is a few threads.
//   1. corners: in each corner a little triangle web — a bridge across the corner, radials from
//      the corner to it, rings between them (top corners first: the spider comes from above)
//   2. drapes: long sagging threads along the edges from one corner web to the next
//   3. the cocoon, two looks: "silk" (a procedural mesh — STRANDS anchored on the
//      edges, BRIDGES tying neighbours, BUNDLES edge to edge; dense at the edges,
//      the middle stays readable) or "classic" (the original: edge bands plus slanting
//      bands across, with the dither haze drawn by the view).
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

// thread sag by kind (a fraction of the thread's length); the cocoon's tuner rewrites
// the strand/cross/bridge rows per generate() call (buildCocoon below)
const SAG = {
    "frame": 0.03,
    "radial": 0.015,
    "ring": 0.05,
    "drape": 0.09,
    "wrap": 0.035,
    "strand": 0.07,
    "cross": 0.07,
    "bridge": 0.03
};

// ---- the cocoon's procedural mesh: strands, bridges, bundles ----
// `base`: the corner + drape steps already woven (their silk counts as cover, drapes
// are bridge targets). Returns cocoon-phase steps to append after them.
// Defaults match the tuner (density/bundles/bridges/gravity); dew stays off.
function buildCocoon(seed, W, H, base, opts) {
    const o = Object.assign({
        "density": 1,
        "bundles": 0,
        "bridges": 1,
        "gravity": 1,
        "dew": 0
    }, opts || {});
    SAG.strand = 0.07 * o.gravity;
    SAG.cross = 0.07 * o.gravity;
    SAG.bridge = 0.03 * o.gravity;

    const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
    const smooth = t => t * t * (3 - 2 * t);
    const hyp = Math.hypot;
    const ws = Math.max(1, W - 1), hs = Math.max(1, H - 1), short = Math.min(W, H);
    const fr = (x, y) => ({
            "fx": clamp(x / ws, 0, 1),
            "fy": clamp(y / hs, 0, 1)
        });
    // every part has a random stream of its own, so the mesh is stable per seed
    const sub = tag => rng(((seed ^ 0x9e3779b9) + Math.imul(tag + 1, 0x85ebca6b)) >>> 0);
    const noise = valueNoise(sub(0), 5);
    const nz = (x, y) => noise(x / ws, y / hs);
    const nearEdge = (x, y) => Math.min(x, y, ws - x, hs - y);
    const edgeW = (x, y) => 0.14 + 0.86 * (1 - smooth(clamp(nearEdge(x, y) / (short * 0.36), 0, 1)));

    // how much silk is already where: a coarse grid of thread length per cell
    const cs = Math.max(5, short / 18), gw = Math.ceil(ws / cs) + 1, gh = Math.ceil(hs / cs) + 1;
    const cov = new Float32Array(gw * gh);
    const addCov = (A, B) => {
        const d = hyp(B.x - A.x, B.y - A.y), n = Math.max(1, Math.ceil(d / (cs * 0.5)));
        for (let i = 0; i <= n; i++) {
            const x = A.x + (B.x - A.x) * i / n, y = A.y + (B.y - A.y) * i / n;
            cov[clamp(Math.floor(y / cs), 0, gh - 1) * gw + clamp(Math.floor(x / cs), 0, gw - 1)] += d / (n + 1);
        }
    };
    // silk near (x, y): any thread length in the 3×3 cells around the point
    const nearSilk = (x, y) => {
        const cx = Math.floor(x / cs), cy = Math.floor(y / cs);
        for (let dy = -1; dy <= 1; dy++)
            for (let dx = -1; dx <= 1; dx++) {
                const nx = cx + dx, ny = cy + dy;
                if (nx < 0 || ny < 0 || nx >= gw || ny >= gh)
                    continue;
                if (cov[ny * gw + nx] > 0.5)
                    return true;
            }
        return false;
    };
    const emptiness = (x, y) => {
        const cx = Math.floor(x / cs), cy = Math.floor(y / cs);
        let s = 0, c = 0;
        for (let dy = -1; dy <= 1; dy++)
            for (let dx = -1; dx <= 1; dx++) {
                const nx = cx + dx, ny = cy + dy;
                if (nx < 0 || ny < 0 || nx >= gw || ny >= gh)
                    continue;
                s += cov[ny * gw + nx];
                c++;
            }
        return 1 / (1 + (s / c) / (cs * 1.2));
    };
    const polyOf = threads => {
        const pts = [];
        for (const t of threads) {
            const cp = curvePoints(restShape(t, W, H));
            for (let i = pts.length ? 1 : 0; i < cp.length; i++)
                pts.push(cp[i]);
        }
        return pts;
    };
    const arc = pts => {
        const out = [0];
        for (let i = 1; i < pts.length; i++)
            out.push(out[i - 1] + hyp(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y));
        return out;
    };

    // the corner webs and drapes: silk already, and drapes are bridge targets.
    // Anchor ids: strands 0, 1, 2…, drapes −1, −2… — bridges remember both ends'
    // anchors in `tie`, so a bridge dies with the line it hangs on.
    const targets = [];
    let drapeIdx = -1;
    for (const st of base)
        for (const t of st.threads) {
            const s = restShape(t, W, H);
            addCov(s.a, s.b);
            if (st.phase === "drape") {
                const poly = polyOf([t]);
                t.strand = drapeIdx;
                targets.push({
                    "poly": poly,
                    "arc": arc(poly),
                    "si": drapeIdx
                });
                drapeIdx--;
            }
        }
    const allStrands = [];
    const edgeLen = e => (e % 2 ? hs : ws);
    // a point on edge e (0 top, 1 right, 2 bottom, 3 left; clockwise), s: 0…1 along it
    const onEdge = (r, e, s) => {
        const i = r() * 1.2;
        if (e === 0)
            return {"x": s * ws, "y": i};
        if (e === 1)
            return {"x": ws - i, "y": s * hs};
        if (e === 2)
            return {"x": ws - s * ws, "y": hs - i};
        return {"x": i, "y": hs - s * hs};
    };

    // ---- strands of one layer. flat 0: gather at the edges; towards 1: anywhere empty
    function strandsBatch(tag, N, flat) {
        const r = sub(tag);
        const biased = () => {
            const u = r() * 2 - 1;
            return 0.5 + 0.5 * Math.sign(u) * Math.pow(Math.abs(u), 0.6);
        };
        // anchor hubs: two points per edge the strands snap to, so threads visibly
        // merge into shared cables at the anchors and fan out across the window —
        // never lone lines with their own private endpoints
        const hubs = [];
        for (let e = 0; e < 4; e++)
            for (let j = 0; j < 2; j++)
                hubs.push({"e": e, "s": biased()});
        const snapS = (e, s) => {
            let bh = null, bd = 0.28;
            for (const hb of hubs) {
                if (hb.e !== e)
                    continue;
                const d = Math.abs(hb.s - s);
                if (d < bd) {
                    bd = d;
                    bh = hb;
                }
            }
            if (bh && r() < 0.65)
                return Math.max(0, Math.min(1, bh.s + (r() - 0.5) * 0.02));
            return s;
        };
        const mine = [];
        const dupe = (A, B) => allStrands.concat(mine).some(s => (hyp(s.A.x - A.x, s.A.y - A.y) < 2.5 && hyp(s.B.x - B.x, s.B.y - B.y) < 2.5) || (hyp(s.A.x - B.x, s.A.y - B.y) < 2.5 && hyp(s.B.x - A.x, s.B.y - A.y) < 2.5));
        for (let guard = 0; mine.length < N && guard < N * 260; guard++) {
            let e1, e2, s1, s2, swag = 0;
            const mode = r();
            if (mode < 0.48 - 0.2 * flat) {
                e1 = Math.floor(r() * 4);
                e2 = (e1 + 1) % 4;
                s1 = clamp(1 - short * (0.05 + 0.5 * Math.pow(r(), 1.6)) / edgeLen(e1), 0, 1);
                s2 = clamp(short * (0.05 + 0.5 * Math.pow(r(), 1.6)) / edgeLen(e2), 0, 1);
            } else if (mode < 0.68 - 0.3 * flat) {
                e1 = e2 = Math.floor(r() * 4);
                s1 = 0.04 + r() * 0.62;
                s2 = Math.min(0.96, s1 + 0.1 + r() * 0.26);
                swag = 0.15 + r() * 0.3;
            } else {
                e1 = Math.floor(r() * 4);
                const q = r();
                e2 = q < 0.62 - 0.3 * flat ? (e1 + (r() < 0.5 ? 1 : 3)) % 4 : q < 0.88 - 0.1 * flat ? (e1 + 2) % 4 : e1;
                if (e2 === e1 && (e1 === 1 || e1 === 3))
                    continue;
                s1 = biased();
                s2 = biased();
                if (e2 === e1 && (Math.abs(s1 - s2) < 0.12 || Math.abs(s1 - s2) > 0.45))
                    continue;
            }
            // share anchors: strands merge into cables at the hubs, fan out after them
            s1 = snapS(e1, s1);
            s2 = snapS(e2, s2);
            const A = onEdge(r, e1, s1), B = onEdge(r, e2, s2);
            const len = hyp(B.x - A.x, B.y - A.y);
            const opposite = e2 === (e1 + 2) % 4;
            if (len < short * 0.1 || len > short * (opposite ? 1.25 : 0.95))
                continue;
            const mx = (A.x + B.x) / 2, my = (A.y + B.y) / 2;
            let e = 0;
            for (const t of [0.1, 0.3, 0.5, 0.7, 0.9])
                e += emptiness(A.x + (B.x - A.x) * t, A.y + (B.y - A.y) * t) / 5;
            const w = edgeW(mx, my);
            const wFlat = w + (1 - w) * flat;
            const typeF = opposite ? 0.7 + 0.7 * flat : 1.3 - 0.5 * flat;
            const need = flat ? 0.15 + 2.2 * e * e : 0.6 + 0.8 * e;
            if (r() > wFlat * (0.75 + 0.6 * nz(mx, my)) * typeF * need)
                continue;
            // no spans across true voids: the middle must start near existing silk, or
            // no tie could ever reach it — the mesh grows dense-first, like a real web
            if (!nearSilk(mx, my))
                continue;
            if (dupe(A, B))
                continue;
            addCov(A, B);
            mine.push({
                "A": A,
                "B": B,
                "len": len,
                "key": e1 + s1,
                "edge": e1,
                "swag": swag ? clamp(len * swag, 2, short * 0.12) : 0,
                "kind": opposite ? "cross" : "strand"
            });
        }
        // the spider goes round the window: strands in order of where they start
        mine.sort((a, b) => a.key - b.key);
        const rot = mine.length ? Math.floor(r() * mine.length) : 0;
        const out = mine.slice(rot).concat(mine.slice(0, rot));
        // each strand is 1-4 slightly kinked segments (a thread is never ruler-straight)
        for (const s of out) {
            const n = clamp(Math.round(s.len / (short * 0.2)), 1, 4);
            const dx = (s.B.x - s.A.x) / s.len, dy = (s.B.y - s.A.y) / s.len;
            const knots = [s.A];
            if (s.swag) {
                const inward = [[0, 1], [-1, 0], [0, -1], [1, 0]][s.edge];
                const t = 0.5 + (r() - 0.5) * 0.3;
                knots.push({
                    "x": clamp(s.A.x + (s.B.x - s.A.x) * t + inward[0] * s.swag, 0, ws),
                    "y": clamp(s.A.y + (s.B.y - s.A.y) * t + inward[1] * s.swag, 0, hs)
                });
            }
            for (let i = 1; i < (s.swag ? 1 : n); i++) {
                const t = i / n + (r() - 0.5) * 0.16 / n;
                const off = (r() * 2 - 1) * s.len * 0.075;
                knots.push({
                    "x": clamp(s.A.x + (s.B.x - s.A.x) * t - dy * off, 0, ws),
                    "y": clamp(s.A.y + (s.B.y - s.A.y) * t + dx * off, 0, hs)
                });
            }
            knots.push(s.B);
            s.threads = [];
            const si = allStrands.length;
            for (let i = 0; i + 1 < knots.length; i++)
                s.threads.push({
                    "a": fr(knots[i].x, knots[i].y),
                    "b": fr(knots[i + 1].x, knots[i + 1].y),
                    "kind": s.kind,
                    "dew": r() < 0.03 * o.dew,
                    "strand": si
                });
            const poly = polyOf(s.threads);
            s.target = {
                "poly": poly,
                "arc": arc(poly),
                "si": si
            };
            targets.push(s.target);
            allStrands.push(s);
        }
        return out;
    }

    // ---- bridges of one layer: tie each strand to a neighbour close by ----
    const seen = new Set();
    const minD = 2.6;
    const tiePts = []; // every tie's ends, art px: lonely strands reach for these
    // nearest thread points to P (not on `me`), roughly across the strand's direction —
    // up to `n` of them, nearest first
    function tieTo(P, tx, ty, me, searchD, perp, n) {
        const tl = hyp(tx, ty) || 1;
        const found = [];
        for (const o2 of targets) {
            if (o2 === me)
                continue;
            const end = o2.arc[o2.arc.length - 1];
            for (let m = 0; m < o2.poly.length; m++) {
                if (o2.arc[m] < 3 || end - o2.arc[m] < 3)
                    continue;
                const Q = o2.poly[m];
                const dx = Q.x - P.x, dy = Q.y - P.y, d = hyp(dx, dy);
                if (d < minD || d > searchD)
                    continue;
                if (Math.abs(dx * tx + dy * ty) / (d * tl) > perp)
                    continue;
                found.push({"Q": Q, "d": d, "si": o2.si});
            }
        }
        found.sort((a, b) => a.d - b.d);
        return found.slice(0, n || 1);
    }
    function addTie(bridges, P, cand, sia, r) {
        const Q = cand.Q;
        const key = Math.round((P.x + Q.x) / 6) + "," + Math.round((P.y + Q.y) / 6);
        if (seen.has(key))
            return false;
        seen.add(key);
        tiePts.push(P, Q);
        bridges.push({
            "a": fr(P.x, P.y),
            "b": fr(Q.x, Q.y),
            "kind": "bridge",
            "dew": r() < 0.1 * o.dew,
            "tie": [sia, cand.si]
        });
        return true;
    }
    function bridgesBatch(tag, layer) {
        const r = sub(tag);
        const searchD = clamp(short * 0.08, 9, 30);
        const gap = clamp(short * 0.03, 4.5, 11) / clamp(o.bridges, 0.2, 3);
        const maxBridges = clamp(Math.round(layer.length * 3.6 * o.bridges), 4, 170);
        const bridges = [];
        for (const s of layer) {
            if (bridges.length >= maxBridges)
                break;
            const me = s.target, total = me.arc[me.arc.length - 1];
            let next = gap * (0.4 + r() * 0.8);
            for (let k = 1; k < me.poly.length - 1; k++) {
                if (me.arc[k] < next)
                    continue;
                next = me.arc[k] + gap * (0.6 + r() * 0.8);
                if (me.arc[k] < 4 || total - me.arc[k] < 4)
                    continue;
                const P = me.poly[k];
                if (r() > 0.3 + 0.7 * edgeW(P.x, P.y) * (0.6 + 0.8 * nz(P.x, P.y)))
                    continue;
                const tx = me.poly[k + 1].x - me.poly[k - 1].x, ty = me.poly[k + 1].y - me.poly[k - 1].y;
                const best = tieTo(P, tx, ty, me, searchD, 0.55)[0];
                if (!best)
                    continue;
                addTie(bridges, P, best, me.si, r);
                if (bridges.length >= maxBridges)
                    break;
            }
        }
        const batchSteps = [];
        for (let i = 0; i < bridges.length;) {
            const n = 3 + Math.floor(r() * 3);
            batchSteps.push({
                "phase": "cocoon",
                "threads": bridges.slice(i, i + n)
            });
            i += n;
        }
        return batchSteps;
    }

    // ---- lonely points: wherever a strand runs farther than a tie's reach from every
    // tie, it gets one — like the reference render, sparse places stay tied to the dense
    // mesh, and no line hangs alone across an empty middle ----
    function lonelyBatch(tag, layer) {
        const r = sub(tag);
        // long reach on purpose: a tie deep into the mesh beats a lone line, even a
        // long one — sparse places stay visibly attached to the dense mesh
        const searchD = clamp(short * 0.3, 30, 110);
        const farD = 30;
        const bridges = [];
        const farFromTies = (x, y) => tiePts.every(q => hyp(q.x - x, q.y - y) > farD);
        for (const s of layer) {
            const me = s.target, total = me.arc[me.arc.length - 1];
            if (total < 24)
                continue;
            const want = clamp(Math.round(total / 45), 2, 5);
            let next = total / (want + 1), added = 0;
            for (let k = 1; k < me.poly.length - 1 && added < want; k++) {
                if (me.arc[k] < next)
                    continue;
                next = me.arc[k] + total / (want + 1);
                if (me.arc[k] < 2 || total - me.arc[k] < 2)
                    continue;
                const P = me.poly[k];
                if (!farFromTies(P.x, P.y))
                    continue;
                const tx = me.poly[k + 1].x - me.poly[k - 1].x, ty = me.poly[k + 1].y - me.poly[k - 1].y;
                // try nearest first, then the next ones: a claimed dedupe cell must not
                // leave the point hanging alone
                let tied = false;
                for (const cand of tieTo(P, tx, ty, me, searchD, 0.85, 3)) {
                    if (addTie(bridges, P, cand, me.si, r)) {
                        tied = true;
                        break;
                    }
                }
                if (tied)
                    added++;
            }
        }
        const loneSteps = [];
        for (let i = 0; i < bridges.length;) {
            const n = 3 + Math.floor(r() * 3);
            loneSteps.push({
                "phase": "cocoon",
                "threads": bridges.slice(i, i + n)
            });
            i += n;
        }
        return loneSteps;
    }

    // ---- bundles: long bands of 2-3 strands side by side, edge to edge ----
    function bundles() {
        const r = sub(30);
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
                pts.sort((p, q) => p[0] - q[0]);
                let a = pts[0], b = pts[pts.length - 1];
                if (hyp(b[0] - a[0], b[1] - a[1]) < short * 0.12)
                    continue;
                // like the classic bands: a tight group of 2–3 parallel lines reads as
                // one cable, so bundles are exempt from the void gate by design
                if (m % 2) {
                    const x = a;
                    a = b;
                    b = x;
                }
                addCov(a, b);
                out.push({
                    "a": fr(a[0], a[1]),
                    "b": fr(b[0], b[1]),
                    "kind": "wrap"
                });
            }
            return out;
        };
        const bundleSteps = [];
        const layers = [[1, 0.45, 2], [-1, 0.45, 2], [1, 0.32, 3], [-1, 0.32, 3]];
        const nLayers = clamp(Math.round(3 * o.bundles), 0, 4);
        for (const L of layers.slice(0, nLayers)) {
            const k = L[0] * (0.45 + r() * 0.3);
            const gapC = short * L[1] * (0.9 + r() * 0.2);
            const dc = gapC * Math.sqrt(1 + k * k);
            const lo = Math.min(0, -k * ws), hi = Math.max(hs, hs - k * ws);
            for (let c = lo + dc * (0.35 + r() * 0.3); c < hi; c += dc) {
                const th = band(c + (r() - 0.5) * dc * 0.25, k, L[2] + Math.floor(r() * 2), 2.2 + r() * 1.2);
                if (th.length)
                    bundleSteps.push({
                        "phase": "cocoon",
                        "threads": th
                    });
            }
        }
        return bundleSteps;
    }

    // ---- assemble: layers of batches of 6 strands; a batch never changes the ones
    // before it, so a bigger density only appends ----
    const cocoonSteps = [];
    const nLayers = Math.max(1, Math.ceil(o.density - 1e-9));
    const baseN = short / 8.5, BATCH = 6;
    for (let li = 0; li < nLayers; li++) {
        const scale = clamp(o.density - li, 0.05, 1);
        const N = li ? clamp(Math.round(baseN * scale * 0.85), 6, 48) : clamp(Math.round(baseN * scale), 12, 56);
        const nb = Math.ceil(N / BATCH);
        for (let bi = 0; bi < nb; bi++) {
            const batch = strandsBatch(10 + li * 40 + bi, BATCH, li ? 0.5 : 0);
            for (const s of batch)
                cocoonSteps.push({
                    "phase": "cocoon",
                    "threads": s.threads
                });
            for (const b of bridgesBatch(500 + li * 40 + bi, batch))
                cocoonSteps.push(b);
            // wherever a strand runs far from every tie, it gets one
            for (const b of lonelyBatch(900 + li * 40 + bi, batch))
                cocoonSteps.push(b);
        }
        if (li === 0)
            for (const b of bundles())
                cocoonSteps.push(b);
    }
    // final sweep over the whole mesh: ties added later may leave earlier far points
    // covered, but anything still hanging alone gets tied now that everything is placed
    for (const b of lonelyBatch(9999, allStrands))
        cocoonSteps.push(b);
    return cocoonSteps;
}

function valueNoise(r, n) {
    const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
    const smooth = t => t * t * (3 - 2 * t);
    const g = [];
    for (let i = 0; i < (n + 1) * (n + 1); i++)
        g.push(r());
    return (u, v) => {
        const x = clamp(u, 0, 1) * n, y = clamp(v, 0, 1) * n;
        const x0 = Math.min(n - 1, Math.floor(x)), y0 = Math.min(n - 1, Math.floor(y));
        const fx = smooth(x - x0), fy = smooth(y - y0);
        const a = g[y0 * (n + 1) + x0], b = g[y0 * (n + 1) + x0 + 1];
        const c = g[(y0 + 1) * (n + 1) + x0], d = g[(y0 + 1) * (n + 1) + x0 + 1];
        return (a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy;
    };
}

// the steps of a web for a window of W × H art px (the size it had when the spider began)
function generate(seed, W, H, opts) {
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
    // the cocoon, two looks (Settings → Windows → Cobwebs → cocoon style):
    // "silk" (procedural mesh) or "classic" (the original: edge bands plus slanting
    // bands across, with the dither haze drawn by the view)
    const co = Object.assign({"style": "silk"}, opts || {});
    if (co.style === "classic")
        classicCocoon(r, W, H, short, steps);
    else
        for (const st of buildCocoon(seed, W, H, steps, opts))
            steps.push(st);
    // number every thread: "step.thread"
    steps.forEach((s, i) => s.threads.forEach((t, j) => t.id = i + "." + j));
    return steps;
}

// the original cocoon: bands of silk wound round the whole window — round its edges
// first, then slanting bands one way, the other way across them. Continues the same
// random stream as the corners/drapes, so legacy webs keep their exact geometry.
function classicCocoon(r, W, H, short, steps) {
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

// a thread with nothing left to hang on (a strand cut elsewhere, a tie torn off both
// ends): two FREE pieces that fall and fade fast instead of sticking around
function breakLoose(s, off) {
    const all = curvePoints(s, off);
    const cut = Math.max(1, Math.min(all.length - 2, Math.round(0.5 * (all.length - 1))));
    return [piece(all.slice(0, cut + 1)), piece(all.slice(cut).reverse())];
}
