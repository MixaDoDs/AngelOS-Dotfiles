.pragma library

// The screenshot editor's marks (modules/capture/ShotEditor, drawn by ShotMark), in the picture's
// pixels: {t: "pen" | "marker", pts: [[x, y]…], c, w} · {t: "line" | "arrow", a: [x, y], b: [x, y], c, w}
// · {t: "rect" | "ellipse", x, y, w, h, c, lw, fill} · {t: "num", x, y, n, c, s} · {t: "text", x, y, s, c,
// size, pixel} · {t: "sticker", x, y, icon, s}

// the box a mark covers: {x, y, w, h}
function bounds(m) {
    if (m.pts) {
        let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
        for (const p of m.pts) {
            x0 = Math.min(x0, p[0]);
            y0 = Math.min(y0, p[1]);
            x1 = Math.max(x1, p[0]);
            y1 = Math.max(y1, p[1]);
        }
        const r = m.w / 2;
        return {
            "x": x0 - r,
            "y": y0 - r,
            "w": x1 - x0 + m.w,
            "h": y1 - y0 + m.w
        };
    }
    if (m.a) {
        const r = m.w * 3;
        return {
            "x": Math.min(m.a[0], m.b[0]) - r,
            "y": Math.min(m.a[1], m.b[1]) - r,
            "w": Math.abs(m.b[0] - m.a[0]) + r * 2,
            "h": Math.abs(m.b[1] - m.a[1]) + r * 2
        };
    }
    if (m.t === "num")
        return {
            "x": m.x - m.s / 2,
            "y": m.y - m.s / 2,
            "w": m.s,
            "h": m.s
        };
    if (m.t === "sticker")
        return {
            "x": m.x - m.s / 2,
            "y": m.y - m.s / 2,
            "w": m.s,
            "h": m.s
        };
    if (m.t === "text")
        return {
            "x": m.x,
            "y": m.y,
            "w": Math.max(m.size, (m.tw || m.s.length * m.size * 0.6)),
            "h": m.th || m.size * 1.3 * (m.s.split("\n").length)
        };
    return {
        "x": m.x,
        "y": m.y,
        "w": m.w,
        "h": m.h
    };
}

// the topmost mark under a point (pad: how near counts), -1 none
function hit(list, x, y, pad) {
    for (let i = list.length - 1; i >= 0; i--) {
        const b = bounds(list[i]);
        if (x >= b.x - pad && x <= b.x + b.w + pad && y >= b.y - pad && y <= b.y + b.h + pad)
            return i;
    }
    return -1;
}

// a copy moved by dx, dy
function moved(m, dx, dy) {
    const o = Object.assign({}, m);
    if (m.pts)
        o.pts = m.pts.map(p => [p[0] + dx, p[1] + dy]);
    else if (m.a) {
        o.a = [m.a[0] + dx, m.a[1] + dy];
        o.b = [m.b[0] + dx, m.b[1] + dy];
    } else {
        o.x = m.x + dx;
        o.y = m.y + dy;
    }
    return o;
}

// a box from two corners (Shift: a square), {x, y, w, h}
function box(a, b, square) {
    let dx = b[0] - a[0], dy = b[1] - a[1];
    if (square) {
        const s = Math.max(Math.abs(dx), Math.abs(dy));
        dx = dx < 0 ? -s : s;
        dy = dy < 0 ? -s : s;
    }
    return {
        "x": Math.min(a[0], a[0] + dx),
        "y": Math.min(a[1], a[1] + dy),
        "w": Math.abs(dx),
        "h": Math.abs(dy)
    };
}

// the end of a line held to 45° steps (Shift)
function snap45(a, b) {
    const dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy);
    const ang = Math.round(Math.atan2(dy, dx) / (Math.PI / 4)) * (Math.PI / 4);
    return [a[0] + Math.cos(ang) * l, a[1] + Math.sin(ang) * l];
}

// the arrow's head: three points (the tip, the two wings), the shaft ending under it
function arrowHead(a, b, w) {
    const dx = b[0] - a[0], dy = b[1] - a[1], l = Math.max(1, Math.hypot(dx, dy));
    const ux = dx / l, uy = dy / l, L = Math.min(l * 0.6, Math.max(w * 4, 10)), W = L * 0.55;
    const bx = b[0] - ux * L, by = b[1] - uy * L;
    return {
        "tip": b,
        "left": [bx - uy * W, by + ux * W],
        "right": [bx + uy * W, by - ux * W],
        "shaftEnd": [b[0] - ux * L * 0.8, b[1] - uy * L * 0.8]
    };
}

// a crop box dragged by a grip (0-3 corners tl tr br bl, 4-7 sides t r b l, 8 inside) by dx, dy,
// kept in the picture (W × H), at least min; aspect > 0: width / height held (from its corner)
function cropDrag(r, grip, dx, dy, W, H, aspect, min) {
    let x0 = r.x, y0 = r.y, x1 = r.x + r.w, y1 = r.y + r.h;
    if (grip === 8) {
        const mx = Math.max(-x0, Math.min(W - x1, dx)), my = Math.max(-y0, Math.min(H - y1, dy));
        return {
            "x": x0 + mx,
            "y": y0 + my,
            "w": r.w,
            "h": r.h
        };
    }
    if (grip === 0 || grip === 3 || grip === 7)
        x0 = Math.max(0, Math.min(x1 - min, x0 + dx));
    if (grip === 1 || grip === 2 || grip === 5)
        x1 = Math.min(W, Math.max(x0 + min, x1 + dx));
    if (grip === 0 || grip === 1 || grip === 4)
        y0 = Math.max(0, Math.min(y1 - min, y0 + dy));
    if (grip === 2 || grip === 3 || grip === 6)
        y1 = Math.min(H, Math.max(y0 + min, y1 + dy));
    if (aspect > 0) {
        // the height follows the width (a top / bottom side: the width follows the height)
        let w = x1 - x0, h = y1 - y0;
        if (grip === 4 || grip === 6)
            w = h * aspect;
        else
            h = w / aspect;
        if (grip === 0 || grip === 1 || grip === 4)
            y0 = y1 - h;
        else
            y1 = y0 + h;
        if (grip === 0 || grip === 3 || grip === 7)
            x0 = x1 - w;
        else
            x1 = x0 + w;
        // pushed out of the picture: shrunk back inside, the ratio kept
        const k = Math.min(1, x0 < 0 ? (x1) / w : 1, x1 > W ? (W - x0) / w : 1, y0 < 0 ? y1 / h : 1, y1 > H ? (H - y0) / h : 1);
        if (k < 1) {
            w *= k;
            h *= k;
            if (grip === 0 || grip === 3 || grip === 7)
                x0 = x1 - w;
            else
                x1 = x0 + w;
            if (grip === 0 || grip === 1 || grip === 4)
                y0 = y1 - h;
            else
                y1 = y0 + h;
        }
    }
    return {
        "x": x0,
        "y": y0,
        "w": x1 - x0,
        "h": y1 - y0
    };
}

// the biggest box of that ratio in the middle of W × H
function fitAspect(W, H, aspect) {
    if (!(aspect > 0))
        return {
            "x": 0,
            "y": 0,
            "w": W,
            "h": H
        };
    let w = W, h = W / aspect;
    if (h > H) {
        h = H;
        w = H * aspect;
    }
    return {
        "x": (W - w) / 2,
        "y": (H - h) / 2,
        "w": w,
        "h": h
    };
}
