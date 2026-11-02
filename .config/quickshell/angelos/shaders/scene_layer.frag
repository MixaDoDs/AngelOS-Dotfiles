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
    float kick;        // 0 = no kicks (services/Bass; the waves are off)
    vec4 kickAt;       // the last four kicks, each rings to its end: `time` of each
    vec4 kickGain;     // 0..1: how hard each hit
    vec4 kickX;        // where each rings out from: the CRT's screen or a modifier's place, art px
    vec4 kickY;
    vec4 kickRate;     // how fast each rings (1: 1.2 s)
    float wave;        // 1: bend this layer by the wave itself (SceneFront; the wall bends as a whole)
    float flare;       // 1: the CRT's screen, it flares on the kick
    vec4 punch;        // 0..1 each: how hard the kick's bass hit: the flare's height
    vec4 hype;         // 0..1 each: the song's first kicks 1, after a quiet while a little (services/Bass)
    float snare;       // 0..1: how hard the music's last snare hit (the CRT's screen only); 0 = none
    float snareAt;     // `time` of it
    float hat;         // 0..1: the last hi-hat (the CRT's screen only); 0 = none
    float hatAt;
    float hatSeed;     // where on the glass its scanline lights, 0..1 down
    float shockAge;    // s since the meteor's blast, < 0 none (SceneWall.shockAge)
    vec2 shockFrom;    // where its wave comes from, art px
    float shockSpeed;  // art px a second
    float flash;       // 0..1: the blast's flash, over everything (lit most where its light lands)
    vec4 flashColor;
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
// one of the last kicks: its wave's shift at d, its flare on the CRT (0 once it has rung out)
vec2 kickPush(vec2 d, float age, float g, float h) {
    return age >= 0.0 && age < 1.2 ? kickWave(d, age) * g * (0.6 + h) : vec2(0.0);
}
float kickFlare(float age, float g, float p, float h) {
    return age >= 0.0 && age < 1.2 ? g * p * exp(-age * 5.0) * (0.5 + 1.5 * h) : 0.0;
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
        if (shockAge >= 0.0) {
            // the blast's wave reaches it: thrown away from the fire, it swings back and is held
            // bent by the wind behind the wave, fluttering, for some seconds; the tips most
            vec2 bd = q - shockFrom;
            float br = max(length(bd), 1.0);
            float a = shockAge - br / shockSpeed;
            if (a > 0.0) {
                float hit = 3.2 * exp(-a / 1.1) * cos(a * 3.6);
                float held = 1.8 * exp(-a / 4.5) * smoothstep(0.0, 0.6, a);
                float flutter = 1.1 * exp(-a / 4.0) * (noise(vec3(q / 9.0, time * 3.5)) - 0.5) * 2.0;
                s -= warp * f.r * smoothstep(0.0, 0.08, a) * (bd / br * vec2(1.0, 0.4) * (hit + held + flutter) + vec2(0.0, 0.4 * flutter));
            }
        }
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
    // the snare knocks the CRT off its signal for a fifth of a second: rows tear sideways in whole
    // pixels, a band of interference rolls down the glass
    float sAge = time - snareAt;
    float sk = snare > 0.0 && flare > 0.5 && sAge >= 0.0 && sAge < 0.2 ? snare * (1.0 - sAge / 0.2) : 0.0;
    float sTick = floor(time * 30.0);
    vec2 held = s;     // a torn row stays inside the glass: its pixels come from the row, its outline doesn't
    if (sk > 0.0 && hash(vec3(floor(s.y), sTick, 5.0)) < 0.45 * sk)
        s.x += floor((hash(vec3(floor(s.y), sTick, 11.0)) - 0.5) * 10.0 * sk + 0.5);
    vec4 age = (time - kickAt) * kickRate;
    if (kick > 0.0 && wave > 0.5) {
        s -= kickPush(s - vec2(kickX.x, kickY.x), age.x, kickGain.x, hype.x) + kickPush(s - vec2(kickX.y, kickY.y), age.y, kickGain.y, hype.y)
           + kickPush(s - vec2(kickX.z, kickY.z), age.z, kickGain.z, hype.z) + kickPush(s - vec2(kickX.w, kickY.w), age.w, kickGain.w, hype.w);
    }
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
    if (kick > 0.0 && flare > 0.5) {
        // the kick comes out of the CRT: its screen brightens, in sixteenths, dithered; the song's
        // first kicks flare it up. The brightest of the kicks still fading, they don't add up
        float f = max(max(kickFlare(age.x, kickGain.x, punch.x, hype.x), kickFlare(age.y, kickGain.y, punch.y, hype.y)),
                      max(kickFlare(age.z, kickGain.z, punch.z, hype.z), kickFlare(age.w, kickGain.w, punch.w, hype.w)));
        float g = floor(f * 16.0 + d) / 16.0;
        c.rgb += c.rgb * g;
    }
    if (sk > 0.0 && held != s)
        c *= texture(source, (clamp(floor(held), vec2(0.0), canvas - 1.0) + 0.5) / canvas).a;
    if (sk > 0.0 && c.a > 0.0) {
        // the band: a third of the screen high, top to bottom; in it the scanlines turn to grey
        // streaks a few pixels long (an analogue channel between stations, not snow), every
        // other row dark
        float y = (t.y - origin.y) / max(area.y, 1.0);
        float b = y - sAge / 0.2 * 1.3 + 0.15;
        if (abs(b) < 0.17) {
            float len = 2.0 + floor(hash(vec3(t.y, sTick, 2.0)) * 6.0);
            float n = hash(vec3(floor(t.x / len), t.y, sTick));
            float g = mod(t.y, 2.0) < 1.0 ? floor(n * 3.0 + 0.5) / 3.0 : 0.15;
            if (hash(vec3(t.y, sTick, 7.0)) < 0.85 * sk + 0.15)
                c.rgb = vec3(g) * c.a;
        } else if (mod(t.y, 2.0) < 1.0) {
            c.rgb *= 1.0 - floor(sk * 4.0) / 16.0;
        }
    }
    // a hi-hat: for two frames one scanline of the glass lights up a few sixteenths, the row under it
    // half as much — a ripple of the beam, not a flash
    float hAge = time - hatAt;
    if (hat > 0.0 && flare > 0.5 && hAge >= 0.0 && hAge < 0.07 && c.a > 0.0) {
        float row = floor(origin.y + (0.1 + 0.8 * hatSeed) * area.y);
        float lit = t.y == row ? 1.0 : t.y == row + 1.0 ? 0.34 : 0.0;
        c.rgb = min(c.rgb + c.rgb * floor(6.0 * lit * hat + 0.5) / 16.0 + vec3(floor(3.0 * lit * hat + 0.5) / 16.0) * c.a, vec3(c.a));
    }
    if (glowNear + glowBlast > 0.0 && c.a > 0.0) {
        vec2 l = texture(light, uv).rg;
        vec3 add = nearColor.rgb * l.r * glowNear * 0.35 + blastColor.rgb * l.g * glowBlast * 0.35;
        c.rgb += c.a * floor(add * 16.0 + d) / 16.0;
    }
    if (flash > 0.0 && c.a > 0.0) {
        float lg = texture(light, uv).g;
        c.rgb = min(c.rgb + c.a * floor((flashColor.rgb * (0.3 + 0.55 * lg) + c.rgb * 0.35) * flash * 0.85 * 16.0 + d) / 16.0, vec3(c.a));
    }
    fragColor = c * qt_Opacity;
}
