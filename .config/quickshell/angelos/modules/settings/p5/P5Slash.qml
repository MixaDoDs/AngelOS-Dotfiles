import QtQuick
import qs.config

// The P5 window's cut, as the approved mockup played it (stage/settings-p5/p5-v9.html, the owner
// liked it best): her silhouette, huge, black with an accent edge, sweeps over the window
// diagonally in a few hard steps; `covered` is the moment it is over the card, for the card and
// the figure to change under it. The silhouette is a still of the figure as the cut begins
// (`sprite`: P5Doll's, at art resolution).
Item {
    id: root

    property color black: "#000000"
    property color accent: "#ff2d8a"
    property bool still: false
    property Item sprite: null
    // her eyes on the sprite's texture (P5Doll.eyeSpots, eyeR), burning on the black silhouette in `glow`
    property vector4d eyes: Qt.vector4d(0, 0, 0, 0)
    property size eyeR: Qt.size(0, 0)
    property color glow: "white"
    property vector4d shotEyes: Qt.vector4d(0, 0, 0, 0)
    property size shotEyeR: Qt.size(0, 0)
    signal covered

    property int dir: 1
    property real t: 0
    readonly property int steps: 7
    readonly property real q: Math.floor(t * steps) / steps
    visible: run.running && q > 0 && q < 1

    function cut(d) {
        if (still || !sprite) {
            covered();
            return;
        }
        dir = d || 1;
        shotEyes = eyes;
        shotEyeR = eyeR;
        snap.scheduleUpdate();
        t = 0;
        coveredSent = false;
        run.restart();
    }
    property bool coveredSent: false
    onQChanged: if (!coveredSent && q >= 0.55) {
        coveredSent = true;
        covered();
    }
    NumberAnimation {
        id: run
        target: root
        property: "t"
        from: 0
        to: 1
        duration: 380
    }

    ShaderEffectSource {
        id: snap
        sourceItem: root.sprite
        live: false
        smooth: false
        // drawn by the two Sil below, never itself (still made while invisible: hidden by
        // being under them, not by visible: false, or the still is never taken)
        width: 1
        height: 1
        opacity: 0
        sourceRect: Qt.rect(-16, -16, 288, 416)
    }
    // across the window, a little rise, leaning against the way it goes
    Item {
        id: sil
        width: 288
        height: 416
        readonly property real k: root.height * 1.35 / 384
        transform: [
            Translate {
                x: -144
                y: -208
            },
            Scale {
                xScale: root.dir * sil.k
                yScale: sil.k
            },
            Rotation {
                angle: -root.dir * 12
            },
            Translate {
                readonly property real a: -0.6 * root.width
                readonly property real b: 1.6 * root.width
                x: root.dir > 0 ? a + (b - a) * root.q : b + (a - b) * root.q
                y: root.height * (0.55 - 0.08 * root.q)
            }
        ]
        Sil {
            x: -6
            y: 4
            solid: root.accent
        }
        Sil {
            solid: root.black
            eyes: root.shotEyes
            eyeR: root.shotEyeR
            glow: root.glow
        }
    }
    component Sil: ShaderEffect {
        width: 288
        height: 416
        property var source: snap
        property color dark: "black"
        property color light: "black"
        property color accent: "black"
        property color solid: "black"
        property vector4d eyes: Qt.vector4d(0, 0, 0, 0)
        property size eyeR: Qt.size(0, 0)
        property color glow: "white"
        fragmentShader: Qt.resolvedUrl("../../../shaders/p5_mask.frag.qsb")
    }
}
