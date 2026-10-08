#version 440
// Workspace transitions: the frozen frame of the old workspace (`source`) is
// taken away over the live new one. Transparent where the new workspace shows.
// mode: 0 pixel dissolve, 1 zoom, 2 card, 3 wipe, 4 fade, 5 heaven / hell (`realm`),
//       6 glitch, 7 CRT.
// dir: 1 the switch goes down (the new desk comes from below, as in niri's slide), -1 up.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float mode;
    float cell;
    float seed;
    vec2 resolution;
    vec4 accent;
    float dir;
    float realm;    // 0 heaven, 1 hell
};
layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21) + seed);
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
float vnoise(vec2 x) {
    vec2 i = floor(x);
    vec2 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + 1.0), f.x), f.y);
}
float bayer2(vec2 a) {
    a = floor(a);
    return fract(a.x / 2.0 + a.y * a.y * 0.75);
}
float bayer8(vec2 a) {
    return bayer2(0.25 * a) * 0.0625 + bayer2(0.5 * a) * 0.25 + bayer2(a);
}
float easeOut3(float x) {
    return 1.0 - pow(1.0 - x, 3.0);
}
float easeInOut3(float x) {
    return x < 0.5 ? 4.0 * x * x * x : 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0;
}
// a rounded box around the origin, half size b; < 0 inside
float roundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
vec3 old(vec2 uv) {
    return texture(source, uv).rgb;
}
// the old frame, softly blurred by r (in uv across)
vec3 blurred(vec2 uv, float r) {
    vec2 o = vec2(r, r * resolution.x / resolution.y);
    vec3 c = old(uv) * 0.25;
    c += (old(uv + vec2(o.x, 0.0)) + old(uv - vec2(o.x, 0.0)) + old(uv + vec2(0.0, o.y)) + old(uv - vec2(0.0, o.y))) * 0.125;
    c += (old(uv + o) + old(uv - o) + old(uv + vec2(o.x, -o.y)) + old(uv + vec2(-o.x, o.y))) * 0.0625;
    return c;
}
// premultiplied
vec4 pre(vec3 c, float a) {
    return vec4(c * a, a);
}
// a over b, both premultiplied
vec4 over(vec4 a, vec4 b) {
    return a + b * (1.0 - a.a);
}

void main() {
    float p = clamp(progress, 0.0, 1.0);
    vec2 uv = qt_TexCoord0;
    if (p <= 0.0) {
        // the frozen frame, whole, until the switch has happened underneath
        fragColor = vec4(old(uv), 1.0) * qt_Opacity;
        return;
    }
    vec2 px = uv * resolution;
    float d = dir < 0.0 ? -1.0 : 1.0;
    // 0 at the end the new desk comes in from, 1 at the far one
    float along = d > 0.0 ? 1.0 - uv.y : uv.y;
    vec4 outc = vec4(0.0);

    if (mode < 0.5) {
        // pixel dissolve: blocks leave in an ordered-dither order, a sparkling edge
        vec2 b = floor(px / cell);
        float t = bayer8(b) * 0.82 + hash(b) * 0.18;
        float edge = t - p;
        if (edge > 0.0) {
            // sample the block's own centre: the old screen turns into pixel art as it goes
            vec2 centre = (b + 0.5) * cell / resolution;
            vec3 c = old(mix(uv, centre, smoothstep(0.0, 0.5, p)));
            if (edge < 0.07)
                c = mix(c, accent.rgb, 0.75);
            outc = vec4(c, 1.0);
        }
    } else if (mode < 1.5) {
        // zoom: the old desk grows a little, blurs and melts, drifting the way niri would slide it
        float e = easeOut3(p);
        vec2 q = (uv - 0.5) / (1.0 + 0.07 * e) + 0.5;
        q.y += d * 0.02 * e;
        outc = pre(blurred(q, 0.006 * e), 1.0 - smoothstep(0.05, 1.0, p));
    } else if (mode < 2.5) {
        // card: the old desk shrinks into a rounded card with a shadow, then flies off
        // the opposite way to where the new desk comes from
        float shrink = easeOut3(clamp(p / 0.38, 0.0, 1.0));
        float fly = clamp((p - 0.18) / 0.82, 0.0, 1.0);
        fly = fly * fly * fly;
        float s = 1.0 - 0.12 * shrink;
        vec2 half_ = resolution * 0.5 * s;
        float shadowPx = min(resolution.x, resolution.y) * 0.045;
        vec2 centre = resolution * 0.5 - vec2(0.0, d * fly * (resolution.y * (0.5 + 0.5 * s) + shadowPx * 2.0));
        float radius = min(resolution.x, resolution.y) * 0.025 * shrink;
        float sd = roundBox(px - centre, half_, radius);
        vec2 local = (px - centre) / (resolution * s) + 0.5;
        // a hairline of light on the card's edge
        vec3 c = mix(old(local) * (1.0 - 0.06 * shrink), vec3(1.0), 0.35 * shrink * (1.0 - smoothstep(-1.5, -0.5, sd)) * step(-1.5, sd));
        vec4 card = pre(c, 1.0 - smoothstep(-1.0, 0.5, sd));
        float shadow = 0.45 * shrink * (1.0 - smoothstep(-shadowPx * 0.3, shadowPx, roundBox(px - centre - vec2(0.0, shadowPx * 0.3), half_, radius)));
        // the new desk behind stays a touch dim until the card is gone
        float dim = 0.2 * shrink * (1.0 - fly);
        outc = over(card, over(vec4(0.0, 0.0, 0.0, shadow), vec4(0.0, 0.0, 0.0, dim)));
    } else if (mode < 3.5) {
        // wipe: a soft edge with an accent line sweeps from where the new desk comes in;
        // the old desk drifts on ahead of it
        float e = easeInOut3(p);
        float feather = 0.08;
        float lineW = max(2.0, cell * 0.25) / resolution.y;
        float f = e * (1.0 + feather + lineW * 2.0) - lineW;
        vec2 q = uv;
        q.y += d * 0.05 * e;
        float keep = smoothstep(f, f + lineW, along);
        vec4 o = pre(old(q) * (1.0 - 0.15 * (1.0 - smoothstep(f, f + feather, along))), keep);
        float line = 1.0 - smoothstep(lineW * 0.5, lineW, abs(along - f));
        float glow = 0.3 * (1.0 - smoothstep(0.0, feather, f - along)) * step(along, f);
        outc = over(pre(mix(accent.rgb, vec3(1.0), 0.25), line), over(o, pre(accent.rgb, glow * (1.0 - p))));
    } else if (mode < 4.5) {
        // fade
        outc = pre(old(uv), 1.0 - smoothstep(0.0, 1.0, p));
    } else if (mode < 5.5) {
        vec2 g = floor(px / (cell * 0.5));
        if (realm < 0.5) {
            // heaven: the old desk overexposes into warm light and scatters, pixel by
            // pixel, upwards; the last motes are the brightest
            vec3 light = vec3(1.0, 0.97, 0.88);
            float glow = smoothstep(0.0, 0.5, p);
            vec3 c = mix(blurred(uv, 0.005 * glow), light, glow * 0.6) + light * 0.12 * glow;
            float t = bayer8(g) * 0.6 + hash(g) * 0.25 + (1.0 - uv.y) * 0.15;
            float gone = smoothstep(0.15, 0.95, p) * 1.1;
            float edge = t - gone;
            if (edge > 0.0) {
                if (edge < 0.08 && gone > 0.0)
                    c = vec3(1.0);
                outc = pre(c, 1.0 - smoothstep(0.8, 1.0, p));
            }
        } else {
            // hell: it burns away from the edges on a ragged front; char behind the
            // embers, sparks over the hole
            float m = min(min(px.x, resolution.x - px.x), min(px.y, resolution.y - px.y)) / (min(resolution.x, resolution.y) * 0.5);
            float n = vnoise(g / 14.0) * 0.65 + vnoise(g / 5.0) * 0.35;
            float k = m + (n - 0.5) * 0.4 - (p * 1.45 - 0.22);
            if (k >= 0.0) {
                vec3 c = old(uv);
                c = mix(c, vec3(0.07, 0.025, 0.02), (1.0 - smoothstep(0.0, 0.2, k)) * 0.85);
                if (k < 0.025)
                    c = vec3(1.0, 0.88, 0.4);
                else if (k < 0.05)
                    c = vec3(1.0, 0.48, 0.1);
                else if (k < 0.075)
                    c = vec3(0.62, 0.1, 0.03);
                outc = vec4(c, 1.0);
            } else {
                float h = hash(g + floor(p * 18.0));
                if (k > -0.12 && h > 0.94)
                    outc = pre(mix(vec3(1.0, 0.45, 0.08), vec3(1.0, 0.9, 0.45), fract(h * 37.0)), 1.0 + k / 0.12);
            }
        }
    } else if (mode < 6.5) {
        // glitch: an RGB split, torn slices sliding sideways in jumps, interference;
        // the slices go in a torn order, the near end first
        float q = floor(p * 14.0) / 14.0;
        float rid = floor(uv.y * mix(16.0, 42.0, hash(vec2(q, 3.0))));
        float r = hash(vec2(rid, q * 7.0 + 1.0));
        float amp = smoothstep(0.0, 0.5, p) * 0.08;
        vec2 s = uv;
        s.x += (r - 0.5) * 2.0 * amp * step(0.45, r);
        s.y += d * q * 0.04 * step(0.5, hash(vec2(q, 5.0)));
        float split = 0.004 + 0.02 * p;
        vec3 c = vec3(old(s + vec2(split, 0.0)).r, old(s).g, old(s - vec2(split, 0.0)).b);
        float line = step(0.97, hash(vec2(floor(px.y / 2.0), q * 13.0)));
        c = mix(c, accent.rgb, line * 0.5) + (hash(floor(px / 2.0) + q) - 0.5) * 0.1 * p;
        float order = hash(vec2(rid, 9.0)) * 0.55 + along * 0.45;
        outc = pre(c, step(p * 1.3 - 0.2, order));
    } else {
        // CRT: the picture collapses to a white-hot line, then a dot, on a black tube;
        // the new desk comes on as the dot dies
        float a1 = clamp(p / 0.42, 0.0, 1.0);
        float a2 = clamp((p - 0.42) / 0.26, 0.0, 1.0);
        float a3 = clamp((p - 0.68) / 0.32, 0.0, 1.0);
        float sy = max(3.0 / resolution.y, 1.0 - a1 * a1);
        float sx = max(3.0 / resolution.x, 1.0 - a2 * a2);
        vec2 c = uv - 0.5;
        float inside = step(abs(c.x), sx * 0.5) * step(abs(c.y), sy * 0.5);
        vec3 col = old(clamp(vec2(c.x / sx, c.y / sy) + 0.5, 0.0, 1.0));
        col = mix(col, vec3(1.0), smoothstep(0.3, 1.0, a1)) * (1.0 + 0.5 * a1);
        col *= 0.86 + 0.14 * step(0.5, fract(px.y / 3.0));
        float dotA = 1.0 - a3;
        vec2 outPx = max(abs(c) - vec2(sx, sy) * 0.5, 0.0) * resolution;
        float halo = exp(-length(outPx) / (cell * 1.5)) * smoothstep(0.5, 1.0, a1) * dotA * 0.7;
        vec4 img = over(pre(col, inside * dotA), pre(vec3(0.85, 0.92, 1.0), halo));
        outc = over(img, vec4(0.0, 0.0, 0.0, (1.0 - smoothstep(0.0, 1.0, a3)) * 0.94));
    }
    fragColor = outc * qt_Opacity;
}
