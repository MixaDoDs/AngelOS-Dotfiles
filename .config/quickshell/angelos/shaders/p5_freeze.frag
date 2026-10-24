#version 440
// The desktop frozen under the P5 settings menu (modules/settings/p5/P5View.qml), as P3 Reload's
// pause: a shot of the screen goes soft, then breaks into big pixels, the colours drained towards
// the theme and dithered (Bayer by formula: NVIDIA's GL takes no constant arrays). `amount` comes
// in steps from QML: 0 the shot as it is, 1 the full mosaic.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;      // the item in logical pixels
    float amount;
    float cell;     // a mosaic pixel at amount 1, in logical pixels
    vec4 tint;
    float dim;      // how far it darkens at amount 1
};
layout(binding = 1) uniform sampler2D source;

float bayer2(vec2 a) {
    a = floor(a);
    return fract(a.x / 2.0 + a.y * a.y * 0.75);
}
float bayer4(vec2 a) {
    return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    // soft first (the first half), the pixels after it
    float soft = clamp(amount * 2.0, 0.0, 1.0);
    float grid = clamp(amount * 2.0 - 1.0, 0.0, 1.0);
    float c = max(1.0, floor(mix(1.0, cell, grid)));
    vec2 centre = (floor(p / c) + 0.5) * c;
    // a 3×3 blur round the mosaic pixel's centre, wider as it softens
    float r = c * 0.5 + soft * cell * 0.6;
    vec3 col = vec3(0.0);
    for (int i = -1; i <= 1; i++)
        for (int j = -1; j <= 1; j++)
            col += texture(source, clamp((centre + vec2(float(i), float(j)) * r) / size, 0.0, 1.0)).rgb;
    col /= 9.0;
    // drained towards the theme, darker, and dithered into a few steps per mosaic pixel
    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    vec3 toned = mix(col, tint.rgb * (0.35 + luma), 0.55 * amount) * (1.0 - dim * amount);
    float levels = mix(64.0, 10.0, grid);
    toned = floor(toned * levels + bayer4(p / c)) / levels;
    fragColor = vec4(toned, 1.0) * qt_Opacity;
}
