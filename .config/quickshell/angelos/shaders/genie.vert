#version 440
// macOS's Genie for minimizing (modules/mac/MacMinimizeFx, Config.mac.minimizeEffect "genie"): the
// window's snapshot on a GridMesh, item = the screen. First (progress 0 → 0.42) its bottom edge
// stretches down to the Dock's icon and the sides bend into a funnel narrowing to the icon's width
// (an S-curve, wide at the window's top); then (0.42 → 1) the top comes down the funnel and the
// window pours into the icon. Played backwards it comes out again.
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    vec4 win;      // the window: x, y, width, height (screen px)
    vec4 tgt;      // the Dock item: centre x, top y, width, height
};

void main() {
    float u = qt_MultiTexCoord0.x;
    float v = qt_MultiTexCoord0.y;
    float a = clamp(progress / 0.42, 0.0, 1.0);            // the bend
    float s = clamp((progress - 0.42) / 0.58, 0.0, 1.0);    // the pour
    a = a * a * (3.0 - 2.0 * a);
    s = s * s;
    float bottomEnd = tgt.y + tgt.w;
    float top = mix(win.y, bottomEnd, s);
    float bottom = mix(win.y + win.w, bottomEnd, a);
    float y = mix(top, bottom, v);
    float t = clamp((y - win.y) / max(1.0, bottomEnd - win.y), 0.0, 1.0);
    float f = a * (0.5 - 0.5 * cos(3.14159265 * t));
    float left = mix(win.x, tgt.x - tgt.z * 0.5, f);
    float right = mix(win.x + win.z, tgt.x + tgt.z * 0.5, f);
    float x = mix(left, right, u);
    qt_TexCoord0 = qt_MultiTexCoord0;
    gl_Position = qt_Matrix * vec4(x, y, 0.0, 1.0);
}
