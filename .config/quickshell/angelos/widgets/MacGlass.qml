import QtQuick
import QtQuick.Effects
import qs.services

// Liquid Glass of the Golden Gate skin: a rounded slab in the glass tint (Config.mac.glass:
// clear … tinted) and a soft shadow under it. Behind it the window asks niri for blur and
// saturation (BackgroundEffect, GoldenGate.blurOn). Over the tint the rim: with the glass on
// (GoldenGate.glassFx) shaders/liquid_glass.frag — the specular edge and the lens's light; with
// Reduce transparency, game mode or hell the plain 1 px edge and highlight, and no shader at all
// (the Loader drops it). The shader has no time in it: it is drawn only when the window draws.
Item {
    id: root

    property real radius: GoldenGate.menuRadius
    property color fill: GoldenGate.glassFill
    property bool shadow: true
    property real shadowSize: GoldenGate.px(28)
    property real shadowY: GoldenGate.px(8)
    property bool highlight: true
    // the lens's reach and strength (small things — a menu row, a capsule — less)
    property real bevel: Math.min(GoldenGate.px(14), Math.min(width, height) * 0.3)
    property real refraction: 1
    default property alias content: inner.data

    RectangularShadow {
        visible: root.shadow
        anchors.fill: slab
        offset.y: root.shadowY
        radius: root.radius
        blur: root.shadowSize
        spread: -GoldenGate.px(2)
        color: GoldenGate.shadow
        cached: true
    }
    Rectangle {
        id: slab
        anchors.fill: parent
        radius: root.radius
        color: root.fill
        border.width: rim.active ? 0 : 1
        border.color: GoldenGate.glassEdge
        // the specular rim (solid glass): brighter at the top, fading down the sides
        Rectangle {
            visible: root.highlight && !rim.active
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, root.radius - 1)
            color: "transparent"
            border.width: 1
            border.color: GoldenGate.glassHighlight
            opacity: 0.9
        }
    }
    Loader {
        id: rim
        anchors.fill: parent
        active: root.highlight && GoldenGate.glassFx && root.width > 0 && root.height > 0
        sourceComponent: ShaderEffect {
            readonly property size size: Qt.size(root.width, root.height)
            readonly property real radius: root.radius
            readonly property real bevel: root.bevel
            readonly property real strength: 1
            readonly property real refraction: root.refraction * (0.6 + 0.4 * (1 - GoldenGate.tint))
            readonly property real dark: GoldenGate.dark ? 1 : 0
            readonly property color highlight: GoldenGate.dark ? Qt.rgba(1, 1, 1, 0.42) : Qt.rgba(1, 1, 1, 0.95)
            readonly property color edge: GoldenGate.glassEdge
            fragmentShader: Qt.resolvedUrl("../shaders/liquid_glass.frag.qsb")
        }
    }
    Item {
        id: inner
        anchors.fill: parent
    }
}
