import QtQuick
import QtQuick.Shapes
import qs.config

// The P5 window's background, all on the art-pixel grid: rays turning round a point in steps
// (a full turn in 90 s), the accent slab that wipes across when the section changes (wipe()),
// stars that flash here and there. `water` (the light theme, the angel): Persona 3 Reload's deep
// water instead of the rays and the stars (shaders/p3_water.frag). Motion off: it all stands.
Item {
    id: root

    property color base: "#1d1026"
    property color base2: "#2a1838"
    property color slab: "#ff2d8a"
    property color star: "#f6eefc"
    // where the rays turn round, in fractions of the window
    property real cx: 0.5
    property real cy: 0.5
    // the slab: its width in fractions of the window
    property real slabWidth: 0.55
    property bool still: false
    property bool water: false
    // the water's colours: the deep, the surface, the glints
    property color deep: "#0a2a6e"
    property color shallow: "#5fc8ff"
    property color glint: "#eaffff"

    function wipe() {
        if (still)
            return;
        slabRun.restart();
    }

    Item {
        id: canvas
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: false
        layer.textureSize: Qt.size(Math.max(1, Math.round(width / Theme.u)), Math.max(1, Math.round(height / Theme.u)))
        clip: true

        Rectangle {
            anchors.fill: parent
            color: root.base
            antialiasing: false
        }
        // ---- P3's water: at one texel per art pixel (this layer's size), 8 steps a second ----
        ShaderEffect {
            id: waterFx
            visible: root.water
            anchors.fill: parent
            property color deep: root.deep
            property color shallow: root.shallow
            property color glint: root.glint
            property size size: Qt.size(Math.max(1, Math.round(width / Theme.u)), Math.max(1, Math.round(height / Theme.u)))
            property real time: 0
            fragmentShader: Qt.resolvedUrl("../../../shaders/p3_water.frag.qsb")
            Timer {
                running: root.water && !root.still && root.visible
                repeat: true
                interval: 125
                onTriggered: waterFx.time += 0.125
            }
        }
        // ---- rays ----
        Shape {
            id: rays
            visible: !root.water
            readonly property real r: Math.hypot(root.width, root.height)
            x: root.width * root.cx - r
            y: root.height * root.cy - r
            width: r * 2
            height: r * 2
            antialiasing: false
            property int step: 0
            rotation: step * 2
            ShapePath {
                strokeWidth: -1
                fillColor: root.base2
                PathPolyline {
                    path: {
                        const out = [], r = rays.r;
                        for (let i = 0; i < 20; i++) {
                            const a = i * 18 * Math.PI / 180, b = (i * 18 + 9) * Math.PI / 180;
                            out.push(Qt.point(r, r), Qt.point(r + Math.cos(a) * r, r + Math.sin(a) * r), Qt.point(r + Math.cos(b) * r, r + Math.sin(b) * r), Qt.point(r, r));
                        }
                        return out;
                    }
                }
            }
            Timer {
                running: !root.still && root.visible
                repeat: true
                interval: 500
                onTriggered: rays.step = (rays.step + 1) % 180
            }
        }
        // ---- the slab ----
        Shape {
            id: slab
            property real shift: 0
            readonly property real w: root.width * root.slabWidth
            x: -root.width * 0.2 + shift * root.width
            y: -root.height * 0.4
            width: w
            height: root.height * 1.9
            rotation: 16
            antialiasing: false
            opacity: 0.92
            ShapePath {
                strokeWidth: -1
                fillColor: root.slab
                PathPolyline {
                    path: [Qt.point(0, 0), Qt.point(slab.w, 0), Qt.point(slab.w, slab.height), Qt.point(0, slab.height), Qt.point(0, 0)]
                }
            }
            SequentialAnimation {
                id: slabRun
                NumberAnimation {
                    target: slab
                    property: "shift"
                    from: -0.6
                    to: 0.06
                    duration: 270
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: slab
                    property: "shift"
                    to: 0
                    duration: 180
                }
            }
        }
        // ---- stars ----
        Repeater {
            id: stars
            model: root.water ? 0 : 7
            Shape {
                id: st
                required property int index
                property real t: 0
                // four steps: in, big, turned, gone
                readonly property real q: Math.floor(t * 4) / 4
                width: Theme.u * 12
                height: width
                antialiasing: false
                opacity: q <= 0 ? 0 : q < 0.5 ? 0.9 : q < 1 ? 0.5 : 0
                scale: q < 0.25 ? 0.4 : q < 0.5 ? 1.3 : q < 0.75 ? 1.0 : 0.8
                rotation: q * 50
                ShapePath {
                    strokeWidth: -1
                    fillColor: root.star
                    PathPolyline {
                        readonly property real h: st.width / 2
                        readonly property real k: st.width * (st.index % 3 === 0 ? 0.12 : 0.18)
                        path: [Qt.point(h, 0), Qt.point(h + k, h - k), Qt.point(st.width, h), Qt.point(h + k, h + k), Qt.point(h, st.width), Qt.point(h - k, h + k), Qt.point(0, h), Qt.point(h - k, h - k), Qt.point(h, 0)]
                    }
                }
                NumberAnimation on t {
                    id: pop
                    running: false
                    from: 0
                    to: 1
                    duration: 600
                }
                function flash() {
                    const s = 0.6 + Math.random() * 2.4;
                    width = Theme.u * Math.round(6 * s);
                    x = root.width * (0.55 + Math.random() * 0.41);
                    y = root.height * (0.05 + Math.random() * 0.85);
                    pop.restart();
                }
            }
        }
        Timer {
            id: twinkle
            running: !root.still && root.visible
            repeat: true
            interval: 260 + Math.random() * 260
            onTriggered: {
                const st = stars.itemAt(Math.floor(Math.random() * 7));
                if (st && st.flash)
                    st.flash();
                interval = 260 + Math.random() * 260;
            }
        }
    }
}
