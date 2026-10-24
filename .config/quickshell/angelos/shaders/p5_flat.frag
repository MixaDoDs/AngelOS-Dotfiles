#version 440
// The P5 settings window's figure (modules/settings/p5/P5Doll.qml) flat, as P5 draws Joker in its
// menus: the owner's coloured pose cut into three of the theme's colours by brightness — the
// shadows `dark`, the middle `mid`, the lights `light`. `solid.a` > 0.5 paints it all one colour
// (her hard shadow, her silhouette) — but in a small oval round each eye (`eyes`: two centres
// on the texture, `eyeR` its radii) her dark iris lights up in `glow`: a silhouette with burning
// eyes, P5's way (the skin round them is as bright as the whites: only the iris tells).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 dark;
    vec4 mid;
    vec4 light;
    vec4 solid;
    float cut1;     // below: dark
    float cut2;     // above: light
    vec4 eyes;
    vec2 eyeR;
    vec4 glow;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 m = texture(source, qt_TexCoord0);
    if (m.a < 0.5) {
        fragColor = vec4(0.0);
        return;
    }
    vec3 c = m.rgb / m.a;
    float l = dot(c, vec3(0.299, 0.587, 0.114));
    vec2 r = max(eyeR, vec2(0.0001));
    vec2 e1 = (qt_TexCoord0 - eyes.xy) / r, e2 = (qt_TexCoord0 - eyes.zw) / r;
    bool eye = eyeR.x > 0.0 && min(dot(e1, e1), dot(e2, e2)) <= 1.0 && l < 0.35;
    vec3 o = solid.a > 0.5 ? (eye ? glow.rgb : solid.rgb) : l < cut1 ? dark.rgb : l < cut2 ? mid.rgb : light.rgb;
    fragColor = vec4(o, 1.0) * qt_Opacity;
}
