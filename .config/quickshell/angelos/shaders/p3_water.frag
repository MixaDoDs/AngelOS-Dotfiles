#version 440
// The P5 settings window's light-theme background, Persona 3 Reload's way: deep water in the
// accent (dark at the bottom, light at the top), light rays slanting down from the surface,
// caustic lines wobbling, bubbles rising. Drawn at one texel per art pixel (the item is a layer
// of that size) and dithered with a 4×4 Bayer matrix: no smooth gradient, only pixel steps.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 deep;
    vec4 shallow;
    vec4 glint;
    vec2 size;      // the texture in art pixels
    float time;     // seconds, stepped by the item
};

// no constant arrays: GLSL 120, which NVIDIA's GL takes, has none
float bayer2(vec2 a) {
    a = floor(a);
    return fract(a.x / 2.0 + a.y * a.y * 0.75);
}
float bayer(vec2 a) {
    return bayer2(0.5 * a) * 0.25 + bayer2(a) + 0.5 / 16.0;
}
float hash(float n) {
    return fract(sin(n) * 43758.5453);
}

void main() {
    vec2 p = floor(qt_TexCoord0 * size);
    vec2 uv = p / size;
    float d = bayer(p);

    // depth: four bands from the surface down, the steps dithered
    float depth = clamp(uv.y + 0.08 * sin(uv.x * 3.0 + time * 0.4), 0.0, 1.0);
    float band = floor(depth * 4.0 + d) / 4.0;
    vec3 c = mix(shallow.rgb, deep.rgb, band);

    // rays from the surface, leaning, slowly breathing
    float r = sin((uv.x + uv.y * 0.45) * 22.0 + time * 0.25) * 0.5 + 0.5;
    r *= sin((uv.x + uv.y * 0.45) * 7.0 - time * 0.15) * 0.5 + 0.5;
    r *= 1.0 - uv.y;
    if (r * 0.9 > d + 0.25)
        c = mix(c, shallow.rgb, 0.55);

    // caustic lines near the surface
    float k = sin(uv.x * 40.0 + sin(uv.y * 30.0 + time) * 2.0 + time * 0.8)
            * sin(uv.y * 34.0 - sin(uv.x * 22.0 - time * 0.7) * 2.0);
    if (k > 0.82 && d < 1.0 - uv.y * 1.2)
        c = glint.rgb;

    // bubbles: a few columns, each rising at its own pace
    for (int i = 0; i < 9; i++) {
        float fi = float(i);
        float bx = floor(hash(fi * 7.1) * size.x);
        float speed = 6.0 + hash(fi * 3.3) * 10.0;
        float by = size.y - mod(time * speed + hash(fi * 1.7) * size.y, size.y + 8.0);
        bx += floor(sin(time * 2.0 + fi) * 1.5);
        float rad = 1.0 + floor(hash(fi * 5.9) * 2.0);
        vec2 q = p - vec2(bx, by);
        float dist = max(abs(q.x), abs(q.y)) + min(abs(q.x), abs(q.y)) * 0.5;
        if (dist <= rad && dist > rad - 1.0)
            c = glint.rgb;
    }

    fragColor = vec4(c, 1.0) * qt_Opacity;
}
