#version 440
// A shard of the meteor lying in the scene (widgets/SceneAftermath, scripts/scene-shards.py): the
// stone from its map (r: shade 0..3, g: crack 0..3, a: stone), and what it does to the ground it
// lies on — its shadow, the scorch it burns, the glow it throws while hot. Art pixels only: every
// step between two colours goes through a 4×4 Bayer matrix, no soft edge, no half-transparent
// pixel. White-hot the whole stone is the night's fire (fire: deep, mid, hot); cooling, it goes dark
// shade by shade from its outline in, and only its cracks glow, a step dimmer and dimmer; cold, the
// scene's own stone.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 origin;        // this item's top-left on the canvas, art px
    vec2 area;          // this item's size, art px
    vec2 at;            // the middle of where the stone touches the ground, art px
    vec2 size;          // the map's size, art px
    float heat;         // 1 white-hot … 0 cold
    float lean;         // art px: the shadow leans (the day's sun; 0 at night)
    float scorch;       // 0..1: how much of the burnt ground there is
    float glowK;        // how much its glow shows (strong at night, faint by day)
    float fade;         // 0..1: going (dithered away)
    vec4 rock0;
    vec4 rock1;
    vec4 rock2;
    vec4 rock3;
    vec4 fire0;
    vec4 fire1;
    vec4 fire2;
    vec4 shadow;
    vec4 burnt;
};
layout(binding = 1) uniform sampler2D map;

float bayer2(vec2 a) {
    a = floor(a);
    return fract(a.x / 2.0 + a.y * a.y * 0.75);
}
float bayer4(vec2 a) {
    return bayer2(0.5 * a) * 0.25 + bayer2(a);
}
vec4 rockOf(float s) {
    return s < 0.5 ? rock0 : s < 1.5 ? rock1 : s < 2.5 ? rock2 : rock3;
}
vec4 hotOf(float s) {
    return s < 0.5 ? fire0 : s < 2.5 ? fire1 : fire2;
}

void main() {
    vec2 t = floor(origin + qt_TexCoord0 * area);
    float b = bayer4(t);
    if (b < fade) {
        fragColor = vec4(0.0);
        return;
    }
    vec2 top = vec2(at.x - floor(size.x / 2.0), at.y - size.y + 1.0);
    vec2 m = t - top;
    vec4 c = vec4(0.0);
    if (m.x >= 0.0 && m.y >= 0.0 && m.x < size.x && m.y < size.y) {
        vec4 px = texture(map, (m + 0.5) / size);
        if (px.a > 0.5) {
            float s = floor(px.r * 3.0 + 0.5);
            float k = floor(px.g * 3.0 + 0.5);
            // it cools from its edges in: the outline goes dark first, the highlight last
            bool glowing = heat > 0.8 - s * 0.08;
            c = glowing ? hotOf(s) : rockOf(s);
            if (k > 0.5) {
                float lvl = floor(k + (heat - 0.65) * 5.0);
                c = lvl >= 3.0 ? fire2 : lvl >= 2.0 ? fire1 : lvl >= 1.0 ? fire0 : glowing ? c : rock1;
            }
            fragColor = c * qt_Opacity;
            return;
        }
    }
    // the ground round it: scorch under the shadow under the glow
    float sw = size.x;
    float ry = max(1.5, sw * 0.13);
    vec2 d = t - at;
    float e = pow(d.x / (sw * 0.75 + 1.0), 2.0) + pow((d.y - 0.5) / (ry * 1.6 + 0.5), 2.0);
    if (e < 1.0 && b < 0.55 * (1.0 - e * 0.5) * scorch)
        c = burnt;
    float e2 = pow((d.x - lean) / (sw * 0.5 + 0.5), 2.0) + pow((d.y - 0.5) / ry, 2.0);
    if (e2 < 1.0 && (e2 < 0.6 || b < 0.5))
        c = shadow;
    float e3 = pow(d.x / (sw * 0.8 + 2.0), 2.0) + pow(d.y / max(2.5, sw * 0.22), 2.0);
    float amt = heat * heat * (1.0 - e3) * (1.0 - e3) * glowK;
    if (e3 < 1.0 && b + 0.0625 < amt)
        c = fire0;
    fragColor = c * qt_Opacity;
}
