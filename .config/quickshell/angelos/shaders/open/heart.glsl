// angelOS open: the window appears through a growing heart with a rim in the theme's accent.
float angelos_heart(vec2 q) {
    float a = q.x * q.x + q.y * q.y - 1.0;
    return a * a * a - q.x * q.x * q.y * q.y * q.y;
}

vec4 open_color(vec3 coords_geo, vec3 size_geo) {
    if (coords_geo.x < 0.0 || coords_geo.x > 1.0 || coords_geo.y < 0.0 || coords_geo.y > 1.0)
        return vec4(0.0);
    float p = niri_clamped_progress;
    vec4 color = texture2D(niri_tex, (niri_geo_to_tex * coords_geo).st);
    if (p >= 0.999)
        return color;
    float e = p * p * (3.0 - 2.0 * p);
    float aspect = size_geo.x / size_geo.y;
    vec2 q = (coords_geo.xy - vec2(0.5, 0.45)) * vec2(aspect, 1.0);
    q.y = -q.y;
    // just big enough to cover the window's corners at the end
    float s = (0.58 + 0.45 * aspect) * e;
    if (s < 0.001)
        return vec4(0.0);
    float h = angelos_heart(q / s);
    if (h > 0.0)
        return vec4(0.0);
    float edge = smoothstep(-0.25, 0.0, h) * (1.0 - smoothstep(0.6, 1.0, p));
    color.rgb = mix(color.rgb, ANGELOS_ACCENT * color.a, edge * 0.85);
    return color * smoothstep(0.0, 0.12, p);
}
