.pragma library

// What the screenshot overlay (services/CircleSearch) learns from the user, per app (its niri
// app_id) with a common "*" for apps it has not seen yet:
//   - edges: how they move an area's frame after tapping it (a window without its title bar, a
//     picture with its caption) — the next tap on that kind of area there takes it so;
//   - grain: how much text a tap should take (the line, its paragraph, its block);
//   - drops: kinds of areas they tap and let go of without doing anything — shown less;
//   - fixes: words they correct in the text card ("CB" → "GB") — the reading put right.
// Pure functions over a plain object (the store is CircleSearch's JSON file); distances in
// logical pixels, so they hold on a scaled screen too.

const KEEP = 12;            // samples kept per app and kind
const SPREAD = 12;          // px: samples this close agree
const ALL = "*";

function fresh() {
    return {
        "v": 1,
        "apps": {}
    };
}
function _app(db, app) {
    if (!db.apps)
        db.apps = {};
    const k = app || ALL;
    if (!db.apps[k])
        db.apps[k] = {
            "edges": {},
            "grain": {},
            "drops": {},
            "fixes": {}
        };
    return db.apps[k];
}
// the app's own entry, else the common one (null: nothing learned anywhere)
function _look(db, app, part, key) {
    for (const k of [app, ALL]) {
        const a = k && db.apps && db.apps[k];
        if (a && a[part] && a[part][key] !== undefined)
            return a[part][key];
    }
    return null;
}
function _median(v) {
    const s = v.slice().sort((a, b) => a - b);
    return s[s.length >> 1];
}

// ---- edges: d = [left, top, right, bottom] moved, logical px (out: negative left/top)
function _edgeOf(list) {
    if (!list || !list.length)
        return null;
    const d = [0, 1, 2, 3].map(i => _median(list.map(s => s.d[i])));
    const agree = list.filter(s => s.d.every((v, i) => Math.abs(v - d[i]) <= SPREAD));
    const sure = agree.filter(s => s.ok).length >= 1 || agree.length >= 3;
    return {
        "d": d,
        "n": list.length,
        "sure": sure && agree.length >= 0.7 * list.length
    };
}
function addEdge(db, app, kind, d, ok) {
    for (const k of [app, ALL]) {
        const e = _app(db, k).edges;
        e[kind] = (e[kind] || []).concat([{
                "d": d.map(v => Math.round(v)),
                "ok": !!ok
            }]).slice(-KEEP);
    }
}
// what to do to a tapped area of this kind here: {d, sure} or null
function edgeFor(db, app, kind) {
    return _edgeOf(_look(db, app, "edges", kind));
}
// a new sample: worth asking about? (nothing sure yet, or it disagrees with what is)
function edgeUnsure(db, app, kind, d) {
    const e = edgeFor(db, app, kind);
    return !e || !e.sure || d.some((v, i) => Math.abs(v - e.d[i]) > SPREAD);
}
// a frame rect moved by d (logical px × scale), kept inside w × h
function moved(r, d, scale, w, h) {
    const k = scale || 1;
    const x0 = Math.max(0, r.x + d[0] * k), y0 = Math.max(0, r.y + d[1] * k);
    const x1 = Math.min(w, r.x + r.w + d[2] * k), y1 = Math.min(h, r.y + r.h + d[3] * k);
    return x1 - x0 < 8 || y1 - y0 < 8 ? r : {
        "x": x0,
        "y": y0,
        "w": x1 - x0,
        "h": y1 - y0
    };
}
// how the final frame differs from the area's own (null: it does not, within 3 px)
function edgeDelta(from, to, scale) {
    const k = scale || 1;
    const d = [(to.x - from.x) / k, (to.y - from.y) / k, (to.x + to.w - from.x - from.w) / k, (to.y + to.h - from.y - from.h) / k];
    return d.every(v => Math.abs(v) <= 3) ? null : d;
}

// ---- grain: "line" | "para" | "block"
function addGrain(db, app, g) {
    for (const k of [app, ALL]) {
        const gr = _app(db, k).grain;
        gr[g] = (gr[g] || 0) + 1;
    }
}
function grainFor(db, app) {
    for (const k of [app, ALL]) {
        const gr = k && db.apps && db.apps[k] && db.apps[k].grain;
        if (!gr)
            continue;
        const n = Object.values(gr).reduce((a, b) => a + b, 0);
        if (n < 3)
            continue;
        const best = Object.keys(gr).sort((a, b) => gr[b] - gr[a])[0];
        return gr[best] >= 0.7 * n ? best : null;
    }
    return null;
}
// what a text pick took, against the line tapped: words [{line, block, para}]
function grainOf(tapped, picked) {
    if (!tapped.length || !picked.length)
        return null;
    const b = tapped[0].block, lines = new Set(picked.map(w => w.line));
    if (picked.some(w => w.block !== b) || !tapped.every(t => picked.some(w => w.line === t.line)))
        return null;
    if (lines.size === 1)
        return picked.length >= tapped.length ? "line" : null;
    return new Set(picked.map(w => w.para)).size > 1 ? "block" : "para";
}

// ---- drops: a kind of area tapped and let go of, against tapped and used
function addDrop(db, app, kind, dropped) {
    for (const k of [app, ALL]) {
        const d = _app(db, k).drops;
        const c = d[kind] || [0, 0];
        d[kind] = dropped ? [c[0] + 1, c[1]] : [c[0], c[1] + 1];
    }
}
// let go of nearly every time (6 taps or more, 80 %): not shown
function unwanted(db, app, kind) {
    const c = _look(db, app, "drops", kind);
    return !!c && c[0] + c[1] >= 6 && c[0] >= 0.8 * (c[0] + c[1]);
}

// ---- fixes: words the user corrected in the card
function _tokens(t) {
    return t.split(/\s+/).filter(Boolean);
}
// the words that changed, one for one (a different number of words: none can be told)
function wordFixes(before, after) {
    const a = _tokens(before), b = _tokens(after);
    if (a.length !== b.length || a.length > 400)
        return [];
    const out = [];
    for (let i = 0; i < a.length; i++)
        if (a[i] !== b[i] && a[i].length <= 40 && b[i].length <= 40)
            out.push([a[i], b[i]]);
    return out.length > 8 ? [] : out;
}
function addFix(db, app, from, to, ok) {
    // a short word ("CB", "l") is a different word in every app: not fixed everywhere; no app is
    // the common entry itself (it was counted twice there: once was "twice")
    const keys = (app ? [app] : []).concat(from.length >= 3 ? [ALL] : []);
    for (const k of keys) {
        const f = _app(db, k).fixes;
        const c = f[from] && f[from].to === to ? f[from] : {
            "to": to,
            "n": 0,
            "ok": false
        };
        f[from] = {
            "to": to,
            "n": c.n + 1,
            "ok": c.ok || !!ok
        };
    }
}
// the word as the user writes it here (confirmed once, or the same fix twice): else null
function fixFor(db, app, word) {
    const f = _look(db, app, "fixes", word);
    return f && (f.ok || f.n >= 2) ? f.to : null;
}
function fixUnsure(db, app, from, to) {
    return fixFor(db, app, from) !== to;
}
// words [{t, app?}] with the learned fixes made (new objects; the rest untouched)
function fixWords(db, words, appOf) {
    return words.map(w => {
        const to = fixFor(db, appOf ? appOf(w) : null, w.t);
        return to === null ? w : Object.assign({}, w, {
            "t": to
        });
    });
}
// how much has been learned (Settings shows it)
function count(db) {
    const a = db.apps && db.apps[ALL];
    if (!a)
        return 0;
    let n = 0;
    for (const k in a.edges)
        n += a.edges[k].length;
    for (const k in a.grain)
        n += a.grain[k];
    for (const k in a.drops)
        n += a.drops[k][0] + a.drops[k][1];
    for (const k in a.fixes)
        n += a.fixes[k].n;
    return n;
}
