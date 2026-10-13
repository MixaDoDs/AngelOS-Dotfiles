#version 440
// The first run's intro, the minutes before (modules/settings/SetupPrequel.qml): the pills
// taking hold of the picture. It swims a little, its colours come apart, a second picture of
// itself drifts over it — more as `high` goes from 0 to 1.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float high;      // 0…1
    float time;      // s
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;
    uv += high * 0.006 * vec2(sin(time * 0.7 + uv.y * 4.0), cos(time * 0.5 + uv.x * 3.0));
    vec2 apart = vec2(high * 0.004 * (1.0 + 0.5 * sin(time * 1.3)), 0.0);
    vec3 col = vec3(texture(source, uv + apart).r, texture(source, uv).g, texture(source, uv - apart).b);
    vec3 other = texture(source, uv + vec2(0.012, 0.004) * high * sin(time * 0.9)).rgb;
    fragColor = vec4(mix(col, other, 0.25 * high), 1.0) * qt_Opacity;
}
