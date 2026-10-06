pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.widgets

// The unlock's second half, in an overlay above the desktop (Lock.qml): the lock's last
// picture (`shot`) is put up while still locked, the lock goes, and the picture leaves
// over the desktop that is already there underneath (shaders/unlock_reveal).
//   heart   a pixel-heart hole grows from the password box, hearts fly out of it
//   pixels  the picture coarsens into blocks that blink out with sparkles
//   crt     "stream ended": an old TV folds into a line, the desktop opens from it
//   gate    heaven's gate: the picture parts like two doors, light pours out
//   glitch  bands jump into RGB and drop out
Item {
    id: root

    property url shot
    property string style: "heart"
    property point origin: Qt.point(0.5, 0.5)
    property bool go: false
    property bool primary: true
    readonly property int duration: ({
            "heart": 900,
            "pixels": 1000,
            "crt": 820,
            "gate": 1100,
            "glitch": 700
        })[style] || 900
    property real progress: 0

    Image {
        id: pic
        anchors.fill: parent
        source: root.shot
        asynchronous: false
        cache: false
        smooth: false
        visible: false
    }
    // no picture (the grab took too long): the theme's desk colour stands in
    Rectangle {
        id: plain
        anchors.fill: parent
        color: Theme.desk
        visible: false
    }
    ShaderEffect {
        anchors.fill: parent
        property var source: ShaderEffectSource {
            sourceItem: pic.status === Image.Ready ? pic : plain
            hideSource: true
        }
        property real progress: root.progress
        property real style: ["heart", "pixels", "crt", "gate", "glitch"].indexOf(root.style)
        property real cell: Theme.u
        property size resolution: Qt.size(width, height)
        property point origin: root.origin
        property color accent: Theme.accent
        property color light: root.style === "gate" ? "#fff6d8" : "#ffffff"
        fragmentShader: Qt.resolvedUrl("../../shaders/unlock_reveal.frag.qsb")
    }

    // hearts out of the hole, feathers out of the gate
    HeartBurst {
        id: burst
        anchors.fill: parent
        poolSize: 64
    }

    NumberAnimation {
        id: run
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: Motion.still ? 1 : root.duration
        easing.type: root.style === "crt" ? Easing.Linear : Easing.InOutQuad
    }
    onGoChanged: if (go) {
        run.restart();
        if (!root.primary || Motion.still)
            return;
        if (style === "heart")
            burst.burst(origin.x * width, origin.y * height, 48, Theme.u * 12);
        else if (style === "pixels" || style === "gate")
            burst.burst(width / 2, height / 2, style === "gate" ? 28 : 20, Theme.u * 9);
    }
}
