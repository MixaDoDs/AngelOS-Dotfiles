pragma ComponentBehavior: Bound

import QtQuick
import qs.services

// serp-skin: rain streaks or snowflakes falling through the weather scene. Each one rides one
// looping 0→1 clock with its own phase (a fixed pseudo-random by its index), so they never fall
// in step; nothing runs unless `live`.
Item {
    id: f
    property bool snow: false
    property int count: 18
    property color tint: "white"
    property bool live: true
    clip: true

    function rnd(i, k) {
        const v = Math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
        return v - Math.floor(v);
    }

    Repeater {
        model: f.count
        Item {
            id: p
            required property int index
            readonly property real r0: f.rnd(index, 1)
            readonly property real r1: f.rnd(index, 2)
            readonly property real r2: f.rnd(index, 3)
            readonly property real len: f.snow ? Serp.px(3 + r2 * 3) : Serp.px(9 + r2 * 9)
            property real t: 0
            NumberAnimation on t {
                running: f.live
                loops: Animation.Infinite
                from: 0
                to: 1
                duration: f.snow ? 4200 + p.r1 * 3000 : 650 + p.r1 * 450
            }
            readonly property real k: (t + r0) % 1
            width: f.snow ? len : Serp.px(1.6)
            height: len
            y: k * (f.height + len) - len
            // rain slants a little (and moves along its slant), snow sways
            x: r1 * (f.width + (f.snow ? 0 : f.height * 0.2)) + (f.snow ? Math.sin((k * 2 + r2) * Math.PI * 2) * Serp.px(6) : -y * 0.2)
            rotation: f.snow ? 0 : 11
            opacity: f.snow ? 0.55 + r2 * 0.45 : 0.35 + r2 * 0.5
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: f.tint
            }
        }
    }
}
