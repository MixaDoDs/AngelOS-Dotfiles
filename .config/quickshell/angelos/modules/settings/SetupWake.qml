import QtQuick
import qs.config

// Waking up, over one screen of the setup wizard while its first-run intro plays (SetupIntro):
// the screen (`source`: the cover's picture) drawn through shaders/setup_wake.frag — blocks for a
// blur, red and blue apart towards the edges, a blocky glow, fire from below, the dark round the
// edges, eyelids opening and blinking, a white flash — all of it growing over the minute, the
// screen shaking with the booms; after the cut it all fades off the wizard. Calm motion: no
// shaking, no flashes, half the split. Off (and drawing the screen as it is) once it is over.
Item {
    id: root

    property var intro: null
    property Item source: null
    // (not while its sound is being made: the installer shows as it is, then the eyes shut and open)
    // (alone it already blurs the desktop behind its question, and keeps that blur on through)
    readonly property bool on: !!intro && !!source && (intro.phase === "ask" || intro.active && (intro.phase !== "bake" || alone))
    readonly property real askIn: intro ? intro.askIn : 0
    readonly property real askBlur: intro ? intro.askBlur : 1
    readonly property real t: intro ? intro.t : 0
    readonly property real k: Math.min(1, t / (intro ? intro.length : 60))
    readonly property string phase: intro ? intro.phase : ""
    // after an update: the desktop darkens into it, no eyes opening at the start
    readonly property bool alone: !!intro && intro.alone
    // after the cut: everything fades to nothing
    readonly property real fade: phase === "reveal" ? 1 - intro.reveal : 1
    property real kick: 0                    // a shake's jolt (the split and the glow jump with it)

    ShaderEffectSource {
        id: picture
        width: root.width
        height: root.height
        visible: false
        sourceItem: root.on ? root.source : null
        hideSource: root.on
        live: true
        mipmap: true
        smooth: true
    }
    Rectangle {
        anchors.fill: parent
        visible: root.on
        color: "#000000"
    }
    ShaderEffect {
        id: wake
        visible: root.on
        width: root.width
        height: root.height
        property var source: picture
        property size itemSize: Qt.size(width, height)
        readonly property real u: Theme.u
        property real aberr: (3 + 45 * Math.pow(root.k, 2) + 16 * root.kick) * (Motion.calm ? 0.5 : 1) * root.fade * (root.phase === "bake" ? 0 : root.phase === "ask" ? root.askIn : 1)
        // the blur: waking for a few seconds, then sharp, and only in the last ten it smears again
        property real pix: {
            if (root.phase === "ask")
                return 1 + (root.askBlur - 1) * root.askIn;
            if (root.phase === "bake")
                return root.alone ? root.askBlur : 12;
            let p = 1;
            if (root.alone && root.t < 6)          // from the question's blur smearing on, then sharp
                p = root.t < 2 ? root.askBlur + (8 - root.askBlur) * root.t / 2 : 1 + 7 * Math.pow(1 - (root.t - 2) / 4, 2);
            else if (root.t < 6)
                p = 1 + 7 * Math.pow(1 - root.t / 6, 2);
            else if (root.t > 50)
                p = 1 + 7 * Math.pow((root.t - 50) / 10, 2);
            if (root.phase === "reveal")
                p = 1 + 4 * root.fade;
            return 1 + (p - 1) * root.fade;
        }
        // the glow: a hint until the ophanim, then more and more
        property real glow: (0.06 + 0.5 * Math.pow(Math.max(0, (root.t - 40) / 20), 2) + 0.3 * root.kick) * root.fade
        property real glowPx: u * 12
        property real vign: (root.phase === "ask" ? 0 : root.phase === "bake" ? (root.alone ? 0 : 0.9) : (0.75 - 0.35 * Math.min(1, root.t / 8) + 0.4 * root.k) * (root.alone ? Math.min(1, root.t / 2) : 1)) * root.fade
        property real fire: Math.max(0, Math.min(1, (root.t - 18) / 40)) * 0.85 * root.fade
        property real flicker: 0.5 + 0.5 * Math.sin(root.t * 21) * Math.sin(root.t * 6.7 + 1)
        // white for a blink, not a grey wash: the strongest jolts, and the cut
        property real flash: Motion.calm ? 0 : root.phase === "reveal" ? (root.intro.reveal < 0.03 ? 0.85 : 0) : root.kick > 0.8 ? 0.5 : 0
        // the eyes: shut while it is made ready, opening in the first second and a half, a few
        // blinks while still waking
        property real lid: {
            if (root.phase === "bake")
                return root.alone ? 0 : 0.85;
            if (root.phase !== "run")
                return 0;
            if (root.t < 1.4)
                return root.alone ? 0 : 1 - root.t / 1.4;
            for (const b of (root.alone ? [] : root.intro.timeline.blinks || [])) {
                const d = root.t - b;
                if (d >= 0 && d < 0.12)
                    return d / 0.12;
                if (d >= 0.12 && d < 0.42)
                    return 1 - (d - 0.12) / 0.3;
            }
            return 0;
        }
        property real step: u * 4
        fragmentShader: Qt.resolvedUrl("../../shaders/setup_wake.frag.qsb")
    }

    // ---- shaking: jolts with the booms, a tremble in the last seconds ----
    Connections {
        target: root.intro
        function onShook(strength) {
            root.kick = strength;
            kickFade.restart();
            if (!Motion.calm) {
                shake.amp = Theme.u * Math.round(2 + 12 * strength);
                shake.left = 9;
            }
        }
    }
    NumberAnimation {
        id: kickFade
        target: root
        property: "kick"
        to: 0
        duration: 700
        easing.type: Easing.OutQuad
    }
    Timer {
        id: shake
        property real amp: 0
        property int left: 0
        interval: 33
        repeat: true
        running: root.on && root.phase === "run" && !Motion.calm
        onTriggered: {
            const tremble = root.k > 0.8 ? Theme.u * Math.round(3 * (root.k - 0.8) / 0.2) : 0;
            let a = tremble;
            if (left > 0) {
                a = Math.max(a, amp * left / 9);
                left--;
            }
            wake.x = Math.round((Math.random() * 2 - 1) * a / Theme.u) * Theme.u;
            wake.y = Math.round((Math.random() * 2 - 1) * a / Theme.u) * Theme.u;
        }
        onRunningChanged: if (!running) {
            wake.x = 0;
            wake.y = 0;
        }
    }
}
