.pragma library

// The flip phone's 3D (modules/sidebar/Phone.qml): every face is a flat Item drawn in its own
// width × height and placed by one Matrix4x4 — the face's frame in the phone, the phone's turn
// and lean, then a perspective onto the screen. Qt Quick draws a 4×4 with a w row as it is (the
// same as a Rotation about x or y does), with no Qt Quick 3D and no new module. The z row of the
// result is zero, so a face is a plain 2D projective transform: crisp at rest, clicks map back.
// Matrices are row-major arrays of 16; points are [x, y, z]. y grows down, z towards the viewer.

function mul(a, b) {
    const r = new Array(16);
    for (let i = 0; i < 4; i++)
        for (let j = 0; j < 4; j++)
            r[i * 4 + j] = a[i * 4] * b[j] + a[i * 4 + 1] * b[4 + j] + a[i * 4 + 2] * b[8 + j] + a[i * 4 + 3] * b[12 + j];
    return r;
}

function chain() {
    let m = arguments[0];
    for (let i = 1; i < arguments.length; i++)
        m = mul(m, arguments[i]);
    return m;
}

function move(x, y, z) {
    return [1, 0, 0, x, 0, 1, 0, y, 0, 0, 1, z, 0, 0, 0, 1];
}

const rad = Math.PI / 180;

// about the x axis: a positive angle tips the top away from the viewer
function turnX(deg) {
    const c = Math.cos(deg * rad), s = Math.sin(deg * rad);
    return [1, 0, 0, 0, 0, c, -s, 0, 0, s, c, 0, 0, 0, 0, 1];
}

// about the y axis: a positive angle swings the right side towards the viewer
function turnY(deg) {
    const c = Math.cos(deg * rad), s = Math.sin(deg * rad);
    return [c, 0, -s, 0, 0, 1, 0, 0, s, 0, c, 0, 0, 0, 0, 1];
}

// in the screen's plane: a positive angle is clockwise
function turnZ(deg) {
    const c = Math.cos(deg * rad), s = Math.sin(deg * rad);
    return [c, -s, 0, 0, s, c, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
}

// a face's own (s, t) → o + s·u + t·v in the phone
function frame(o, u, v) {
    return [u[0], v[0], 0, o[0], u[1], v[1], 0, o[1], u[2], v[2], 0, o[2], 0, 0, 0, 1];
}

// the eye `d` px in front of the screen point (cx, cy): world (0, 0) lands there
function lens(cx, cy, d) {
    return [1, 0, -cx / d, cx, 0, 1, -cy / d, cy, 0, 0, 0, 0, 0, 0, -1 / d, 1];
}

function apply(m, p) {
    return [m[0] * p[0] + m[1] * p[1] + m[2] * p[2] + m[3], m[4] * p[0] + m[5] * p[1] + m[6] * p[2] + m[7], m[8] * p[0] + m[9] * p[1] + m[10] * p[2] + m[11]];
}

// a direction (no translation)
function dir(m, p) {
    return [m[0] * p[0] + m[1] * p[1] + m[2] * p[2], m[4] * p[0] + m[5] * p[1] + m[6] * p[2], m[8] * p[0] + m[9] * p[1] + m[10] * p[2]];
}

function cross(a, b) {
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
}

// where a face sits after `model` (world, before the lens): its centre, its normal, and whether
// the eye at (0, 0, d) sees its front
function look(model, f, d) {
    const c = apply(model, [f.o[0] + (f.u[0] * f.w + f.v[0] * f.h) / 2, f.o[1] + (f.u[1] * f.w + f.v[1] * f.h) / 2, f.o[2] + (f.u[2] * f.w + f.v[2] * f.h) / 2]);
    const n = dir(model, cross(f.u, f.v));
    const facing = n[0] * -c[0] + n[1] * -c[1] + n[2] * (d - c[2]) > 0;
    return {
        "centre": c,
        "normal": n,
        "facing": facing
    };
}

// a point through a matrix with a lens: on the screen (after the w divide)
function project(m, p) {
    const x = m[0] * p[0] + m[1] * p[1] + m[2] * p[2] + m[3];
    const y = m[4] * p[0] + m[5] * p[1] + m[6] * p[2] + m[7];
    const w = m[12] * p[0] + m[13] * p[1] + m[14] * p[2] + m[15];
    return [x / w, y / w];
}

// ---- turns held as quaternions [w, x, y, z]: a drag or a knock adds a turn about a world axis,
// with no gimbal (the old yaw-then-pitch steered wrong once it was upside down) ----

// `rad` about `axis` (any length)
function quat(axis, rad) {
    const l = Math.hypot(axis[0], axis[1], axis[2]);
    if (l < 1e-9)
        return [1, 0, 0, 0];
    const s = Math.sin(rad / 2) / l;
    return [Math.cos(rad / 2), axis[0] * s, axis[1] * s, axis[2] * s];
}

// b first, then a
function qmul(a, b) {
    return [a[0] * b[0] - a[1] * b[1] - a[2] * b[2] - a[3] * b[3], a[0] * b[1] + a[1] * b[0] + a[2] * b[3] - a[3] * b[2], a[0] * b[2] - a[1] * b[3] + a[2] * b[0] + a[3] * b[1], a[0] * b[3] + a[1] * b[2] - a[2] * b[1] + a[3] * b[0]];
}

function qnorm(q) {
    const l = Math.hypot(q[0], q[1], q[2], q[3]) || 1;
    return [q[0] / l, q[1] / l, q[2] / l, q[3] / l];
}

// the rotation as a matrix like the others
function qmatrix(q) {
    const w = q[0], x = q[1], y = q[2], z = q[3];
    return [1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y), 0, 2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x), 0, 2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y), 0, 0, 0, 0, 1];
}

// how far it is turned from facing you, degrees
function qangle(q) {
    return 2 * Math.acos(Math.min(1, Math.abs(q[0]))) / rad;
}

// from a towards b; t a little past 1 overshoots (an OutBack easing)
function qslerp(a, b, t) {
    let d = a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3];
    if (d < 0) {
        b = [-b[0], -b[1], -b[2], -b[3]];
        d = -d;
    }
    if (d > 0.9995)
        return qnorm([a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t]);
    const th = Math.acos(d), s = Math.sin(th), ka = Math.sin((1 - t) * th) / s, kb = Math.sin(t * th) / s;
    return qnorm([a[0] * ka + b[0] * kb, a[1] * ka + b[1] * kb, a[2] * ka + b[2] * kb, a[3] * ka + b[3] * kb]);
}

// a direction through a matrix's transpose (the inverse of a pure rotation)
function undir(m, p) {
    return [m[0] * p[0] + m[4] * p[1] + m[8] * p[2], m[1] * p[0] + m[5] * p[1] + m[9] * p[2], m[2] * p[0] + m[6] * p[1] + m[10] * p[2]];
}

function dot(a, b) {
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}

// two boxes seen end-on (their corners, [y, z] pairs): the line that parts them widest, as
// [ny, nz, c] — `a` lies on its n·p < c side, `b` on the other. Two convex shapes that do not
// overlap are parted along the normal of one of their own sides, so only lines through two
// corners of one of them are tried
function parting(a, b) {
    let best = [0, 1, 0], gap = -Infinity;
    for (const s of [a, b])
        for (let i = 0; i < s.length; i++)
            for (let j = i + 1; j < s.length; j++) {
                const ey = s[j][0] - s[i][0], ez = s[j][1] - s[i][1], l = Math.hypot(ey, ez);
                if (l < 1e-9)
                    continue;
                for (const n of [[-ez / l, ey / l], [ez / l, -ey / l]]) {
                    let hiA = -Infinity, loB = Infinity;
                    for (const p of a)
                        hiA = Math.max(hiA, n[0] * p[0] + n[1] * p[1]);
                    for (const p of b)
                        loB = Math.min(loB, n[0] * p[0] + n[1] * p[1]);
                    if (loB - hiA > gap) {
                        gap = loB - hiA;
                        best = [n[0], n[1], (hiA + loB) / 2];
                    }
                }
            }
    return best;
}
