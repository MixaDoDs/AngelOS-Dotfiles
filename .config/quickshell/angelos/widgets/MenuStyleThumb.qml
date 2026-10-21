import QtQuick
import qs.config

// A small picture of a right-click menu look (Settings → Right-click menu, the setup
// wizard): list | wings | harp | pentagram.
Item {
    id: root

    property string style: "list"
    implicitWidth: Theme.u * 58
    implicitHeight: Theme.u * 42

    // the wallpaper
    Rectangle {
        anchors.fill: parent
        color: root.style === "pentagram" ? "#1a0508" : Theme.mix(Theme.desk, Theme.accent, 0.12)
        border.width: Math.max(1, Theme.u / 2)
        border.color: Theme.lo
    }

    // list: the Windows 11-like menu
    Rectangle {
        visible: root.style === "list"
        x: Theme.u * 12
        y: Theme.u * 5
        width: Theme.u * 34
        height: Theme.u * 32
        color: Theme.menuSurface
        border.width: Math.max(1, Theme.u / 2)
        border.color: Theme.edge
        Row {
            x: Theme.u * 3
            y: Theme.u * 3
            spacing: Theme.u * 2
            Repeater {
                model: 4
                Rectangle {
                    width: Theme.u * 5
                    height: Theme.u * 5
                    color: Theme.accent
                }
            }
        }
        Column {
            x: Theme.u * 3
            y: Theme.u * 11
            spacing: Theme.u * 2
            Repeater {
                model: 5
                Rectangle {
                    required property int index
                    width: index === 1 ? Theme.u * 28 : Theme.u * (18 + index * 2)
                    height: Theme.u * 2
                    color: index === 1 ? Theme.accent : Theme.textDim
                }
            }
        }
    }

    // wings: two wings of feathers under a halo (heaven's own), in pixels
    Canvas {
        visible: root.style === "wings"
        anchors.fill: parent
        antialiasing: false
        readonly property color pale: Theme.dark ? Theme.mix(Theme.text, Theme.menuSurface, 0.12) : Theme.menuSurface
        readonly property var colours: [pale, Theme.mix(Theme.accent, Theme.dark ? Theme.face : Theme.text, 0.55), Theme.accent, Theme.mix(pale, Theme.accent, 0.4)]
        onColoursChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const u = Theme.u, W = Math.floor(width / u), H = Math.floor(height / u), cx = W / 2, cy = H / 2 + 1;
            // five feathers a side, fanned from the shoulder; the third on the right is lit
            const who = (x, y) => {
                const s = x < cx ? -1 : 1, dx = (x + 0.5 - cx) * s - 2, dy = y + 0.5 - (cy - 2);
                if (dx < 0)
                    return -1;
                for (let f = 0; f < 5; f++) {
                    const a = -0.75 + f * 0.36, len = 25 - f * 2.8;
                    const t = dx * Math.cos(a) + dy * Math.sin(a), v = -dx * Math.sin(a) + dy * Math.cos(a);
                    if (t > 2 && t < len && Math.abs(v) < (t < 5 ? 0.8 : 1.6) * (t > len - 3 ? (len - t) / 3 + 0.3 : 1))
                        return f === 2 && s > 0 ? 3 : 0;
                }
                return -1;
            };
            const on = (x, y) => x >= 0 && y >= 0 && x < W && y < H && who(x, y) >= 0;
            for (let y = 0; y < H; y++)
                for (let x = 0; x < W; x++) {
                    const k = who(x, y);
                    if (k < 0)
                        continue;
                    ctx.fillStyle = colours[!on(x - 1, y) || !on(x + 1, y) || !on(x, y - 1) || !on(x, y + 1) ? 1 : k];
                    ctx.fillRect(x * u, y * u, u, u);
                }
            // the round plate in the middle and the halo over it
            for (let y = -3; y <= 3; y++)
                for (let x = -3; x <= 3; x++) {
                    const d = x * x + y * y;
                    if (d > 11)
                        continue;
                    ctx.fillStyle = colours[d > 6 ? 1 : 0];
                    ctx.fillRect(Math.floor(cx + x) * u, (cy - 1 + y) * u, u, u);
                }
            for (let x = -4; x <= 4; x++) {
                const e = Math.abs(x) > 2 ? 0 : 1;
                ctx.fillStyle = colours[2];
                ctx.fillRect(Math.floor(cx + x) * u, (cy - 9 + e) * u, u, u);
                ctx.fillRect(Math.floor(cx + x) * u, (cy - 7 - e) * u, u, u);
            }
        }
    }

    // harp: a harp on a cloud (heaven's own), strings of falling length, one plucked
    Canvas {
        visible: root.style === "harp"
        anchors.fill: parent
        antialiasing: false
        readonly property var colours: [Theme.accent, Theme.mix(Theme.text, Theme.menuSurface, 0.45), Theme.menuSurface, Theme.mix(Theme.accent, Theme.text, 0.4)]
        onColoursChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const u = Theme.u;
            const box = (x, y, w, h, c) => {
                ctx.fillStyle = colours[c];
                ctx.fillRect(x * u, y * u, w * u, h * u);
            };
            const x0 = 14, y0 = 6, w = 30;
            // strings, then the frame over their ends: pillar, neck, soundboard
            for (let i = 0; i < 9; i++) {
                const x = x0 + 4 + i * 3, foot = y0 + 28 - Math.round(i * 2.2);
                box(x + (i === 4 ? 1 : 0), y0 + 3, 1, foot - y0 - 3, i === 4 ? 0 : 1);
                box(x - 1, foot - 3, 3, 2, i === 4 ? 0 : 2);
            }
            box(x0, y0, 3, 31, 0);
            box(x0, y0, w, 3, 0);
            for (let i = 0; i < w - 2; i++)
                box(x0 + 2 + i, y0 + 28 - Math.round(i * 0.73), 1, 3, 0);
            box(x0 - 1, y0 - 1, 5, 2, 3);
            // the cloud under its foot
            box(x0 - 6, y0 + 33, 14, 3, 2);
            box(x0 - 3, y0 + 31, 7, 2, 2);
        }
    }

    // pentagram: hell's own
    Canvas {
        visible: root.style === "pentagram"
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const cx = width / 2, cy = height / 2, r = Math.min(width, height) * 0.38;
            ctx.strokeStyle = "#e0203a";
            ctx.lineWidth = Math.max(1, Theme.u);
            ctx.beginPath();
            ctx.arc(cx, cy, r + Theme.u * 2, 0, Math.PI * 2);
            ctx.stroke();
            ctx.beginPath();
            for (let k = 0; k <= 5; k++) {
                const a = -Math.PI / 2 + (k * 2 % 5) * 2 * Math.PI / 5;
                const x = cx + Math.cos(a) * r, y = cy + Math.sin(a) * r;
                if (k === 0)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }
            ctx.stroke();
            ctx.fillStyle = "#ff7a2a";
            for (let k = 0; k < 5; k++) {
                const a = -Math.PI / 2 + k * 2 * Math.PI / 5;
                ctx.fillRect(cx + Math.cos(a) * r - Theme.u * 2, cy + Math.sin(a) * r - Theme.u * 2, Theme.u * 4, Theme.u * 4);
            }
        }
    }
}
