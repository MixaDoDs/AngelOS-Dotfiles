// angelOS open: the window opens through a growing Y2K sparkle star ✦ with a shiny rim, the theme's accent going white.
float angelos_star(vec2 q) {
    q = abs(q);
    return sqrt(q.x) + sqrt(q.y) - 1.0;
}

vec4 open_color(vec3 coords_geo, vec3 size_geo) {
    if (coords_geo.x < 0.0 || coords_geo.x > 1.0 || coords_geo.y < 0.0 || coords_geo.y > 1.0)
        return vec4(0.0);
    float p = niri_clamped_progress;
    vec4 color = texture2D(niri_tex, (niri_geo_to_tex * coords_geo).st);
    if (p >= 0.999)
        return color;
    float e = 1.0 - pow(1.0 - p, 3.0);
    float aspect = size_geo.x / size_geo.y;
    vec2 q = (coords_geo.xy - 0.5) * vec2(aspect, 1.0);
    // big enough to reach the window's corners at the end
    float reach = pow(sqrt(0.5 * aspect) + sqrt(0.5), 2.0) * 1.05;
    float s = reach * e;
    if (s < 0.001)
        return vec4(0.0);
    float h = angelos_star(q / s);
    if (h > 0.0)
        return vec4(0.0);
    float edge = smoothstep(-0.14, 0.0, h) * (1.0 - smoothstep(0.55, 1.0, p));
    // a glint travels round the rim
    float glint = step(0.75, fract(atan(q.y, q.x) * 0.3183 + p * 2.0));
    vec3 rim = mix(ANGELOS_ACCENT, vec3(1.0), glint);
    color.rgb = mix(color.rgb, rim * color.a, edge * 0.9);
    return color * smoothstep(0.0, 0.12, p);
}
