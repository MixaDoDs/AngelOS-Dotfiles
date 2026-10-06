#version 440
// The heaven lock's sky (modules/lock/HeavenLock): a pixel sky in dithered bands, a sun
// (or a moon and stars) with turning rays, three layers of drifting clouds lit from above
// and a sea of clouds below. Colours come from the hour (QML picks them); `storm` greys it
// for a wrong password, `glow` pours the gate's light over it.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float cell;          // one art pixel of the sky, in the item's pixels
    float night;         // 0 day … 1 night: stars, a moon instead of the sun
    float storm;
    float glow;
    vec2 resolution;
    vec2 sunPos;         // 0..1
    vec2 gatePos;        // where the light comes from, 0..1
    vec4 skyTop;
    vec4 skyBottom;
    vec4 cloud;
    vec4 cloudShade;
    vec4 sun;
};

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = p * 2.03 + vec2(17.0, 9.0);
        a *= 0.5;
    }
    return v;
}
float bayer2(vec2 a) {
    a = floor(a);
    return fract(a.x / 2.0 + a.y * a.y * 0.75);
}
float bayer4(vec2 a) {
    return bayer2(0.5 * a) * 0.25 + bayer2(a);
}
// a cloud layer: density at a point (y grows downward, 0..1 of the height)
float layer(vec2 q, float scale, float speed, float top, float bottom, float thin) {
    vec2 p = vec2(q.x * scale * (resolution.x / resolution.y) + time * speed, q.y * scale * 2.2);
    float n = fbm(p);
    // only inside its band, thicker toward the bottom of it
    float band = smoothstep(top, top + 0.08, q.y) * (1.0 - smoothstep(bottom - 0.05, bottom, q.y));
    return step(thin, n * band + (q.y - top) * 0.25 * band);
}

void main() {
    vec2 px = qt_TexCoord0 * resolution;
    vec2 cid = floor(px / cell);
    vec2 q = (cid + 0.5) * cell / resolution;          // the cell's middle, 0..1
    float dy = cell / resolution.y;

    // sky: bands with an ordered dither between them
    float t = clamp(q.y * 1.15, 0.0, 1.0);
    float steps = 9.0;
    float tq = floor(t * steps + bayer4(cid) * 0.999) / steps;
    vec3 col = mix(skyTop.rgb, skyBottom.rgb, tq);

    // stars at night, twinkling
    float st = hash(cid);
    if (night > 0.01 && st > 0.992 && q.y < 0.7) {
        float tw = step(0.4, fract(time * 0.35 + st * 13.0));
        col = mix(col, vec3(1.0, 0.97, 0.9), night * (0.55 + 0.45 * tw));
    }

    // sun or moon with rays turning slowly
    vec2 d = (q - sunPos) * vec2(resolution.x / resolution.y, 1.0);
    float r = length(d);
    float a = atan(d.y, d.x);
    float rays = step(0.5, fract(a / 6.2831853 * 12.0 + time * 0.01)) * (1.0 - smoothstep(0.05, 0.32, r)) * (1.0 - night);
    col = mix(col, sun.rgb, rays * 0.18);
    float halo = 1.0 - smoothstep(0.05, 0.11, r);
    col = mix(col, mix(sun.rgb, vec3(1.0), 0.3), floor(halo * 3.0) / 3.0 * 0.45);
    float disk = step(r, 0.05);
    vec3 diskCol = night > 0.5 ? mix(sun.rgb, vec3(0.8, 0.82, 0.95), step(0.0, d.x - 0.018) * step(length(d - vec2(0.022, -0.012)), 0.046)) : sun.rgb;
    col = mix(col, diskCol, disk);

    // clouds: far and slow first, near and fast last; lit edge above, shade below
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float scale = 3.0 + fi * 1.6;
        float speed = 0.012 + fi * 0.014;
        float top = 0.18 + fi * 0.2;
        float bottom = top + 0.26;
        float thin = 0.62 - fi * 0.04;
        float c0 = layer(q, scale, speed, top, bottom, thin);
        if (c0 > 0.5) {
            float up = layer(q - vec2(0.0, dy), scale, speed, top, bottom, thin);
            float down = layer(q + vec2(0.0, dy * 2.0), scale, speed, top, bottom, thin);
            vec3 cc = mix(cloudShade.rgb, cloud.rgb, 0.55 + fi * 0.2);
            if (up < 0.5)
                cc = mix(cloud.rgb, vec3(1.0), 0.6 - night * 0.4);
            else if (down < 0.5)
                cc = cloudShade.rgb;
            // the far ones melt into the sky
            col = mix(col, cc, 0.55 + fi * 0.22);
        }
    }

    // the sea of clouds the gate stands on
    float seaN = fbm(vec2(q.x * 7.0 * (resolution.x / resolution.y) + time * 0.02, q.y * 3.0));
    float sea = step(0.8 - (q.y - 0.68) * 2.6, seaN + 0.05);
    if (q.y > 0.66 && sea > 0.5) {
        float seaUp = step(0.8 - (q.y - dy - 0.68) * 2.6, fbm(vec2(q.x * 7.0 * (resolution.x / resolution.y) + time * 0.02, (q.y - dy) * 3.0)) + 0.05);
        vec3 sc = seaUp < 0.5 ? mix(cloud.rgb, vec3(1.0), 0.5 - night * 0.3) : mix(cloud.rgb, cloudShade.rgb, smoothstep(0.7, 1.0, q.y) * 0.8 + bayer4(cid) * 0.12);
        col = sc;
    }

    // sparkles drifting in the daylight
    float sp = hash(cid + floor(time * 0.6));
    if (sp > 0.9985 && night < 0.5)
        col = mix(col, vec3(1.0), 0.85);

    // a wrong password: the sky clouds over
    float grey = dot(col, vec3(0.3, 0.55, 0.15));
    col = mix(col, vec3(grey * 0.6 + 0.08, grey * 0.62 + 0.08, grey * 0.72 + 0.12), storm * 0.75);

    // the gate's light
    vec2 g = (q - gatePos) * vec2(resolution.x / resolution.y, 1.0);
    float lg = glow * (1.0 - smoothstep(0.0, 0.9, length(g)));
    col = mix(col, vec3(1.0, 0.97, 0.86), clamp(floor(lg * 6.0) / 6.0 * 1.2, 0.0, 1.0));

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
