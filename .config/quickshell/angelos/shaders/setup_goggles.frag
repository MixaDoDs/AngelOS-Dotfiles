#version 440
// The first run's intro, its first minute: what she sees in the cheap wired goggles of 2002
// (modules/settings/SetupPrequel.qml cuts to it for a few seconds at a time). Two round lenses;
// in each the game — falling down a round shaft of nine tiers, doors in its wall with an amber
// eye in each, the bricks swimming as they did on that hardware — a little differently for each
// eye, and more so as `apart` grows. A slow panel: fifteen pictures a second, the last one still
// fading; its three colours side by side in every pixel; the lens's rim splitting them.
// `depth` 0…1: how far down (cold blue to red, the light from below); `burn`: fire down there.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;   // px
    float px;        // one art pixel, px
    float time;      // s
    float depth;     // 0…1
    float apart;     // the eyes' pictures apart, in lens radii
    float burn;      // 0…1
    float still;     // 1: the title — the shaft far and slow behind it
};

const float PI2 = 6.2831853;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float bayer2(vec2 a) {
    a = floor(a);
    return fract(dot(a, vec2(0.5, a.y * 0.75)));
}
float bayer4(vec2 a) {
    return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

// the game at `t`, `q` −1…1 over the lens
vec3 game(vec2 q, float t) {
    float fall = still > 0.5 ? t * 0.35 : t * 1.9;
    // her head: never quite still
    vec3 d = normalize(vec3(q * 0.95 + 0.10 * vec2(sin(t * 0.9), cos(t * 0.7)), 1.0));
    vec3 c = vec3(0.28 * sin(t * 0.6), 0.22 * cos(t * 0.45), fall);
    float a = dot(d.xy, d.xy);
    float b = dot(c.xy, d.xy);
    float s = (-b + sqrt(max(0.0, b * b - a * (dot(c.xy, c.xy) - 1.0)))) / max(a, 1.0e-5);
    vec3 h = c + s * d;
    // the wall, on a coarse grid that swims
    float ang = atan(h.y, h.x) / PI2 + 0.03 * h.z;
    vec2 w = vec2(ang * 16.0, h.z * 1.6);
    w = floor(w * 8.0 + 0.5 * sin(t * 6.0 + w.yx * 3.0)) / 8.0;
    float tier = floor(h.z / 3.0);
    float zf = fract(h.z / 3.0);
    vec2 f = fract(w + vec2(0.5 * mod(floor(w.y), 2.0), 0.0));
    vec3 cold = vec3(0.34, 0.40, 0.74), hot = vec3(0.80, 0.22, 0.12);
    vec3 col = mix(cold, hot, clamp(depth + 0.06 * mod(tier, 3.0), 0.0, 1.0));
    col *= 0.72 + 0.28 * hash(floor(w + vec2(0.5 * mod(floor(w.y), 2.0), 0.0)));
    if (f.x < 0.08 || f.y < 0.10)
        col *= 0.45;
    // a ledge round every tier, a door in every fourth of it, an eye in the door
    if (zf < 0.07)
        col = mix(col, vec3(0.95, 0.85, 0.6), 0.6);
    float door = fract(ang * 4.0 + tier * 0.37);
    if (zf > 0.22 && zf < 0.80 && door < 0.34) {
        vec2 dq = vec2((door - 0.17) / 0.17, (zf - 0.51) / 0.29);
        col = abs(dq.x) > 0.84 || abs(dq.y) > 0.9 ? vec3(0.62, 0.50, 0.30) : vec3(0.03, 0.02, 0.05);
        vec2 e = dq * vec2(1.0, 2.2);
        if (dot(e, e) < 0.16)
            col = abs(e.x) < 0.07 ? vec3(0.05, 0.02, 0.06) : vec3(0.98, 0.70, 0.18);
    }
    // the dark of the shaft, lit from below the deeper it is
    float fog = exp(-s * 0.26);
    vec3 below = mix(vec3(0.02, 0.02, 0.07), vec3(0.95, 0.30, 0.06), depth * depth);
    col = mix(below, col, fog);
    // fire down there, coming up
    if (burn > 0.0) {
        float n = noise(vec2(q.x * 3.5, q.y * 2.5 + t * 3.0)) * (1.0 - fog) + 0.25 * burn - length(q) * 0.5;
        if (n > 0.62 - 0.4 * burn)
            col = n > 0.8 - 0.4 * burn ? vec3(1.0, 0.92, 0.6) : vec3(1.0, 0.55, 0.12);
    }
    return col;
}

void main() {
    vec2 frag = qt_TexCoord0 * itemSize;
    vec2 cell = floor(frag / px);
    vec2 p = (cell + 0.5) * px;
    vec2 uv = (p - itemSize * 0.5) / (0.5 * min(itemSize.x, itemSize.y));
    // two lenses, side by side; on an upright screen they overlap
    bool wide = itemSize.x > itemSize.y;
    float r = wide ? 0.84 : 0.72;
    float off = wide ? 0.80 : 0.36;
    float side = uv.x < 0.0 ? -1.0 : 1.0;
    vec2 e = (uv - vec2(side * off, 0.0)) / r;
    float d = length(e);
    if (d > 1.0) {
        fragColor = vec4(0.008, 0.006, 0.012, 1.0) * qt_Opacity;
        return;
    }
    // each eye its own picture; fifteen a second, the one before still there
    float ts = floor(time * 15.0) / 15.0;
    vec2 q = e + vec2(side * apart, 0.02 * side * apart);
    vec3 col = mix(game(q, ts), game(q, ts - 1.0 / 15.0), 0.4);
    col = floor(col * 5.0 + bayer4(cell)) / 5.0;
    // the lens: dark towards its rim, red on one side of it and blue on the other
    float rim = smoothstep(0.72, 1.0, d);
    col *= 1.0 - 0.75 * rim * rim;
    col += rim * 0.22 * (e.x > 0.0 ? vec3(1.0, 0.1, 0.2) : vec3(0.1, 0.5, 1.0)) * (0.3 + col);
    // the panel: red, green, blue side by side in every pixel, a dark line under each row
    float third = mod(floor(frag.x / max(1.0, floor(px / 3.0))), 3.0);
    col *= third < 0.5 ? vec3(1.30, 0.80, 0.80) : third < 1.5 ? vec3(0.80, 1.30, 0.80) : vec3(0.80, 0.80, 1.30);
    if (mod(frag.y, px) < 1.0)
        col *= 0.55;
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
