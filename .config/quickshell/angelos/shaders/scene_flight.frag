#version 440
// A piece the meteor's blast throws, in the air and landing (widgets/SceneThrow): a ballistic arc
// in the world seen through the scene's camera, so far off it is a speck creeping out of the fire
// and the last of it rushes at you, growing; tumbling a quarter turn at a time, a tail behind it
// (fire, or the smoke of a dark stone); hidden while it is deeper than the house's wall and over
// it on the canvas. On the ground: a thud, a hop or two bounces and a roll, a splash of sparks
// and earth (dust, for a big or a dark one). Art pixels only: whole-pixel positions, the map read
// nearest (smaller is fewer of its pixels), the tail and the splash thinned by a Bayer dither.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 origin;        // this item's top-left on the canvas, art px
    vec2 area;          // this item's size, art px
    float centre;       // the camera: the canvas's middle x, the horizon y, the focal length, art px
    float horizon;
    float focal;
    vec3 from;          // the world: where it is thrown from (the fire), where it touches down
    vec3 dest;
    float arc;          // how high over the straight line its arc goes, world units
    vec2 wallAt;        // the house's wall: on the canvas left of x, at depth y
    float progress;     // 0..1 along the arc; 1 on the ground
    float tail;         // the arc's share of one step of its tail
    float turn;         // quarter turns now, 0..3
    float hop;          // s since it touched down, < 0 in the air
    float hopCount;     // 0 a thud, 1 a hop, 2 two bounces and a roll
    vec2 restAt;        // where it lies at last, art px
    vec2 size;          // its map's size, art px; 0: a pebble
    float speckSize;    // a pebble's size where it lands, art px
    float heat;         // 1 white-hot … 0.5 a dark stone glowing in its cracks
    vec4 fire0;
    vec4 fire1;
    vec4 fire2;
    vec4 trail0;        // its tail, hottest first
    vec4 trail1;
    vec4 trail2;
    vec4 rock0;
    vec4 rock1;
    vec4 rock2;
    vec4 rock3;
    vec4 ground0;       // the earth it throws up
};
layout(binding = 1) uniform sampler2D map;

float bayer2(vec2 a) {
    a = floor(a);
    return fract(a.x / 2.0 + a.y * a.y * 0.75);
}
float bayer4(vec2 a) {
    return bayer2(0.5 * a) * 0.25 + bayer2(a);
}
float hash(float n) {
    return fract(sin(n * 127.1) * 43758.5453);
}
vec3 world(float v) {
    return vec3(mix(from.x, dest.x, v), mix(from.y, dest.y, v) + arc * 4.0 * v * (1.0 - v), mix(from.z, dest.z, v));
}
vec2 screen(vec3 w) {
    return vec2(centre + focal * w.x / w.z, horizon - focal * (w.y - 1.0) / w.z);
}
// behind the house's wall: deeper than it and over it on the canvas
bool hidden(vec3 w, vec2 s) {
    return w.z > wallAt.y && s.x < wallAt.x;
}
vec2 turned(vec2 q, float n) {
    return n < 0.5 ? q : n < 1.5 ? vec2(q.y, -q.x) : n < 2.5 ? -q : vec2(-q.y, q.x);
}
vec4 stoneOf(float shade, bool crack) {
    if (heat > 0.8)
        return crack ? fire2 : shade < 0.5 ? fire0 : shade < 2.5 ? fire1 : fire2;
    if (crack)
        return fire1;
    return shade < 0.5 ? rock0 : shade < 1.5 ? rock1 : shade < 2.5 ? rock2 : rock3;
}
// how high it is off the ground in its hops, art px, and how far along to its rest
float hopHeight(float h) {
    if (hopCount < 0.5)
        return 0.0;
    if (hopCount < 1.5)
        return h < 0.3 ? 2.5 * sin(3.14159 * h / 0.3) : 0.0;
    return h < 0.3 ? 3.0 * sin(3.14159 * h / 0.3) : h < 0.5 ? 1.2 * sin(3.14159 * (h - 0.3) / 0.2) : 0.0;
}
float hopFor() {
    return hopCount < 0.5 ? 0.0 : hopCount < 1.5 ? 0.3 : 0.5;
}

void main() {
    vec2 t = floor(origin + qt_TexCoord0 * area);
    vec2 p = t + 0.5;
    float b = bayer4(t);
    bool pebble = size.x < 0.5;
    // its middle against its bottom middle, at full size (as scene_shard.frag lays it)
    vec2 mid = pebble ? vec2(0.0, -0.5 * speckSize) : vec2(size.x * 0.5 - floor(size.x * 0.5), 1.0 - size.y * 0.5);
    vec2 touch = screen(dest);

    // ---- itself: in the air, or hopping to its rest ----
    if (hop < hopFor()) {
        bool down = hop >= 0.0;
        vec3 w = world(progress);
        vec2 foot = down ? floor(mix(touch, restAt, clamp(hop / max(hopFor(), 0.01), 0.0, 1.0)) + 0.5) - vec2(0.0, floor(hopHeight(hop) + 0.5))
                         : floor(screen(w) + 0.5);
        float s = down ? 1.0 : dest.z / w.z;
        if (down || !hidden(w, foot)) {
            if (pebble) {
                float px = max(1.0, floor(speckSize * s + 0.5));
                vec2 m = t - (foot - vec2(floor(px * 0.5), px));
                if (m.x >= 0.0 && m.y >= 0.0 && m.x < px && m.y < px) {
                    fragColor = (heat > 0.8 ? fire2 : fire1) * qt_Opacity;
                    return;
                }
            } else if (s * max(size.x, size.y) < 2.5) {
                // too far to be more than a speck
                if (t == foot - vec2(0.0, 1.0)) {
                    fragColor = (heat > 0.8 ? fire2 : fire1) * qt_Opacity;
                    return;
                }
            } else {
                vec2 q = turned((p - foot - mid * s) / s, turn);
                vec2 m = floor(q + size * 0.5);
                if (m.x >= 0.0 && m.y >= 0.0 && m.x < size.x && m.y < size.y) {
                    vec4 px = texture(map, (m + 0.5) / size);
                    if (px.a > 0.5) {
                        fragColor = stoneOf(floor(px.r * 3.0 + 0.5), px.g > 0.1) * qt_Opacity;
                        return;
                    }
                }
            }
        }
    }
    vec4 c = vec4(0.0);
    // ---- its tail: where it was the last moments, thinner and fainter further back ----
    if (hop < 0.0) {
        float big = pebble ? speckSize : min(size.x, size.y);
        for (int i = 1; i <= 9; i++) {
            float n = float(i);
            float v = progress - n * tail;
            if (v < 0.0)
                break;
            vec3 w = world(v);
            float s = dest.z / w.z;
            vec2 at = screen(w) + (pebble ? vec2(0.0, -0.5) : mid * s);
            if (hidden(w, at))
                continue;
            float r = max(0.6, 0.36 * big * s * (1.0 - n / 10.0));
            if (length(p - at) < r && b < 1.0 - n / 10.0) {
                c = n < 3.0 ? trail0 : n < 6.0 ? trail1 : trail2;
                break;
            }
        }
    }
    // ---- the landing: sparks and earth thrown up and falling back (dust, for a thud) ----
    if (hop >= 0.0 && c.a < 0.5) {
        float sparks = pebble ? 3.0 : heat > 0.8 ? 7.0 : 2.0;
        float clods = pebble ? 1.0 : hopCount < 0.5 ? 12.0 : 5.0;
        for (int i = 0; i < 19; i++) {
            float n = float(i);
            if (n >= sparks + clods)
                break;
            bool earth = n >= sparks;
            float life = (earth ? 0.5 : 0.4) + 0.4 * hash(n * 2.3 + touch.x);
            if (hop > life)
                continue;
            float a = 3.14159 * (1.08 + 0.84 * hash(n * 1.9 + touch.y));
            float speed = (pebble ? 8.0 : earth ? (hopCount < 0.5 ? 20.0 : 12.0) : 18.0) + (pebble ? 10.0 : 24.0) * hash(n * 4.1 + touch.x * 0.7);
            vec2 at = touch + vec2(0.0, -1.0) + vec2(cos(a), sin(a)) * speed * hop + vec2(0.0, 100.0 * hop * hop);
            if (at.y > touch.y + 1.0)
                continue;
            float x = hop / life;
            if (floor(at) == t && b < 1.0 - smoothstep(0.55, 1.0, x)) {
                c = earth ? ground0 : x < 0.3 ? fire2 : x < 0.65 ? fire1 : fire0;
                break;
            }
        }
    }
    fragColor = c * qt_Opacity;
}
