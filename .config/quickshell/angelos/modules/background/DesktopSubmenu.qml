pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Flyout for the desktop menu. items: [{label, icon, hint, separator, checkable, checked, run}];
// `checked` may be a function, re-read live while the flyout is open.
PopupWindow {
    id: root

    required property var parentMenu
    property Item anchorItem: null
    property var items: []
    property bool switching: false
    signal done

    function hide() {
        switching = true;
        visible = false;
        switching = false;
    }
    function openFor(item, list) {
        switching = true;
        anchorItem = item;
        items = list;
        visible = false;
        visible = true;
        switching = false;
    }
    // Qt dismisses only the topmost popup on an outside click. Without closing its
    // parent, that first click merely removes the flyout and a second is needed.
    onVisibleChanged: if (!visible && !switching && parentMenu.visible)
        parentMenu.close()

    anchor.window: parentMenu
    anchor.item: anchorItem
    anchor.rect.x: anchorItem ? anchorItem.width - Theme.u * 2 : 0
    anchor.rect.y: -Theme.u * 2
    anchor.rect.width: 1
    anchor.rect.height: 1
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.FlipX | PopupAdjustment.SlideY
    grabFocus: !Shell.demo
    color: "transparent"
    implicitWidth: frame.width + Theme.u * 3
    implicitHeight: frame.height + Theme.u * 3
    visible: false

    BackgroundEffect.blurRegion: Config.appearance.blur ? blurRegion : null
    Region {
        id: blurRegion
        item: frame
    }

    PxBox {
        id: frame
        width: Math.max(Theme.u * 110, ...col.children.map(c => c.implicitWidth || 0)) + inset * 2
        height: col.implicitHeight + inset * 2 + (y2k ? Theme.u * 6 : 0)
        readonly property bool y2k: root.parentMenu && root.parentMenu.skin === "y2k"
        color: y2k ? "transparent" : Qt.alpha(Theme.menuSurface, Theme.panelAlpha)
        outline: !y2k
        flat: y2k
        shadow: Config.appearance.shadows && !y2k
        Y2kGloss {
            visible: frame.y2k
            anchors.fill: parent
            z: -1
            sparkles: false
        }
        Column {
            id: col
            y: frame.y2k ? Theme.u * 4 : 0
            width: parent.width - frame.inset * 2
            Repeater {
                model: root.items
                PxMenuItem {
                    required property var modelData
                    skin: frame.y2k ? "y2k" : ""
                    text: modelData.label || ""
                    icon: modelData.icon || ""
                    hint: modelData.hint || ""
                    separator: !!modelData.separator
                    checkable: !!modelData.checkable
                    checked: typeof modelData.checked === "function" ? !!modelData.checked() : !!modelData.checked
                    enabled: modelData.enabled !== false
                    onTriggered: {
                        if (modelData.run)
                            modelData.run();
                        if (!modelData.keepOpen)
                            root.done();
                    }
                }
            }
        }
    }

    RightClickGuard {}
}
