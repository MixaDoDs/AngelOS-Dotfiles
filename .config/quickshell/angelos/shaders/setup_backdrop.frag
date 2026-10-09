#version 440
// The first run's intro behind everything (modules/settings/SetupIntroScreen.qml), in pixels: the
// dark, a barely-there pattern of sigils and shut eyes (more of them open, one by one, towards the
// end — `opened`), and ash and sparks drifting up from the fire below, more and faster as the
// minute goes on (`k`).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;   // px
    float px;        // one art pixel, px
    float time;      // s into the minute
    float k;         // 0…1: how far into it
    float opened;    // 0…1: the share of the pattern's eyes open
};

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-5), 0.0, 1.0);
    return length(pa - ba * h);
}

// a point of a rune's 3×3 grid, 0…8
vec2 node(float i) {
    return vec2(mod(i, 3.0), floor(i / 3.0)) * 0.3 + 0.2;
}

// one particle a cell at most, on the art-pixel grid, drifting up
float particles(vec2 a, float cell, float speed, float seed, float density, float size) {
    vec2 q = a + vec2(0.0, time * speed);
    vec2 c = floor(q / cell);
    float h = hash(c + seed);
    if (h > density)
        return 0.0;
    vec2 pos = vec2(hash(c + seed + 1.3), hash(c + seed + 2.7)) * (cell - 2.0 * size) + size;
    pos.x += floor(sin(time * 1.7 + h * 40.0) * 2.0 + 0.5);
    vec2 l = q - c * cell;
    return step(abs(l.x - pos.x), size * 0.5) * step(abs(l.y - pos.y), size * 0.5);
}

void main() {
    vec2 a = floor(qt_TexCoord0 * itemSize / px);    // art pixels
    float up = 1.0 - qt_TexCoord0.y;                   // 0 at the bottom
    vec3 col = vec3(0.027, 0.024, 0.047);

    // ---- the pattern: runes and eyes by turns, 22 art pixels a cell ----
    float S = 22.0;
    vec2 cell = floor(a / S);
    vec2 uv = (a - cell * S + 0.5) / S;                 // 0…1 in the cell
    float line = 1.1 / S;
    float ink = 0.0;
    vec3 inkCol = vec3(0.10, 0.08, 0.14);
    if (mod(cell.x + cell.y, 2.0) < 0.5) {
        // a rune: three strokes between the points of a 3×3 grid
        for (int i = 0; i < 3; i++) {
            float fi = float(i);
            float n0 = floor(hash(cell + fi * 1.7) * 9.0);
            float n1 = floor(hash(cell + fi * 2.9 + 0.5) * 9.0);
            if (segment(uv, node(n0), node(n1)) < line)
                ink = 1.0;
        }
    } else {
        // an eye, shut (the lower lid's curve) or, later, open and gold
        vec2 e = (uv - 0.5) / vec2(0.34, 0.14);
        bool open = hash(cell + 7.7) < opened;
        if (open) {
            float lid = abs(abs(e.y) - (1.0 - e.x * e.x));
            if (abs(e.x) < 1.0 && lid < 0.28)
                ink = 1.0;
            if (length((uv - 0.5) / 0.07) < 1.0) {
                ink = 1.0;
                inkCol = vec3(0.42, 0.28, 0.06);
            }
        } else if (abs(e.x) < 1.0 && abs(e.y - (1.0 - e.x * e.x) * 0.6) < 0.3 && e.y > 0.0) {
            ink = 1.0;
        }
    }
    // about half the cells empty (not a wallpaper's grid), the rest breathing a little
    ink *= step(0.45, hash(cell + 21.3));
    col = mix(col, inkCol, ink * (0.55 + 0.15 * sin(time * 0.8 + cell.x)));

    // ---- ash (grey, slow) and sparks (orange, quicker), thicker by the end ----
    float ash = particles(a, 9.0, 4.0 + 8.0 * k, 3.1, 0.12 + 0.25 * k, 1.0)
              + particles(a + 37.0, 13.0, 6.0 + 10.0 * k, 9.4, 0.10 + 0.2 * k, 2.0);
    col = mix(col, vec3(0.32, 0.30, 0.31), clamp(ash, 0.0, 1.0) * (0.25 + 0.35 * (1.0 - up)));
    float spark = particles(a + 11.0, 15.0, 10.0 + 26.0 * k, 5.2, 0.05 + 0.3 * k, 1.0);
    float fl = 0.7 + 0.3 * sin(time * 23.0 + a.x * 0.7);
    vec3 sparkCol = mix(vec3(1.0, 0.45, 0.08), vec3(1.0, 0.85, 0.35), hash(floor(a / 15.0)));
    col = mix(col, sparkCol * fl, spark * clamp(1.15 - up * 1.1, 0.0, 1.0));

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
