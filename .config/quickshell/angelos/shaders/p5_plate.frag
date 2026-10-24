#version 440
// A plate of the P5 settings window (modules/settings/p5/P5Plate.qml) in one pass: a polygon of up
// to 8 corners (unused ones repeat the last), its hard shadow (the same polygon shifted) and a rim
// (a grown copy, given on its own), each pixel tested at its art pixel's centre — the slanted
// edges step on the angelOS pixel grid as they did drawn into a layer of one texel per art pixel,
// without the layer and the shapes (hundreds of them made a page take half a second to build).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;      // the item in logical pixels
    float u;        // one art pixel in logical pixels
    vec4 fill;
    vec4 shadow;
    vec4 rim;
    vec2 shift;     // the shadow's offset
    vec2 p0; vec2 p1; vec2 p2; vec2 p3; vec2 p4; vec2 p5; vec2 p6; vec2 p7;
    vec2 r0; vec2 r1; vec2 r2; vec2 r3; vec2 r4; vec2 r5; vec2 r6; vec2 r7;
};

// one edge of the even-odd crossing test (a repeated corner makes an edge that never crosses)
float crossing(vec2 q, vec2 a, vec2 b) {
    if ((a.y > q.y) == (b.y > q.y))
        return 0.0;
    return q.x < (b.x - a.x) * (q.y - a.y) / (b.y - a.y) + a.x ? 1.0 : 0.0;
}
bool inPlate(vec2 q) {
    float c = crossing(q, p0, p1) + crossing(q, p1, p2) + crossing(q, p2, p3) + crossing(q, p3, p4)
            + crossing(q, p4, p5) + crossing(q, p5, p6) + crossing(q, p6, p7) + crossing(q, p7, p0);
    return mod(c, 2.0) > 0.5;
}
bool inRim(vec2 q) {
    float c = crossing(q, r0, r1) + crossing(q, r1, r2) + crossing(q, r2, r3) + crossing(q, r3, r4)
            + crossing(q, r4, r5) + crossing(q, r5, r6) + crossing(q, r6, r7) + crossing(q, r7, r0);
    return mod(c, 2.0) > 0.5;
}

void main() {
    vec2 q = (floor(qt_TexCoord0 * size / u) + 0.5) * u;
    vec4 c = vec4(0.0);
    if (rim.a > 0.0 && inRim(q))
        c = rim;
    if (shadow.a > 0.0 && inPlate(q - shift))
        c = shadow;
    if (inPlate(q))
        c = fill;
    fragColor = vec4(c.rgb * c.a, c.a) * qt_Opacity;
}
