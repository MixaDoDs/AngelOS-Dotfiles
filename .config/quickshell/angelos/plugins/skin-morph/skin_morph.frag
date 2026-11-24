#version 440
// skin-morph: the frozen frame of the old skin over the live new one, taken away in a wave that
// runs down the screen — the top bar first, then the windows and widgets, the Dock / taskbar last
// (each band starts `STAGE` later and lasts `DUR` of the whole progress).
//   toMac 1 (Classic → Golden Gate): the pixels frost over — they blur, soften and go milky like
//           glass — and melt away, the glass UI showing through.
//   mode 2 (→ serp): a drop falls over the islands and a ring runs out from it as on water: its
//           front is a liquid lens (the old skin bends and splits a hair by colour under it, a
//           sheen in serp's accent on the crest), the new skin opens behind it with soft ripples
//           fading across it, and ahead of it the old frame trembles like a surface about to be hit.
//   toMac 0 (Golden Gate → Classic): the glass degrades — the mosaic grows in steps (art pixel,
//           ×2, ×4, ×8), the palette is crushed with a Bayer dither, scanlines flicker in,
//           and the big cells drop out in an ordered-dither order, revealing the pixel desktop.
// Output is premultiplied.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;     // 0 … 1, linear
    float toMac;
    vec2 resolution;    // the item's size, px
    float cell;         // one art pixel, px
    float topBand;      // the top bar's band, px
    float bottomBand;   // the Dock's / taskbar's band, px
    vec4 frost;         // the glass's milk
    float mode;         // 0 Classic, 1 Golden Gate, 2 serp (the skin arriving)
    vec2 origin;        // serp: where the drop falls, px
    vec4 accent;        // serp: the crest's sheen
};
layout(binding = 1) uniform sampler2D source;

float bayer2(vec2 a) {
    a = floor(a);
    return fract(dot(a, vec2(0.5, a.y * 0.75)));
}
float bayer4(vec2 a) {
    return bayer2(0.5 * a) * 0.25 + bayer2(a);
}
float bayer8(vec2 a) {
    return bayer4(0.5 * a) * 0.25 + bayer2(a);
}
float easeInOut(float t) {
    return t < 0.5 ? 4.0 * t * t * t : 1.0 - pow(-2.0 * t + 2.0, 3.0) * 0.5;
}

void main() {
    const float STAGE = 0.22;
    const float DUR = 0.56;
    vec2 px = qt_TexCoord0 * resolution;
    float h = resolution.y;
    float ramp = h * 0.12;
    float delay = STAGE * smoothstep(topBand, topBand + ramp, px.y)
                + STAGE * smoothstep(h - bottomBand - ramp, h - bottomBand, px.y);
    float t = clamp((progress - delay) / DUR, 0.0, 1.0);

    if (mode > 1.5) {
        vec2 dv = px - origin;
        float d = length(dv);
        vec2 dir = dv / max(d, 1.0);
        vec2 far = max(origin, resolution - origin);
        float maxD = length(far) + 180.0;
        float p = progress;
        float te = 1.0 - pow(1.0 - p, 2.1);            // the ring flies out, then slows
        float R = te * maxD;
        float W = 70.0 + 90.0 * te;                     // the front widens as it travels
        float x = (d - R) / W;                          // < 0 behind the front, > 0 ahead
        // ahead: the surface trembles, more the nearer the front
        float ahead = step(0.0, x) * exp(-x * 0.9);
        float tremble = sin(d * 0.07 - p * 46.0) * 2.4 * ahead * (1.0 - p);
        // the front: a lens (the gaussian's slope), strongest early on
        float lens = -2.0 * x * exp(-x * x * 1.6) * 34.0 * (1.0 - 0.55 * p);
        vec2 off = dir * (lens + tremble);
        vec3 c;
        c.r = texture(source, clamp(px - off * 1.10, vec2(0.5), resolution - 0.5) / resolution).r;
        c.g = texture(source, clamp(px - off, vec2(0.5), resolution - 0.5) / resolution).g;
        c.b = texture(source, clamp(px - off * 0.90, vec2(0.5), resolution - 0.5) / resolution).b;
        // the crest's sheen, and a thin caustic just behind it
        float crest = exp(-pow((x - 0.12) / 0.16, 2.0));
        float caustic = exp(-pow((x + 0.38) / 0.07, 2.0));
        vec3 sheen = mix(vec3(1.0), accent.rgb, 0.45);
        c += sheen * (0.42 * crest + 0.25 * caustic) * (1.0 - 0.6 * p);
        float alpha = smoothstep(-0.55, 0.35, x);
        // behind: soft ripples over the new skin, dying out away from the front and with time
        float behind = clamp(-x, 0.0, 30.0);
        float ring = pow(max(0.0, sin((R - d) * 0.055 + 0.6)), 8.0);
        float rip = ring * 0.24 * exp(-behind * 0.16) * (1.0 - p) * (1.0 - alpha);
        // the drop itself, the first instant: a bright bead at the origin
        float bead = exp(-d * d / (900.0 + 40000.0 * p)) * smoothstep(0.12, 0.0, p) * 0.6;
        vec3 col = c * alpha + sheen * (rip + bead);
        float a = clamp(alpha + rip + bead, 0.0, 1.0);
        fragColor = vec4(col, a) * qt_Opacity;
        return;
    }
    if (toMac > 0.5) {
        float r = 22.0 * easeInOut(smoothstep(0.0, 0.75, t));
        vec3 c = vec3(0.0);
        for (int i = 0; i < 24; i++) {
            float fi = float(i);
            float rr = r * sqrt((fi + 0.5) / 24.0);
            float a = fi * 2.39996;
            c += texture(source, (px + rr * vec2(cos(a), sin(a))) / resolution).rgb;
        }
        c /= 24.0;
        c = mix(c, frost.rgb, 0.22 * smoothstep(0.1, 0.6, t));
        // a soft sheen on the front of the wave
        c += 0.06 * (1.0 - abs(t - 0.45) / 0.45) * step(abs(t - 0.45), 0.45);
        float alpha = 1.0 - easeInOut(smoothstep(0.35, 1.0, t));
        fragColor = vec4(c * alpha, alpha) * qt_Opacity;
    } else {
        float steps = floor(3.0 * smoothstep(0.04, 0.5, t) + 0.0001);
        float bs = t < 0.04 ? 1.0 : cell * exp2(steps);
        vec2 blk = floor(px / bs);
        vec3 c = texture(source, min((blk + 0.5) * bs, resolution - 0.5) / resolution).rgb;
        float lv = mix(48.0, 4.0, smoothstep(0.08, 0.55, t));
        c = clamp(floor(c * lv + bayer8(px / cell) - 0.5 + 0.5) / lv, 0.0, 1.0);
        float scan = step(0.5, fract(px.y / (cell * 2.0)));
        c *= 1.0 - 0.14 * scan * sin(3.14159 * clamp(t * 1.4, 0.0, 1.0));
        float k = (t - 0.55) / 0.45;
        float alpha = bayer8(blk) < k ? 0.0 : 1.0;
        fragColor = vec4(c * alpha, alpha) * qt_Opacity;
    }
}
