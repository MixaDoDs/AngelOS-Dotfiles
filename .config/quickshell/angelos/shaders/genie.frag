#version 440
// genie.vert's snapshot, fading a little as it reaches the Dock
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    vec4 win;
    vec4 tgt;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    fragColor = texture(source, qt_TexCoord0) * qt_Opacity * (1.0 - 0.2 * progress);
}
