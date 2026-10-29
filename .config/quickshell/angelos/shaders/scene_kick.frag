#version 440
// The music's kick over a whole layered scene (WallpaperView: SceneWall's layer, while it hears
// the bass): a ring out of the CRT's screen bends everything the wall draws as it passes — its
// layers, the text in the scene, the meteor's shards, leaves, stars — and the picture breathes
// toward you for a moment. Nearest texels: the screen's pixels move, none is blended.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;        // the wall, px
    vec2 from;        // the CRT's screen on it, px
    float k;          // px per art px
    float kick;       // 0..1: how hard the last kick hit
    float kickAt;     // `time` of it
    float time;
};
layout(binding = 1) uniform sampler2D source;

// as shaders/scene_layer.frag: d = from → here, art px; the shift back, art px
vec2 kickWave(vec2 d, float age) {
    float r = max(length(d), 1.0);
    float x = (r - age * 520.0) / 16.0;
    float push = 2.2 * x * exp(-x * x) * (1.0 - age / 1.2);
    return d / r * push + d * 0.006 * exp(-age * 9.0);
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    float age = time - kickAt;
    if (kick > 0.0 && age >= 0.0 && age < 1.2)
        p -= kickWave((p - from) / k, age) * k * kick;
    fragColor = texture(source, (floor(p) + 0.5) / size) * qt_Opacity;
}
