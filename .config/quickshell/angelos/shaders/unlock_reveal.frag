#version 440
// The unlock (modules/lock/UnlockReveal): the lock screen's last picture leaves over
// the desktop that is already back underneath — what goes away turns transparent.
// style: 0 heart iris, 1 pixels, 2 old TV ("stream ended"), 3 heaven's gate, 4 glitch
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float style;
    float cell;          // one art pixel, in the item's pixels
    vec2 resolution;
    vec2 origin;         // the heart's middle, 0..1
    vec4 accent;
    vec4 light;
};

layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
// heart curve: <= 0 inside
float heart(vec2 q) {
    float a = q.x * q.x + q.y * q.y - 1.0;
    return a * a * a - q.x * q.x * q.y * q.y * q.y;
}
float easeIn(float x) {
    return x * x * x;
}

void main() {
    float p = clamp(progress, 0.0, 1.0);
    vec2 uv = qt_TexCoord0;
    if (p >= 1.0) {
        fragColor = vec4(0.0);
        return;
    }
    vec2 px = uv * resolution;
    float cs = max(cell, 1.0);
    vec4 outc;

    if (style < 0.5) {
        // heart iris: a hole in the shape of a pixel heart grows from the password box,
        // an accent rim and a white one inside it
        vec2 c = (floor(px / (cs * 2.0)) + 0.5) * cs * 2.0;
        float s = min(resolution.x, resolution.y);
        vec2 q = (c - origin * resolution) / s;
        q.y = -q.y + 0.06;
        float r = easeIn(p) * 3.2 + p * 0.25 + 0.0001;
        float out0 = step(heart(q / r), 0.0);
        float in1 = step(heart(q / (r * 0.94)), 0.0);
        float in2 = step(heart(q / (r * 0.88)), 0.0);
        outc = texture(source, uv) * (1.0 - out0);
        if (out0 > 0.5 && in1 < 0.5)
            outc = vec4(accent.rgb, 1.0);
        else if (in1 > 0.5 && in2 < 0.5)
            outc = vec4(light.rgb, 1.0) * 0.85;
    } else if (style < 1.5) {
        // pixels: the picture coarsens into blocks, then they blink out one by one,
        // a sparkle where one just went
        float grow = smoothstep(0.0, 0.4, p);
        float bs = cs * exp2(floor(grow * 4.0 + 0.5));
        vec2 cid = floor(px / bs);
        vec2 cuv = (cid + 0.5) * bs / resolution;
        vec2 big = floor(px / (cs * 16.0));
        float r = hash(big);
        float t = (p - 0.3) / 0.7;
        float alive = step(t, r);
        outc = texture(source, cuv) * alive;
        float fresh = (1.0 - alive) * step(r, t) * step(t - 0.08, r);
        vec2 f = fract(px / (cs * 16.0)) - 0.5;
        float plus = step(min(abs(f.x), abs(f.y)), 0.07) * step(max(abs(f.x), abs(f.y)), 0.35);
        outc = mix(outc, vec4(mix(accent.rgb, light.rgb, 0.4), 1.0), fresh * plus);
    } else if (style < 2.5) {
        // old TV: the lock folds into a bright line, then the desktop opens from it
        float scan = 0.82 + 0.18 * step(0.5, fract(px.y / (cs * 1.5)));
        if (p < 0.45) {
            float h = 1.0 - p / 0.45;
            h = max(h * h, 0.004);
            float w = mix(0.04, 1.0, smoothstep(0.0, 0.25, h));
            vec2 suv = vec2(0.5 + (uv.x - 0.5) / w, 0.5 + (uv.y - 0.5) / h);
            float on = step(abs(suv.y - 0.5), 0.5) * step(abs(suv.x - 0.5), 0.5);
            vec3 img = texture(source, suv).rgb + (1.0 - h) * (1.0 - h) * 1.2;
            outc = vec4(mix(vec3(0.0), img * scan, on), 1.0);
        } else {
            float q = (p - 0.45) / 0.55;
            float hh = max(q * q * 0.62, 0.002);
            float d = abs(uv.y - 0.5);
            float open = step(d, hh);
            float edge = step(d, hh + cs * 2.0 / resolution.y) - open;
            float fade = 1.0 - smoothstep(0.55, 1.0, q);
            vec3 rim = mix(light.rgb, accent.rgb, q);
            outc = vec4(0.0, 0.0, 0.0, 1.0) * (1.0 - open) * fade;
            outc = mix(outc, vec4(rim, 1.0) * fade, edge);
        }
    } else if (style < 3.5) {
        // heaven's gate: the picture parts in the middle like two doors, light pours
        // out of the gap and fades
        vec2 g = floor(px / cs) * cs / resolution;
        float o = easeIn(min(1.0, p * 1.15)) * 0.52;
        float gx = abs(g.x - 0.5);
        vec2 suv = vec2(g.x < 0.5 ? g.x + o : g.x - o, g.y);
        float door = g.x < 0.5 ? step(suv.x, 0.5) : step(0.5, suv.x);
        vec4 img = texture(source, suv);
        // a door darkens toward its outer edge as it swings
        img.rgb *= 1.0 - 0.35 * o * (1.0 - abs(suv.x - 0.5) * 2.0);
        float glow = (1.0 - p) * (1.0 - p) * max(0.0, 1.0 - gx / (o + 0.06));
        vec4 shine = vec4(light.rgb, 1.0) * clamp(glow * 1.4, 0.0, 1.0);
        float flash = (1.0 - smoothstep(0.0, 0.22, p)) * 0.55;
        outc = door * vec4(mix(img.rgb, light.rgb, flash), 1.0) + (1.0 - door) * shine;
    } else {
        // glitch: bands jump sideways split into RGB and drop out at random
        float amt = sin(p * 3.14159265);
        float band = floor(px.y / (cs * 8.0));
        float rnd = hash(vec2(band, floor(p * 14.0)));
        float off = (rnd - 0.5) * 0.2 * amt * step(0.45, hash(vec2(band, 7.0 + floor(p * 11.0))));
        float gone = step(hash(vec2(band, 3.0)) * 0.8 + 0.08, p);
        vec2 g = vec2(uv.x + off, uv.y);
        float sp = 0.014 * amt;
        vec4 cr = texture(source, g + vec2(sp, 0.0));
        vec4 cg = texture(source, g);
        vec4 cb = texture(source, g - vec2(sp, 0.0));
        float a = max(cr.a, max(cg.a, cb.a)) * (1.0 - gone);
        outc = vec4(cr.r, cg.g, cb.b, 1.0) * a;
        float tint = 0.3 * amt * step(0.9, hash(vec2(band, floor(p * 20.0))));
        outc.rgb = mix(outc.rgb, accent.rgb * a, tint);
    }
    fragColor = outc * qt_Opacity;
}
