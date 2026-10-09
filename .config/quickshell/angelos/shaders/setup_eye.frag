#version 440
// The first run's intro on the screens without the installer (modules/settings/SetupEye.qml):
// one huge eye in pixels — an almond of veined white, a golden iris in rays (the ophanim's
// gold), the pupil, a square glint — opening out of the dark, looking where `look` says. Shaded
// in dithered steps like a ball (darker round the white's edges), the iris flattening as it turns
// aside, the upper lid's shadow falling over the iris and the pupil.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;   // px
    float px;        // one art pixel, px
    vec2 look;       // where the iris is: −1…1 of its room each way (0, 0: at you)
    float open;      // the lids: 0 shut … 1 open
    float pupil;     // the pupil's share of the iris
    float shown;     // 0…1: out of the dark
    float time;      // s
};

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// ordered dither, 4×4 (0…1), over art pixels
float bayer2(vec2 a) {
    a = floor(a);
    return fract(dot(a, vec2(0.5, a.y * 0.75)));
}
float bayer4(vec2 a) {
    return bayer2(0.5 * a) * 0.25 + bayer2(a);
}
// `v` 0…1 to one of `steps` levels, dithered
float dithered(float v, float steps, vec2 cell) {
    float s = v * steps;
    return (floor(s) + step(bayer4(cell), fract(s))) / steps;
}

void main() {
    // art pixels: everything on a grid of `px`
    vec2 p = (floor(qt_TexCoord0 * itemSize / px) + 0.5) * px;
    vec2 c = itemSize * 0.5;
    float W = min(itemSize.x * 0.44, itemSize.y * 0.62);   // half the eye's width
    float H = W * 0.46 * clamp(open, 0.0, 1.0);             // half its height, open
    vec2 d = p - c;
    float ex = d.x / W;
    // the almond: the lids' curve, a little fuller above
    float lidUp = H * (1.0 - ex * ex) * 1.05;
    float lidDown = H * (1.0 - ex * ex) * 0.9;
    float inside = step(abs(ex), 1.0) * step(-lidUp, d.y) * step(d.y, lidDown);
    // the lids' rim, one art pixel and a half
    float rimW = px * 1.5;
    float rim = step(abs(ex), 1.02) * (1.0 - inside) * step(-lidUp - rimW, d.y) * step(d.y, lidDown + rimW);
    if (inside < 0.5 && rim < 0.5) {
        fragColor = vec4(0.0);
        return;
    }
    vec3 col;
    if (inside < 0.5) {
        col = vec3(0.10, 0.05, 0.06);
    } else {
        // the white: warm, darker and redder towards the corners, veins in from the edges
        float edge = clamp(abs(ex), 0.0, 1.0);
        vec3 white = mix(vec3(0.93, 0.89, 0.82), vec3(0.62, 0.42, 0.40), pow(edge, 3.0));
        float around = atan(d.y, d.x);
        float vein = step(0.93, hash(vec2(floor(around * 18.0), 1.0))) * step(0.35, edge) * step(hash(floor(p / px)), 0.8);
        white = mix(white, vec3(0.70, 0.12, 0.12), vein * edge);
        // a ball: the white darker towards its rim, in dithered steps
        vec2 cell = floor(p / px);
        float ball = clamp(length(vec2(ex, d.y / max(W * 0.46, 1.0))) * 0.95, 0.0, 1.0);
        white *= 1.0 - 0.42 * dithered(smoothstep(0.3, 1.0, ball), 3.0, cell);
        col = white;

        // the iris, where it looks, inside the almond's room
        float R = W * 0.36;
        vec2 room = vec2(W - R * 1.1, max(0.0, H - R * 0.55));
        vec2 ic = c + clamp(look, vec2(-1.0), vec2(1.0)) * room;
        vec2 q = p - ic;
        // turned aside, the round iris shows as an oval
        vec2 squash = vec2(1.0 - 0.38 * abs(clamp(look.x, -1.0, 1.0)), 1.0 - 0.3 * abs(clamp(look.y, -1.0, 1.0)));
        q /= squash;
        float r = length(q) / R;
        if (r < 1.0) {
            float ang = atan(q.y, q.x);
            float ray = hash(vec2(floor(ang * 28.0 / 6.2832 * 6.0), 3.0));
            vec3 gold = mix(vec3(0.55, 0.32, 0.05), vec3(0.98, 0.78, 0.25), r * 0.6 + ray * 0.4);
            gold = mix(gold, vec3(0.30, 0.15, 0.02), step(0.86, r));          // the dark ring
            col = gold;
            float pr = clamp(pupil, 0.15, 0.85);
            if (r < pr)
                col = vec3(0.02, 0.01, 0.02);
            // the glint: a square, up and left of the pupil
            vec2 g = q / R - vec2(-0.32, -0.36);
            if (abs(g.x) < 0.11 && abs(g.y) < 0.11)
                col = vec3(1.0, 0.98, 0.92);
        }
        // the upper lid's shadow over all of it, iris and pupil too: a dithered band under the lid
        float under = clamp((d.y + lidUp) / max(lidUp * 0.75, 1.0), 0.0, 1.0);   // 0 at the lid
        col *= 1.0 - 0.55 * dithered(1.0 - under, 4.0, cell);
    }
    // a faint breath of light on it
    col *= 0.94 + 0.06 * sin(time * 1.3);
    float a = clamp(shown, 0.0, 1.0);
    fragColor = vec4(col * a, a) * qt_Opacity;
}
