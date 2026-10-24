#version 440
// The P5 settings window's characters (modules/settings/p5/art): a mask whose red, green and
// blue say dark, light and accent is painted in the theme's colours; `solid.a` > 0 paints the
// whole figure one colour (her silhouette wiping the window) — but in a small oval round each
// eye (`eyes`: two centres on the texture, `eyeR` its radii) the dark iris goes `glow`: the
// silhouette keeps burning eyes.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 dark;
    vec4 light;
    vec4 accent;
    vec4 solid;
    vec4 eyes;
    vec2 eyeR;
    vec4 glow;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 m = texture(source, qt_TexCoord0);
    if (m.a < 0.004) {
        fragColor = vec4(0.0);
        return;
    }
    vec3 w = m.rgb / m.a;
    float s = max(w.r + w.g + w.b, 0.0001);
    vec2 r = max(eyeR, vec2(0.0001));
    vec2 e1 = (qt_TexCoord0 - eyes.xy) / r, e2 = (qt_TexCoord0 - eyes.zw) / r;
    bool eye = eyeR.x > 0.0 && min(dot(e1, e1), dot(e2, e2)) <= 1.0 && dot(w, vec3(0.299, 0.587, 0.114)) < 0.35;
    vec3 c = solid.a > 0.5 ? (eye ? glow.rgb : solid.rgb) : (w.r * dark.rgb + w.g * light.rgb + w.b * accent.rgb) / s;
    fragColor = vec4(c, 1.0) * m.a * qt_Opacity;
}
