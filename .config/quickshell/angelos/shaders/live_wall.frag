#version 440
// Half-alive wallpaper (widgets/LiveWall): the picture as it is, and a scene in it that lives
// quietly, from the mask scripts/live-wall.py made of it — r the layer of every art pixel
// (×32: 1 sky, 2 cloud, 3 a ring or another thing in the sky, 4 still water, 5 falling water,
// 6 land), g a place within it (the water's depth, a fall's way down, the place round a ring),
// b the picture's own bright points (lights in the sky, glints on the water). Everything sits
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
};
layout(binding = 1) uniform sampler2D source;   // the picture as shown (cropped to the item)
layout(binding = 2) uniform sampler2D mask;     // in the picture's own uv

const float SKY = 1.0;
const float CLOUD = 2.0;
const float THING = 3.0;
const float WATER = 4.0;
const float FALL = 5.0;
const float LAND = 6.0;

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

void main() {
    vec2 iu = toImg(qt_TexCoord0);
    vec2 c = cellOf(iu);
    vec2 cu = cellUv(c);
    float lay = layerAt(cu);
    vec4 m = texture(mask, cu);
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
    if (lay >= WATER) {
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
    if (lay == SKY && lights > 0.5 && m.b > 0.0) {
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
    fragColor = vec4(clamp(col.rgb, 0.0, 1.0), 1.0) * qt_Opacity;
}
