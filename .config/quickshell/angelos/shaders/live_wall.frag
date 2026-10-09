#version 440
// Half-alive wallpaper (widgets/LiveWall): the picture as it is, and what in it may
// move a little, from the mask scripts/live-wall.py made of it (r sky, g water: 1 still, ½ falling,
// b the picture's own bright points: lights off the water, glints on it). Everything sits on the art's pixel grid (`grid`: one art
// pixel and its offset, in the picture's pixels) and is scaled by `strength` (0 = the picture).
//   - the picture's stars and lit windows twinkle; now and then one blinks
//   - a few new stars come and go in the night sky, only on its dark parts
//   - a star falls every so often, behind anything bright, gone where the sky ends
//   - the water ripples in whole art pixels (more towards the bottom), its glints shimmer,
//     and with a mirror (the water shows the scene upside down) it shows the new stars and the
//     falling ones too, a little dimmer, wavering with the ripples
//   - by day the shadows of clouds drift over it, in a few steps of shade
//   - a fall streams down: light streaks run down each column of art pixels, a pixel at a time,
//     and where it pours over an edge the foam flickers
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;          // seconds
    float strength;      // 0 … 1
    float night;         // 0 day … 1 night: the new stars and the falling ones
    float axis;          // the waterline, 0 top … 1 bottom of the picture
    float mirror;        // 1: the water mirrors the sky
    float skyMode;       // 0 the mask, 1 above the waterline, 2 none
    float waterMode;     // 0 the mask, 1 below the waterline, 2 none
    float stars;         // 0/1: new stars
    float meteors;       // 0/1: falling stars
    float water;         // 0/1: ripples and glints
    float lights;        // 0/1: the picture's lights twinkle
    float pixelArt;      // 1: whole-pixel ripples
    float seed;
    vec2 resolution;     // the item, px
    vec2 imgSize;        // the picture, px
    vec4 grid;           // xy one art pixel, zw the grid's offset (picture px)
};
layout(binding = 1) uniform sampler2D source;   // the picture as shown (cropped to the item)
layout(binding = 2) uniform sampler2D mask;     // in the picture's own uv

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
vec2 hash2(vec2 p) {
    return vec2(hash(p), hash(p + vec2(17.3, 41.9)));
}
float lum(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
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

float waterAt(vec2 iu) {
    if (waterMode > 1.5 || iu.y < 0.0 || iu.y > 1.0)
        return 0.0;
    if (waterMode > 0.5)
        return step(axis, iu.y);
    return texture(mask, iu).g;
}
// still water (a lake, a sea) is 1 in the mask, falling water ½
float stillAt(vec2 iu) {
    return step(0.75, waterAt(iu));
}
float fallAt(vec2 iu) {
    if (waterMode > 0.5 || iu.y < 0.0 || iu.y > 1.0)
        return 0.0;
    float g = texture(mask, iu).g;
    return step(0.25, g) * step(g, 0.75);
}
float skyAt(vec2 iu) {
    if (skyMode > 1.5 || iu.y < 0.0 || iu.y > 1.0 || iu.x < 0.0 || iu.x > 1.0)
        return 0.0;
    if (skyMode > 0.5)
        return step(iu.y, axis) * (1.0 - waterAt(iu));
    return texture(mask, iu).r;
}
vec3 pictureAt(vec2 iu) {
    return texture(source, toItem(iu)).rgb;
}

// a new star now and then: one place in a block of art pixels, its own slow cycle
vec3 newStars(vec2 iu) {
    float slot = max(5.0, floor(imgSize.x * 0.019 / grid.x + 0.5));
    vec2 c = cellOf(iu);
    vec2 s = floor(c / slot);
    vec2 h = hash2(s + seed);
    if (hash(s * 1.7 + seed + 3.1) > 0.22)
        return vec3(0.0);
    vec2 at = s * slot + 1.0 + floor(h * (slot - 2.0));
    vec2 d = abs(c - at);
    float big = step(0.9, hash(s + 11.3));
    float shape = d.x + d.y < 0.5 ? 1.0 : (big > 0.5 && d.x + d.y < 1.5 ? 0.4 : 0.0);
    if (shape == 0.0)
        return vec3(0.0);
    vec2 iuc = cellUv(at);
    if (skyAt(iuc) < 0.5 || lum(pictureAt(iuc)) > 0.4 || texture(mask, iuc).b > 0.0)
        return vec3(0.0);
    float per = 7.0 + 13.0 * hash(s + 5.0);
    float ph = fract(time / per + hash(s + 7.0));
    float vis = smoothstep(0.0, 0.25, ph) * (1.0 - smoothstep(0.5, 0.8, ph));
    float tw = 0.8 + 0.2 * sin(time * (2.0 + 3.0 * h.x) + h.y * 6.283);
    vec3 tint = mix(vec3(0.82, 0.88, 1.0), vec3(1.0, 0.95, 0.85), hash(s + 9.0));
    return tint * shape * vis * tw * (0.35 + 0.4 * hash(s + 2.0));
}

// a smooth noise of art-pixel cells, 0 … 1
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// a fall: in every column of art pixels light streaks of their own length run down, a whole
// pixel at a time, at the column's own speed; the head of a streak is the brightest
float fallStreak(vec2 c) {
    float hx = hash(vec2(c.x, 3.7) + seed);
    float speed = 7.0 + 7.0 * hx;                       // art pixels a second
    float len = 2.0 + floor(5.0 * hash(vec2(c.x, 9.1)));
    float per = len + 3.0 + floor(10.0 * hash(vec2(c.x, 1.3)));
    float ph = mod(c.y - floor(time * speed) + floor(hash(vec2(c.x, 5.5)) * per), per);
    if (ph >= len)
        return 0.0;
    return ph > len - 1.5 ? 1.0 : 0.55 * (1.0 - ph / len) + 0.25;
}

// a falling star: one chance every 11 s, a short streak down and away, in the upper sky
float fallingStars(vec2 iu) {
    vec2 q = (grid.zw + (cellOf(iu) + 0.5) * grid.xy);          // this art pixel, picture px
    float width = max(grid.x * 0.55, 0.9 * imgSize.x / resolution.x);
    float P = 11.0;
    float lit = 0.0;
    for (int k = 0; k < 2; k++) {
        float n = floor(time / P) - float(k);
        vec2 r1 = hash2(vec2(n, seed));
        vec2 r2 = hash2(vec2(n + 0.37, seed + 4.0));
        vec2 r3 = hash2(vec2(n + 0.71, seed + 9.0));
        if (r1.x > 0.55)
            continue;
        float dur = 1.1 + 0.6 * r1.y;
        float t0 = n * P + r2.x * (P - dur);
        float p = (time - t0) / dur;
        if (p < 0.0 || p > 1.0)
            continue;
        vec2 start = vec2(0.1 + 0.8 * r2.y, 0.04 + 0.32 * r3.x);
        if (skyAt(start) < 0.5)
            continue;
        float ang = radians(16.0 + 24.0 * r3.y);
        vec2 dir = vec2((r1.y < 0.5 ? -1.0 : 1.0) * cos(ang), sin(ang));
        float travel = (0.12 + 0.12 * fract(r1.x * 7.3)) * imgSize.x;
        vec2 head = start * imgSize + dir * travel * p;
        float env = smoothstep(0.0, 0.12, p) * (1.0 - smoothstep(0.65, 1.0, p));
        float tailLen = 0.055 * imgSize.x * (0.4 + 0.6 * env);
        vec2 v = head - q;
        float t = dot(v, dir);
        float side = abs(v.x * dir.y - v.y * dir.x);
        if (t < -width || t > tailLen || side > width)
            continue;
        float a = pow(1.0 - clamp(t / tailLen, 0.0, 1.0), 1.6);
        if (t < grid.x * 1.5)
            a = 1.0;
        lit = max(lit, a * env);
    }
    return lit;
}

void main() {
    vec2 iu = toImg(qt_TexCoord0);
    vec2 c = cellOf(iu);
    vec2 at = iu;                      // where the picture is read (moved by the ripples)
    float gate = smoothstep(0.3, 0.7, night);
    float wet = water > 0.5 ? stillAt(iu) : 0.0;
    float falling = water > 0.5 && wet < 0.5 ? fallAt(cellUv(c)) : 0.0;
    // how far into the water: a lake to the bottom of the picture, a sea under a horizon (that
    // ends at a shore or a fall) over its first quarter of the picture
    float depth = clamp((iu.y - axis) / max(1e-3, mirror > 0.5 ? 1.0 - axis : min(1.0 - axis, 0.25)), 0.0, 1.0);

    if (wet > 0.5) {
        float wave = sin(c.y * 0.7 - time * 1.6 + sin(c.y * 0.13 + time * 0.4) * 2.0);
        float amp = (0.3 + 1.4 * depth) * strength;
        float sh = pixelArt > 0.5 ? floor(wave * amp + 0.5) : wave * amp;
        vec2 moved = iu + vec2(sh * grid.x / imgSize.x, 0.0);
        if (stillAt(moved) > 0.5)
            at = moved;
    }
    vec4 col = texture(source, toItem(at));
    vec4 m = texture(mask, at);

    // the water's glints: shimmer, and now and then go out
    if (wet > 0.5 && m.b > 0.0) {
        vec2 b = floor(cellOf(at) / 3.0);
        float pulse = 0.5 + 0.5 * sin(time * (1.8 + 1.4 * hash(b)) + hash(b + 3.0) * 6.283);
        float off = step(0.93, hash(b + floor(time * 0.7 + hash(b + 5.0))));
        col.rgb *= 1.0 + m.b * strength * (0.55 * pulse - 0.3 - 0.45 * off);
    }
    // by day the shadows of clouds drift over still water, in three steps of shade
    if (wet > 0.5 && night < 0.5) {
        vec2 cc = cellOf(at);
        float n = noise(cc * vec2(0.035, 0.07) + vec2(time * 0.18, time * 0.03) + seed);
        float shade = floor(smoothstep(0.45, 0.8, n) * 3.0) / 3.0;
        col.rgb *= 1.0 - shade * 0.14 * strength * (1.0 - night * 2.0);
    }
    // a fall streams down; the streaks light what is lit (the abyss stays dark), and where the
    // water pours over an edge the foam flickers
    if (falling > 0.5) {
        float l = lum(col.rgb);
        float s = fallStreak(c);
        col.rgb *= 1.0 + strength * (0.55 * s - 0.08) * smoothstep(0.03, 0.25, l);
        col.rgb += strength * vec3(0.55, 0.75, 0.9) * s * 0.10 * smoothstep(0.08, 0.4, l);
        float top = 0.0;
        for (int k = 1; k <= 3; k++)
            top = max(top, (1.0 - fallAt(cellUv(c - vec2(0.0, float(k))))) * (1.0 - 0.3 * float(k - 1)));
        if (top > 0.0) {
            float fl = step(0.55, hash(c + floor(time * 9.0 + hash(c) * 3.0)));
            col.rgb = mix(col.rgb, vec3(0.9, 0.96, 1.0), strength * top * fl * 0.55);
        }
    }
    // the picture's own lights twinkle; once in a while one blinks
    if (lights > 0.5 && wet < 0.5 && falling < 0.5 && m.b > 0.0) {
        vec2 b = floor(c / 4.0);
        float f = sin(time * (0.7 + 1.6 * hash(b + 1.0)) + hash(b) * 6.283);
        float blink = step(0.975, hash(b + floor(time * 0.5 + hash(b + 2.0))));
        col.rgb *= 1.0 + m.b * strength * (0.22 * f - 0.12 - 0.55 * blink);
    }

    vec3 add = vec3(0.0);
    if (gate > 0.0) {
        float sky = skyAt(iu);
        if (sky > 0.5) {
            if (stars > 0.5)
                add += newStars(iu);
            // a falling star passes behind what is bright (a halo, a moon, a feather)
            if (meteors > 0.5)
                add += vec3(0.92, 0.95, 1.0) * fallingStars(iu) * (1.0 - smoothstep(0.38, 0.55, lum(col.rgb)));
        } else if (wet > 0.5 && mirror > 0.5) {
            // the same sky, upside down in the water, wavering with it
            vec2 mi = vec2(at.x, 2.0 * axis - iu.y);
            vec3 r = vec3(0.0);
            if (stars > 0.5)
                r += newStars(mi);
            if (meteors > 0.5)
                r += vec3(0.92, 0.95, 1.0) * fallingStars(mi);
            add += r * 0.45 * (1.0 - 0.5 * depth) * (1.0 - smoothstep(0.38, 0.55, lum(col.rgb)));
        }
    }
    col.rgb += add * strength * gate;
    fragColor = vec4(clamp(col.rgb, 0.0, 1.0), 1.0) * qt_Opacity;
}
