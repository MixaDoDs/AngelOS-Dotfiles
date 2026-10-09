import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

PopupWindow {
    id: root
    required property Item anchorItem
    property bool above: true
    property string title: I18n.t("Панель", "Taskbar")
    property string panelId: "panel-menu"
    readonly property string outputName: anchorItem && anchorItem.QsWindow.window && anchorItem.QsWindow.window.screen ? anchorItem.QsWindow.window.screen.name : ""
    Component.onCompleted: PopupManager.registerPopup(root)
    Component.onDestruction: PopupManager.unregisterPopup(root)
    // Reopening in the same event would reuse the old surface position, so a
    // visible menu is closed first and shown again on the next turn of the loop;
    // clicks while that is pending only move the target (fast double right-click).
    property bool reopening: false
    function openAt(x, y) {
        anchor.rect.x = x;
        anchor.rect.y = y;
        if (!visible && !reopening) {
            visible = true;
            return;
        }
        visible = false;
        if (reopening)
            return;
        reopening = true;
        Qt.callLater(() => {
            if (!reopening)
                return;
            reopening = false;
            anchor.updateAnchor();
            visible = true;
        });
    }
    function run(action) {
        reopening = false;
        visible = false;
        action();
    }
    anchor.item: anchorItem
    anchor.rect.width: 1
    anchor.rect.height: 1
    // a taskbar on the left or the right (BarLayout.side): the menu grows away from that edge
    property string side: BarLayout.side
    anchor.edges: above ? Edges.Top | Edges.Left : Edges.Bottom | Edges.Left
    anchor.gravity: side === "left" ? Edges.Bottom | Edges.Right : side === "right" ? Edges.Bottom | Edges.Left : above ? Edges.Top | Edges.Right : Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
    grabFocus: true
    visible: false
    color: "transparent"
    implicitWidth: frame.width + Theme.u * 3
    implicitHeight: frame.height + Theme.u * 3
    onVisibleChanged: {
        if (visible) {
            DesktopActions.refresh();
            if (PopupManager.active && PopupManager.active !== root)
                PopupManager.close(PopupManager.active);
            PopupManager.active = root;
        } else if (PopupManager.active === root)
            PopupManager.active = null;
    }
    BackgroundEffect.blurRegion: Config.appearance.blur ? blurRegion : null
    Region { id: blurRegion; item: frame }
    PxBox {
        id: frame
        width: Math.max(Theme.u * 145, ...column.children.map(child => child.implicitWidth || 0)) + inset * 2
        height: column.implicitHeight + inset * 2
        color: Qt.alpha(Theme.menuSurface, Theme.panelAlpha)
        shadow: Config.appearance.shadows
        focus: true
        Keys.onEscapePressed: root.visible = false
        Column {
            id: column
            width: parent.width
            PxMenuItem {
                text: I18n.t("Диспетчер задач", "Task Manager")
                hint: Config.system.monitor === "custom" ? "" : DesktopActions.selectedMonitor ? DesktopActions.selectedMonitor.label : ""
                icon: "chip"
                enabled: DesktopActions.available
                onTriggered: root.run(() => DesktopActions.launchMonitor())
            }
            PxMenuItem {
                text: I18n.t("Выбрать системный монитор…", "Choose system monitor…")
                icon: "gear"
                onTriggered: root.run(() => Shell.openSettings("system"))
            }
            PxMenuItem { separator: true }
            PxMenuItem {
                text: I18n.t("Настройки панели", "Taskbar settings")
                icon: "window"
                onTriggered: root.run(() => Shell.openSettings("bar"))
            }
        }
    }

    RightClickGuard {}
}
