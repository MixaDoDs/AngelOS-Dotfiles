import QtQuick
import Quickshell
import qs.config

// A tip in RetroUI's speech bubble: a cream plate, an ink outline, a hard shadow stepped
// down-right, a stepped tail pointing at what it is about. The bar's icons show it after the
// pointer rests on them a moment (BarItem).
//   anchorItem · text · above (the tail points down: the bubble stands over the item)
PopupWindow {
    id: root

    property Item anchorItem: null
    property string text: ""
    property bool above: true

    readonly property int u: Theme.u
    readonly property int tail: u * 3
    readonly property int shadow: u * 2
    readonly property color paper: "#fff3c4"
    readonly property color ink: "#141016"

    anchor.item: anchorItem
    anchor.rect.x: 0
    anchor.rect.y: above ? -u : (anchorItem ? anchorItem.height : 0) + u
    anchor.rect.width: anchorItem ? anchorItem.width : 1
    anchor.rect.height: 1
    anchor.edges: above ? Edges.Top : Edges.Bottom
    anchor.gravity: above ? Edges.Top : Edges.Bottom
    anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.Flip
    color: "transparent"
    implicitWidth: Math.min(u * 160, label.implicitWidth + u * 10) + shadow
    implicitHeight: label.implicitHeight + u * 8 + tail + shadow

    // the plate's shadow, then the plate
    Rectangle {
        x: root.shadow
        y: (root.above ? 0 : root.tail) + root.shadow
        width: plate.width
        height: plate.height
        color: root.ink
    }
    Rectangle {
        id: plate
        y: root.above ? 0 : root.tail
        width: parent.width - root.shadow
        height: parent.height - root.tail - root.shadow
        color: root.paper
        border.width: root.u
        border.color: root.ink
        PxText {
            id: label
            anchors.centerIn: parent
            width: Math.min(implicitWidth, root.u * 150)
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            text: root.text
            kind: "tiny"
            color: root.ink
        }
    }
    // the tail: three stepped rows at the middle of the item, ink edges, paper inside
    Repeater {
        model: 3
        Item {
            required property int index
            readonly property int half: (3 - index) * root.u
            x: Math.round(plate.width / 2 / root.u) * root.u - half
            y: root.above ? plate.height + index * root.u - root.u : root.tail - (index + 1) * root.u + root.u
            width: half * 2
            height: root.u
            Rectangle {
                anchors.fill: parent
                color: root.ink
            }
            Rectangle {
                visible: parent.half > root.u
                x: root.u
                width: parent.width - root.u * 2
                height: root.u
                color: root.paper
            }
        }
    }

    RightClickGuard {}
}
