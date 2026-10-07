// angelOS open: pops up like a Y2K bubble — springs a little past full size, a shine rim from the theme's accent to its second one and a glossy glint fade away.
vec4 open_color(vec3 coords_geo, vec3 size_geo) {
    float p = niri_clamped_progress;
    // a damped spring: overshoots ~8 %, settles
    float e = 1.0 - pow(2.0, -9.0 * p) * cos(p * 10.5);
    float s = mix(0.45, 1.0, e);
    vec2 g = (coords_geo.xy - 0.5) / s + 0.5;
    if (g.x < 0.0 || g.x > 1.0 || g.y < 0.0 || g.y > 1.0)
        return vec4(0.0);
    vec4 color = texture2D(niri_tex, (niri_geo_to_tex * vec3(g, 1.0)).st);
    float fade = 1.0 - smoothstep(0.35, 0.9, p);
    // the bubble's rim: the accent on the left, the second accent on the right
    vec2 d = min(g, 1.0 - g) * size_geo.xy * s;
    float edge = 1.0 - smoothstep(0.0, 12.0, min(d.x, d.y));
    vec3 shine = mix(ANGELOS_ACCENT, ANGELOS_ACCENT2, g.x);
    color.rgb = mix(color.rgb, shine * color.a, edge * fade * 0.9);
    // a glossy diagonal glint sweeps across
    float band = abs((g.x + g.y) - mix(-0.3, 2.3, p));
    color.rgb += vec3(0.35) * color.a * (1.0 - smoothstep(0.0, 0.12, band)) * fade;
    return color * smoothstep(0.0, 0.2, p);
}
