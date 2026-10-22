#version 440
// Heaven's Gate: the wallpaper change as a game's loading screen (GateScene).
// The desktop freezes (frozenTex) and fades; the gates (cinema bars, 21:9, their height and
// cut from GateScene) carry a pixel ornament and a halo turning with its wings. Then three
// slabs sweep across on a slant (Persona 5): the old colour, white, the new picture's colour,
// which holds as a title card (sunburst, halftone, a great halo; the name is GateScene's).
// The slabs leave the other way over the new picture (wallTex) as an old photograph in the
// new colour, grain on it, the camera drifting, developing in blots (RDR2's loading). The gates
// open like a film widening to the full screen, and a slanted light sweeps the live desktop
// back. Times in seconds, the same as GateScene's cues.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float t;
    float barNow;      // the bars' height now, a share of the screen's
    float slant;       // their cut's slope while they slam in
    float seed;
    vec2 resolution;
    vec4 accent;       // the old picture's colour (the theme follows the picture)
    vec4 accentNew;    // the new one's
};

layout(binding = 1) uniform sampler2D frozenTex;
layout(binding = 2) uniform sampler2D wallTex;

const float CUT_IN = 1.7;
const float COVER = 2.0;
const float CARD_OUT = 2.8;
const float REVEALED = 3.15;
const float OPEN = 3.9;
const float OPENED = 4.5;
const float END = 5.15;

float bayer2(vec2 a) {
    a = floor(a);
    return fract(a.x / 2.0 + a.y * a.y * 0.75);
}
float bayer4(vec2 a) {
    return bayer2(0.5 * a) * 0.25 + bayer2(a);
}
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
float vnoise(vec2 x) {
    vec2 i = floor(x);
    vec2 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
vec2 rot(vec2 v, float a) {
    float c = cos(a);
    float s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}
float easeOut3(float x) {
    float y = 1.0 - clamp(x, 0.0, 1.0);
    return 1.0 - y * y * y;
}
float easeIn3(float x) {
    float y = clamp(x, 0.0, 1.0);
    return y * y * y;
}
// a pixel halo: an ellipse one cell and a half thick, with three feathers a side;
// 2 on the ring, 1 on a wing, 0 off it
float halo(vec2 cpx, vec2 hc, float hr, float cs, float t, out float lit) {
    vec2 q = (cpx - hc) / vec2(1.0, 0.34);
    float ring = step(abs(length(q) - hr), cs * 1.6);
    lit = 0.35 + 0.65 * smoothstep(0.5, 1.0, fract(atan(q.y, q.x) / 6.2831853 + 0.5 - t * 0.9));
    float flap = 0.12 * sin(t * 9.0);
    float wing = 0.0;
    for (int w = 0; w < 6; w++) {
        float side = w < 3 ? -1.0 : 1.0;
        float k = mod(float(w), 3.0);
        vec2 fq = rot(cpx - hc - vec2(side * hr * 0.95, 0.0), -side * (0.35 + k * 0.38 + flap));
        float fl = hr * (0.9 - k * 0.2);
        wing = max(wing, step(length((fq - vec2(side * fl * 0.5, 0.0)) / vec2(fl * 0.5, max(cs * 1.4, hr * 0.06))), 1.0));
    }
    return ring > 0.5 ? 2.0 : wing;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * resolution;
    float cs = max(3.0, floor(resolution.y / 240.0));
    vec2 cpx = (floor(px / cs) + 0.5) * cs;
    float dith = bayer4(cpx / cs);
    vec3 lumW = vec3(0.299, 0.587, 0.114);
    // the gates take the new colour as the card comes in, in a quick dither
    vec3 acc = mix(accent.rgb, accentNew.rgb, step(dith, (t - COVER) / 0.1));
    vec3 glow = mix(acc, vec3(1.0), 0.6);
    vec3 glowNew = mix(accentNew.rgb, vec3(1.0), 0.6);

    // ---- the frozen desktop: a slow push-in, colour draining, the channels drifting apart
    float hush = smoothstep(0.0, 0.45, t);
    vec2 fz = 0.5 + (uv - 0.5) / (1.0 + 0.04 * smoothstep(0.0, COVER, t));
    float split = 1.5 * hush / resolution.x;
    vec3 frozen = vec3(texture(frozenTex, fz + vec2(split, 0.0)).r, texture(frozenTex, fz).g, texture(frozenTex, fz - vec2(split, 0.0)).b);
    frozen = mix(frozen, vec3(dot(frozen, lumW)), 0.55 * hush) * (1.0 - 0.22 * hush);

    // ---- the new picture: an old photograph in the new colour, grain on it, the camera
    // drifting (already under the card), developing in blots into its own colours; framed
    // exactly as the live wallpaper once the gates are open
    float cam = smoothstep(CARD_OUT, OPENED, t);
    vec2 wuv = 0.5 + (uv - 0.5) / mix(1.1, 1.0, cam) + vec2(0.03, -0.012) * (1.0 - cam);
    vec3 wall = texture(wallTex, wuv).rgb;
    float dev = clamp((t - REVEALED) / (OPEN - REVEALED), 0.0, 1.0);
    float blot = vnoise(cpx / resolution.y * 4.0 + seed);
    float shown = step(blot * 0.8 + dith * 0.2, dev * 1.15 - 0.05);
    float wl = dot(wall, lumW);
    float grain = (hash(floor(cpx / cs) + floor(t * 24.0)) - 0.5) * 0.09;
    vec3 photo = mix(vec3(wl), wl * accentNew.rgb * 1.6, 0.5) * 0.92 + grain;
    vec3 scene = t < COVER ? frozen : mix(photo, wall, shown);
    // inside the frame the corners sink while the gates hold
    float holdV = smoothstep(0.45, 0.75, t) * (1.0 - smoothstep(OPEN, OPENED, t));
    scene *= 1.0 - 0.35 * holdV * smoothstep(0.35, 0.85, length((uv - 0.5) * vec2(1.0, 1.4)));

    // ---- the slabs: three bands on a slant, in from the right one after another, out to
    // the left the other way round; a lit edge leads each
    float k = 0.45;
    float span = resolution.x + resolution.y * k;
    float s = (cpx.x + (resolution.y - cpx.y) * k) / span;
    float rim = cs * 1.5 / span;
    int top = -1;
    float edge = 0.0;
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float front = 1.15 - 1.3 * easeOut3((t - CUT_IN - fi * 0.07) / 0.26);
        float back = 1.15 - 1.3 * easeIn3((t - CARD_OUT - (2.0 - fi) * 0.07) / 0.26);
        if (s > front && s < back) {
            top = i;
            edge = max(step(s - front, rim), step(back - s, rim));
        }
    }
    vec3 col = scene;
    if (top == 0) {
        // the old colour, dark, a halftone of it
        vec2 hd = mod(cpx, cs * 4.0) - cs * 2.0;
        col = mix(vec3(0.03), accent.rgb, 0.35);
        col = mix(col, accent.rgb * 0.7, step(length(hd), cs * 1.2));
    } else if (top == 1) {
        col = mix(vec3(1.0), accent.rgb, 0.12);
    } else if (top == 2) {
        // the card: the new colour, a turning sunburst, a halftone swelling to the edges and a
        // great halo behind the name
        vec2 c = cpx - resolution * 0.5;
        float rays = step(0.5, fract(atan(c.y, c.x) / 6.2831853 * 18.0 + t * 0.12));
        col = accentNew.rgb * mix(0.72, 0.92, rays);
        vec2 hd = mod(cpx, cs * 5.0) - cs * 2.5;
        float dotR = cs * (0.4 + 2.2 * smoothstep(0.15, 0.75, length(c / resolution.y)));
        col = mix(col, accentNew.rgb * 0.5, step(length(hd), dotR));
        float lit;
        float h = halo(cpx, resolution * vec2(0.5, 0.47), resolution.y * 0.3, cs, t, lit);
        if (h > 1.5)
            col = mix(glowNew, vec3(1.0), 0.4 * lit) * (0.6 + 0.4 * lit);
        else if (h > 0.5)
            col = mix(vec3(1.0), accentNew.rgb, 0.25);
    }
    if (top >= 0 && edge > 0.5)
        col = mix(vec3(1.0), top == 2 ? accentNew.rgb : accent.rgb, 0.15);

    // ---- the gates: near black in their colour, a lit rim, a double line and a row of
    // diamonds a light runs along; the halo and its wings in the lower one
    vec2 cuv = cpx / resolution;
    float tilt = slant * (0.5 - cuv.x) - 0.5 * slant;
    float dT = barNow + tilt - cuv.y;
    float dB = cuv.y - (1.0 - barNow - tilt);
    if (max(dT, dB) >= 0.0) {
        float dc = max(dT, dB) * resolution.y / cs;      // cells from the cut
        vec3 bar = mix(vec3(0.015), acc, 0.08);
        bar = mix(bar, acc * 0.6, 0.6 * step(dith + 0.07, 0.5 * exp(-dc / 6.0)));
        float line = step(abs(dc - 3.3), 0.4) + step(abs(dc - 10.7), 0.4);
        float lx = floor(cpx.x / cs);
        vec2 dm = vec2(mod(lx, 14.0) - 7.0, dc - 7.0);
        float dd = abs(dm.x) + abs(dm.y);
        float diamond = step(dd, 2.6) * (step(1.6, dd) + step(dd, 0.6));
        float head = fract(t * 0.45 + (dB > 0.0 ? 0.5 : 0.0)) * resolution.x / cs;
        float run = exp(-abs(lx - head) / 10.0);
        bar = mix(bar, acc * (0.55 + 0.6 * run), min(1.0, line + diamond) * 0.85);
        bar = mix(bar, mix(acc, vec3(1.0), 0.45 + 0.3 * run), step(dc, 1.5));
        float outer = barNow * resolution.y - 12.0 * cs;
        if (dB > 0.0 && outer > 28.0) {
            float lit;
            float h = halo(cpx, vec2(resolution.x - outer * 1.6, resolution.y - outer * 0.5), outer * 0.5, cs, t, lit);
            if (h > 1.5)
                bar = mix(acc, glow, 0.5 * lit) * (0.5 + 0.5 * lit);
            else if (h > 0.5)
                bar = mix(glow, acc, 0.3);
        }
        col = bar;
    }

    // ---- the end: a slanted light sweeps across, the live desktop behind it
    float alpha = 1.0;
    if (t > OPENED) {
        // nearly even, a touch slower at the start: seen all the way across
        float x = clamp((t - OPENED) / (END - OPENED - 0.05), 0.0, 1.0);
        float sw = 1.25 - 1.5 * mix(x, x * x, 0.3);
        float behind = (s - sw) * span / cs;           // cells past the light
        if (behind > 0.0) {
            // a trail of light, thinning out in a dither
            alpha = step(dith, (1.0 - behind / 26.0) * 0.85);
            col = mix(acc, vec3(1.0), 0.35 + 0.4 * exp(-behind / 6.0));
        } else if (behind > -2.0) {
            col = vec3(1.0);
        } else if (behind > -10.0) {
            // the light comes before it
            col = mix(col, mix(acc, vec3(1.0), 0.6), step(dith, (1.0 + behind / 10.0) * 0.7));
        }
    }
    fragColor = vec4(col, 1.0) * alpha * qt_Opacity;
}
