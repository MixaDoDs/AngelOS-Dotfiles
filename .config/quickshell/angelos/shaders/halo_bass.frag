#version 440
// The Halo's beat (modules/halo HaloWindow, services/Bass), in art pixels, three solid colours
// and no alpha ramps — an 8-bit look. The effect covers the pill (or the open card) and a
// margin of `margin` cells round it; the pill's own staircase corners (widgets/PxPill) are
// rebuilt here so the pattern hugs them.
//   style 0 dither  along the inner edge an ordered-dither band (2×2 Bayer): `level` 1 — one
//                   row, every other pixel; 2 — the row solid, a sparse second; 3 — three rows
//                   thinning inwards. `flash` (a kick, 1 → 0) fills it solid for a moment
//   style 1 halo    an arc over the pill, thicker with the level, a pixel higher on a kick;
//                   `wave` (0 → 1 after a kick) sends a dotted ring out from the pill's edge,
//                   fading in three steps
// colours: bright (the cover's or the accent), mid and dim (mixed with the face beforehand)
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 cells;     // the whole effect in art pixels (the pill and the margin round it)
    float margin;   // cells between the effect's edge and the pill's
    float corner;   // the pill's corner, in cells (PxPill's n)
    float style;
    float level;    // 0…3
    float flash;    // 0…1
    float wave;     // 0…1, 0 = none
    vec4 cBright;
    vec4 cMid;
    vec4 cDim;
};

// PxPill's staircase: how far row i (from the nearer end) stands in
float inset(float i, float n) {
    if (i >= n)
        return 0.0;
    float d = n - i - 0.5;
    return floor(n - sqrt(max(0.0, n * n - d * d)) + 0.5);
}

float bayer(vec2 c) {
    vec2 m = mod(c, 2.0);
    return m.x < 1.0 ? (m.y < 1.0 ? 0.0 : 0.75) : (m.y < 1.0 ? 0.5 : 0.25);
}

void main() {
    vec2 cell = floor(qt_TexCoord0 * cells);
    vec2 size = cells - 2.0 * margin;          // the pill, in cells
    vec2 p = cell - margin;                    // the cell in the pill's frame
    float n = min(corner, floor(min(size.x, size.y) * 0.5));
    vec4 o = vec4(0.0);
    int s = int(style + 0.5);

    bool inside = p.x >= 0.0 && p.y >= 0.0 && p.x < size.x && p.y < size.y;
    float depth = -1.0;
    if (inside) {
        float l = inset(min(p.y, size.y - 1.0 - p.y), n);
        float t = inset(min(p.x, size.x - 1.0 - p.x), n);
        depth = min(min(p.x - l, size.x - 1.0 - p.x - l), min(p.y - t, size.y - 1.0 - p.y - t));
    }

    if (s == 0) {
        // depth 0 is the pill's own outline: the band starts just inside it
        if (depth >= 1.0) {
            float row = depth;
            float b = bayer(cell);
            float lv = flash > 0.6 ? 4.0 : level;
            if (row == 1.0) {
                if (lv >= 2.0 || b < 0.5)
                    o = lv >= 1.0 ? cBright : o;
            } else if (row == 2.0) {
                if (lv >= 4.0 || (lv >= 3.0 && b < 0.5) || (lv >= 2.0 && b < 0.25))
                    o = lv >= 4.0 ? cMid : (lv >= 3.0 ? cMid : cDim);
            } else if (row == 3.0) {
                if ((lv >= 4.0 && b < 0.5) || (lv >= 3.0 && b < 0.25))
                    o = cDim;
            }
        }
    } else {
        // the arc over the pill: the top half of a flat ellipse, centred, half the pill wide
        float halfW = max(6.0, floor(size.x * 0.25));
        float cx = (p.x + 0.5 - size.x * 0.5) / halfW;
        if (level >= 1.0 && abs(cx) <= 1.0 && p.y < 0.0) {
            float lift = flash > 0.6 ? 1.0 : 0.0;
            float y = -2.0 - lift - floor(sqrt(max(0.0, 1.0 - cx * cx)) * 1.5 + 0.5);
            float thick = level >= 2.0 ? 2.0 : 1.0;
            if (p.y <= y && p.y > y - thick)
                o = (level >= 3.0 || flash > 0.6) ? cBright : (p.y == y ? cBright : cMid);
            else if (level >= 1.0 && p.y == y - thick && bayer(cell) < 0.5)
                o = cDim;
        }
        // the kick's ring: a dotted outline that walks out from the pill's edge
        if (wave > 0.0 && !inside) {
            vec2 q = abs(p + 0.5 - size * 0.5) - (size * 0.5 - n);
            float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - n;
            float at = 1.0 + floor(wave * (margin - 1.0));
            if (floor(d) == at && mod(cell.x + cell.y, 2.0) < 1.0)
                o = wave < 0.34 ? cBright : (wave < 0.67 ? cMid : cDim);
        }
    }
    fragColor = o * qt_Opacity;
}
