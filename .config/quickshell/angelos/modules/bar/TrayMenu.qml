pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Pixel-styled DBus menu with drill-down submenus.
PopupWindow {
    id: root

    required property Item anchorItem
    property bool above: true
    property var handle: null
    property var stack: []
    readonly property var current: stack.length ? stack[stack.length - 1] : handle

    // An app sends its menu items over DBus after the menu is asked for, sometimes in
    // several bursts. A popup that grows while it is shown keeps its old position
    // until the next repaint (niri), so on a bottom bar the lower items hung below
    // the screen edge (#49). The menu shows once the items have stopped coming, and
    // a shown menu whose size changes (late items, a submenu) is put up again.
    property bool opening: false
    property bool reopening: false
    property double openingSince: 0
    function toggle() {
        stack = [];
        if (opening) {
            opening = false;
            return;
        }
        if (!handle || visible || PopupManager.dismissed === root) {
            PopupManager.toggle(root);
            return;
        }
        opening = true;
        openingSince = Date.now();
        settle.restart();
    }
    function itemsChanged() {
        if (opening && Date.now() - openingSince < 400)
            settle.restart();
        else if (visible)
            refit.restart();
    }
    Timer {
        id: settle
        interval: 70
        onTriggered: {
            if (!root.opening)
                return;
            root.opening = false;
            PopupManager.toggle(root);
        }
    }
    Timer {
        id: refit
        interval: 30
        onTriggered: {
            if (!root.visible || root.reopening)
                return;
            root.reopening = true;
            root.visible = false;
            Qt.callLater(() => {
                root.anchor.updateAnchor();
                root.visible = true;
                root.reopening = false;
            });
        }
    }
    onImplicitWidthChanged: itemsChanged()
    onImplicitHeightChanged: itemsChanged()
    // a menu taller than the screen scrolls instead of running off it
    readonly property real maxMenuHeight: {
        const w = anchorItem && anchorItem.QsWindow.window;
        return w && w.screen ? w.screen.height * 0.8 : Theme.u * 300;
    }

    // a taskbar on the left or the right (BarLayout.side): beside it, as BarPopup
    property string side: BarLayout.side
    anchor.item: anchorItem
    anchor.rect.x: side === "left" ? anchorItem.width + Theme.u * 2 : side === "right" ? -Theme.u * 2 : 0
    anchor.rect.y: side ? 0 : above ? -Theme.u * 2 : anchorItem.height + Theme.u * 2
    anchor.rect.width: side ? 1 : anchorItem.width
    anchor.rect.height: side ? anchorItem.height : 1
    anchor.edges: side === "left" ? Edges.Top | Edges.Right : side === "right" ? Edges.Top | Edges.Left : above ? Edges.Top : Edges.Bottom
    anchor.gravity: side === "left" ? Edges.Bottom | Edges.Right : side === "right" ? Edges.Bottom | Edges.Left : above ? Edges.Top : Edges.Bottom
    anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.Flip
    grabFocus: true
    color: "transparent"
    implicitWidth: frame.width + Theme.u * 3
    implicitHeight: frame.height + Theme.u * 3
    onVisibleChanged: {
        if (reopening)
            return;
        if (visible) {
            if (PopupManager.active && PopupManager.active !== root)
                PopupManager.close(PopupManager.active);
            PopupManager.active = root;
        } else if (PopupManager.active === root)
            PopupManager.active = null;
    }
    visible: false

    BackgroundEffect.blurRegion: Config.appearance.blur ? blurRegion : null
    Region {
        id: blurRegion
        item: frame
    }

    QsMenuOpener {
        id: opener
        menu: root.current
    }

    PxBox {
        id: frame
        width: Math.max(Theme.u * 90, col.implicitWidth + inset * 2)
        height: Math.min(col.implicitHeight, root.maxMenuHeight) + inset * 2
        color: Theme.panel
        shadow: Config.appearance.shadows

        PxScroll {
            id: scroll
            width: parent.width
            height: parent.height
            contentHeight: col.implicitHeight

            Column {
                id: col
                width: scroll.flick.width

                PxMenuItem {
                    visible: root.stack.length > 0
                    text: I18n.t("◂ назад", "◂ Back")
                    icon: "arrowUp"
                    onTriggered: root.stack = root.stack.slice(0, -1)
                }
                Repeater {
                    model: opener.children
                    PxMenuItem {
                        required property var modelData
                        separator: modelData.isSeparator
                        text: (modelData.text || "").replace(/_(?!_)/, "")
                        enabled: modelData.enabled
                        submenu: modelData.hasChildren
                        checkable: modelData.buttonType !== QsMenuButtonType.None
                        checked: modelData.checkState === Qt.Checked
                        icon: ""
                        onTriggered: {
                            if (modelData.hasChildren) {
                                root.stack = root.stack.concat([modelData]);
                            } else {
                                modelData.triggered();
                                root.visible = false;
                            }
                        }
                    }
                }
            }
        }
    }

    RightClickGuard {}
}
