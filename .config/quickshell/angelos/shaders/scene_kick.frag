#version 440
// The music's kick over a whole layered scene (WallpaperView: SceneWall's layer, while it hears
// the bass) and over the desktop widgets (Background: the same wave): a ring out of the CRT's
// screen bends everything as it passes — the layers, the text in the scene, the meteor's shards,
// leaves, stars, the widgets — and the picture breathes toward you for a moment. The song's first
// kicks (`hype`, services/Bass) ring harder: a second ring behind the first, and the air of the
// front lights up and splits red from blue. The last four kicks ring at once, each to its end
// (SceneWall.kickNow): a new one doesn't cut the one before short. The night's meteor sends one
// wave of its own through it, out of the fire's foot: wider, harder, across the whole scene in a
// second and a half (`blast`). The snare splits red from blue at the screen's edges for a moment,
// the middle stays clean, and the space bends after it as through a lens (`edge`); the bass keeps a
// smaller lens and split breathing all the while (`breath`). Nearest texels: the screen's pixels move, none is blended.
// The wallpaper editor's modifiers (widgets/SceneWall): each ring has its own centre and speed, and up
// to four zones (a speaker's cone) swell from their middle on a hit, their edges staying put; `hold`
// is what its brush pinned (alpha 1: nothing moves).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;        // the wall, px
    vec4 kickX;       // each of the last four kicks: where it rings out from, px
    vec4 kickY;
    vec4 kickRate;    // and how fast: 1 = 520 art px a second, for 1.2 s
    float k;          // px per art px
    float kick;       // 0 = no waves (the bass is off)
    vec4 kickAt;      // the last four kicks: `time` of each
    vec4 kickGain;    // 0..1: how hard each hit
    float time;
    vec4 hype;        // 0..1 each: the song's first kicks 1, after a quiet while a little, else 0
    float blast;      // s since the meteor's blast, < 0 none (SceneWall.shockAge)
    vec2 blastFrom;   // where it comes from, px
    float blastSpeed; // art px a second
    float edge;       // 0..1: how hard the last snare hit; 0 = no split at the edges
    float edgeAt;     // `time` of it
    float breath;     // 0..1: the bass now: the lens and the split at the edges follow it
    float zones;      // 0 = none
    vec4 zoneA;       // centre, radii, px
    vec4 zoneB;
    vec4 zoneC;
    vec4 zoneD;
    vec4 zoneAt;      // `time` of each zone's last hit
    vec4 zoneGain;    // how far it swells, 0..1
    vec4 zoneRelease; // how soon it settles, s
    float holdOn;     // 1: `hold` is there
    vec4 holdRect;    // the canvas on it, px: x, y, w, h
};
layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D hold;

// an 8×8 Bayer matrix as a formula (as shaders/scene_layer.frag), 0..63/64
float bayer2(vec2 a) {
    a = floor(a);
    return fract(a.x / 2.0 + a.y * a.y * 0.75);
}
float bayer8(vec2 a) {
    return bayer2(0.25 * a) * 0.0625 + bayer2(0.5 * a) * 0.25 + bayer2(a);
}

// as shaders/scene_layer.frag: d = from → here, art px; the shift back, art px
vec2 kickWave(vec2 d, float age) {
    float r = max(length(d), 1.0);
    float x = (r - age * 520.0) / 16.0;
    float push = 2.2 * x * exp(-x * x) * (1.0 - age / 1.2);
    return d / r * push + d * 0.006 * exp(-age * 9.0);
}

vec4 at(vec2 p) {
    return texture(source, (floor(p) + 0.5) / size);
}

// the snare's split at this point of the screen, whole art px: steps down to 0 in 0.18 s; the bass
// keeps a smaller one going under it
float edgeSplit(vec2 n) {
    float age = time - edgeAt;
    float amount = breath * 2.0;
    if (edge > 0.0 && age >= 0.0 && age < 0.18)
        amount += edge * (1.0 - age / 0.18) * 3.0;
    if (amount <= 0.0)
        return 0.0;
    n *= n;
    n *= n;
    // a rounded rectangle: every edge of the screen alike, not just the corners
    float r = sqrt(sqrt(n.x + n.y));
    return floor(smoothstep(0.55, 1.0, r) * amount + 0.5);
}

// the lens: the picture swells outward with the bass and a little more on a snare (settling in
// 0.3 s), most at the edges and corners, nothing in the middle. It samples inward, so no hole
// opens at the screen's edge.
vec2 edgeLens(vec2 n) {
    float age = time - edgeAt;
    float a = breath * 0.006;
    if (edge > 0.0 && age >= 0.0 && age < 0.3) {
        float fade = 1.0 - age / 0.3;
        a += edge * fade * fade * 0.008;
    }
    return n * dot(n, n) * size * 0.5 * a;
}

// one kick's wave at d, art px: adds its shift back and the light of its front (lit: its d)
void one(vec2 d, float age, float g, float h, inout vec2 shift, inout float band, inout vec2 lit) {
    if (age < 0.0 || age >= 1.2 || g <= 0.0)
        return;
    shift += kickWave(d, age) * g * (0.6 + h);
    if (h <= 0.0)
        return;
    if (age > 0.12)
        shift += kickWave(d, age - 0.12) * g * h * 0.6;
    float x = (max(length(d), 1.0) - age * 520.0) / 24.0;
    band += exp(-x * x) * h * g * (1.0 - age / 1.2);
    lit = d;
}

// how far a zone is swollen `age` seconds after a hit: out fast, back with a little give
float zoneNow(float age, float g, float release) {
    if (g <= 0.0 || age < 0.0 || age > release * 6.0)
        return 0.0;
    return g * smoothstep(0.0, 0.025, age) * exp(-age / release) * cos(age / release * 1.4);
}
// the shift back at p: most around the middle, none at the zone's edge
vec2 zonePush(vec2 p, vec4 z, float a) {
    if (a == 0.0)
        return vec2(0.0);
    vec2 q = (p - z.xy) / z.zw;
    float r = 1.0 - dot(q, q);
    return r <= 0.0 ? vec2(0.0) : (p - z.xy) * a * r * r;
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    if (kick <= 0.0 && blast < 0.0 && edge <= 0.0 && breath <= 0.0 && zones <= 0.0) {
        fragColor = at(p) * qt_Opacity;
        return;
    }
    vec2 d = vec2(1.0, 0.0);
    vec2 shift = vec2(0.0);
    float band = 0.0;
    if (kick > 0.0) {
        vec4 age = (time - kickAt) * kickRate;
        one((p - vec2(kickX.x, kickY.x)) / k, age.x, kickGain.x, hype.x, shift, band, d);
        one((p - vec2(kickX.y, kickY.y)) / k, age.y, kickGain.y, hype.y, shift, band, d);
        one((p - vec2(kickX.z, kickY.z)) / k, age.z, kickGain.z, hype.z, shift, band, d);
        one((p - vec2(kickX.w, kickY.w)) / k, age.w, kickGain.w, hype.w, shift, band, d);
    }
    if (blast >= 0.0) {
        // the blast's wave: a wide ring of squeezed and stretched air, its front lit
        vec2 bd = (p - blastFrom) / k;
        float br = max(length(bd), 1.0);
        float x = (br - blast * blastSpeed) / 26.0;
        float fade = 1.0 - smoothstep(0.2, 2.4, blast);
        shift += bd / br * 4.5 * x * exp(-x * x) * fade;
        band += exp(-x * x) * 0.8 * fade;
        d = bd;
    }
    vec2 n = qt_TexCoord0 * 2.0 - 1.0;
    vec2 swell = vec2(0.0);
    if (zones > 0.0) {
        vec4 age = time - zoneAt;
        swell = zonePush(p, zoneA, zoneNow(age.x, zoneGain.x, zoneRelease.x)) + zonePush(p, zoneB, zoneNow(age.y, zoneGain.y, zoneRelease.y))
              + zonePush(p, zoneC, zoneNow(age.z, zoneGain.z, zoneRelease.z)) + zonePush(p, zoneD, zoneNow(age.w, zoneGain.w, zoneRelease.w));
        if (holdOn > 0.0 && swell != vec2(0.0))
            swell *= 1.0 - texture(hold, (p - holdRect.xy) / holdRect.zw).a;
    }
    p -= shift * k + edgeLens(n) + swell;
    float edgePx = edgeSplit(n);
    if (band <= 0.0 && edgePx <= 0.0) {
        fragColor = at(p) * qt_Opacity;
        return;
    }
    // the air at the front: lit in sixteenths, dithered, red and blue a pixel or two apart
    band = min(band, 1.0);
    float r = max(length(d), 1.0);
    vec2 split = (d / r * floor(band * 3.0 + 0.5) + normalize(n * size) * edgePx) * k;
    vec4 c = at(p);
    vec4 cr = at(p + split);
    vec4 cb = at(p - split);
    c = vec4(cr.r, c.g, cb.b, max(c.a, max(cr.a, cb.a)));
    c.rgb += c.rgb * floor(band * 0.6 * 16.0 + bayer8(floor(p / k))) / 16.0;
    fragColor = vec4(min(c.rgb, vec3(c.a)), c.a) * qt_Opacity;
}
