#version 440
// The dark between hell's circles (modules/y2k/CircleTransition): an ordered dither in whole
// art pixels — at `progress` 0 nothing, at 1 all of it the tint: the coming circle's colour
// glowing faintly in the middle, sinking to `edge` (near black) at the corners.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float cell;      // one art pixel, in item pixels
    vec2 size;       // the item, in item pixels
    vec4 tint;
    vec4 edge;
};

float bayer2(vec2 a) {
    a = floor(a);
    return fract(a.x / 2.0 + a.y * a.y * 0.75);
}
float bayer4(vec2 a) {
    return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

void main() {
    vec2 px = floor(qt_TexCoord0 * size / max(1.0, cell));
    float on = progress >= 0.999 ? 1.0 : step(bayer4(px) + 0.0001, progress);
    // the glow in whole art pixels, in steps, like everything else here
    vec2 d = (px * max(1.0, cell) + 0.5 * cell) / size - 0.5;
    d.x *= size.x / size.y;
    float g = 1.0 - clamp(length(d) / 0.85, 0.0, 1.0);
    g = floor(g * g * 6.0 + 0.5) / 6.0;
    fragColor = vec4(mix(edge.rgb, tint.rgb, g), 1.0) * on * qt_Opacity;
}
