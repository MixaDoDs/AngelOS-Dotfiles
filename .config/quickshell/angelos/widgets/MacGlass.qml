import QtQuick
import QtQuick.Effects
import qs.services

// Liquid Glass of the Golden Gate skin: a rounded slab in the glass tint (Config.mac.glass:
// clear … tinted), a darker outer edge, a bright inner highlight along the top and a soft
// shadow under it. Behind it the window asks niri for blur (BackgroundEffect) where it can.
Item {
    id: root

    property real radius: GoldenGate.menuRadius
    property color fill: GoldenGate.glassFill
    property bool shadow: true
    property real shadowSize: GoldenGate.px(28)
    property real shadowY: GoldenGate.px(8)
    property bool highlight: true
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
        border.width: 1
        border.color: GoldenGate.glassEdge
        // the specular rim: brighter at the top, fading down the sides
        Rectangle {
            visible: root.highlight
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, root.radius - 1)
            color: "transparent"
            border.width: 1
            border.color: GoldenGate.glassHighlight
            opacity: 0.9
        }
    }
    Item {
        id: inner
        anchors.fill: parent
    }
}
