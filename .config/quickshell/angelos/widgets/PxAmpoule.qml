pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// A glass ampoule filled to a charge (value 0..1): the bar's device meters (services/Peripherals)
// and the same thing larger in their panel and in Settings. Pixel art drawn from a grid of
// `cols` × `rows` art pixels: the sealed head, the pinched neck with its colour ring (where a
// real one is snapped open), the shoulder, the body.
//   the liquid  `stops` from the bottom (empty) to the top (full). paint "height": the colours
//               run up the glass and the charge cuts them, so the colour it reaches says how
//               much is left; "level": all of it in the colour of its level. `steps`: a colour
//               an art-pixel row; else blended.
//   the ring    the ampoule's lamp: the liquid's top colour, yellow while it charges, red low,
//               grey asleep
//   the level   moves by screen pixels, not art pixels: it sinks smoothly
// Hard edges only: the glint is a column of pixels, the bubbles are squares.
Item {
    id: root

    property real value: 0
    property bool charging: false
    property bool low: false
    property bool asleep: false
    property real dim: 1                    // the rack blinks an almost empty one through this
    property int pixel: Theme.u
    property int cols: 6                    // 4 slim | 6 | 8 wide
    property int rows: 13
    property var stops: [Theme.danger, Theme.accent3, Theme.accent2, Theme.accent]
    property string paint: "height"
    property bool steps: true
    property bool glint: true
    property bool bubbles: true
    property color ink: Theme.text
    property color glass: Qt.alpha(ink, 0.13)
    // the charger's amber, whatever the theme: a wallpaper's palette may have no yellow at all
    property color chargeColor: "#ffcf40"
    property color lowColor: Theme.danger

    readonly property int w: Math.max(4, cols - cols % 2)
    readonly property int h: Math.max(9, rows)
    readonly property int neck: w / 2 - 1                   // the neck's left column (two wide)
    readonly property int bodyRows: h - 5                   // the rows the liquid fills
    readonly property real shownValue: Math.max(0, Math.min(1, value))
    // a drop is always left to see: one screen pixel at 1 %
    readonly property int level: shownValue <= 0 ? 0 : Math.max(1, Math.round(shownValue * bodyRows * pixel))

    implicitWidth: w * pixel
    implicitHeight: h * pixel
    opacity: (asleep ? 0.45 : 1) * dim

    // the colour at t (0 the bottom … 1 the top)
    function sample(t) {
        const s = stops && stops.length ? stops : [Theme.accent];
        if (s.length === 1)
            return Qt.color(s[0]);
        const x = Math.max(0, Math.min(1, t)) * (s.length - 1);
        const i = Math.min(s.length - 2, Math.floor(x));
        return Theme.mix(Qt.color(s[i]), Qt.color(s[i + 1]), x - i);
    }
    readonly property color surface: paint === "level" ? sample(shownValue) : sample(level / Math.max(1, bodyRows * pixel))
    readonly property color ring: asleep ? ink : charging ? chargeColor : low ? lowColor : surface

    // the liquid's whole column as a bitmap of its own: a row an art pixel (steps), or a row a
    // screen pixel (blended), each row one colour
    readonly property var column: {
        const flat = paint === "level";
        const unit = steps || flat ? pixel : 1;
        const n = Math.max(1, Math.round(bodyRows * pixel / unit));
        const across = Math.max(1, Math.round((w - 2) * pixel / unit));
        const rows = [], palette = {};
        for (let i = 0; i < n; i++) {
            // rows from the top; keys the icons' own letters never use
            const key = flat ? "A" : String.fromCharCode(0x100 + i);
            if (!palette[key])
                palette[key] = Theme.hex(flat ? surface : sample((n - 1 - i + 0.5) / n));
            rows.push(key.repeat(across));
        }
        return {
            "rows": rows,
            "palette": palette,
            "unit": unit
        };
    }

    readonly property var bitmap: {
        const line = f => {
            let s = "";
            for (let x = 0; x < w; x++)
                s += f(x);
            return s;
        };
        const inNeck = x => x === neck || x === neck + 1;
        const out = [line(x => inNeck(x) ? "#" : "."), line(x => x === neck - 1 || x === neck + 2 ? "#" : "."), line(x => inNeck(x) ? "k" : "."), line(x => inNeck(x) ? "." : w === 4 || (x > 0 && x < w - 1) ? "#" : ".")];
        for (let y = 4; y < h - 1; y++)
            out.push(line(x => x === 0 || x === w - 1 ? "#" : "."));
        out.push(line(x => x === 0 || x === w - 1 ? "." : "#"));
        return out;
    }

    // the empty glass
    Rectangle {
        x: root.pixel
        y: root.pixel * 4
        width: (root.w - 2) * root.pixel
        height: root.bodyRows * root.pixel
        color: root.glass
    }
    Repeater {
        // the air in the head and in the shoulder
        model: [1, 3]
        Rectangle {
            required property int modelData
            x: root.neck * root.pixel
            y: root.pixel * modelData
            width: root.pixel * 2
            height: root.pixel
            color: root.glass
        }
    }

    // the liquid: the whole column painted, cut at the level
    Item {
        id: cut
        x: root.pixel
        width: (root.w - 2) * root.pixel
        height: root.level
        y: (root.h - 1) * root.pixel - height
        clip: true
        // one picture, shared by every ampoule of the same colours (PxIcon's cache), not a
        // rectangle a row
        PxIcon {
            anchors.bottom: parent.bottom
            bitmap: root.column.rows
            palette: root.column.palette
            iconStyle: "angelos"
            exactPixel: root.column.unit
        }
        // bubbles rise while it charges: squares, moving with the monitor's frames
        Repeater {
            model: root.charging && root.bubbles && !root.asleep && !Motion.still && root.visible ? Math.min(2, Math.max(1, (root.w - 2) / 2)) : 0
            Rectangle {
                id: bubble
                required property int index
                width: root.pixel
                height: root.pixel
                x: (index === 0 ? 0 : root.w - 3) * root.pixel
                y: cut.height
                color: Qt.alpha("#ffffff", 0.75)
                SequentialAnimation {
                    running: true
                    loops: Animation.Infinite
                    PauseAnimation {
                        duration: bubble.index * 700
                    }
                    NumberAnimation {
                        target: bubble
                        property: "y"
                        from: cut.height
                        to: -root.pixel
                        duration: 1500 + bubble.index * 500
                    }
                    PauseAnimation {
                        duration: 900 - bubble.index * 400
                    }
                }
            }
        }
        // the surface: one lighter line, so the level reads against a liquid of one colour
        Rectangle {
            visible: root.level > root.pixel && root.shownValue < 1
            width: parent.width
            height: Math.max(1, Math.round(root.pixel / 2))
            color: Theme.mix(root.surface, "#ffffff", 0.45)
        }
    }

    // the glass's highlight: a column of pixels, never a blur
    Rectangle {
        visible: root.glint && root.w >= 6 && !root.asleep
        x: root.pixel
        y: root.pixel * 5
        width: root.pixel
        height: root.pixel * Math.min(3, root.bodyRows - 3)
        color: Qt.alpha("#ffffff", 0.5)
    }

    PxIcon {
        bitmap: root.bitmap
        pixel: root.pixel
        iconStyle: "angelos"
        ink: root.ink
        palette: ({
                "k": Theme.hex(root.ring)
            })
    }
}
