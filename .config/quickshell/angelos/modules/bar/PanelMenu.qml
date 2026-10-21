import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// The bar's own right-click menu: the shared pixel menu (widgets/PxMenu), what it holds from
// services/DeskMenu (target "panel": Settings → Right-click menu).
PxMenu {
    id: root
    required property Item anchorItem
    property bool above: true
    // x, y in anchorItem; the menu hangs off the bar's window (PxMenu anchors to parentWindow)
    function openAt(x, y) {
        DesktopActions.refresh();
        const p = anchorItem.mapToItem(null, x, y);
        const m = DeskMenu.menu("panel", {
            "screen": parentWindow && parentWindow.screen ? parentWindow.screen.name : ""
        });
        quick = m.quick;
        items = m.items;
        show(p.x, p.y);
    }

    parentWindow: anchorItem ? anchorItem.QsWindow.window : null
    kind: "panel"
    panelId: "panel-menu"
    // a taskbar on the left or the right (BarLayout.side): the menu grows away from that edge
    property string side: BarLayout.side
    anchor.edges: above ? Edges.Top | Edges.Left : Edges.Bottom | Edges.Left
    anchor.gravity: side === "left" ? Edges.Bottom | Edges.Right : side === "right" ? Edges.Bottom | Edges.Left : above ? Edges.Top | Edges.Right : Edges.Bottom | Edges.Right
}
