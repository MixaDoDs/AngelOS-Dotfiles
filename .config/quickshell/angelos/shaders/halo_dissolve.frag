#version 440
// The Halo's pixel dissolve (modules/halo HaloWindow: the closed pill's song ↔ its resting
// clock, cat and weather): whole art pixels come or go in an 8×8 ordered-dither (Bayer) order.
// `incoming` 1: a cell shows once its threshold is under `vis`; 0: a cell stays while its
// threshold is at or over 1 − vis — the complement, so the leaving layer's cells go exactly
// where the coming one's appear.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 cells;      // the item's size in art pixels
    float vis;       // 0 gone … 1 whole
    float incoming;
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

void main() {
    vec2 cell = floor(qt_TexCoord0 * cells);
    float t = bayer8(cell);
    bool on = incoming > 0.5 ? t < vis : t >= 1.0 - vis;
    fragColor = on ? texture(source, qt_TexCoord0) * qt_Opacity : vec4(0.0);
}
