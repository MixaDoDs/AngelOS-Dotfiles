#version 440
// Celestia's face, the whole of it: one signed-distance scene drawn smooth (Golden Gate) or
// through a matrix of dots or square pixels (Classic, hell, the bar). Redrawn only when one of
// these values changes, so a face at rest costs nothing.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 ink;      // the lit dots, the eyes
    vec4 glowC;    // the light around them, the halo
    vec4 plate;    // what the face lies on
    vec4 cheek;    // blush, sweat, the second colour
    vec4 eye;      // look x, look y, open 0..1, wide
    vec4 expr;     // happy, brow (-1 sad..1 angry), squint, blush
    vec4 mouth;    // open, width, smile (-1..1), music level 0..1
    vec4 fx;       // bounce, beat, glitch, think
    vec4 fx2;      // halo, sweat, horns, sleep
    vec4 cfg;      // grid (0 smooth), square, round plate, time
    vec4 res;      // width, height, small (the bar: thick lines, no sparks)
    vec4 tint;     // the mood's colour, a = how much
};

float bump() {
    return fx.x * (res.z > 0.5 ? 0.25 : 1.0);
}
float box(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float eyeD(vec2 p, float side) {
    vec2 c = vec2(side * 0.40 + eye.x * 0.14, 0.05 + eye.y * 0.12 - bump() * 0.06);
    vec2 q = p - c;
    float w = 0.185 * eye.w * (1.0 - 0.13 * eye.x * side) * (res.z > 0.5 ? 1.3 : 1.0);
    float h = max(res.z > 0.5 ? 0.075 : 0.018, 0.275 * eye.z * eye.w);
    float d = box(q, vec2(w, h), min(w, h) * 0.62);
    // happy: the eye bends into a thick upward arc
    vec2 qa = q + vec2(0.0, 0.10);
    float arc = max(abs(length(qa) - 0.18) - (res.z > 0.5 ? 0.09 : 0.052), -qa.y - 0.015);
    d = mix(d, arc, smoothstep(0.25, 0.8, expr.x));
    // squint from above and below
    d = max(d, abs(q.y) - h * (1.0 - 0.72 * expr.z));
    // the brow: an angled lid, in towards the nose when angry, out when sad
    float lid = q.y + expr.y * side * q.x * 0.9 - h * (1.0 - 0.5 * abs(expr.y));
    d = max(d, lid);
    return d;
}
float mouthD(vec2 p) {
    vec2 q = p - vec2(eye.x * 0.09, -0.47 + eye.y * 0.06 - bump() * 0.03);
    float w = mouth.y;
    if (w < 0.01)
        return 9.0;
    float wc = res.z > 0.5 ? max(w, 0.20) : w;
    float arc = q.y - mouth.z * (res.z > 0.5 ? 0.08 : 0.18) * (q.x * q.x / (wc * wc) - 0.5);
    float d = max(abs(arc) - (res.z > 0.5 ? 0.095 : 0.028), abs(q.x) - max(w, res.z > 0.5 ? 0.20 : 0.0));
    float o = mouth.x;
    if (o > 0.01) {
        vec2 e = q / vec2(max(w * 0.8, 0.05), 0.04 + 0.2 * o);
        d = min(d, (length(e) - 1.0) * 0.1);
    }
    return d;
}
float haloD(vec2 p) {
    if (res.z > 0.5) {
        // the bar: a plain thick bar of light, it must not fall between the dots
        vec2 q = p - vec2(0.0, 0.80 - bump() * 0.05);
        return box(q, vec2(0.42, 0.075), 0.05);
    }
    vec2 q = p - vec2(eye.x * 0.05, 0.80 + 0.02 * sin(cfg.w * 1.3) - fx.x * 0.09);
    return abs(length(q / vec2(0.46, 0.11)) - 1.0) * 0.11 - 0.022;
}
float hornD(vec2 p, float side) {
    vec2 q = p - vec2(side * 0.47, 0.74 - fx.x * 0.05);
    q.x *= side;
    float a = q.y - 0.24 + q.x * 0.2;
    float b = -q.y - 0.14;
    float c = abs(q.x + q.y * 0.28) - 0.13 * (0.24 - q.y) / 0.38;
    return max(max(a, b), c);
}
// the catchlights: where the eyes hold a spark of the plate; they follow the look a little
float shineD(vec2 p) {
    float d = 9.0;
    for (int i = 0; i < 2; i++) {
        float side = i == 0 ? -1.0 : 1.0;
        vec2 c = vec2(side * 0.40 + eye.x * 0.17 - 0.055, 0.15 + eye.y * 0.14 - fx.x * 0.06);
        d = min(d, box(p - c, vec2(0.052), 0.02));
        d = min(d, box(p - c - vec2(0.105, -0.13), vec2(0.024), 0.01));
    }
    return d;
}
// x: lit, y: second colour, z: halo
vec3 scene(vec2 p, out float dMain) {
    float d = min(eyeD(p, -1.0), eyeD(p, 1.0));
    d = min(d, mouthD(p));
    float t = cfg.w;
    // thinking: three dots climbing beside the head
    if (fx.w > 0.01) {
        for (int i = 0; i < 3; i++) {
            float fi = float(i);
            float ph = fract(t * 0.6 - fi * 0.33);
            vec2 c = vec2(0.70 + fi * 0.09, 0.30 + fi * 0.19 + sin(ph * 6.283) * 0.03);
            d = min(d, length(p - c) - (0.045 + 0.02 * fi) * fx.w * (0.65 + 0.35 * sin(ph * 6.283)));
        }
    }
    // asleep: small z's drifting up
    if (fx2.w > 0.5) {
        for (int i = 0; i < 2; i++) {
            float ph = fract(t * 0.22 + float(i) * 0.5);
            vec2 q = p - vec2(0.52 + ph * 0.3, 0.2 + ph * 0.5);
            float s = 0.05 * (1.0 + ph);
            float zz = max(box(q, vec2(s), 0.0), -box(q, vec2(s * 0.62), 0.0));
            zz = min(max(abs(q.x + q.y) - s * 0.2, box(q, vec2(s), 0.0)), zz);
            d = min(d, mix(zz, 9.0, smoothstep(0.75, 1.0, ph)));
        }
    }
    dMain = d;
    float lit = 1.0 - smoothstep(-0.006, 0.012, d);
    // no spark in shut or laughing eyes
    float spark = (1.0 - smoothstep(0.25, 0.6, expr.x)) * smoothstep(0.35, 0.7, eye.z);
    if (res.z > 0.5)
        spark = 0.0;
    lit *= 1.0 - spark * (1.0 - smoothstep(-0.004, 0.01, shineD(p)));
    float second = 0.0;
    float blush = expr.w * (1.0 - smoothstep(0.0, 0.17, min(length((p - vec2(-0.62, -0.20)) / vec2(1.0, 0.6)), length((p - vec2(0.62, -0.20)) / vec2(1.0, 0.6)))));
    second = max(second, blush);
    // sweat drop
    if (fx2.y > 0.01) {
        vec2 q = p - vec2(0.72, 0.30 - fract(t * 0.35) * 0.3);
        float s = length(q * vec2(1.0, 0.7)) - 0.05 * fx2.y;
        second = max(second, 1.0 - smoothstep(-0.01, 0.015, s));
    }
    float halo = 0.0;
    if (fx2.x > 0.01)
        halo = fx2.x * (1.0 - smoothstep(-0.006, 0.012, haloD(p)));
    if (fx2.z > 0.01) {
        float hd = min(hornD(p, -1.0), hornD(p, 1.0));
        second = max(second, fx2.z * (1.0 - smoothstep(-0.006, 0.012, hd)));
    }
    return vec3(lit, second, halo);
}
void main() {
    vec2 uv = qt_TexCoord0;
    float aspect = res.x / max(res.y, 1.0);
    float grid = cfg.x;
    // a glitch: rows of the picture slip sideways
    if (fx.z > 0.01) {
        float row = floor(uv.y * 22.0);
        uv.x += (hash(vec2(row, floor(cfg.w * 18.0))) - 0.5) * 0.14 * fx.z * step(0.55, hash(vec2(row * 1.7, floor(cfg.w * 9.0))));
    }
    vec2 cellUv = uv;
    vec2 f = vec2(0.5);
    if (grid > 0.5) {
        vec2 g = uv * grid;
        f = fract(g);
        cellUv = (floor(g) + 0.5) / grid;
    }
    vec2 p = (cellUv * 2.0 - 1.0) * vec2(aspect, -1.0);
    vec2 pt = (uv * 2.0 - 1.0) * vec2(aspect, -1.0);
    // the head nods with the beat
    float tilt = res.z > 0.5 ? 0.0 : sin(fx.y * 3.14159) * 0.03;
    p = mat2(cos(tilt), -sin(tilt), sin(tilt), cos(tilt)) * p;

    float dm;
    vec3 s = scene(p, dm);
    float dFine;
    vec3 fine = scene(pt, dFine);

    // the mood's colour over the ink, deeper towards the bottom of the eyes
    vec3 inkC = mix(ink.rgb, tint.rgb, tint.a);
    vec3 inkLow = mix(inkC, glowC.rgb, 0.55);
    float shade = clamp(0.5 - p.y * 1.4, 0.0, 1.0);
    inkC = mix(inkC, inkLow, shade);
    // the plate
    float plateD = cfg.z > 0.5 ? length(pt) - 0.985 : box(pt, vec2(aspect * 0.985, 0.985), 0.10);
    float inside = 1.0 - smoothstep(-0.008, 0.004, plateD);
    vec3 col = plate.rgb;
    // a soft light on the plate around the face
    float aura = exp(-max(dFine, 0.0) * 5.5);
    col += mix(glowC.rgb, tint.rgb, tint.a) * aura * (0.20 + 0.30 * fx.y);
    // music: a low wall of dots that rises with the sound, and sparks on the kick
    float eq = 0.0;
    float spk = 0.0;
    if (mouth.w > 0.01 && grid > 0.5) {
        float cx = floor(cellUv.x * grid);
        float hgt = (0.35 + 0.65 * abs(sin(cx * 0.9 + cfg.w * 7.0) * sin(cx * 0.37 - cfg.w * 3.1))) * mouth.w * 0.13;
        eq = step(1.0 - cellUv.y, hgt) * smoothstep(0.0, 0.05, cellUv.x) * smoothstep(0.0, 0.05, 1.0 - cellUv.x);
    }
    if (fx.y > 0.02 && grid > 0.5 && res.z < 0.5) {
        vec2 cc = floor(cellUv * grid);
        spk = step(0.985, hash(cc + floor(cfg.w * 11.0))) * fx.y;
    }

    if (grid > 0.5) {
        float dotM = cfg.y > 0.5 ? step(max(abs(f.x - 0.5), abs(f.y - 0.5)), 0.43) : 1.0 - smoothstep(0.34, 0.46, length(f - 0.5));
        float flick = 0.94 + 0.06 * hash(floor(cellUv * grid) + floor(cfg.w * 7.0));
        vec3 dim = mix(plate.rgb, ink.rgb, 0.075);
        vec3 lit = inkC * flick;
        vec3 dotC = mix(dim, lit, s.x);
        // the halo: a slow light running around it
        float run = 0.62 + 0.38 * sin(atan(p.y - 0.8, p.x * 0.3) * 3.0 + cfg.w * 1.7);
        dotC = mix(dotC, glowC.rgb * (0.65 + 0.55 * run) + fx.y * 0.25, s.z);
        dotC = mix(dotC, mix(inkC, glowC.rgb, 0.7), eq * 0.5);
        dotC = mix(dotC, vec3(1.0), spk);
        dotC = mix(dotC, cheek.rgb, s.y * (1.0 - s.x));
        col = mix(col, dotC, dotM);
    } else {
        col = mix(col, inkC, fine.x);
        col = mix(col, glowC.rgb, fine.z);
        col = mix(col, cheek.rgb, fine.y * (1.0 - fine.x));
    }
    // light that escapes the lit shapes, a touch more on a kick
    col += inkC * exp(-max(dFine, 0.0) * 16.0) * (0.14 + 0.30 * fx.y);
    // the tube: a line of light that passes, the corners falling off into the dark
    if (cfg.y > 0.5) {
        float sweep = exp(-pow((uv.y - fract(cfg.w * 0.09)) * 26.0, 2.0));
        col += inkC * sweep * 0.05;
        col *= 1.0 - 0.28 * smoothstep(0.55, 1.25, length(pt / vec2(aspect, 1.0)));
    }
    float a = inside * plate.a;
    a = max(a, inside * max(max(s.x, s.y), s.z));
    fragColor = vec4(col * a, a) * qt_Opacity;
}
