import QtQuick
import qs.config
import qs.widgets

// Preview: the taskbar on its edge (variant: bottom | top | left | right). It slides in from
// that edge, then a window opens and gets its button.
Scene {
    id: root

    readonly property string edge: ["bottom", "top", "left", "right"].includes(variant) ? variant : "bottom"
    readonly property bool upright: edge === "left" || edge === "right"
    readonly property int thick: Theme.u * 9
    readonly property int s: Math.max(1, Math.round(Theme.u / 2))
    readonly property real slide: 1 - ease(seg(0, 0.25))
    readonly property real opened: ease(seg(0.4, 0.65))

    // a window that opens in the middle
    MiniWindow {
        width: root.width * 0.42
        height: root.height * 0.5
        x: (root.width - width) / 2
        y: (root.height - height) / 2
        opacity: root.opened
        scale: 0.85 + 0.15 * root.opened
    }

    Item {
        id: bar
        width: root.upright ? root.thick : root.width
        height: root.upright ? root.height : root.thick
        x: root.edge === "right" ? root.width - width + root.slide * width : root.edge === "left" ? -root.slide * width : 0
        y: root.edge === "bottom" ? root.height - height + root.slide * height : root.edge === "top" ? -root.slide * height : 0
        Rectangle {
            anchors.fill: parent
            color: Theme.face
            border.width: root.s
            border.color: Theme.lo
        }
        // Start, two windows, the one that opens; the clock at the far end
        Repeater {
            model: 4
            Rectangle {
                required property int index
                readonly property real cell: root.thick - root.s * 4
                readonly property real at: root.s * 2 + index * (root.upright ? cell + root.s * 2 : (index === 0 ? 0 : cell * 1.6 + cell * 3 * (index - 1) + root.s * 2 * index))
                visible: index < 3 || root.opened > 0.5
                x: root.upright ? root.s * 2 : at
                y: root.upright ? at : root.s * 2
                width: root.upright || index === 0 ? cell : cell * 3
                height: cell
                color: index === 0 ? Theme.accent : index === 3 ? Theme.mix(Theme.faceAlt, Theme.accent, 0.35) : Theme.faceAlt
                border.width: root.s
                border.color: Theme.lo
            }
        }
        Rectangle {
            readonly property real cell: root.thick - root.s * 4
            x: root.upright ? root.s * 2 : bar.width - width - root.s * 2
            y: root.upright ? bar.height - height - root.s * 2 : root.s * 2
            width: root.upright ? cell : cell * 2.4
            height: cell
            color: Theme.sunken
            border.width: root.s
            border.color: Theme.lo
        }
    }
}
