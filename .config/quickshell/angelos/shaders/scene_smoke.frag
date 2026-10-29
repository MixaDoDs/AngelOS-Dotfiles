#version 440
// The smoke the meteor left (widgets/SceneAftermath): a column rising from behind the houses
// where it fell, leaning the way the wind blows, rolling upward in puffs, thinning over the
// hours. Art pixels only: how dense it is picks one of two palette greys or nothing, through an
// 8×8 Bayer matrix — no soft edge, no half-transparent pixel. Its foot glows with the fire's
// colour while the fire is there.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 origin;        // this item's top-left on the canvas, art px
    vec2 area;          // this item's size, art px
    vec2 pan;           // the camera, art px
    vec2 foot;          // where the column rises from, art px
    float strength;     // 0..1: how much smoke there is now
    float rise;         // art px: how high it has climbed
    float lean;         // how far it bends toward the open sky (the wind adds or takes)
    float time;
    float glow;         // 0..1: the fire under it
    vec4 dark;
    vec4 light;
    vec4 glowColor;
};

float bayer2(vec2 a) {
    a = floor(a);
    return fract(a.x / 2.0 + a.y * a.y * 0.75);
}
float bayer8(vec2 a) {
    return bayer2(0.25 * a) * 0.0625 + bayer2(0.5 * a) * 0.25 + bayer2(a);
}
float hash(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.x + p.y) * p.z);
}
float noise(vec3 p) {
    vec3 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
                   mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
               mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
                   mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void main() {
    vec2 t = floor(origin + qt_TexCoord0 * area - pan);
    float h = foot.y - t.y;                       // height above the foot
    if (h < -2.0 || h > rise || strength <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    // the column bends out over the houses the higher it gets, and wavers
    float cx = foot.x + 10.0 + lean * pow(max(h, 0.0), 1.25) * 0.35 + 3.0 * sin(h * 0.05 + time * 0.07);
    float width = 7.0 + h * 0.45;
    float dx = (t.x - cx) / width;
    float body = exp(-dx * dx * 2.2) * (1.0 - smoothstep(rise * 0.65, rise, h)) * (1.0 - 0.45 * h / (foot.y + 40.0));
    // puffs rolling up
    float puff = noise(vec3(t.x * 0.09, (t.y + time * 5.0) * 0.09, time * 0.03))
               + 0.5 * noise(vec3(t.x * 0.2, (t.y + time * 8.0) * 0.2, 7.0 + time * 0.05));
    float dens = body * strength * (0.2 + 0.8 * puff);
    // puffs, not a halftone: two flat greys, the dither only along their edges
    float d = bayer8(t) - 0.5;
    if (dens < 0.32 + 0.1 * d) {
        fragColor = vec4(0.0);
        return;
    }
    vec3 c = dens > 0.62 + 0.08 * d ? dark.rgb : light.rgb;
    d += 0.5;
    // the fire lights its foot, in steps
    float g = glow * (1.0 - smoothstep(0.0, 34.0, h));
    if (g > 0.1 + 0.6 * d)
        c = mix(c, glowColor.rgb, floor(g * 3.0 + d) / 3.0);
    fragColor = vec4(c, 1.0) * qt_Opacity;
}
