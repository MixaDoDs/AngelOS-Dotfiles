// angelOS open: the window appears pixel by pixel through an ordered (Bayer) dither, the grid of
// 4 px "pixels" filling in evenly; each one lights up in the theme's accent for a moment.
float angelos_bayer2(vec2 c) {
    vec2 d = mod(c, 2.0);
    return 2.0 * d.x + 3.0 * d.y - 4.0 * d.x * d.y;
}

// 8×8 Bayer matrix, 0..63: 64 even steps
float angelos_bayer(vec2 c) {
    return 16.0 * angelos_bayer2(c) + 4.0 * angelos_bayer2(floor(c / 2.0)) + angelos_bayer2(floor(c / 4.0));
}

vec4 open_color(vec3 coords_geo, vec3 size_geo) {
    if (coords_geo.x < 0.0 || coords_geo.x > 1.0 || coords_geo.y < 0.0 || coords_geo.y > 1.0)
        return vec4(0.0);
    float p = niri_clamped_progress;
    vec2 cell = floor(coords_geo.xy * size_geo.xy / 4.0);
    float t = (angelos_bayer(cell) + 0.5) / 64.0 * 0.85;
    if (p < t)
        return vec4(0.0);
    vec4 color = texture2D(niri_tex, (niri_geo_to_tex * coords_geo).st);
    float fresh = 1.0 - clamp((p - t) / 0.1, 0.0, 1.0);
    color.rgb = mix(color.rgb, ANGELOS_ACCENT * color.a, fresh * 0.7);
    return color;
}
