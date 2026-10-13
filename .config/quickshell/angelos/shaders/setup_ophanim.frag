#version 440
// The first run's intro: the ophanim (modules/settings/SetupOphanim.qml) — in three dimensions,
// in art pixels. Wheels within wheels: five bands on their own axes round one great eye, the
// last so wide the screen sits inside it; every band set with eyes, inside and out; six wings,
// each beating in its own time (the feathers a little after the bone). All of it too big for the
// screen. Every eye looks at the pointer (`look`, `attend`) — or at you. It moves wrongly: on
// twelves, stopping, jerking back. Unlit (`shown` 0) it is a shape in the dark with the open
// eyes' amber in it; `awake` is how many of the small eyes have opened (past 0.38 the great one
// shows in the dark too).
// The parts are the author's, in one atlas (data/intro/ophanim.png, 4×3 cells: the wings, the
// eye's frame, its white, the iris, a shut eye, the finials — owner/intro-art/ophanim_atlas.py,
// which also prints the hinges and sizes below).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;   // px
    float px;        // one art pixel, px
    vec2 origin;     // its middle: from the screen's, in half short sides (y down)
    vec2 look;       // the pointer, the same way
    float attend;    // 0: every eye at you … 1: at the pointer
    float pupil;     // the slits: 0 narrow … 1 wide
    float shown;     // 0: a shape in the dark … 1: lit
    float awake;     // the share of the small eyes open
    float time;      // s
};
layout(binding = 1) uniform sampler2D atlas;

const float TAN = 0.5;        // half the view, across the short side
const float FAR = 6.0;        // how far its middle is
const float EYE = 1.3;        // half the great eye's frame
const float PI2 = 6.2831853;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float bayer2(vec2 a) {
    a = floor(a);
    return fract(dot(a, vec2(0.5, a.y * 0.75)));
}
float bayer4(vec2 a) {
    return bayer2(0.5 * a) * 0.25 + bayer2(a);
}
mat3 rotX(float a) {
    float c = cos(a), s = sin(a);
    return mat3(1.0, 0.0, 0.0, 0.0, c, s, 0.0, -s, c);
}
mat3 rotZ(float a) {
    float c = cos(a), s = sin(a);
    return mat3(c, s, 0.0, -s, c, 0.0, 0.0, 0.0, 1.0);
}

// a part: `uv` 0…1 inside cell `i`; nothing outside it, hard edges
vec4 part(float i, vec2 uv) {
    if (uv.x <= 0.0 || uv.x >= 1.0 || uv.y <= 0.0 || uv.y >= 1.0)
        return vec4(0.0);
    vec4 c = texture(atlas, (vec2(mod(i, 4.0), floor(i / 4.0)) + uv) / vec2(4.0, 3.0));
    return c.a > 0.5 ? vec4(c.rgb / c.a, 1.0) : vec4(0.0);
}
// a wing's hinge (its turquoise stone) in its cell
vec2 hinge(float i) {
    if (i < 0.5) return vec2(0.8195, 0.6875);
    if (i < 1.5) return vec2(0.8814, 0.4589);
    if (i < 2.5) return vec2(0.7348, 0.2840);
    if (i < 3.5) return vec2(0.1768, 0.6697);
    if (i < 4.5) return vec2(0.1720, 0.5259);
    return vec2(0.2619, 0.3138);
}

// wrong: on twelves; now and then it stops for half a second, or runs back, then is where it
// should have been
float wrong(float t, float who) {
    float seg = floor(t / 1.7 + who * 0.37);
    float at = t - (seg - who * 0.37) * 1.7;
    float h = hash(vec2(seg, 7.0 + who));
    if (h > 0.7 && at < 0.5)
        t -= at * (h > 0.9 ? 2.2 : 1.0);
    return floor(t * 12.0) / 12.0;
}

// an iris with its slit, `q` −1…1 over it; rgb and how much of it is there
vec4 iris(vec2 q) {
    if (dot(q, q) >= 1.0)
        return vec4(0.0);
    vec3 col = part(8.0, 0.5 + q * vec2(0.2630, 0.2669) * 0.97).rgb;
    float slit = mix(0.07, 0.34, clamp(pupil, 0.0, 1.0)) * (1.0 - q.y * q.y / 0.74);
    if (abs(q.x) < slit)
        col = vec3(0.07, 0.02, 0.10);
    vec2 g = q - vec2(-0.30, -0.36);
    if (abs(g.x) < 0.10 && abs(g.y) < 0.10)
        col = vec3(1.0, 0.97, 0.90);
    return vec4(col, 1.0);
}

// what an eye looks at: you, or the pointer (a point close in front of the screen)
vec3 target() {
    return vec3(look * TAN * 1.5, 1.5) * clamp(attend, 0.0, 1.0);
}

// one band's face where the ray meets it. `h`: the place in the band's own space (its axis y),
// `m`: that space; rgb, and in a: 1 it is there, 2 an open eye's iris (it shows in the dark)
vec4 band(vec3 h, float R, float w, float n, float spin, float inner, float ring, mat3 m, vec3 mid) {
    float th = atan(h.z, h.x);
    float ut = (th + spin) / PI2 * n;
    float k = floor(ut);
    float fu = fract(ut) - 0.5;
    float tile = PI2 * R / n;
    float v = abs(h.y) / w;
    // ivory between golden rims
    vec3 col = vec3(0.96, 0.89, 0.76);
    if (v > 0.93)
        col = vec3(0.36, 0.17, 0.05);
    else if (v > 0.78)
        col = vec3(0.96, 0.68, 0.17);
    else if (v > 0.73)
        col = vec3(0.58, 0.31, 0.08);
    float a = 1.0;
    // a turquoise stone between the eyes
    vec2 st = vec2((0.5 - abs(fu)) * tile / (0.30 * w), h.y / (0.42 * w));
    float stone = abs(st.x) + abs(st.y);
    if (stone < 1.0)
        col = stone < 0.45 ? vec3(0.72, 0.96, 0.96) : vec3(0.20, 0.72, 0.80);
    else if (stone < 1.4)
        col = vec3(0.96, 0.68, 0.17);
    // the eye in the middle of the tile
    float eh = 0.72 * w, ew = eh * 1.82;
    vec2 e = vec2(fu * tile / ew, h.y / eh);
    if (abs(e.x) < 1.25 && abs(e.y) < 1.25) {
        float id = ring * 31.0 + mod(k, n);
        bool open = hash(vec2(id, 1.0)) < awake && fract(time * (0.06 + 0.09 * hash(vec2(id, 2.0))) + hash(vec2(id, 3.0))) > 0.035;
        if (!open) {
            vec4 lid = part(9.0, 0.5 + e * vec2(0.5, 0.2513) * 0.94);
            if (lid.a > 0.5)
                col = lid.rgb;
        } else {
            vec4 white = part(7.0, 0.5 + e * vec2(0.3997, 0.2201));
            if (white.a > 0.5) {
                col = white.rgb;
                if (abs(e.y) < 0.80 * (1.0 - e.x * e.x)) {
                    // where it looks, in the band's own space; no further than its corners
                    float tk = (mod(k, n) + 0.5) / n * PI2 - spin;
                    vec3 at = mid + m * (R * vec3(cos(tk), 0.0, sin(tk)));
                    vec3 g = normalize(target() - at) * m;
                    vec2 off = vec2(dot(g, vec3(-sin(tk), 0.0, cos(tk))), g.y);
                    off *= min(1.0, 1.0 / max(length(off), 0.001)) * min(1.0, length(off) * 1.6);
                    vec4 ir = iris((e - off * vec2(0.46, 0.22)) / vec2(0.43, 0.78));
                    if (ir.a > 0.5) {
                        col = ir.rgb;
                        a = 2.0;
                    }
                }
            }
        }
    }
    // lit from the front and above; the inside in its own shadow
    vec3 nrm = m * vec3(cos(th), 0.0, sin(th)) * (inner > 0.5 ? -1.0 : 1.0);
    float lit = max(0.0, dot(nrm, normalize(vec3(-0.3, -0.55, -0.75))));
    col *= inner > 0.5 ? 0.34 + 0.36 * lit : 0.5 + 0.5 * lit;
    if (inner > 0.5)
        col *= vec3(1.0, 0.80, 0.60);
    return vec4(col, a);
}

void main() {
    // art pixels: everything on a grid of `px`
    vec2 cell = floor(qt_TexCoord0 * itemSize / px);
    vec2 p = (cell + 0.5) * px;
    vec2 uv = (p - itemSize * 0.5) / (0.5 * min(itemSize.x, itemSize.y));
    vec3 rd = normalize(vec3(uv * TAN, 1.0));
    vec3 mid = vec3(origin * TAN * FAR, FAR);
    float t = wrong(time, 0.0);

    float best = 1.0e9;
    vec4 col = vec4(0.0);

    // ---- the bands ----
    for (float i = 0.0; i < 4.5; i += 1.0) {
        float R = i > 3.5 ? 8.5 : 1.5 + 0.75 * i + 0.08 * i * i;
        float w = 0.13 * R + 0.05;
        float n = floor(PI2 * R / (4.2 * w));
        float dir = mod(i, 2.0) < 0.5 ? 1.0 : -1.0;
        float ti = wrong(time, i + 1.0);
        float b = 0.35 + 0.28 * i + 0.5 * sin(ti * (0.13 + 0.05 * i) + i * 2.1);
        float g = i * 1.1 + ti * (0.05 + 0.03 * i) * dir;
        float spin = ti * (0.34 - 0.05 * i) * dir;
        mat3 m = rotZ(g) * rotX(b);
        vec3 o = -mid * m;
        vec3 d = rd * m;
        float qa = d.x * d.x + d.z * d.z;
        float qb = o.x * d.x + o.z * d.z;
        float qc = o.x * o.x + o.z * o.z - R * R;
        float disc = qb * qb - qa * qc;
        if (disc <= 0.0 || qa < 1.0e-6)
            continue;
        float sq = sqrt(disc);
        for (float side = 0.0; side < 1.5; side += 1.0) {
            float s = (-qb + (side < 0.5 ? -sq : sq)) / qa;
            if (s <= 0.05 || s >= best)
                continue;
            vec3 h = o + s * d;
            if (abs(h.y) >= w)
                continue;
            vec4 c = band(h, R, w, n, spin, side, i, m, mid);
            // further off, darker
            c.rgb *= mix(1.0, 0.5, clamp((s - 2.0) / 12.0, 0.0, 1.0));
            best = s;
            col = c;
        }
    }

    // ---- the wings: six planes on their hinges, behind the great eye ----
    for (float i = 0.0; i < 5.5; i += 1.0) {
        float side = i < 2.5 ? -1.0 : 1.0;
        float row = mod(i, 3.0) - 1.0;
        float tw = wrong(time, i + 9.0);
        vec3 hin = mid + vec3(side * (1.08 - 0.10 * abs(row)) * EYE, row * 0.40 * EYE, 0.25);
        // the beat: towards you and away
        float beat = (0.55 + 0.2 * hash(vec2(i, 5.0))) * sin(tw * (1.1 + 0.9 * hash(vec2(i, 6.0))) + i * 1.9);
        vec3 e1 = vec3(cos(beat), 0.0, -side * sin(beat));
        vec3 nrm = vec3(side * sin(beat), 0.0, cos(beat));
        float dn = dot(rd, nrm);
        if (abs(dn) < 1.0e-4)
            continue;
        float s = dot(hin, nrm) / dn;
        if (s <= 0.05 || s >= best)
            continue;
        vec3 at = rd * s - hin;
        vec2 ab = vec2(dot(at, e1), at.y);
        // up and down, the feathers after the bone
        float sway = (0.22 + 0.12 * hash(vec2(i, 8.0))) * sin((tw - 0.22 * length(ab)) * (0.8 + 0.7 * hash(vec2(i, 9.0))) + i * 2.7);
        float cs = cos(sway), sn = sin(sway);
        ab = vec2(ab.x * cs + ab.y * sn, -ab.x * sn + ab.y * cs);
        vec4 c = part(i, hinge(i) + ab / 3.6);
        if (c.a < 0.5)
            continue;
        c.rgb *= (0.62 + 0.38 * abs(nrm.z)) * mix(1.0, 0.5, clamp((s - 2.0) / 12.0, 0.0, 1.0));
        best = s;
        col = c;
    }

    // ---- the great eye, facing you: frame over iris over white over the finials ----
    {
        float s = FAR / rd.z;
        if (s < best) {
            vec2 q = (rd.xy * s - mid.xy) / EYE;
            vec4 c = part(6.0, 0.5 + q * 0.5);
            if (c.a < 0.5) {
                vec4 white = part(7.0, 0.5 + q * 0.5);
                if (white.a > 0.5) {
                    c = white;
                    if (abs(q.y) < 0.385 * (1.0 - q.x * q.x / 0.60)) {
                        vec2 off = clamp((look - origin) * 0.9 * attend, vec2(-1.0), vec2(1.0)) * vec2(0.36, 0.11);
                        vec4 ir = iris((q - off) / 0.37);
                        if (ir.a > 0.5)
                            c = vec4(ir.rgb, awake > 0.38 ? 2.0 : 1.0);   // it opens late in the dark
                    }
                }
            }
            if (c.a < 0.5)
                c = part(10.0, 0.5 + (q - vec2(0.0, -1.72)) * 0.5);
            if (c.a < 0.5)
                c = part(11.0, 0.5 + (q - vec2(0.0, 1.52)) * 0.5);
            if (c.a > 0.5) {
                best = s;
                col = c;
            }
        }
    }

    if (col.a < 0.5) {
        fragColor = vec4(0.0);
        return;
    }
    // a few colours, dithered
    vec3 lit = floor(col.rgb * 5.0 + bayer4(cell)) / 5.0;
    // unlit: a shape a shade off the dark, the open eyes' amber in it
    float on = clamp(shown, 0.0, 1.0);
    vec3 dark = vec3(0.043, 0.035, 0.066);
    if (col.a > 1.5)
        dark += col.rgb * 0.30 * step(bayer4(cell), 0.75);
    fragColor = vec4(mix(dark, lit, on), 1.0) * qt_Opacity;
}
