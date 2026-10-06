#version 440
// Liquid Glass's rim for the Golden Gate skin (widgets/MacGlass, MacWidgetCard): drawn over the
// tint, under the content. niri blurs and saturates what is behind the surface (ext-background-
// effect); the client never sees those pixels, so the "refraction" here is the lens's light, not
// a displacement: the curved edge gathers light (a brighter band just inside it, a little colour
// split across it, like dispersion) and a thin specular line runs along the rim, strongest where
// it faces the light (top left) and again, weaker, on the opposite side (light bouncing inside).
// Static: no time, nothing animates — Qt renders it only when the window draws a frame anyway.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;          // the item, logical px
    float radius;       // corner radius, logical px
    float bevel;        // how far in the lens reaches, px
    float strength;     // 0 … 1: the whole effect
    float refraction;   // 0 … 1: the lens band and its colour split
    float dark;         // 1 over a dark tint
    vec4 highlight;     // the specular line's colour (straight alpha)
    vec4 edge;          // the outer edge's colour (straight alpha)
};

// signed distance to the rounded rectangle (negative inside)
float box(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
    vec2 p = qt_TexCoord0 * size - size * 0.5;
    float r = min(radius, min(size.x, size.y) * 0.5);
    float d = box(p, size * 0.5, r);
    float aa = max(fwidth(d), 0.5);
    float inside = 1.0 - smoothstep(-aa, 0.0, d);
    if (inside <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    // the edge's outward normal, from the distance field
    vec2 e = vec2(0.5, 0.0);
    vec2 n = normalize(vec2(box(p + e.xy, size * 0.5, r) - box(p - e.xy, size * 0.5, r),
                            box(p + e.yx, size * 0.5, r) - box(p - e.yx, size * 0.5, r)) + 1e-5);
    vec2 light = normalize(vec2(-0.55, -1.0));
    float facing = dot(n, light);                    // 1: faces the light
    float t = -d;                                    // px in from the edge

    // 1 px dark outer edge (depth, separation from what's behind)
    float edgeLine = (1.0 - smoothstep(0.0, 1.0 + aa, t)) * edge.a;
    // the specular line just inside it
    float spec = smoothstep(0.0, aa, t - 0.6) * (1.0 - smoothstep(1.2, 2.4 + aa, t));
    float specK = pow(max(facing, 0.0), 1.6) + 0.35 * pow(max(-facing, 0.0), 2.0);
    float specA = spec * specK * highlight.a;
    // the lens: light gathered in a band inside the edge, fading inwards, with a colour split
    float band = refraction * (1.0 - smoothstep(0.0, bevel, t)) * smoothstep(0.0, 2.0, t);
    float lift = band * (0.10 + 0.08 * max(facing, 0.0)) * (dark > 0.5 ? 0.8 : 1.0);
    vec3 split = vec3(0.06, 0.0, -0.06) * facing * band;

    vec3 col = vec3(0.0);
    float a = 0.0;
    // over: the lens (white light), then the specular line, then the dark edge
    col = col * (1.0 - lift) + (vec3(1.0) + split) * lift;
    a = a + lift * (1.0 - a);
    col = col * (1.0 - specA) + highlight.rgb * specA;
    a = a + specA * (1.0 - a);
    col = col * (1.0 - edgeLine) + edge.rgb * edgeLine;
    a = a + edgeLine * (1.0 - a);

    float k = strength * inside * qt_Opacity;
    // premultiplied out (col is already weighted by its coverage)
    fragColor = vec4(col, a) * k;
}
