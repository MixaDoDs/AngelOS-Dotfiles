// angelOS open: the window assembles from pixel blocks that blink in (flashing in the theme's accent), chunky first, then sharp.
float angelos_hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 open_color(vec3 coords_geo, vec3 size_geo) {
    if (coords_geo.x < 0.0 || coords_geo.x > 1.0 || coords_geo.y < 0.0 || coords_geo.y > 1.0)
        return vec4(0.0);
    float p = niri_clamped_progress;
    vec2 px = coords_geo.xy * size_geo.xy;
    // a fixed 16 px grid decides when each block arrives: top rows first, with noise
    vec2 cell = floor(px / 16.0);
    float t = angelos_hash(cell + niri_random_seed * 37.0) * 0.6 + coords_geo.y * 0.2;
    if (p < t)
        return vec4(0.0);
    // the picture sharpens: 24 px blocks → real pixels over the second half
    float k = clamp((p - 0.4) / 0.55, 0.0, 1.0);
    float block = 4.0 * floor(mix(6.99, 0.0, k));
    vec2 sample_geo = block >= 4.0 ? (floor(px / block) + 0.5) * block / size_geo.xy : coords_geo.xy;
    vec4 color = texture2D(niri_tex, (niri_geo_to_tex * vec3(sample_geo, 1.0)).st);
    // a block that just arrived flashes in the theme's accent
    float fresh = 1.0 - clamp((p - t) / 0.12, 0.0, 1.0);
    color.rgb = mix(color.rgb, ANGELOS_ACCENT * color.a, fresh * 0.8);
    return color;
}
