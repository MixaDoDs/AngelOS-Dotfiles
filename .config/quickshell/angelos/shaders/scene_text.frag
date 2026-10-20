#version 440
// Text drawn on a scene's art grid (widgets/SceneDepthText): hard pixels only, colours from the
// scene's palette, in one of four looks (style):
//   0 outline — a sticker: the glyphs on a light rim, a dark hairline round it; textured, a
//               gloss stripe runs across
//   1 neon    — a light core, a ring of the glyphs' colour, a checker glow (no blur); neonFx
//               adds light touches: 1 the colour rising at the top, 2 electrodes at the stroke
//               ends, 4 scan lines in the ring, 8 dust, 16 the colour sinking to the foot (the
//               top brightest), 32 the glow pooling under the letters
//   2 chrome  — light to dark bands ringed in the darkest colour; textured, it mirrors the scene:
//               its sky above a dark horizon, its ground below
//   3 cutout  — a calling card (Persona 5): every symbol on its own tilted plate, black, white
//               or the accent, in its own font (SceneDepthText draws them in those colours), a
//               dark rim round all and a hard shadow of the accent; textured, halftone dots on
//               the light plates
//   4 lcd     — a Nokia screen: a green panel in a dark bezel, the glyphs as a dot matrix (a gap
//               between the font's pixels) with a ghost down-right; textured, the unlit grid
//   5 aqua    — a glossy bubble (Windows XP, Frutiger Aero): a light top edge, a pale gloss over the
//               upper half, the colour below, a dark hairline, a light rim, a drop shadow
// texel = one art pixel; w = the ring / shadow width in art pixels (at most 4).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 glyph;     // the main colour
    vec4 second;    // shadow / glow: stands out from both the glyphs and the backdrop
    vec4 light;     // the palette's light end (neon foot, chrome top, the sticker's rim)
    vec4 dark;      // the palette's dark end (chrome bottom, hairlines, electrodes)
    vec2 texel;
    vec2 band;      // the glyphs' top and bottom, texture y
    float w;
    float style;
    vec4 glyphAlt;  // a step off the glyphs' colour (neon ring, specks, an unlit tube)
    vec2 texFrom;   // where the cut-out's paper reads the picture's grain, art px on the canvas
    vec2 canvas;
    vec2 artSize;
    float textured;
    vec4 mid;       // between the light end and the glyphs (the neon's middle)
    float time;     // the scene's seconds
    vec4 panel;     // the LCD: x, y, width, height, art px
    vec4 lcdBg;
    vec4 lcdInk;
    vec4 lcdGhost;
    float neonFx;   // bits: 1 colour at the top, 2 electrodes, 4 scan lines, 8 dust, 16 colour at
                    // the foot, 32 glow below
    vec2 fontAt;    // the label's top-left, art px
    float fontPx;   // art px per font px
};
layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D pattern;
layout(binding = 3) uniform sampler2D reflection;   // the whole scene (chrome)

// a 4×4 ordered dither threshold, 0..1
float bayer2(vec2 a) {
    a = floor(a);
    return fract(dot(a, vec2(0.5, a.y * 0.75)));
}
float bayer4(vec2 a) {
    return bayer2(0.5 * a) * 0.25 + bayer2(a);
}
float hash3(vec3 p) {
    return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}
float lum(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}
// a darker speck in the picture's grain here: the pixel against its four neighbours
bool speck() {
    vec2 p = texFrom + floor(qt_TexCoord0 * artSize) + 0.5;
    float c = lum(texture(pattern, p / canvas).rgb);
    float n = lum(texture(pattern, (p + vec2(1.0, 0.0)) / canvas).rgb) + lum(texture(pattern, (p - vec2(1.0, 0.0)) / canvas).rgb)
            + lum(texture(pattern, (p + vec2(0.0, 1.0)) / canvas).rgb) + lum(texture(pattern, (p - vec2(0.0, 1.0)) / canvas).rgb);
    return c < n * 0.25 - 0.025;
}
bool fx(float bit) {
    return mod(floor(neonFx / bit), 2.0) > 0.5;
}

float at(vec2 d) {
    return step(0.5, texture(source, qt_TexCoord0 + d * texel).a);
}
// the distance (square) to the nearest glyph pixel within r art px; r + 1 when none
float near(float r) {
    float best = r + 1.0;
    for (int y = -8; y <= 8; y++)
        for (int x = -8; x <= 8; x++) {
            vec2 d = vec2(float(x), float(y));
            float m = max(abs(d.x), abs(d.y));
            if (m <= r && m < best && at(d) > 0.5)
                best = m;
        }
    return best;
}
// the glyph on the font's own grid: is the font pixel `c` (whole font px) inked
float cell(vec2 c) {
    vec2 a = fontAt + (c + 0.5) * fontPx;
    return step(0.5, texture(source, a / artSize).a);
}

vec4 neon(vec2 p, float on, float t) {
    // the first neon, the owner's favourite, is the base: a light core, a ring of the glyphs'
    // colour, a checker glow. Every touch on top of it is light and its own bit (neonFx)
    float up = 1.0 - t;                  // 0 at the glyphs' foot, 1 at their top
    if (on > 0.5) {
        vec2 f = floor((p - fontAt) / fontPx);
        // 2: electrodes, a stroke's end (one neighbour on the font grid, none corner to corner,
        // and the stroke runs on: a colon's dot is no tube) capped by a dark line
        if (fx(2.0) && fontPx >= 2.0) {
            vec2 sub = p - fontAt - f * fontPx;
            float n = cell(f + vec2(1.0, 0.0)) + cell(f - vec2(1.0, 0.0)) + cell(f + vec2(0.0, 1.0)) + cell(f - vec2(0.0, 1.0));
            float m = n + cell(f + vec2(1.0, 1.0)) + cell(f - vec2(1.0, 1.0)) + cell(f + vec2(1.0, -1.0)) + cell(f - vec2(1.0, -1.0));
            vec2 dir = cell(f + vec2(1.0, 0.0)) * vec2(1.0, 0.0) - cell(f - vec2(1.0, 0.0)) * vec2(1.0, 0.0)
                     + cell(f + vec2(0.0, 1.0)) * vec2(0.0, 1.0) - cell(f - vec2(0.0, 1.0)) * vec2(0.0, 1.0);
            // the line across the end, on the side away from the stroke
            vec2 edge = dir.x > 0.5 ? vec2(sub.x, 0.0) : dir.x < -0.5 ? vec2(fontPx - 1.0 - sub.x, 0.0)
                      : dir.y > 0.5 ? vec2(sub.y, 0.0) : vec2(fontPx - 1.0 - sub.y, 0.0);
            if (n > 0.5 && m < 1.5 && cell(f + 2.0 * dir) > 0.5 && edge.x < 1.0)
                return dark;
        }
        // 1: the colour rises: the top of the core goes over to the middle shade, a thin dither
        if (fx(1.0) && up > 0.62 && bayer4(p) < (up - 0.62) * 1.3)
            return mid;
        // 16: the colour sinks to the foot instead, the top brightest
        if (fx(16.0) && up < 0.38 && bayer4(p) < (0.38 - up) * 1.3)
            return mid;
        // 8: dust, a still speck here and there
        if (fx(8.0) && hash3(vec3(p, 1.0)) > 0.975)
            return mid;
        return light;
    }
    float d = near(2.0 * w);
    if (d <= w)
        // 4: scan lines, every third row of the ring a step off
        return fx(4.0) && mod(p.y, 3.0) > 1.5 ? glyphAlt : glyph;
    if (d <= 2.0 * w && mod(p.x + p.y, 2.0) < 0.5)
        return second;
    // 32: the light pools under the letters, thinning out downward
    if (fx(32.0)) {
        for (int k = 1; k <= 20; k++) {
            if (at(vec2(0.0, -float(k))) > 0.5) {
                float fade = clamp(1.0 - (float(k) - 2.0 * w) / 16.0, 0.0, 1.0);
                return bayer4(p) < fade * 0.85 ? (bayer4(p) < fade * 0.4 ? second : glyph) : vec4(0.0);
            }
        }
    }
    return vec4(0.0);
}
// the nearest of the colours the cut-out looks are drawn in: the layer's edges blend, the
// picture keeps to the palette
vec4 snap(vec4 s) {
    vec3 c = s.rgb / max(s.a, 1e-4);
    vec4 best = light;
    float bd = distance(c, light.rgb);
    if (distance(c, dark.rgb) < bd) { best = dark; bd = distance(c, dark.rgb); }
    if (distance(c, glyph.rgb) < bd) { best = glyph; bd = distance(c, glyph.rgb); }
    if (distance(c, mid.rgb) < bd) { best = mid; }
    return best;
}

void main() {
    float on = at(vec2(0.0));
    vec2 p = floor(qt_TexCoord0 / texel);
    float t = clamp((qt_TexCoord0.y - band.x) / max(1e-4, band.y - band.x), 0.0, 1.0);
    bool tex = textured > 0.5;
    vec4 c = vec4(0.0);
    if (style < 0.5) {
        // a sticker: the glyphs, a light rim, a dark hairline; textured, a gloss stripe
        float d = near(w + 1.0);
        if (on > 0.5) {
            c = glyph;
            if (tex && abs(p.x - p.y * 0.6 - artSize.x * 0.3) < 1.0)
                c = light;
            else if (tex && speck())
                c = glyphAlt;
        } else if (d <= w)
            c = light;
        else if (d <= w + 1.0)
            c = dark;
    } else if (style < 1.5) {
        c = neon(p, on, t);
    } else if (style < 2.5) {
        float r = max(1.0, floor(w / 2.0));
        if (on > 0.5) {
            if (tex) {
                // the scene in the metal: its sky above, a dark horizon, its ground below
                if (abs(t - 0.5) < 0.06)
                    c = dark;
                else {
                    float u = (qt_TexCoord0.x - 0.5) * 0.6 + 0.5;
                    float v = t < 0.5 ? t / 0.5 * 0.3 : 0.62 + (t - 0.5) / 0.5 * 0.38;
                    c = vec4(texture(reflection, (floor(vec2(u, v) * canvas) + 0.5) / canvas).rgb, 1.0);
                    // the top band a step brighter: where the light catches
                    if (t < 0.12)
                        c = light;
                }
            } else
                c = t < 0.38 ? light : t < 0.62 ? second : glyph;
        } else if (near(r) <= r)
            c = dark;
    } else if (style < 3.5) {
        // the calling card: what SceneDepthText drew, snapped to the palette, ringed dark; its
        // hard shadow is the accent
        vec4 s = texture(source, qt_TexCoord0);
        if (s.a > 0.5) {
            c = snap(s);
            if (tex && distance(c.rgb, light.rgb) < 0.01 && mod(p.x, 3.0) < 1.0 && mod(p.y, 3.0) < 1.0
                    && mod(floor(p.x / 3.0) + floor(p.y / 3.0), 2.0) < 1.0)
                c = mid;    // halftone, magazine print
        } else if (near(2.0) <= 2.0)
            c = dark;
        else if (at(vec2(-w - 2.0)) > 0.5)
            c = glyph;
    } else if (style < 4.5) {
        vec2 q = p - panel.xy;
        bool inPanel = q.x >= 0.0 && q.y >= 0.0 && q.x < panel.z && q.y < panel.w;
        if (inPanel) {
            bool ex = q.x < 1.0 || q.x >= panel.z - 1.0, ey = q.y < 1.0 || q.y >= panel.w - 1.0;
            vec2 f = floor((p - fontAt) / fontPx);
            vec2 sub = p - fontAt - f * fontPx;
            bool gap = fontPx >= 3.0 && (sub.x >= fontPx - 1.0 || sub.y >= fontPx - 1.0);
            if (ex && ey)
                c = vec4(0.0);          // rounded off
            else if (ex || ey)
                c = dark;               // the bezel
            else if (on > 0.5 && !gap)
                c = lcdInk;
            else if (at(vec2(-1.0)) > 0.5 && on < 0.5)
                c = lcdGhost;           // the slow crystal trails a pixel behind
            else if (tex && sub.x >= fontPx - 1.0 && sub.y >= fontPx - 1.0)
                c = lcdGhost;           // the unlit grid
            else
                c = lcdBg;
        } else {
            vec2 r = q - 2.0;
            if (r.x >= 0.0 && r.y >= 0.0 && r.x < panel.z && r.y < panel.w)
                c = second;             // the phone's shadow
        }
    } else {
        if (on > 0.5) {
            if (at(vec2(0.0, -1.0)) < 0.5)
                c = light;              // the light catches the top edge
            else if (t < 0.45)
                c = tex && bayer4(p) < (0.45 - t) * 1.2 ? light : mid;   // the gloss
            else if (at(vec2(0.0, 1.0)) < 0.5)
                c = glyphAlt;           // the bottom edge, shaded
            else
                c = glyph;
        } else {
            float d = near(2.0);
            if (d <= 1.0)
                c = dark;
            else if (d <= 2.0)
                c = light;
            else if (at(vec2(-1.0, -4.0)) > 0.5)
                c = second;             // a drop shadow
        }
    }
    fragColor = vec4(c.rgb, 1.0) * c.a * qt_Opacity;
}
