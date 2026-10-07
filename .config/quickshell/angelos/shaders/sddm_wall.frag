#version 440
// The login screen's wallpaper (extras/sddm/angelos), alive: cropped to cover the screen
// like PreserveAspectCrop, it drifts and zooms very slowly; big pixels, with a band of
// finer ones sweeping across now and then; a block twinkles here and there; scanlines
// and a vignette; the hour's tint; and a ring of pixels from where a key was typed.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float block;        // screen px of one big pixel (1 = no pixelation)
    float line;         // screen px of one scanline (the theme's art pixel)
    float time;         // seconds
    vec2 resolution;    // the item, screen px
    vec2 imgSize;       // the picture, any unit: only its shape matters
    vec4 tint;          // rgb, a = how much
    vec4 ripple;        // xy = centre (screen px), z = age (s), w = strength
    vec4 rippleColor;
};
layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// screen px → picture uv: cover, then a slow zoom and drift inside what is left over
vec2 pictureUv(vec2 px) {
    vec2 st = px / resolution;
    float cover = max(resolution.x / imgSize.x, resolution.y / imgSize.y);
    float zoom = 1.06 + 0.03 * sin(time * 0.045);
    vec2 span = resolution / (imgSize * cover) / zoom;      // the part of the picture seen
    vec2 drift = vec2(sin(time * 0.031), cos(time * 0.023)) * 0.85;
    vec2 centre = 0.5 + (1.0 - span) * 0.5 * drift;
    return centre + (st - 0.5) * span;
}

void main() {
    vec2 px = qt_TexCoord0 * resolution;
    float b = max(block, 1.0);

    // a diagonal band of finer pixels, once every ~40 s, decided per big pixel
    vec2 coarse = (floor(px / b) + 0.5) * b;
    float diag = (coarse.x + coarse.y * 0.6) / (resolution.x + resolution.y * 0.6);
    float sweep = fract(time / 40.0) * 1.6 - 0.3;
    bool fine = b > 2.0 && abs(diag - sweep) < 0.05;
    float cb = fine ? b * 0.5 : b;
    vec2 cell = floor(px / cb);
    vec2 centre = (cell + 0.5) * cb;

    // the typing ring: pushes the pixels outward and lights them
    float ring = 0.0;
    vec2 push = vec2(0.0);
    if (ripple.w > 0.0) {
        vec2 d = coarse - ripple.xy;
        float dist = length(d);
        float radius = ripple.z * resolution.y * 0.55;
        float width = b * 3.0 + ripple.z * b * 4.0;
        ring = exp(-pow((dist - radius) / width, 2.0)) * ripple.w * max(0.0, 1.0 - ripple.z / 1.4);
        push = dist > 0.0 ? d / dist * ring * b * 1.5 : vec2(0.0);
    }

    vec4 c = texture(source, pictureUv(centre - push));

    // twinkle: a few big pixels flare for a moment
    float slot = floor(time * 1.3);
    float h = hash(floor(px / b) + slot * 17.0);
    if (b > 2.0 && h > 0.9965) {      // not on a picture shown as it is: it would be noise
        float k = sin(fract(time * 1.3) * 3.14159);
        c.rgb = mix(c.rgb, vec3(1.0), 0.35 * k);
    }

    // the hour's light
    float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
    c.rgb = mix(c.rgb, tint.rgb * (0.35 + lum * 1.2), tint.a);

    c.rgb = mix(c.rgb, rippleColor.rgb, ring * 0.45);

    // scanlines, a gentle flicker, the vignette
    if (line >= 1.0 && mod(floor(px.y / line), 2.0) == 1.0)
        c.rgb *= 0.93;
    c.rgb *= 0.985 + 0.015 * sin(time * 9.0);
    vec2 v = qt_TexCoord0 - 0.5;
    c.rgb *= 1.0 - 0.45 * dot(v, v) * 1.6;

    fragColor = vec4(c.rgb, 1.0) * qt_Opacity;
}
