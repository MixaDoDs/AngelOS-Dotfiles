#version 440
// The first run's intro, its first minute (modules/settings/SetupPrequel.qml): her room on the
// night of 31.12.2002 — one of the author's pictures of it (data/intro/room-*.png: from the
// window, from behind her, from the door), the camera at `cam` in it. Her monitors' blank
// screens show the desktop of that year (`desk`: three of them side by side —
// SetupPrequelDesk), each in the perspective its glass has in that picture (s0…s2: what takes a
// point of the picture to a point of the screen), so a screen seen from the side is drawn from
// the side; whatever of her is in front of one stays in front (only the blank white is replaced).
// The cigarette in the ashtray: an ember breathing at `ember`, a thread of smoke (`smoke`), and
// from `burn` 0 on the hearths h0…h4 catch one after another — the room lit by them, the smoke
// coming down from the ceiling. Fireworks in the window (`pane`) flash with `burst`, in the
// colour `spark`: the shells painted in its sky show, the glass lights up, and the room with
// it — most by the window, falling off across the wall.
// `glitch`: the recording breaking up.
// `view` 1…3: no room — one of her monitors, whole, as a tube shows it. Something has come up
// at `spot` of it: as `near` grows the camera leans a little that way and the dark closes in
// round it, softly — no frame, no jump; the eye finds it by itself.
// All of it darker towards the corners.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;   // px
    float px;        // one art pixel, px
    float view;      // 0: the room; 1, 2, 3: her monitor 0, 1, 2, whole
    float picAspect; // the picture's width over its height
    vec3 cam;        // the middle of the view in the picture (0…1), and how close
    float time;      // s
    float smoke;     // 0…1
    float burn;      // s since the papers caught (before that: less than 0)
    float burst;     // a firework's flash, 0…1
    vec3 spark;      // …and its colour
    float glitch;    // 0…1
    mat4 s0;         // her screens: the picture's (x, y, 0, 1) to a screen's (x·w, y·w, 0, w)
    mat4 s1;
    mat4 s2;
    vec4 h0;         // what burns: x, y, the flame's size, s after `burn` 0 it catches
    vec4 h1;
    vec4 h2;
    vec4 h3;
    vec4 h4;
    vec2 ember;      // the cigarette's tip
    vec4 pane;       // the window's glass: x0 y0 x1 y1
    vec4 shellA;     // the two fireworks painted in its sky: x, y, how big (picture heights)
    vec4 shellB;
    vec4 spot;       // her screen whole: what has come up on it (x0 y0 x1 y1, 0…1 of it)
    float near;      // …and how much the camera leans to it and the dark closes round it, 0…1
};
layout(binding = 1) uniform sampler2D room;
layout(binding = 2) uniform sampler2D desk;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
    return 0.55 * noise(p) + 0.3 * noise(p * 2.1 + 7.0) + 0.15 * noise(p * 4.3 + 19.0);
}
float bayer2(vec2 a) {
    a = floor(a);
    return fract(dot(a, vec2(0.5, a.y * 0.75)));
}
float bayer4(vec2 a) {
    return bayer2(0.5 * a) * 0.25 + bayer2(a);
}
vec4 hearth(float i) {
    return i < 0.5 ? h0 : i < 1.5 ? h1 : i < 2.5 ? h2 : i < 3.5 ? h3 : h4;
}

void main() {
    vec2 suv = qt_TexCoord0;
    float sa = itemSize.x / itemSize.y;
    // the tape: rows torn sideways
    float row = floor(suv.y * itemSize.y / px);
    float frame = floor(time * 24.0);
    if (glitch > 0.0 && hash(vec2(row, frame)) < glitch * 0.6)
        suv.x += (hash(vec2(row, frame + 3.0)) - 0.5) * 0.3 * glitch;
    vec3 col;

    if (view > 0.5) {
        // ---- one of her monitors, whole: 4:3, the glass a little round, its lines showing ----
        vec2 q = (suv - 0.5) * vec2(max(1.0, sa / 1.3333), max(1.0, 1.3333 / sa)) * 2.0;
        // leaning to the spot: a third of the way to its middle, a little closer
        vec2 mid = (spot.xy + spot.zw) - 1.0;
        q = mix(q, mid * 0.34 + q / 1.14, near);
        q *= 1.0 + 0.045 * dot(q, q) - 0.045;
        if (abs(q.x) > 1.0 || abs(q.y) > 1.0) {
            // the tube's dark surround, the screen's light on its edge
            float beyond = max(abs(q.x), abs(q.y)) - 1.0;
            col = vec3(0.030, 0.024, 0.045) + vec3(0.10, 0.08, 0.16) * exp(-beyond * 40.0);
        } else {
            vec2 t = q * 0.5 + 0.5;
            col = texture(desk, vec2((view - 1.0 + t.x) / 3.0, t.y)).rgb;
            col *= 0.86 + 0.14 * step(0.5, fract(t.y * 240.0));
            col *= 1.0 - 0.11 * dot(q, q);
            col *= 0.97 + 0.03 * sin(time * 50.0);
            // the dark closing in round the spot
            float off = length((t - 0.5 * (spot.xy + spot.zw)) * vec2(1.3333, 1.0));
            col *= 1.0 - 0.78 * near * smoothstep(0.16, 0.72, off);
        }
    } else {
        // ---- the room: the picture covers the screen, the camera inside it ----
        vec2 part = sa > picAspect ? vec2(1.0, picAspect / sa) : vec2(sa / picAspect, 1.0);
        vec2 span = 0.5 * part / cam.z;
        vec2 uv = clamp(cam.xy, span, 1.0 - span) + (suv - 0.5) * part / cam.z;
        col = texture(room, uv).rgb;
        // her screens: where the picture is their blank white. (A hair beyond the fitted glass
        // is still that screen: its round corners, the picture's own soft edge.)
        vec4 r0 = s0 * vec4(uv, 0.0, 1.0), r1 = s1 * vec4(uv, 0.0, 1.0), r2 = s2 * vec4(uv, 0.0, 1.0);
        vec2 q = r0.xy / r0.w;
        float which = 0.0;
        if (max(abs(q.x - 0.5), abs(q.y - 0.5)) > 0.54) {
            q = r1.xy / r1.w;
            which = 1.0;
        }
        if (max(abs(q.x - 0.5), abs(q.y - 0.5)) > 0.54) {
            q = r2.xy / r2.w;
            which = 2.0;
        }
        // (four samples across a pixel: small in the picture, her screen's letters would crawl)
        vec2 dx = 0.25 * dFdx(q), dy = 0.25 * dFdy(q);
        if (min(col.r, min(col.g, col.b)) > 0.76 && max(abs(q.x - 0.5), abs(q.y - 0.5)) <= 0.54 && length(dx) + length(dy) < 0.02) {
            vec3 lit = vec3(0.0);
            for (float i = 0.0; i < 3.5; i += 1.0) {
                vec2 at = clamp(q + dx * (mod(i, 2.0) * 2.0 - 1.0) + dy * (floor(i / 2.0) * 2.0 - 1.0), 0.004, 0.996);
                lit += texture(desk, vec2((which + at.x) / 3.0, at.y)).rgb;
            }
            col = 0.25 * lit * (0.93 + 0.04 * sin(time * 50.0));
        }
        // ---- everything that moves: on a grid of art pixels in the picture ----
        vec2 grid = vec2(270.0 * picAspect, 270.0);
        vec2 cell = floor(uv * grid);
        vec2 p = (cell + 0.5) / grid;
        vec2 P = vec2(p.x * picAspect, p.y);          // the same both ways
        float tq = floor(time * 12.0) / 12.0;

        // fireworks: the window's glass, and their light across the room from it
        bool inPane = p.x > pane.x && p.x < pane.z && p.y > pane.y && p.y < pane.w;
        // (the picture has two shells painted in its sky: only the night and its stars there
        // between the bangs — the roofs under them left alone — the shells in full with one)
        float painted = 1.0 - smoothstep(0.5, 1.0, min(length(P - vec2(shellA.x * picAspect, shellA.y)) / shellA.z, length(P - vec2(shellB.x * picAspect, shellB.y)) / shellB.z));
        float lit = max(smoothstep(0.42, 0.50, max(col.r, max(col.g, col.b))), smoothstep(0.5, 0.7, col.r / max(col.b, 0.01)));
        float grain = hash(cell);
        vec3 night = grain > 0.988 ? vec3(0.55, 0.55, 0.82) : mix(vec3(0.137, 0.141, 0.376), vec3(0.21, 0.20, 0.44), step(0.45, grain));
        col = mix(col, night, painted * lit * (1.0 - clamp(burst * 1.6, 0.0, 1.0)));
        vec2 from = (P - vec2(0.5 * (pane.x + pane.z) * picAspect, 0.5 * (pane.y + pane.w))) / vec2(1.25, 0.9);
        float spill = exp(-2.2 * dot(from, from));
        float flick = burst * (0.8 + 0.2 * step(0.5, fract(tq * 5.0)));
        col += spark * flick * (inPane ? 0.42 : 0.05 + 0.24 * spill) * (0.35 + 0.65 * dot(col, vec3(0.333)));
        col = mix(col, col * (0.6 + 0.9 * spark), flick * 0.45 * spill);

        // the flames, the light of them
        float flame = 0.0;
        float glow = 0.0;
        for (float i = 0.0; i < 4.5; i += 1.0) {
            vec4 h = hearth(i);
            float g = clamp((burn - h.w) / 5.0, 0.0, 1.0);
            if (g <= 0.0)
                continue;
            float R = h.z * (0.25 + 0.75 * g);
            vec2 q = (P - vec2(h.x * picAspect, h.y)) / R;
            float up = -q.y;                           // above the hearth
            glow += g * h.z * 14.0 * exp(-dot(q, q) * 0.05);
            if (up < -0.25 || up > 2.6)
                continue;
            // tongues: hot in the middle, thin and red at the edges
            float n = fbm(vec2(q.x * 2.6 + i * 5.0, q.y * 2.2 + tq * 3.6));
            float n2 = noise(vec2(q.x * 7.0 + i, q.y * 5.0 + tq * 6.0));
            float width = (0.74 - 0.23 * up) * (0.45 + n);
            float lick = abs(q.x + 0.15 * up * sin(up * 2.3 + tq * 4.0 + i));
            if (lick < width)
                flame = max(flame, (1.0 - up / 2.6) * (1.0 - lick / width) * 1.5 * (0.55 + 0.75 * n2));
        }
        col *= mix(vec3(1.0), vec3(1.22, 0.92, 0.74), clamp(glow * 0.6, 0.0, 1.0));
        col += vec3(1.0, 0.42, 0.10) * glow * 0.22 * (0.85 + 0.15 * sin(tq * 17.0));
        flame += 0.08 * (bayer4(cell) - 0.5);
        if (flame > 0.95)
            col = vec3(1.0, 0.93, 0.62);
        else if (flame > 0.60)
            col = vec3(1.0, 0.62, 0.16);
        else if (flame > 0.30)
            col = vec3(0.86, 0.26, 0.08);
        else if (flame > 0.14)
            col = mix(col, vec3(0.35, 0.08, 0.05), 0.7);

        // the cigarette: an ember breathing, a thread of smoke
        vec2 A = vec2(ember.x * picAspect, ember.y);
        if (burn < 0.0 && cell == floor(ember * grid))
            col = mix(vec3(0.9, 0.3, 0.08), vec3(1.0, 0.75, 0.3), 0.5 + 0.5 * sin(time * 1.7));
        float up = A.y - P.y;
        float reach = 0.04 + 0.5 * smoke;
        if (up > 0.0 && up < reach) {
            float dx = P.x - A.x - 0.012 * sin(up * 42.0 - tq * 1.4) * (0.3 + up * 7.0);
            float thick = 0.0022 + 0.05 * up * smoke;
            float a = (1.0 - up / reach) * (0.35 + 0.5 * smoke);
            if (abs(dx) < thick && bayer4(cell) < a)
                col = mix(col, vec3(0.74, 0.71, 0.82), 0.55);
        }
        // and under the ceiling, coming down
        float low = 0.15 + 0.7 * smoke * smoke;
        float haze = smoke * smoke * clamp(1.0 - p.y / low, 0.0, 1.0) * (0.5 + 0.8 * fbm(vec2(P.x * 5.0 - tq * 0.25, P.y * 7.0 + tq * 0.1)));
        if (bayer4(cell) < haze)
            col = mix(col, vec3(0.30, 0.27, 0.33), 0.75);
    }

    // darker towards the corners
    vec2 corner = qt_TexCoord0 - 0.5;
    col *= 1.0 - 0.95 * dot(corner, corner);

    // the recording breaking up: snow over it, the colours gone
    if (glitch > 0.0) {
        float snow = hash(vec2(floor(suv.x * itemSize.x / px), row) + frame);
        col = mix(col, vec3(snow), glitch * glitch * 0.85);
        if (hash(vec2(floor(row / 9.0), frame)) < glitch * 0.35)
            col = vec3(snow * 0.9 + 0.1);
    }
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
