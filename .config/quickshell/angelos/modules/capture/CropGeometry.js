.pragma library

function select(ax, ay, bx, by, width, height) {
    const clamp = (p, limit) => Math.max(0, Math.min(p, limit));
    const x = clamp(Math.min(ax, bx), width);
    const y = clamp(Math.min(ay, by), height);
    const w = clamp(Math.max(ax, bx), width) - x;
    const h = clamp(Math.max(ay, by), height) - y;
    return w >= 4 && h >= 4 ? {x: x / width, y: y / height, w: w / width, h: h / height} : null;
}
