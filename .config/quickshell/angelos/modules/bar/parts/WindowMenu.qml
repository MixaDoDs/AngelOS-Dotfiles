pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Right-click menu of a window button: the shared pixel menu (widgets/PxMenu), what it holds
// from services/DeskMenu (target "task": Settings → Right-click menu), the window's icon and
// name over it.
PxMenu {
    id: root

    required property Item anchorItem
    property bool above: true
    property var win: null                 // niri window object

    function openFor(item, w) {
        win = w;
        // the bar's window coordinates: PxMenu anchors to parentWindow
        const p = item.mapToItem(null, 0, 0);
        // a taskbar on the left or the right: beside the button, from its top down
        anchor.rect.width = side ? 1 : item.width;
        anchor.rect.height = side ? item.height : 1;
        // the entries as they are now: a live list would rebuild its rows (and lose the
        // keyboard's place) whenever any window changes
        const m = DeskMenu.menu("task", {
            "screen": parentWindow && parentWindow.screen ? parentWindow.screen.name : "",
            "win": w
        });
        quick = m.quick;
        popup(m.items, "", side === "left" ? p.x + item.width + Theme.u * 2 : side === "right" ? p.x - Theme.u * 2 : p.x, side ? p.y : above ? p.y : p.y + item.height);
    }
    parentWindow: anchorItem ? anchorItem.QsWindow.window : null
    kind: "task"
    panelId: "window-menu"
    property string side: BarLayout.side
    anchor.edges: side === "left" ? Edges.Top | Edges.Right : side === "right" ? Edges.Top | Edges.Left : above ? Edges.Top | Edges.Left : Edges.Bottom | Edges.Left
    anchor.gravity: side === "left" ? Edges.Bottom | Edges.Right : side === "right" ? Edges.Bottom | Edges.Left : above ? Edges.Top | Edges.Right : Edges.Bottom | Edges.Right

    // the window's icon and name over the entries
    header: [
        Item {
            id: head
            readonly property var t: MenuLook.tokens(root.look)
            width: parent ? parent.width : 0
            height: Theme.u * 16
            AppIcon {
                x: Theme.u * 5
                anchors.verticalCenter: parent.verticalCenter
                appId: root.win ? root.win.app_id || "" : ""
                size: Theme.u * 9
            }
            PxText {
                x: Theme.u * 18
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Theme.u * 24
                text: root.win ? Niri.titleOf(root.win) || root.win.app_id || "?" : ""
                elide: Text.ElideRight
                font.bold: true
                color: head.t.text
                style: head.t.outlineText !== "transparent" ? Text.Outline : Text.Normal
                styleColor: head.t.outlineText
            }
        },
        PxMenuItem {
            separator: true
        }
    ]
}
