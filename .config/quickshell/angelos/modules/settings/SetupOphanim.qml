import QtQuick
import qs.config

// The first run's intro: the ophanim behind the installer (shaders/setup_ophanim.frag, the
// author's parts in data/intro/ophanim.png). It is there from the first second — a shape in the
// dark, a few amber eyes open in it, more of them as the minute goes; lit for one film frame at
// the timeline's `glimpses` (a whisper into each), and for good at its `ophanim` (the flash, the
// choir and the bell: SetupWake, the sound). Every eye follows the pointer — unseen while the
// intro plays — and narrows when it moves; left alone for a while, they look at you.
// Calm motion: no glimpses, and it comes out of the dark over a second.
Item {
    id: root

    property var intro: null
    property bool running: false
    property point pointer: Qt.point(-1, -1)     // in this item, px
    readonly property real t: intro ? intro.t : 0
    readonly property real moment: intro ? intro.timeline.ophanim || 50 : 50
    readonly property bool lit: running && t >= moment

    // ---- the glimpses ----
    property int glimpseNext: 0
    property bool glimpsing: false
    onRunningChanged: {
        glimpseNext = 0;
        glimpsing = false;
    }
    onTChanged: {
        const list = intro ? intro.timeline.glimpses || [] : [];
        if (!running || Motion.calm || glimpseNext >= list.length || t < list[glimpseNext].t)
            return;
        while (glimpseNext < list.length && t >= list[glimpseNext].t)
            glimpseNext++;
        glimpsing = true;
        glimpseOff.restart();
    }
    Timer {
        id: glimpseOff
        interval: 40
        onTriggered: root.glimpsing = false
    }

    // ---- the pointer: they turn to it at once, let go of it slowly, narrow as it moves ----
    property real attend: 0
    property real stir: 0
    onPointerChanged: {
        if (pointer.x < 0 || !running)
            return;
        letGo.stop();
        attend = 1;
        stir = 1;
        widen.restart();
        idle.restart();
    }
    Timer {
        id: idle
        interval: 2500
        onTriggered: letGo.restart()
    }
    NumberAnimation {
        id: letGo
        target: root
        property: "attend"
        to: 0
        duration: 1200
        easing.type: Easing.InOutQuad
    }
    NumberAnimation {
        id: widen
        target: root
        property: "stir"
        to: 0
        duration: 1500
        easing.type: Easing.OutQuad
    }

    Image {
        id: parts
        source: Qt.resolvedUrl("../../data/intro/ophanim.png")
        smooth: false
        visible: false
    }
    ShaderEffect {
        anchors.fill: parent
        readonly property real half: 0.5 * Math.min(width, height)
        property size itemSize: Qt.size(width, height)
        property real px: Math.max(2, Math.floor(Math.min(width, height) / 270))
        // under the installer's window: the great eye looks out from below it
        property point origin: Qt.point(0, width > height ? 0.55 : 0.6)
        property point look: Qt.point((root.pointer.x - width / 2) / half, (root.pointer.y - height / 2) / half)
        property real attend: root.attend
        // wide in the dark, narrow in the light, narrower still while the pointer moves
        property real pupil: (root.lit ? 0.32 : 0.9) * (1 - 0.8 * root.stir)
        property real shown: root.lit ? (Motion.calm ? Math.min(1, root.t - root.moment) : 1) : root.glimpsing ? 0.8 : 0
        property real awake: root.lit ? 1 : 0.06 + 0.5 * Math.max(0, Math.min(1, (root.t - 5) / (root.moment - 5)))
        property real time: root.t
        property var atlas: parts
        fragmentShader: Qt.resolvedUrl("../../shaders/setup_ophanim.frag.qsb")
    }
}
