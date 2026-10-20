import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// The bar's own right-click menu: the shared pixel menu (widgets/PxMenu) in the "panel" look.
PxMenu {
    id: root
    required property Item anchorItem
    property bool above: true
    // x, y in anchorItem; the menu hangs off the bar's window (PxMenu anchors to parentWindow)
    function openAt(x, y) {
        DesktopActions.refresh();
        const p = anchorItem.mapToItem(null, x, y);
        show(p.x, p.y);
    }

    parentWindow: anchorItem ? anchorItem.QsWindow.window : null
    kind: "panel"
    panelId: "panel-menu"
    // the 2004 looks carry a title bar; classic stays as it was, without one
    title: look === "save" || look === "sticker" ? I18n.t("Панель", "Taskbar") : ""
    // a taskbar on the left or the right (BarLayout.side): the menu grows away from that edge
    property string side: BarLayout.side
    anchor.edges: above ? Edges.Top | Edges.Left : Edges.Bottom | Edges.Left
    anchor.gravity: side === "left" ? Edges.Bottom | Edges.Right : side === "right" ? Edges.Bottom | Edges.Left : above ? Edges.Top | Edges.Right : Edges.Bottom | Edges.Right

    items: [
        {
            "label": I18n.t("Диспетчер задач", "Task Manager"),
            "hint": Config.system.monitor === "custom" ? "" : DesktopActions.selectedMonitor ? DesktopActions.selectedMonitor.label : "",
            "icon": "chip",
            "enabled": () => DesktopActions.available,
            "run": () => DesktopActions.launchMonitor()
        },
        {
            "label": I18n.t("Выбрать системный монитор…", "Choose system monitor…"),
            "icon": "gear",
            "run": () => Shell.openSettings("taskmanager")
        },
        {
            "separator": true
        },
        {
            "label": I18n.t("Настройки панели", "Taskbar settings"),
            "icon": "window",
            "run": () => Shell.openSettings("bar")
        }
    ]
}
