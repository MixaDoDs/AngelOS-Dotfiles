.pragma library

// Where windows are on a screen (services/Cobweb): niri tells where floating windows are, not
// tiled ones, so these are laid out the way niri does it — the way the region screenshot tool
// (~/.local/bin/niri-screenshot-region) does: the active column centred in the working area
// (center-focused-column "always"), the others beside it with the gaps, tiles from the top.
// With another centring mode niri's view could be anywhere: then only the floating windows and
// a column that fills the whole working area are placed.

// gaps, center-focused-column and struts from niri's config text (comments stripped)
function parseLayout(text) {
    const src = String(text || "").replace(/\/\/[^\n]*/g, "");
    const num = (re, body, dflt) => {
        const m = re.exec(body);
        return m ? parseFloat(m[1]) : dflt;
    };
    const center = /^\s*center-focused-column\s+"?([\w-]+)/m.exec(src);
    const struts = /^\s*struts\s*\{([^}]*)\}/m.exec(src);
    const body = struts ? struts[1] : "";
    const s = {};
    for (const e of ["left", "right", "top", "bottom"])
        s[e] = num(new RegExp("\\b" + e + "\\s+(-?[\\d.]+)"), body, 0);
    return {
        "gaps": num(/^\s*gaps\s+([\d.]+)/m, src, 16),
        "center": center ? center[1] : "never",
        "struts": s
    };
}

// what the bars keep on each edge of a screen: {top, bottom, left, right}
function zoneEdges(parts, screen) {
    const z = {
        "top": 0,
        "bottom": 0,
        "left": 0,
        "right": 0
    };
    for (const id in parts) {
        const p = parts[id];
        if (p.screen === screen && p.edge in z)
            z[p.edge] += p.px;
    }
    return z;
}

function tsKey(ts) {
    return ts ? (ts.secs || 0) * 1e9 + (ts.nanos || 0) : 0;
}

// the windows of workspace `ws` on a screen of sw × sh: [{id, x, y, w, h, floating}] in the
// screen's logical px (parts may be off screen), topmost last
function rects(windows, ws, sw, sh, zone, cfg) {
    if (!ws)
        return [];
    const mine = windows.filter(w => w.workspace_id === ws.id && w.layout && w.layout.window_size);
    const out = [];
    const wx0 = zone.left + cfg.struts.left, wy0 = zone.top + cfg.struts.top;
    const ww = sw - zone.left - zone.right - cfg.struts.left - cfg.struts.right;
    const pw = sw - zone.left - zone.right, ph = sh - zone.top - zone.bottom;
    const add = (w, tx, ty, floating) => {
        const off = w.layout.window_offset_in_tile || [0, 0];
        out.push({
            "id": w.id,
            "x": Math.round(tx + off[0]),
            "y": Math.round(ty + off[1]),
            "w": w.layout.window_size[0],
            "h": w.layout.window_size[1],
            "floating": floating,
            "key": tsKey(w.focus_timestamp)
        });
    };
    const tiled = mine.filter(w => !w.is_floating && w.layout.pos_in_scrolling_layout && w.layout.tile_size);
    const cols = {};
    for (const w of tiled) {
        const c = w.layout.pos_in_scrolling_layout[0];
        (cols[c] = cols[c] || []).push(w);
    }
    const keys = Object.keys(cols).map(Number).sort((a, b) => a - b);
    if (keys.length) {
        const width = {}, colx = {};
        let x = 0;
        for (const c of keys) {
            width[c] = Math.max.apply(null, cols[c].map(w => w.layout.tile_size[0]));
            colx[c] = x;
            x += width[c] + cfg.gaps;
        }
        const act = tiled.find(w => w.id === ws.active_window_id) || tiled.reduce((a, b) => tsKey(a.focus_timestamp) >= tsKey(b.focus_timestamp) ? a : b);
        const ac = act.layout.pos_in_scrolling_layout[0];
        const mode = ts => {
            const tw = Math.max.apply(null, ts.map(t => t.layout.tile_size[0]));
            const th = Math.max.apply(null, ts.map(t => t.layout.tile_size[1]));
            if (tw >= sw - 0.5 && th >= sh - 0.5)
                return "fullscreen";
            if (tw >= pw - 0.5 && th >= ph - 0.5)
                return "maximized";
            return "normal";
        };
        const am = mode(cols[ac]), aw = width[ac];
        let xa = null;
        if (am === "fullscreen")
            xa = 0;
        else if (am === "maximized")
            xa = zone.left;
        else if (cfg.center === "always")
            xa = aw >= ww ? wx0 : wx0 + (ww - aw) / 2;
        else if (aw >= ww - 0.5)
            xa = wx0;
        // without centring, only the active column is known (when it fills the view)
        for (const c of keys) {
            if (xa === null || (cfg.center !== "always" && c !== ac))
                continue;
            const m = mode(cols[c]);
            let y = m === "fullscreen" ? 0 : m === "maximized" ? zone.top : wy0 + cfg.gaps;
            const cx = xa + colx[c] - colx[ac];
            for (const w of cols[c].slice().sort((a, b) => a.layout.pos_in_scrolling_layout[1] - b.layout.pos_in_scrolling_layout[1])) {
                const tw = w.layout.tile_size[0], th = w.layout.tile_size[1];
                add(w, cx + (width[c] - tw) / 2, y, false);
                y += th + cfg.gaps;
            }
        }
    }
    const floats = mine.filter(w => w.is_floating && w.layout.tile_pos_in_workspace_view);
    floats.sort((a, b) => tsKey(a.focus_timestamp) - tsKey(b.focus_timestamp));
    for (const w of floats)
        add(w, w.layout.tile_pos_in_workspace_view[0], w.layout.tile_pos_in_workspace_view[1], true);
    return out;
}

// did the window move (by the user) between two snapshots of it? Its workspace, floating or
// not, a floating window's place, a tiled one's column while the workspace kept as many
// columns (a neighbour opening or closing shifts the numbers, that is no move)
function moved(a, b, colsA, colsB) {
    if (!a || !b)
        return false;
    if (a.workspace_id !== b.workspace_id || !!a.is_floating !== !!b.is_floating)
        return true;
    const la = a.layout || {}, lb = b.layout || {};
    if (a.is_floating) {
        const pa = la.tile_pos_in_workspace_view, pb = lb.tile_pos_in_workspace_view;
        return !!pa && !!pb && (Math.abs(pa[0] - pb[0]) > 2 || Math.abs(pa[1] - pb[1]) > 2);
    }
    const sa = la.pos_in_scrolling_layout, sb = lb.pos_in_scrolling_layout;
    if (!sa || !sb)
        return false;
    return colsA === colsB && sa[0] !== sb[0];
}

function columnCount(windows, wsId) {
    const set = {};
    for (const w of windows)
        if (w.workspace_id === wsId && !w.is_floating && w.layout && w.layout.pos_in_scrolling_layout)
            set[w.layout.pos_in_scrolling_layout[0]] = true;
    return Object.keys(set).length;
}

// ---- niri's animations, so a web moves the way its window does ----
// niri's defaults (niri-config), for what the config leaves out
const ANIM_DEFAULTS = {
    "horizontal-view-movement": { "kind": "spring", "ratio": 1, "k": 800, "eps": 0.0001 },
    "window-movement": { "kind": "spring", "ratio": 1, "k": 800, "eps": 0.0001 },
    "window-resize": { "kind": "spring", "ratio": 1, "k": 800, "eps": 0.0001 },
    "workspace-switch": { "kind": "spring", "ratio": 1, "k": 1000, "eps": 0.0001 }
};

// the animations block of niri's config text: {slowdown, view, move, resize, ws}
function parseAnims(text) {
    const src = String(text || "").replace(/\/\/[^\n]*/g, "");
    const out = {
        "slowdown": 1,
        "view": ANIM_DEFAULTS["horizontal-view-movement"],
        "move": ANIM_DEFAULTS["window-movement"],
        "resize": ANIM_DEFAULTS["window-resize"],
        "ws": ANIM_DEFAULTS["workspace-switch"]
    };
    const start = src.search(/(^|\n)\s*animations\s*\{/);
    if (start < 0)
        return out;
    // the block's body: braces counted (the named animations nest one level)
    let i = src.indexOf("{", start), depth = 0, end = src.length;
    for (let j = i; j < src.length; j++) {
        if (src[j] === "{")
            depth++;
        else if (src[j] === "}" && --depth === 0) {
            end = j;
            break;
        }
    }
    const body = src.slice(i + 1, end);
    const top = body.replace(/\{[^{}]*\}/g, "");
    if (/(^|\n)\s*off\s*($|\n)/.test(top)) {
        for (const k of ["view", "move", "resize", "ws"])
            out[k] = { "kind": "off" };
        return out;
    }
    const sd = /(^|\n)\s*slowdown\s+([\d.]+)/.exec(top);
    if (sd)
        out.slowdown = Math.max(0.01, parseFloat(sd[2]));
    const names = { "horizontal-view-movement": "view", "window-movement": "move", "window-resize": "resize", "workspace-switch": "ws" };
    for (const name in names) {
        const m = new RegExp("(^|\\n)\\s*" + name + "\\s*\\{([^{}]*)\\}").exec(body);
        if (!m)
            continue;
        const b = m[2];
        if (/(^|\n)\s*off\s*($|\n)/.test(b)) {
            out[names[name]] = { "kind": "off" };
            continue;
        }
        const sp = /spring\s+([^\n]*)/.exec(b);
        if (sp) {
            const num = (key, d) => {
                const r = new RegExp(key + "=([\\d.]+)").exec(sp[1]);
                return r ? parseFloat(r[1]) : d;
            };
            out[names[name]] = { "kind": "spring", "ratio": num("damping-ratio", 1), "k": num("stiffness", 800), "eps": num("epsilon", 0.0001) };
            continue;
        }
        const dur = /duration-ms\s+(\d+)/.exec(b);
        const curve = /curve\s+"([\w-]+)"([^\n]*)/.exec(b);
        if (dur) {
            const c = {
                "kind": "curve",
                "ms": parseInt(dur[1]),
                "curve": curve ? curve[1] : "ease-out-cubic"
            };
            if (curve && curve[1] === "cubic-bezier")
                c.bez = curve[2].trim().split(/\s+/).map(Number).slice(0, 4);
            out[names[name]] = c;
        }
    }
    return out;
}

// a cubic bezier easing (CSS's): x(s) solved for s by Newton, then y(s)
function bezierEase(b, t) {
    const [x1, y1, x2, y2] = b;
    const bx = s => 3 * (1 - s) * (1 - s) * s * x1 + 3 * (1 - s) * s * s * x2 + s * s * s;
    const by = s => 3 * (1 - s) * (1 - s) * s * y1 + 3 * (1 - s) * s * s * y2 + s * s * s;
    let s = t;
    for (let i = 0; i < 8; i++) {
        const d = 3 * (1 - s) * (1 - s) * x1 + 6 * (1 - s) * s * (x2 - x1) + 3 * s * s * (1 - x2);
        if (Math.abs(d) < 1e-6)
            break;
        s = Math.max(0, Math.min(1, s - (bx(s) - t) / d));
    }
    return by(s);
}
function ease(name, t) {
    switch (name) {
    case "linear":
        return t;
    case "ease-out-quad":
        return 1 - (1 - t) * (1 - t);
    case "ease-out-expo":
        return t >= 1 ? 1 : 1 - Math.pow(2, -10 * t);
    default:
        return 1 - Math.pow(1 - t, 3);
    }
}

// how far an animation has got after `ms` real milliseconds: {p (0…1, a spring may overshoot), done}
function animAt(a, ms, slowdown) {
    if (!a || a.kind === "off")
        return { "p": 1, "done": true };
    const t = ms / 1000 / (slowdown || 1);
    if (a.kind === "curve") {
        const x = Math.min(1, t * 1000 / Math.max(1, a.ms));
        return { "p": a.bez ? bezierEase(a.bez, x) : ease(a.curve, x), "done": x >= 1 };
    }
    // a spring from 1 to 0 (mass 1, as niri's): the displacement left
    const w0 = Math.sqrt(a.k), beta = a.ratio * w0;
    let x, env;
    if (a.ratio < 1) {
        const w1 = w0 * Math.sqrt(1 - a.ratio * a.ratio);
        env = Math.exp(-beta * t);
        x = env * (Math.cos(w1 * t) + beta / w1 * Math.sin(w1 * t));
        env *= 1 + beta / w1;
    } else if (a.ratio === 1) {
        env = Math.exp(-w0 * t) * (1 + w0 * t);
        x = env;
    } else {
        const w2 = w0 * Math.sqrt(a.ratio * a.ratio - 1);
        const r1 = -beta + w2, r2 = -beta - w2;
        const c2 = -r1 / (r2 - r1), c1 = 1 - c2;
        x = c1 * Math.exp(r1 * t) + c2 * Math.exp(r2 * t);
        env = Math.abs(x);
    }
    const done = env < Math.max(a.eps, 0.0005) || t > 3;
    return { "p": done ? 1 : 1 - x, "done": done };
}
