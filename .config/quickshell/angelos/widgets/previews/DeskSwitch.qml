pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// Workspace switch transitions (services/WorkspaceAnim), all going down (the
// new desk comes from below): soft | dash | spring | snap | zoom | card | wipe |
// fade | dissolve | realm | glitch | crt | instant. Two little desks drawn as a
// grid of art pixels; each cell shows the old or the new desk depending on the style.
Scene {
    id: root

    readonly property int cols: 28
    readonly property int rows: 16
    readonly property real k: seg(0.2, 0.75)          // 0..1 through the switch
    readonly property real cw: width / cols
    readonly property real ch: height / rows
    readonly property color deskA: Theme.mix(Theme.desk, Theme.accent, 0.25)
    readonly property color deskB: Theme.mix(Theme.desk, Theme.accent2, 0.3)

    // what each desk shows at (u, v) in 0..1
    function old(u, v) {
        if (u > 0.12 && u < 0.62 && v > 0.18 && v < 0.82)
            return v < 0.28 ? Theme.title1 : Theme.face;
        return deskA;
    }
    function neu(u, v) {
        if (u > 0.5 && u < 0.9 && v > 0.12 && v < 0.52)
            return v < 0.21 ? Theme.title2 : Theme.face;
        if (u > 0.08 && u < 0.44 && v > 0.48 && v < 0.9)
            return v < 0.57 ? Theme.title1 : Theme.faceAlt;
        return deskB;
    }
    function hash(i, j) {
        const s = Math.sin(i * 127.1 + j * 311.7) * 43758.5453;
        return s - Math.floor(s);
    }
    function slide(u, v, e) {
        const vv = v + e;
        return vv < 1 ? old(u, vv) : neu(u, vv - 1);
    }
    function cell(i, j) {
        const u = (i + 0.5) / cols, v = (j + 0.5) / rows;
        const p = steps(k, 10);
        switch (variant) {
        case "dash":
            return slide(u, v, p < 0.4 ? p * 0.25 : 0.1 + (p - 0.4) / 0.6 * 0.9);
        case "spring":
            // overshoots a touch and settles back
            return slide(u, v, 1 - Math.exp(-5 * p) * Math.cos(7.5 * p));
        case "snap":
            return slide(u, v, 1 - Math.pow(1 - Math.min(1, p * 2.5), 4));
        case "zoom":
            {
                const s = 1 + 0.3 * ease(p);
                return Theme.mix(old((u - 0.5) / s + 0.5, (v - 0.5) / s + 0.5), neu(u, v), ease(p));
            }
        case "card":
            {
                const sh = Math.min(1, p / 0.38), sc = 1 - 0.2 * sh;
                const fly = Math.pow(Math.max(0, (p - 0.18) / 0.82), 3) * 1.2;
                const cu = (u - 0.5) / sc + 0.5, cv = (v - 0.5 + fly) / sc + 0.5;
                if (cu >= 0 && cu <= 1 && cv >= 0 && cv <= 1)
                    return old(cu, cv);
                return Theme.mix(neu(u, v), "#000000", 0.25 * sh * (1 - fly));
            }
        case "wipe":
            {
                const f = ease(p) * 1.1, along = 1 - v;
                if (Math.abs(along - f) < 0.05)
                    return Theme.accent;
                return along > f ? old(u, v + 0.08 * ease(p)) : neu(u, v);
            }
        case "fade":
            return Theme.mix(old(u, v), neu(u, v), ease(p));
        case "dissolve":
            return hash(i, j) < p ? neu(u, v) : old(u, v);
        case "realm":
            {
                if (Theme.hell) {
                    // burns away from the edges
                    const m = Math.min(u, 1 - u, v, 1 - v) * 2 + (hash(i, j) - 0.5) * 0.3 - (p * 1.45 - 0.22);
                    if (m < 0)
                        return hash(i + 3, j) > 0.92 && m > -0.15 ? "#ffcf5a" : neu(u, v);
                    return m < 0.07 ? "#ff7a1a" : m < 0.14 ? "#7a1408" : old(u, v);
                }
                // overexposes and scatters into light
                const lit = Theme.mix(old(u, v), "#fffaf0", Math.min(1, p * 2));
                return hash(i, j) * 0.85 + (1 - v) * 0.15 < (p - 0.3) * 1.5 ? neu(u, v) : lit;
            }
        case "glitch":
            {
                const q = Math.floor(p * 6);
                const shift = hash(j, q) > 0.55 ? (hash(j + 9, q) - 0.5) * 0.4 * p : 0;
                if (hash(j, 77) * 0.55 + (1 - v) * 0.45 < p * 1.3 - 0.2)
                    return neu(u, v);
                const c = old(u + shift, v);
                return hash(j, q + 40) > 0.85 ? Theme.mix(c, Theme.accent, 0.6) : c;
            }
        case "crt":
            {
                const a1 = Math.min(1, p / 0.42), a2 = Math.max(0, Math.min(1, (p - 0.42) / 0.26)), a3 = Math.max(0, (p - 0.68) / 0.32);
                const sy = Math.max(1 / rows, 1 - a1 * a1), sx = Math.max(1 / cols, 1 - a2 * a2);
                if (Math.abs(u - 0.5) <= sx / 2 && Math.abs(v - 0.5) <= sy / 2 && a3 < 0.5)
                    return Theme.mix(old((u - 0.5) / sx + 0.5, (v - 0.5) / sy + 0.5), "#ffffff", a1);
                return Theme.mix("#000000", neu(u, v), a3);
            }
        case "instant":
            return p < 0.5 ? old(u, v) : neu(u, v);
        default:
            // niri's soft slide: the old desk leaves upwards
            return slide(u, v, ease(p));
        }
    }

    Repeater {
        model: root.cols * root.rows
        Rectangle {
            required property int index
            readonly property int i: index % root.cols
            readonly property int j: Math.floor(index / root.cols)
            x: Math.floor(i * root.cw)
            y: Math.floor(j * root.ch)
            width: Math.ceil(root.cw)
            height: Math.ceil(root.ch)
            color: root.cell(i, j)
        }
    }
}
