#version 440
// The night's event in a layered scene (widgets/SceneEvent): a meteor (light added: black is
// nothing, so the colour goes out with alpha 0 — premultiplied blending adds it) and a dome of
// fire drawn over. Both sampled nearest at art pixels; how much of them shows (coming out of the
// dark, dying down) is an 8×8 Bayer dither, never a half-transparent pixel.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 canvas;        // logical size, art px
    vec2 origin;        // this item's top-left on the canvas, art px
    vec2 area;          // this item's size, art px
    vec2 pan;           // the camera, art px
    float night;        // 0..1: as dark as the night is, as much of the event shows
    vec2 head;          // the meteor's head on the canvas, art px
    vec2 headIn;        // the head inside its sprite, px
    vec2 meteorSize;
    float meteorScale;
    float meteorAlpha;
    vec2 fireOrigin;    // the dome's bottom middle on the canvas, art px
    vec2 fireSize;
    float fireScale;
    float fireAlpha;
    float tint;         // 1: tonight's colours instead of the sprites' own
    vec4 deep;
    vec4 mid;
    vec4 hot;
};
layout(binding = 1) uniform sampler2D meteor;
layout(binding = 2) uniform sampler2D fire;

// an 8×8 Bayer matrix as a formula (NVIDIA's GL drops shaders with constant arrays), 0..63/64
float bayer2(vec2 a) {
    a = floor(a);
    return fract(a.x / 2.0 + a.y * a.y * 0.75);
}
float bayer8(vec2 a) {
    return bayer2(0.25 * a) * 0.0625 + bayer2(0.5 * a) * 0.25 + bayer2(a);
}

// a lightness through tonight's ramp, in eight flat steps
vec3 ramp(float l) {
    l = floor(clamp(l, 0.0, 1.0) * 8.0 + 0.5) / 8.0;
    return l < 0.5 ? mix(deep.rgb, mid.rgb, l * 2.0) : mix(mid.rgb, hot.rgb, l * 2.0 - 1.0);
}

void main() {
    vec2 t = floor(origin + qt_TexCoord0 * area - pan);
    float d = bayer8(t);
    vec4 c = vec4(0.0);
    if (fireAlpha > 0.0 && d < fireAlpha * night) {
        vec2 size = fireSize * fireScale;
        vec2 u = floor((t + 0.5 - vec2(fireOrigin.x - size.x * 0.47, fireOrigin.y - size.y)) / fireScale);
        if (u.x >= 0.0 && u.y >= 0.0 && u.x < fireSize.x && u.y < fireSize.y) {
            vec4 f = texture(fire, (u + 0.5) / fireSize);
            if (f.a > 0.5)
                c = vec4(tint > 0.5 ? ramp(dot(f.rgb, vec3(0.3, 0.59, 0.11)) * 1.25) : f.rgb, 1.0);
        }
    }
    if (meteorAlpha > 0.0 && c.a < 0.5 && d < meteorAlpha * night) {
        vec2 u = floor((t + 0.5 - head) / meteorScale + headIn);
        if (u.x >= 0.0 && u.y >= 0.0 && u.x < meteorSize.x && u.y < meteorSize.y) {
            vec3 m = texture(meteor, (u + 0.5) / meteorSize).rgb;
            float l = max(m.r, max(m.g, m.b));
            c.rgb += tint > 0.5 ? ramp(l) * l : m;
        }
    }
    fragColor = c * qt_Opacity;
}
