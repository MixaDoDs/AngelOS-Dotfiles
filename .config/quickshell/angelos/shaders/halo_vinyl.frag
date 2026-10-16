#version 440
// The song's cover as a record (modules/halo HaloWindow, component Cover): a disc of whole art
// pixels (the same staircase as the pill's round ends), a one-pixel rim in the Halo's colour,
// a dark spindle hole; the picture sampled once per art pixel (it stays pixel art) and turned
// by `angle`. `plain`: only the round picture (the closed pill's small one: at ten pixels a
// rim, a hole and grooves are noise). No picture: the disc in the blank colour.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 cells;     // the disc's box in art pixels
    float angle;    // radians
    float hasArt;
    float plain;
    vec4 cRim;
    vec4 cHole;
    vec4 cBlank;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 cell = floor(qt_TexCoord0 * cells);
    vec2 c = cell + 0.5 - cells * 0.5;
    float R = min(cells.x, cells.y) * 0.5;
    float r = length(c);
    vec4 o = vec4(0.0);
    if (r <= R) {
        float hole = plain > 0.5 ? -1.0 : max(1.0, floor(R * 0.18 + 0.5));
        if (plain < 0.5 && r > R - 1.0) {
            o = cRim;
        } else if (r < hole) {
            o = cHole;
        } else if (hasArt > 0.5) {
            float s = sin(-angle), k = cos(-angle);
            vec2 q = vec2(c.x * k - c.y * s, c.x * s + c.y * k);
            vec4 t = texture(source, clamp(q / cells + 0.5, 0.0, 1.0));
            // a groove every third ring from the rim: a shade darker, as on a record
            float g = plain < 0.5 && mod(floor(R - r), 3.0) < 1.0 && r > hole + 1.0 && r < R - 2.0 ? 0.85 : 1.0;
            o = vec4(t.rgb * g, 1.0);
        } else {
            o = cBlank;
        }
    }
    fragColor = o * qt_Opacity;
}
