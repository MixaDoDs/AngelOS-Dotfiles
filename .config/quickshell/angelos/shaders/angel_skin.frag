#version 440
// The angel's skins (services/HeavenStars): her pinks (dress, ribbons, a pink hair) and her
// blonde take other colours; skin, eyes, outlines and whites stay as the artist drew them.
// Hues in degrees; s and v are factors. white.y < 0: the whites stay white.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 pink;           // hue, s factor, v factor, on
    vec4 hair;           // hue, s factor, v factor, on
    vec4 white;          // hue, s, -, - (s < 0: off)
};
layout(binding = 1) uniform sampler2D source;

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}
void main() {
    vec4 c = texture(source, qt_TexCoord0);
    if (c.a < 0.004) {
        fragColor = vec4(0.0);
        return;
    }
    vec3 rgb = c.rgb / c.a;
    vec3 hsv = rgb2hsv(rgb);
    float hd = hsv.x * 360.0;
    float s = hsv.y;
    float v = hsv.z;
    if (pink.w > 0.5 && s > 0.12 && v >= 0.4 && (hd >= 285.0 || (hd < 10.0 && v > 0.8))) {
        hsv = vec3(pink.x / 360.0, clamp(s * pink.y, 0.0, 1.0), clamp(v * pink.z, 0.0, 1.0));
    } else if (hair.w > 0.5 && ((hd >= 30.0 && hd < 62.0 && s > 0.28) || (hd >= 18.0 && hd < 30.0 && s > 0.5))) {
        hsv = vec3(hair.x / 360.0, clamp(s * hair.y, 0.0, 1.0), clamp(v * hair.z, 0.0, 1.0));
    } else if (white.y >= 0.0 && s < 0.1 && v > 0.8) {
        hsv = vec3(white.x / 360.0, white.y, v);
    }
    fragColor = vec4(hsv2rgb(hsv) * c.a, c.a) * qt_Opacity;
}
