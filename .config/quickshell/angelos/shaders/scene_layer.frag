#version 440
// One layer of a layered pixel-art scene (widgets/SceneWall), drawn at screen resolution over the
// layer's own rectangle. Texels stay sharp (nearest, palette colours only) but move by fractions
// of an art pixel: a soft parallax shift, and a puppet warp for plants — the root is pinned,
// the bend grows toward the free end, everything leans downwind (wind, windDir), a gust front
// rolls across the scene and every crown and bunch of leaves also sways on its own, so a bush
// never moves as one block. At night (scripts/scene-night.py) every art pixel moves to its night
// colour as `night` grows (day and night share every edge: nothing doubles, a pixel stays one flat
// square), and the night's event lights the scene in steps of a sixteenth, dithered on an 8×8
// Bayer matrix: no smooth gradient across the pixels.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 canvas;       // logical size, art px
    vec2 origin;       // this item's top-left on the canvas, art px
    vec2 area;         // this item's size, art px
    vec2 shift;        // parallax + drift, art px (fractional); a plant's: its nearest, scaled by `flex`
    float clampEdge;   // 1: edges repeat (layers that touch the frame), 0: transparent outside
    float warp;        // puppet bend at the free end of the nearest plant, art px; 0 = rigid
    float time;
    float wind;        // 0..~1.6: the scene's wind now (SceneWall: the hour's, its gusts, events)
    float windDir;     // -1..1: where it blows
    float pinned;      // 1: a plant — bends by `flex`, the scene's one field (scripts/scene-hold.py)
    vec2 pan;          // the camera: the whole picture moves by it, art px
    float night;       // 0..1: day → night
    float glowNear;    // 0..1: the meteor's light as it comes near (light.r)
    float glowBlast;   // 0..1: the blast's (light.g)
    vec4 nearColor;    // their colours
    vec4 blastColor;
    float screenHit;   // 0..1: the CRT's screen shaken by the blast (the screen's layer only)
    float twilight;    // 0..1: day → the dusk or the dawn, under the night
    float kick;        // 0..1: how hard the music's last kick hit (services/Bass); 0 = none
    float kickAt;      // `time` of that kick
    vec2 kickFrom;     // where its wave rings out from: the CRT's screen, art px
    float wave;        // 1: bend this layer by the wave itself (SceneFront; the wall bends as a whole)
    float flare;       // 1: the CRT's screen, it flares on the kick
};
layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D flex;   // r: how far it bends (0 at roots and held), g: how near
layout(binding = 3) uniform sampler2D nightSource;   // the layer at night (the same frame when it keeps its own)
layout(binding = 4) uniform sampler2D light;         // r: the meteor's light, g: the blast's
layout(binding = 5) uniform sampler2D twilightSource;  // the layer at dusk or at dawn

// an 8×8 Bayer matrix as a formula (NVIDIA's GL drops shaders with constant arrays), 0..63/64
float bayer2(vec2 a) {
    a = floor(a);
    return fract(a.x / 2.0 + a.y * a.y * 0.75);
}
float bayer8(vec2 a) {
    return bayer2(0.25 * a) * 0.0625 + bayer2(0.5 * a) * 0.25 + bayer2(a);
}

// the kick's wave (as shaders/scene_kick.frag): a ring out of `from` that bends the picture as it
// passes, and a breath toward you for a moment; d = from → here, art px; the shift back, art px
vec2 kickWave(vec2 d, float age) {
    float r = max(length(d), 1.0);
    float x = (r - age * 520.0) / 16.0;                      // where the ring is, its width
    float push = 2.2 * x * exp(-x * x) * (1.0 - age / 1.2);  // in front it stretches, behind it squeezes
    return d / r * push + d * 0.006 * exp(-age * 9.0);
}

float hash(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.x + p.y) * p.z);
}
// smooth value noise, 0..1
float noise(vec3 p) {
    vec3 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
                   mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
               mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
                   mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void main() {
    vec2 a = origin + qt_TexCoord0 * area;   // where this fragment is on the canvas
    vec2 s = a - pan;
    if (pinned > 0.5) {
        // one field for every plant, read where the picture is (scripts/scene-hold.py): two layers
        // of one crown bend alike where they meet, or they part and what is under them shows
        // through; the root and what lies on a thing (ivy over the TV, the fence in a bush) keep
        // still. Its parts are broad and slow: a field that changes faster than about a fifth of
        // a pixel per pixel cuts the art into strips one screen pixel thin (it tore)
        vec2 f = texture(flex, s / canvas).rg;
        vec2 q = s;
        // the gust front rolls across the scene the way the wind blows
        float front = noise(vec3(q.x * 0.012 - windDir * time * 0.11, 0.0, 0.0));
        float w = wind * (0.6 + 0.5 * front);
        float sway = sin(6.28318530718 * time / 8.5 * (0.8 + 0.4 * w) + q.x * 0.02 + q.y * 0.008);
        float cluster = noise(vec3(q / 22.0, time * (0.25 + 0.25 * w))) - 0.5;      // each crown
        float bunch = noise(vec3(q / 11.0 + 31.0, time * (0.5 + 0.6 * w))) - 0.5;   // each bunch on its own
        float lean = windDir * w * 0.45;                                            // bent downwind
        s -= shift * f.g * f.r;
        s.x -= warp * f.r * (lean + (0.3 + 0.7 * w) * (0.45 * sway + 0.8 * cluster + 0.35 * bunch));
        s.y -= warp * f.r * 0.3 * (0.5 + 0.5 * w) * (noise(vec3(q / 16.0 + 7.0, time * 0.35)) - 0.5);
    } else {
        s -= shift;
    }
    if (screenHit > 0.0) {
        // the blast reaches the CRT: rows of the picture slip sideways, a few at a time
        float row = floor(s.y / 2.0);
        float tick = floor(time * 12.0);
        if (hash(vec3(row, tick, 3.0)) < 0.35 * screenHit)
            s.x += (hash(vec3(row, tick, 9.0)) - 0.5) * 6.0 * screenHit;
    }
    float age = time - kickAt;
    bool kicking = kick > 0.0 && age >= 0.0 && age < 1.2;
    if (kicking && wave > 0.5)
        s -= kickWave(s - kickFrom, age) * kick;
    vec2 t = floor(s);
    if (clampEdge < 0.5 && (t.x < 0.0 || t.y < 0.0 || t.x >= canvas.x || t.y >= canvas.y)) {
        fragColor = vec4(0.0);
        return;
    }
    t = clamp(t, vec2(0.0), canvas - 1.0);
    vec2 uv = (t + 0.5) / canvas;
    float d = bayer8(t);
    vec4 c = mix(mix(texture(source, uv), texture(twilightSource, uv), twilight), texture(nightSource, uv), night);
    if (screenHit > 0.0 && mod(t.y + floor(time * 20.0), 5.0) < 1.0)
        c.rgb *= 1.0 - 0.45 * screenHit;
    if (kicking && flare > 0.5) {
        // the kick comes out of the CRT: its screen brightens, in sixteenths, dithered
        float g = floor(kick * exp(-age * 7.0) * 0.4 * 16.0 + d) / 16.0;
        c.rgb += c.rgb * g;
    }
    if (glowNear + glowBlast > 0.0 && c.a > 0.0) {
        vec2 l = texture(light, uv).rg;
        vec3 add = nearColor.rgb * l.r * glowNear * 0.35 + blastColor.rgb * l.g * glowBlast * 0.35;
        c.rgb += c.a * floor(add * 16.0 + d) / 16.0;
    }
    fragColor = c * qt_Opacity;
}
