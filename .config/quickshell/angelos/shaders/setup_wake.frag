#version 440
// The setup wizard's first-run intro (modules/settings/SetupWake.qml): waking up over the whole
// screen, in pixels. The picture in blocks (`pix`, each its mip's average: a pixel blur), red and
// blue apart towards the edges by whole pixels (`aberr` at the corners), a glow of big blocks over
// what is bright, an orange flicker of fire rising from below, the dark round the edges in steps,
// the eyelids (`lid`: 1 shut) as a stepped ellipse, a white flash.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;   // px
    float aberr;     // px apart at the corners
    float pix;       // the blocks' size, px (1: sharp)
    float glow;      // the glow's strength
    float glowPx;    // its blocks, px
    float vign;      // 0…1
    float fire;      // 0…1
    float flicker;   // 0…1
    float flash;     // 0…1
    float lid;       // 0 open … 1 shut
    float step;      // the steps' size of the shapes (vignette, lids, fire), px
};
layout(binding = 1) uniform sampler2D source;

vec3 at(vec2 px, float lod) {
    return textureLod(source, clamp(px / itemSize, vec2(0.0), vec2(1.0)), lod).rgb;
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    float s = max(1.0, step);
    vec2 ps = (floor(p / s) + 0.5) * s;          // the shapes' grid
    vec2 c = itemSize * 0.5;
    vec2 d = (ps - c) / c;                        // −1…1
    float r2 = clamp(dot(d, d) * 0.5, 0.0, 1.0);  // 0 in the middle, 1 in the corners

    // the eyelids: a stepped ellipse closing to a line
    float open = 1.0 - clamp(lid, 0.0, 1.0);
    if (open < 0.999) {
        float h = open * 0.62;
        if (h <= 0.0 || (d.x * d.x) * 0.55 + (d.y * d.y) / (h * h) > 1.0) {
            fragColor = vec4(0.0, 0.0, 0.0, 1.0) * qt_Opacity;
            return;
        }
    }

    // the picture in blocks, red and blue apart towards the edges
    float b = max(1.0, floor(pix + 0.5));
    vec2 q = (floor(p / b) + 0.5) * b;
    float lod = log2(b);
    vec2 dir = length(d) > 0.0001 ? normalize(d) : vec2(0.0);
    vec2 off = floor(dir * aberr * (0.12 + r2) + 0.5);
    vec3 col;
    col.r = at(q + off, lod).r;
    col.g = at(q, lod).g;
    col.b = at(q - off, lod).b;

    // the glow: big blocks of what is bright, added
    float g = max(2.0, glowPx);
    vec2 gq = (floor(p / g) + 0.5) * g;
    vec3 gl = at(gq, log2(g) + 0.5);
    gl = max(gl - vec3(0.12), vec3(0.0)) * 1.6 + gl * 0.2;
    col += gl * glow;

    // fire from below: orange, flickering, in bands
    float up = floor(qt_TexCoord0.y * itemSize.y / (s * 2.0)) * (s * 2.0) / itemSize.y;
    float f = clamp(fire * pow(up, 3.0) * (0.7 + 0.3 * flicker), 0.0, 1.0);
    col = mix(col, col * vec3(1.35, 0.72, 0.45) + vec3(0.32, 0.07, 0.0), f);

    // the dark round the edges, in eight steps
    float v = floor(smoothstep(0.25, 1.0, r2) * 8.0) / 8.0;
    col *= 1.0 - clamp(vign, 0.0, 1.0) * v;

    col = mix(col, vec3(1.0), clamp(flash, 0.0, 1.0));
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
