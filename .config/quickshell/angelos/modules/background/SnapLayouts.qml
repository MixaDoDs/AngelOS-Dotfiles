pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// The green button's Snap Layouts (DesktopMenu.openGreen, services/SnapAssist), as in Windows
// 11: the screen's layouts as little screens split into their parts; the part under the pointer
// lights up, a click snaps the window there and the rest of the layout is offered to the desk's
// other windows. Three to a row, as tall as the screen is to its width.
Item {
    id: root

    property var win: null
    property var screen: null
    property var t: ({})                    // the menu's colours (MenuLook.tokens)
    signal picked

    readonly property int u: Theme.u
    readonly property var layouts: SnapAssist.layoutsFor(screen)
    readonly property real aspect: screen && screen.width > 0 ? screen.height / screen.width : 9 / 16
    readonly property int miniW: (aspect > 1 ? 16 : 30) * u
    readonly property int miniH: Math.round(miniW * aspect / u) * u
    property int perRow: Math.min(3, layouts.length)
    // a point over the layouts that lights the part under it as the pointer would (the snap
    // bar: the pointer is the compositor's while it drags a window), in this item's coordinates
    property point at: Qt.point(-1, -1)
    readonly property var atPart: partAt(at.x, at.y)
    // the layout and the part at x, y: [index, zone], or null
    function partAt(x, y) {
        for (let i = 0; i < layouts.length; i++) {
            const mx = flow.leftPadding + (i % perRow) * (miniW + flow.spacing);
            const my = flow.topPadding + Math.floor(i / perRow) * (miniH + flow.spacing);
            for (const z of layouts[i]) {
                const f = SnapAssist.zones[z];
                if (x >= mx + f[0] * miniW && x < mx + (f[0] + f[2]) * miniW && y >= my + f[1] * miniH && y < my + (f[1] + f[3]) * miniH)
                    return [i, z];
            }
        }
        return null;
    }

    implicitWidth: perRow * miniW + (perRow - 1) * flow.spacing + 8 * u
    implicitHeight: flow.implicitHeight
    width: parent ? parent.width : implicitWidth
    height: visible ? implicitHeight : 0

    Flow {
        id: flow
        width: parent.width
        leftPadding: 4 * root.u
        rightPadding: 4 * root.u
        topPadding: 3 * root.u
        bottomPadding: 3 * root.u
        spacing: 3 * root.u

        Repeater {
            model: root.layouts
            // one layout: a little screen, its parts with a pixel of seam between them
            Rectangle {
                id: mini
                required property var modelData
                required property int index
                width: root.miniW
                height: root.miniH
                color: root.t.edge || Theme.edge
                Repeater {
                    model: mini.modelData
                    Rectangle {
                        id: part
                        required property string modelData
                        readonly property var f: SnapAssist.zones[modelData]
                        // whole art pixels, a seam of one on each side
                        readonly property int x0: Math.round(f[0] * mini.width / root.u) * root.u
                        readonly property int x1: Math.round((f[0] + f[2]) * mini.width / root.u) * root.u
                        readonly property int y0: Math.round(f[1] * mini.height / root.u) * root.u
                        readonly property int y1: Math.round((f[1] + f[3]) * mini.height / root.u) * root.u
                        x: x0 + root.u
                        y: y0 + root.u
                        width: x1 - x0 - 2 * root.u
                        height: y1 - y0 - 2 * root.u
                        readonly property bool lit: hover.containsMouse || (!!root.atPart && root.atPart[0] === mini.index && root.atPart[1] === modelData)
                        color: lit ? (root.t.lit || Theme.select) : (root.t.tileBg || Theme.face)
                        MouseArea {
                            id: hover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.win)
                                    SnapAssist.snap(root.win.id, part.modelData, mini.modelData, root.screen ? root.screen.name : "");
                                root.picked();
                            }
                        }
                    }
                }
            }
        }
    }
}
