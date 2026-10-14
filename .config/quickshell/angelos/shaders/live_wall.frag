#version 440
// Half-alive wallpaper (widgets/LiveWall): the picture as it is, and a scene in it that lives
// quietly, from the mask scripts/live-wall.py made of it — r the layer of every art pixel
// (×32: 1 sky, 2 cloud, 3 a ring or another thing in the sky, 4 still water, 5 falling water,
// 6 land, 7 outdoors where only snow falls; the low bits: 1…3 a garland's bulb of that group,
// 4…6 a CRT screen), g a place within it (the water's depth, a fall's way down, the place round
// a ring), b the picture's own bright points (lights in the sky, glints on the water). Everything sits
// on the art's pixel grid (`grid`: one art pixel and its offset, in the picture's pixels) and is
// scaled by `strength` (0 = the picture). Nothing flickers fast: the eye is left alone.
//
// Always, smoothly (a layer's own picture slides — two copies, each restarting while the other
// is whole, so no jump shows):
//   - the falls pour down, the sea sways; mist curls up out of the abyss (the clouds stay:
//     their drift pulled the eye)
//   - the shadows of clouds pass over the water, the falls and the land
//   - glints on the water and the sky's lights swell and fade over seconds
//   - at night a few new stars come and go on the sky's dark; now and then a star falls
// Now and then (`event`, chosen by LiveWall every 12–35 s, on a beat when music plays):
//   1 a glint runs over the ring        2 a pebble breaks off the edge and falls
//   3 a gust of wind ripples across the water
//   4 an eye opens in a cloud, looks, closes  5 small rings spread on open water
//   (4 and 5: Uriel's — the Ophanim, wheels full of eyes, are near, just out of the picture)
//   6 the eye the picture's author pointed at blinks (its own clock: 90 s and more apart)
// What the author's hints add (release 2002; all 0 for older pictures, nothing of it runs):
// snow over the sky and outdoors, far fireworks on a night sky's dark, a garland's bulbs taking
// turns, CRT glass breathing, a thread of smoke
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;          // seconds (stops while the desk is covered)
    float strength;      // 0 … 1
    float night;         // 0 day … 1 night
    float axis;          // the waterline, 0 top … 1 bottom of the picture
    float mirror;        // 1: the water mirrors the sky
    float skyMode;       // 0 the mask, 1 above the waterline, 2 none
    float waterMode;     // 0 the mask, 1 below the waterline, 2 none
    float stars;         // 0/1: new stars
    float meteors;       // 0/1: falling stars
    float water;         // 0/1: the water and the falls live
    float lights;        // 0/1: the picture's lights
    float pixelArt;      // 1: whole-pixel moves
    float seed;
    float event;         // 0 none, 1 glint on the ring, 2 pebble, 3 gust, 4 eye, 5 rings
    float eventAge;      // seconds since it began
    float eventSeed;     // 0 … 1
    vec2 eventAt;        // the pebble's edge, the eye, the rings' centre: the picture's 0 … 1
    vec2 resolution;     // the item, px
    vec2 imgSize;        // the picture, px
    vec4 grid;           // xy one art pixel, zw the grid's offset (picture px)
    vec4 lid;            // the eye that blinks (event 6): centre xy, radii zw, the picture's 0 … 1
    vec4 fireworks;      // where a far firework may open (x0 y0 x1 y1, the picture's 0 … 1); 0: none
    vec4 fireworks2;     // a second such place (the first again when there is one only)
    vec4 smoke;          // xy where the smoke starts (0 … 1), z how high it rises (art px), w 1: on
    float snow;          // 0 none … 1 thick: flakes over every layer but nothing (0)
    float calm;          // 1: Motion.calm — gentler bulbs, no band crawling down the screens
};
layout(binding = 1) uniform sampler2D source;   // the picture as shown (cropped to the item)
layout(binding = 2) uniform sampler2D mask;     // in the picture's own uv

const float SKY = 1.0;
const float CLOUD = 2.0;
const float THING = 3.0;
const float WATER = 4.0;
const float FALL = 5.0;
const float LAND = 6.0;
const float OUT = 7.0;     // outdoors where nothing else lives: snow falls over it

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
vec2 hash2(vec2 p) {
    return vec2(hash(p), hash(p + vec2(17.3, 41.9)));
}
float lum(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float bell(float x) {
    return exp(-x * x);
}

// the item ⇄ the picture (PreserveAspectCrop)
vec2 spanOf() {
    float cover = max(resolution.x / imgSize.x, resolution.y / imgSize.y);
    return resolution / (imgSize * cover);
}
vec2 toImg(vec2 s) {
    return 0.5 + (s - 0.5) * spanOf();
}
vec2 toItem(vec2 iu) {
    return 0.5 + (iu - 0.5) / spanOf();
}
vec2 cellOf(vec2 iu) {
    return floor((iu * imgSize - grid.zw) / grid.xy);
}
vec2 cellUv(vec2 c) {
    return (grid.zw + (c + 0.5) * grid.xy) / imgSize;
}

// the layer at a place of the picture, with the hand's corrections (Settings: sky / water "yes"
// = above / below the waterline, "no" = none)
float layerAt(vec2 iu) {
    if (iu.x < 0.0 || iu.x > 1.0 || iu.y < 0.0 || iu.y > 1.0)
        return 0.0;
    float l = floor(texture(mask, iu).r * 255.0 / 32.0 + 0.5);
    if (waterMode > 1.5 && (l == WATER || l == FALL))
        l = 0.0;
    if (skyMode > 1.5 && l == SKY)
        l = 0.0;
    if (waterMode > 0.5 && waterMode < 1.5)
        l = iu.y >= axis ? WATER : (l == WATER || l == FALL ? 0.0 : l);
    if (skyMode > 0.5 && skyMode < 1.5 && iu.y < axis && l != THING)
        l = SKY;
    return l;
}
vec3 pictureAt(vec2 iu) {
    return texture(source, toItem(iu)).rgb;
}

// a new star now and then on the night sky's dark: one place in a block of art pixels, its
// own slow cycle (it comes over seconds, stays, goes)
vec3 newStars(vec2 iu) {
    float slot = max(5.0, floor(imgSize.x * 0.019 / grid.x + 0.5));
    vec2 c = cellOf(iu);
    vec2 s = floor(c / slot);
    vec2 h = hash2(s + seed);
    if (hash(s * 1.7 + seed + 3.1) > 0.2)
        return vec3(0.0);
    vec2 at = s * slot + 1.0 + floor(h * (slot - 2.0));
    vec2 d = abs(c - at);
    if (d.x + d.y > 0.5)
        return vec3(0.0);
    vec2 iuc = cellUv(at);
    if (layerAt(iuc) != SKY || lum(pictureAt(iuc)) > 0.4 || texture(mask, iuc).b > 0.0)
        return vec3(0.0);
    float per = 14.0 + 20.0 * hash(s + 5.0);
    float ph = fract(time / per + hash(s + 7.0));
    float vis = smoothstep(0.0, 0.3, ph) * (1.0 - smoothstep(0.55, 0.85, ph));
    vec3 tint = mix(vec3(0.82, 0.88, 1.0), vec3(1.0, 0.95, 0.85), hash(s + 9.0));
    return tint * vis * (0.3 + 0.35 * hash(s + 2.0));
}

// a falling star: one chance in 30 s, a short streak down and away, high in the sky
float fallingStar(vec2 iu) {
    vec2 q = grid.zw + (cellOf(iu) + 0.5) * grid.xy;
    float width = max(grid.x * 0.55, 0.9 * imgSize.x / resolution.x);
    float P = 30.0;
    float n = floor(time / P);
    vec2 r1 = hash2(vec2(n, seed));
    vec2 r2 = hash2(vec2(n + 0.37, seed + 4.0));
    vec2 r3 = hash2(vec2(n + 0.71, seed + 9.0));
    if (r1.x > 0.45)
        return 0.0;
    float dur = 1.3 + 0.5 * r1.y;
    float t0 = n * P + r2.x * (P - dur);
    float p = (time - t0) / dur;
    if (p < 0.0 || p > 1.0)
        return 0.0;
    vec2 start = vec2(0.1 + 0.8 * r2.y, 0.04 + 0.3 * r3.x);
    if (layerAt(start) != SKY)
        return 0.0;
    float ang = radians(16.0 + 24.0 * r3.y);
    vec2 dir = vec2((r1.y < 0.5 ? -1.0 : 1.0) * cos(ang), sin(ang));
    float travel = (0.1 + 0.1 * fract(r1.x * 7.3)) * imgSize.x;
    vec2 head = start * imgSize + dir * travel * p;
    float env = smoothstep(0.0, 0.15, p) * (1.0 - smoothstep(0.6, 1.0, p));
    float tailLen = 0.05 * imgSize.x * (0.4 + 0.6 * env);
    vec2 v = head - q;
    float t = dot(v, dir);
    float side = abs(v.x * dir.y - v.y * dir.x);
    if (t < -width || t > tailLen || side > width)
        return 0.0;
    float a = pow(1.0 - clamp(t / tailLen, 0.0, 1.0), 1.6);
    return (t < grid.x * 1.5 ? 1.0 : a) * env * 0.8;
}

// a layer's own picture sliding along `dir` by up to `span` art pixels each `period` seconds:
// two copies half a period apart, each weighed most when whole; a place whose source is not
// of the layer (`keep`: what may move into it) keeps its own pixel
vec3 slide(vec2 c, vec2 dir, float span, float period, float phase, float lay) {
    vec3 own = pictureAt(cellUv(c));
    vec3 acc = vec3(0.0);
    for (int k = 0; k < 2; k++) {
        float f = fract(time / period + phase + 0.5 * float(k));
        vec2 src = c - floor(dir * f * span + 0.5);
        vec2 su = cellUv(src);
        float sl = layerAt(su);
        bool ok = sl == lay;
        acc += (ok ? pictureAt(su) : own) * (1.0 - abs(2.0 * f - 1.0));
    }
    return acc;
}

// an eye in a cloud: 0 outside, 1 the white, 2 the iris, 3 the pupil, 4 the lid's line
float eyeAt(vec2 d, float open, float look) {
    float hw = 6.5;
    if (abs(d.x) > hw + 0.5)
        return 0.0;
    float hh = 3.3 * sqrt(max(0.0, 1.0 - (d.x / hw) * (d.x / hw))) * open;
    if (abs(d.y) > hh + 0.9)
        return 0.0;
    if (abs(d.y) > hh - 0.1)
        return open > 0.15 ? 4.0 : 0.0;
    vec2 i = d - vec2(look, 0.0);
    float r = length(i);
    return r < 1.45 ? 3.0 : r < 2.7 ? 2.0 : 1.0;
}

// the pebble: where it is after `age` seconds (art pixels), falling from the edge
vec2 pebbleAt(vec2 start, float age, float k) {
    float g = 26.0 + 10.0 * k;                     // art pixels a second²
    float drift = (eventSeed - 0.5) * 3.0;
    return start + vec2(floor(drift * age + 0.5), floor(0.5 * g * age * age + 0.5));
}

// snow: three sheets of flakes, far to near, one art pixel each, falling (and drifting with the
// wind) a whole art pixel at a time; one flake to a block of a sheet, like newStars
float snowAt(vec2 c) {
    float a = 0.0;
    for (int k = 0; k < 3; k++) {
        float fk = float(k);
        float slot = 13.0 - 3.0 * fk;                // a flake in 13, 10, 7 art pixels square
        float speed = 2.0 + 1.5 * fk;                // art pixels a second: the near fall faster
        vec2 q = c - floor(vec2(0.3 * speed * time, speed * time) + 0.5);
        vec2 s = floor(q / slot);
        if (hash(s * 1.3 + fk * 7.7 + seed) > snow)
            continue;
        vec2 h = hash2(s + fk * 19.7 + seed);
        // it sways an art pixel to each side over seconds (it stays in its block: 1 … slot-2, ±1)
        float sway = floor(1.2 * sin(time * (0.5 + 0.4 * h.y) + h.x * 6.283) + 0.5);
        vec2 at = s * slot + 1.0 + floor(h * (slot - 2.0)) + vec2(sway, 0.0);
        if (all(equal(q, at)))
            a = max(a, 0.55 + 0.2 * fk);
    }
    return a;
}

// a firework far away, in `area`: one clock of `P` seconds; in a slot, one chance in 2.5, a small
// ring of dots (10…14 of them, 5…9 art pixels out) opens on the dark of the sky, droops, goes out
// dot by dot. It comes up over a quarter of a second (no flash), and the whole of it is a few dots
vec3 firework(vec2 c, float P, float salt, vec4 area) {
    float n = floor(time / P);
    vec2 r1 = hash2(vec2(n, seed + salt));
    if (r1.x > 0.4)
        return vec3(0.0);
    float dur = 2.2;
    float a = (time - n * P - r1.y * (P - dur)) / dur;
    if (a < 0.0 || a > 1.0)
        return vec3(0.0);
    vec2 r2 = hash2(vec2(n + 0.37, seed + salt + 4.0));
    vec2 o = cellOf(mix(area.xy, area.zw, r2));
    float R = 5.0 + 4.0 * fract(r1.x * 13.7);
    vec2 d = c - o - vec2(0.0, floor(3.0 * a * a + 0.5));    // the dots droop
    if (any(greaterThan(abs(d), vec2(R + 1.0))) || (d.x == 0.0 && d.y == 0.0))
        return vec3(0.0);
    vec2 ou = cellUv(o);
    if (layerAt(ou) != SKY || lum(pictureAt(ou)) > 0.3 || texture(mask, ou).b > 0.0)
        return vec3(0.0);
    float rad = R * (1.0 - (1.0 - a) * (1.0 - a));            // fast out, slowing
    float N = 10.0 + 2.0 * floor(r2.x * 2.99);
    float rot = r2.y * 6.283;
    float k = floor((atan(d.y, d.x) - rot) / 6.283 * N + 0.5);
    float th = rot + k * 6.283 / N;
    vec2 dir = vec2(cos(th), sin(th));
    float hit = all(equal(d, floor(dir * rad + 0.5))) ? 1.0 : all(equal(d, floor(dir * rad * 0.55 + 0.5))) ? 0.45 : 0.0;
    if (a > 0.6 && hash(vec2(k, n + salt)) < (a - 0.6) * 2.5)
        hit = 0.0;
    float env = smoothstep(0.0, 0.12, a) * (1.0 - smoothstep(0.45, 1.0, a));
    // the release's colours: pink, soft gold, turquoise, coral (no const arrays: GL 1.20)
    float p = fract(r1.x * 7.1 + r2.y * 3.3);
    vec3 tint = p < 0.25 ? vec3(1.0, 0.5, 0.69) : p < 0.5 ? vec3(1.0, 0.91, 0.66) : p < 0.75 ? vec3(0.37, 0.78, 0.75) : vec3(1.0, 0.35, 0.43);
    return tint * hit * env;
}

// a thread of smoke from `smoke.xy`: one art pixel wide (two near the top), swaying more the
// higher it gets, broken into wisps that drift up; fainter as it rises. 0 … 1
float smokeAt(vec2 c) {
    vec2 s = cellOf(smoke.xy);
    float up = s.y - c.y;
    if (up < 0.0 || up >= smoke.z || abs(c.x - s.x) > 8.0)
        return 0.0;
    float h = up / smoke.z;
    float sway = (0.4 + 3.5 * h * h) * sin(up * 0.22 - time * 1.1) + 2.0 * h * (noise(vec2(up * 0.08 - time * 0.25, seed)) - 0.5);
    float dx = c.x - (s.x + floor(sway + 0.5));
    if (!(dx == 0.0 || (h > 0.6 && dx == 1.0)))
        return 0.0;
    float wisp = floor(smoothstep(0.3, 0.65, noise(vec2(c.x * 0.3, (up - time * 4.0) * 0.18) + seed)) * 3.0) / 3.0;
    return (1.0 - h) * (0.35 + 0.65 * wisp);
}

void main() {
    vec2 iu = toImg(qt_TexCoord0);
    vec2 c = cellOf(iu);
    vec2 cu = cellUv(c);
    float lay = layerAt(cu);
    vec4 m = texture(mask, cu);
    // what a hint marked here (R's low bits: 0 in older masks): 1…3 a bulb, 4…6 a screen
    float r8 = floor(m.r * 255.0 + 0.5);
    float code = r8 - 32.0 * floor(r8 / 32.0 + 0.5);
    vec2 at = iu;
    float gate = smoothstep(0.3, 0.7, night);

    // a gust: a patch of ripples crosses the water, rows moving a pixel to and fro
    if (event > 2.5 && event < 3.5 && lay == WATER && water > 0.5) {
        float p = eventAge / 6.0;
        float front = mix(-0.25, 1.25, p);
        float x = eventSeed < 0.5 ? iu.x : 1.0 - iu.x;
        float k = bell((x - front) / 0.12) * smoothstep(0.0, 0.1, p) * (1.0 - smoothstep(0.85, 1.0, p));
        float wave = sin(c.y * 1.3 + eventAge * 2.2);
        float sh = floor(wave * k * (0.6 + 0.8 * m.g) * strength * 1.6 + 0.5);
        vec2 moved = iu + vec2(sh * grid.x / imgSize.x, 0.0);
        if (layerAt(cellUv(cellOf(moved))) == WATER)
            at = moved;
    }
    vec4 col = texture(source, toItem(at));

    // the layers' own pictures in motion: the falls pour, the sea sways, the clouds drift
    bool gust = event > 2.5 && event < 3.5;
    if (water > 0.5 && lay == FALL)
        col.rgb = slide(c, vec2(0.0, 1.0), 12.0, 1.6, hash(vec2(floor(c.x / 2.0), 4.2)), FALL);
    else if (water > 0.5 && lay == WATER && !gust)
        col.rgb = slide(c, vec2(1.0, 0.0), 2.0 + 3.0 * m.g, 7.0, hash(vec2(4.1, floor(c.y / 2.0))), WATER);

    float l = lum(col.rgb);

    // mist curls up out of the abyss, low in the falls
    if (water > 0.5 && lay == FALL && m.g > 0.35) {
        float n = noise(c * vec2(0.09, 0.14) + vec2(time * 0.06, time * 0.16) + seed);
        float fog = floor(smoothstep(0.45, 0.85, n) * 4.0) / 4.0;
        vec3 mist = mix(vec3(0.75, 0.85, 0.95), vec3(0.35, 0.45, 0.6), night);
        col.rgb = mix(col.rgb, mist, fog * 0.22 * strength * smoothstep(0.35, 0.9, m.g));
    }

    // the shadows of clouds drift over what is under the sky, in three steps of shade
    if (lay >= WATER && lay < OUT) {
        float n = noise(c * vec2(0.022, 0.06) + vec2(time * 0.035, time * 0.006) + seed);
        float shade = floor(smoothstep(0.5, 0.85, n) * 3.0) / 3.0;
        col.rgb *= 1.0 - shade * strength * mix(0.2, 0.1, night);
    }
    // glints on the water swell and fade over seconds
    if (lay == WATER && water > 0.5 && m.b > 0.0) {
        vec2 b = floor(c / 3.0);
        float pulse = 0.5 + 0.5 * sin(time * (0.9 + 0.7 * hash(b)) + hash(b + 3.0) * 6.283);
        col.rgb *= 1.0 + m.b * strength * (0.5 * pulse - 0.18);
    }
    // the sky's own lights (stars, windows) glimmer, slowly
    // (a bulb in the sky has its own rhythm, below)
    if (lay == SKY && lights > 0.5 && m.b > 0.0 && code < 0.5) {
        vec2 b = floor(c / 4.0);
        float f = sin(time * (0.3 + 0.5 * hash(b + 1.0)) + hash(b) * 6.283);
        col.rgb *= 1.0 + m.b * strength * (0.3 * f - 0.08);
    }

    // a glint runs over the ring: a soft light along a good part of it, there and gone in five
    // seconds
    if (event > 0.5 && event < 1.5 && lay == THING) {
        float p = eventAge / 5.0;
        float pos = fract(eventSeed + p * 0.6);
        float d = abs(m.g - pos);
        d = min(d, 1.0 - d);
        float k = bell(d / 0.09) * sin(3.14159 * clamp(p, 0.0, 1.0));
        // light on stone: added, so the dark side of a night ring catches it too
        vec3 light = mix(vec3(1.0, 0.93, 0.8), vec3(0.8, 0.88, 1.0), night);
        col.rgb += strength * k * (0.35 + 0.6 * l) * light;
    }

    vec3 add = vec3(0.0);
    if (gate > 0.0 && lay == SKY) {
        if (stars > 0.5)
            add += newStars(iu);
        if (meteors > 0.5)
            add += vec3(0.92, 0.95, 1.0) * fallingStar(iu) * (1.0 - smoothstep(0.38, 0.55, l));
    }
    col.rgb += add * strength * gate;

    // a pebble breaks off the edge: a crumb of the rock there, falling, gone in three seconds
    if (event > 1.5 && event < 2.5) {
        vec2 start = cellOf(eventAt);
        vec3 rock = pictureAt(cellUv(start)) * 1.15 + 0.03;
        float fade = 1.0 - smoothstep(2.0, 3.0, eventAge);
        for (int i = 0; i < 2; i++) {
            float age = eventAge - 0.3 * float(i);
            if (age <= 0.0)
                continue;
            vec2 pc = pebbleAt(start + vec2(float(i), 0.0), age, float(i));
            if (all(equal(c, pc)))
                col.rgb = mix(col.rgb, rock * (1.0 - 0.25 * float(i)), strength * fade);
        }
        // a puff of grit where it broke
        if (eventAge < 0.6 && abs(c.x - start.x) <= 1.0 && c.y >= start.y && c.y <= start.y + 1.0 && hash(c + floor(eventAge * 6.0)) > 0.6)
            col.rgb = mix(col.rgb, rock, strength * 0.6 * (1.0 - eventAge / 0.6));
    }
    // an eye opens in a cloud: wakes over a second, glances, blinks once, closes
    if (event > 3.5 && event < 4.5 && lay == CLOUD) {
        float a = eventAge;
        float open = smoothstep(0.3, 1.2, a) * (1.0 - smoothstep(4.8, 5.8, a));
        open *= 1.0 - (1.0 - smoothstep(0.0, 0.12, abs(a - 3.2))) ;
        float look = floor(2.0 * sin(a * 0.9 + eventSeed * 6.283) + 0.5);
        float e = eyeAt(c - cellOf(eventAt), open, look);
        if (e > 0.5) {
            vec3 iris = mix(vec3(1.0, 0.78, 0.35), vec3(1.0, 0.55, 0.25), night);
            // of the cloud's own light: the white is the cloud lit, the lid its shade
            vec3 eye = e < 1.5 ? mix(col.rgb, vec3(0.95, 0.9, 0.84), 0.3) : e < 2.5 ? mix(col.rgb, iris, 0.75) : e < 3.5 ? col.rgb * 0.25 : col.rgb * 0.7;
            col.rgb = mix(col.rgb, eye, strength * 0.85);
        }
    }
    // rings on open water (something touched it from out of the frame): flat circles seen from
    // the shore, 16 art pixels across at most — the place was chosen with that much water
    // round it, and any cell that is not open water stays as it is
    if (event > 4.5 && event < 5.5 && lay == WATER && water > 0.5) {
        vec2 d = c - cellOf(eventAt);
        float r = length(vec2(d.x, d.y / 0.3));
        float fade = smoothstep(0.0, 0.4, eventAge) * (1.0 - smoothstep(3.0, 4.5, eventAge));
        vec3 light = mix(vec3(1.0, 0.95, 0.85), vec3(0.75, 0.85, 1.0), night);
        for (int k = 0; k < 3; k++) {
            float rk = (eventAge - 0.7 * float(k)) * 5.0;
            if (rk > 0.0 && rk < 16.0 && abs(r - rk) < 0.75)
                col.rgb += strength * fade * (1.0 - 0.6 * rk / 16.0) * (0.42 - 0.1 * float(k)) * light * (0.6 + 0.8 * l);
        }
    }
    // a garland: three groups of bulbs take turns, each swelling and dimming over 4.5 s (an old
    // chaser, smooth, never on/off)
    if (code > 0.5 && code < 3.5)
        col.rgb *= 1.0 + strength * (calm > 0.5 ? 0.18 : 0.35) * sin(time * 1.396 - code * 2.094);
    // a CRT's glass breathes a few per cent, slowly; a dim band two pixels high crawls down it
    if (code > 3.5 && code < 6.5) {
        float k = code - 4.0;
        float breath = 0.03 * sin(time * (0.9 + 0.3 * k) + k * 2.1) + 0.02 * (2.0 * noise(vec2(time * 0.5, k * 7.0)) - 1.0);
        float band = calm > 0.5 ? 0.0 : (mod(c.y - floor(time * 3.0) + k * 13.0, 46.0) < 2.0 ? 0.06 : 0.0);
        col.rgb *= 1.0 + strength * (breath - band);
    }
    // the smoke of a cigarette, a cup, a chimney
    if (smoke.w > 0.5) {
        float a = smokeAt(c);
        if (a > 0.0)
            col.rgb = mix(col.rgb, mix(vec3(0.78, 0.76, 0.88), vec3(0.55, 0.52, 0.68), night), strength * 0.5 * a);
    }
    // far fireworks: two clocks, so never more than two at once, on the dark of a night sky only
    if (fireworks.z > fireworks.x && gate > 0.0 && lay == SKY) {
        vec4 area2 = fireworks2.z > fireworks2.x ? fireworks2 : fireworks;
        vec3 fw = firework(c, 9.0, 0.0, fireworks) + firework(c, 14.0, 31.0, area2);
        col.rgb += fw * 0.45 * strength * gate * (1.0 - smoothstep(0.3, 0.45, l));
    }
    // the eye blinks (event 6): the upper lid comes down over 0.4 s, the lower one up a little,
    // and they part over half a second; the lid is the colour just over the eye, its edge darker
    if (event > 5.5 && event < 6.5) {
        vec2 e = cellOf(lid.xy);
        vec2 r = max(vec2(2.0), floor(lid.zw * imgSize / grid.xy + 0.5));
        vec2 d = c - e;
        float qx = d.x / r.x;
        float span = r.y * sqrt(max(0.0, 1.0 - qx * qx));
        float shut = smoothstep(0.0, 0.4, eventAge) * (1.0 - smoothstep(0.55, 1.05, eventAge));
        if (abs(qx) <= 1.0 && abs(d.y) <= span && shut > 0.02) {
            float yu = floor(-span + 1.3 * span * shut + 0.5);
            float yl = floor(span - 0.75 * span * shut + 0.5);
            if (d.y < yu || d.y > yl) {
                // one colour for the whole lid (taken per column it came out striped)
                vec3 skin = pictureAt(cellUv(e - vec2(0.0, r.y + 1.0)));
                vec3 lidc = (d.y == yu - 1.0 || d.y == yl + 1.0) ? skin * 0.55 : skin * 0.9;
                col.rgb = mix(col.rgb, lidc, clamp(strength * 2.0, 0.0, 1.0));
            }
        }
    }
    // snow last, in front of everything but nothing (a room's walls are 0: none there; its
    // window, painted sky or outdoors, shows it)
    if (snow > 0.0 && lay > 0.5) {
        float a = snowAt(c);
        if (a > 0.0)
            col.rgb = mix(col.rgb, mix(vec3(0.91, 0.89, 0.94), vec3(0.72, 0.69, 0.82), 0.6 * night), a * strength);
    }
    fragColor = vec4(clamp(col.rgb, 0.0, 1.0), 1.0) * qt_Opacity;
}
