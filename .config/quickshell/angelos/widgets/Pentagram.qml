import QtQuick

// A pentagram in a circle, drawn with lines: hell's achievement card (modules/y2k/AchievementToast)
// and the Angel's diary cover (modules/diary/DiaryBook). `glow` breathes a soft halo behind the
// lines, `spin` turns it slowly (both stop with Motion off: `animate`). `gilded` shades the lines
// like cast metal — a stroke gradient (Qt 6.12 ShapePath.strokeGradient) in three hard bands,
// light on top and dark below, never a smooth blur. Shapes on the GPU: nothing repaints on the CPU.
Item {
    id: root

    property color color: "#f2c75c"
    property color glowColor: color
    property real line: Math.max(1.5, width / 40)
    property bool ring: true                // the circle round it (and a second, thin one)
    property bool inverted: true            // a point down, as hell draws it
    property bool glow: true
    property bool spin: false
    property bool animate: true
    property bool gilded: true
    property real pulse: 0

    implicitWidth: 64
    implicitHeight: 64

    SequentialAnimation on pulse {
        running: root.glow && root.animate && root.visible
        loops: Animation.Infinite
        NumberAnimation {
            to: 1
            duration: 1400
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: 0
            duration: 1400
            easing.type: Easing.InOutSine
        }
    }
    RotationAnimation on rotation {
        running: root.spin && root.animate && root.visible
        loops: Animation.Infinite
        from: 0
        to: 360
        duration: 24000
    }

    // the halo: the same drawing, wide and faint
    PentagramFigure {
        anchors.fill: parent
        visible: root.glow
        opacity: 0.18 + root.pulse * 0.32
        stroke: root.line * 3.2
        tint: root.glowColor
        ring: root.ring
        inverted: root.inverted
    }
    PentagramFigure {
        anchors.fill: parent
        stroke: root.line
        tint: root.color
        shaded: root.gilded
        ring: root.ring
        inverted: root.inverted
    }
}
