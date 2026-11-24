#version 440
// serp-skin: the boot screen («Пробуждение»), one pass over the whole screen, p 0 … 1 (3.4 s).
//   0.00–0.14  a drop of light falls into the middle out of the dark
//   0.14       it hits: rings run out as on water (flattened, as if seen over a lake)
//   0.14–0.30  the drop opens into a halo — a ring of liquid light, an ellipse
//   0.24–0.84  the halo fills with light round from its top: that is the progress
//   0.84–0.97  the halo rises to where the Halo lives (top middle) and shrinks
//   0.86–1.00  the screen opens in a widening circle from the middle onto the desktop under it
// Behind it all: the user's wallpaper (SerpBackdrop's texture) blurred deep and darkened into the
// skin's base, as through frosted glass. Output premultiplied.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float p;
    vec2 resolution;
    vec4 accent;
    vec4 base;
    float haloY;        // px, where the halo goes at the end
    float wallOn;       // the wallpaper texture is there
};
layout(binding = 1) uniform sampler2D wall;

const float PI = 3.14159265;

float outBack(float t) {
    float c1 = 1.5, c3 = c1 + 1.0;
    return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0);
}
float ease(float t) {
    return t * t * (3.0 - 2.0 * t);
}

void main() {
    vec2 px = qt_TexCoord0 * resolution;
    float m = min(resolution.x, resolution.y);
    vec2 c = vec2(resolution.x * 0.5, resolution.y * 0.42);
    vec3 acc = accent.rgb;
    vec3 light = mix(acc, vec3(1.0), 0.45);

    // ---- the ground: the wallpaper through frosted glass, the skin's base over it ----
    vec3 bg = base.rgb;
    if (wallOn > 0.5) {
        vec3 w = textureLod(wall, qt_TexCoord0, 5.5).rgb;
        bg = mix(base.rgb, w * 0.85, 0.72);
    }
    float vig = length((px - c) / resolution);
    bg *= 1.0 - 0.45 * smoothstep(0.3, 0.9, vig);
    bg += acc * 0.07 * exp(-pow(length(px - c) / (m * 0.45), 2.0));
    bg *= smoothstep(0.0, 0.18, p);                      // out of the dark

    vec3 lightc = vec3(0.0);                         // what glows, over everything
    float glowA = 0.0;

    // ---- the drop ----
    if (p < 0.16) {
        float t = clamp(p / 0.14, 0.0, 1.0);
        vec2 dp = vec2(c.x, mix(-m * 0.05, c.y, t * t));
        float r = m * 0.010;
        float d = length(px - dp);
        float core = smoothstep(r, r * 0.6, d);
        float halo = exp(-d / (m * 0.025)) * 0.6;
        // a short tail of light above it while it falls
        vec2 q = px - dp;
        float tail = q.y < 0.0 ? exp(-abs(q.x) / (m * 0.004)) * exp(q.y / (m * 0.06)) * 0.5 * t : 0.0;
        float fade = 1.0 - smoothstep(0.14, 0.16, p);
        lightc += (light * core + acc * (halo + tail)) * fade;
        glowA = max(glowA, clamp(core + halo + tail, 0.0, 1.0) * fade);
    }

    // ---- the rings on the water ----
    for (int k = 0; k < 3; k++) {
        float start = 0.14 + float(k) * 0.07;
        float age = p - start;
        if (age > 0.0 && age < 0.55) {
            vec2 q = px - c;
            float dist = length(vec2(q.x, q.y * 2.8));    // flattened: a surface seen at a slant
            float rad = age * m * 1.5;
            float w = m * (0.004 + age * 0.03);
            float ring = exp(-pow((dist - rad) / w, 2.0)) * (1.0 - age / 0.55) * (0.32 - 0.07 * float(k));
            lightc += light * ring;
            glowA = max(glowA, ring);
        }
    }

    // ---- the halo ----
    float form = clamp((p - 0.14) / 0.16, 0.0, 1.0);
    if (form > 0.0) {
        float rise = ease(smoothstep(0.84, 0.97, p));
        vec2 hc = vec2(c.x, mix(c.y, haloY, rise));
        float sc = outBack(form) * mix(1.0, 0.32, rise);
        vec2 rad = vec2(m * 0.17, m * 0.17 * 0.30) * max(sc, 0.001);
        vec2 q = (px - hc) / rad;
        float len = length(q);
        float d = (len - 1.0) / max(length(q / (max(len, 1e-3) * rad)), 1e-4);   // ≈ px off the ellipse
        float tk = m * 0.0045 * mix(1.0, 0.6, rise);
        float core = exp(-pow(d / tk, 2.0));
        float glow = exp(-abs(d) / (tk * 7.0));
        // round from the top, clockwise: how far along this point lies
        float frac = fract(atan(q.x, -q.y) / (2.0 * PI) + 1.0);
        float fill = clamp((p - 0.24) / 0.60, 0.0, 1.0);
        float lit = fill >= 1.0 ? 1.0 : smoothstep(fill + 0.004, fill - 0.004, frac);
        float spark = fill > 0.0 && fill < 1.0 ? exp(-pow((frac - fill) * 60.0, 2.0)) : 0.0;
        float shimmer = 0.15 * sin(frac * 38.0 - p * 26.0) * lit;
        float bright = mix(0.22, 1.0, lit) + shimmer + spark * 1.2;
        float fade = 1.0 - smoothstep(0.95, 1.0, p);
        vec3 hcol = (light * core * bright + acc * glow * (0.35 + 0.45 * fill) + vec3(1.0) * spark * core * 0.6) * fade;
        lightc += hcol;
        glowA = max(glowA, clamp(core * bright + glow * 0.5, 0.0, 1.0) * fade);
    }

    // ---- the opening: a circle from the middle onto the desktop ----
    float o = smoothstep(0.86, 1.0, p);
    float far = length(max(c, resolution - c)) + m * 0.2;
    float R = pow(o, 1.6) * far;
    float dc = length(px - c);
    float alpha = o > 0.0 ? smoothstep(R - m * 0.04, R + m * 0.01, dc) : 1.0;
    float sheen = o > 0.0 && o < 1.0 ? exp(-pow((dc - R) / (m * 0.012), 2.0)) * (1.0 - o) : 0.0;

    // the ground goes with the opening, the light stays over the desktop until it fades
    lightc += light * sheen * 0.8;
    float outa = clamp(alpha + (1.0 - alpha) * max(glowA, sheen) * 0.9, 0.0, 1.0);
    vec3 outc = bg * alpha + lightc;
    fragColor = vec4(min(outc, vec3(outa)), outa) * qt_Opacity;
}
