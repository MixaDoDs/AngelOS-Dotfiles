pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// A tray app's DBus menu: the shared pixel menu (widgets/PxMenu) in the "tray" look, its
// submenus beside it like every other menu's.
PxMenu {
    id: root

    required property Item anchorItem
    property bool above: true
    property var handle: null

    // An app sends its menu items over DBus after the menu is asked for, sometimes in
    // several bursts. The menu shows once the items have stopped coming; one that still
    // changes size once shown is put up again by PxMenu (#49). A submenu's items come once
    // it is opened: each opened submenu has its own opener, read again (PxMenu.refresh) as
    // its items come and change.
    property bool opening: false
    property double openingSince: 0
    function toggle() {
        if (opening) {
            opening = false;
            return;
        }
        if (visible || (PopupManager.dismissed === root && Date.now() - PopupManager.dismissedAt < 600)) {
            PopupManager.toggle(root);
            return;
        }
        if (!handle)
            return;
        opening = true;
        openingSince = Date.now();
        settle.restart();
    }
    onItemsChanged: {
        if (opening && Date.now() - openingSince < 400)
            settle.restart();
        later.restart();
    }
    Timer {
        id: settle
        interval: 70
        onTriggered: {
            if (!root.opening)
                return;
            root.opening = false;
            // the bar's window coordinates: PxMenu anchors to parentWindow
            const a = root.anchorItem, p = a.mapToItem(null, 0, 0), u = Theme.u;
            root.anchor.rect.width = root.side ? 1 : a.width;
            root.anchor.rect.height = root.side ? a.height : 1;
            root.show(root.side === "left" ? p.x + a.width + u * 2 : root.side === "right" ? p.x - u * 2 : p.x, root.side ? p.y : root.above ? p.y - u * 2 : p.y + a.height + u * 2);
        }
    }
    Timer {
        id: later
        interval: 0
        onTriggered: root.refresh()
    }

    QsMenuOpener {
        id: opener
        menu: root.handle
    }
    items: entriesOf(opener.children)
    // the app's items as menu entries; read in a binding, so a changed label rebuilds them
    function entriesOf(model) {
        return Array.from(model ? model.values : []).map(e => e.isSeparator ? {
                "separator": true
            } : {
                "label": (e.text || "").replace(/_(?!_)/, ""),
                "checkable": e.buttonType !== QsMenuButtonType.None,
                "checked": () => e.checkState === Qt.Checked,
                "enabled": () => e.enabled,
                "children": e.hasChildren ? () => root.kidsOf(e) : undefined,
                "run": () => e.triggered()
            });
    }
    // a submenu's entries: its opener, made as it opens (that is what asks the app for them)
    property var openers: []
    function kidsOf(e) {
        let o = openers.find(x => x.menu === e);
        if (!o) {
            o = openerMaker.createObject(root, {
                "menu": e
            });
            openers.push(o);
        }
        return o.rows;
    }
    Component {
        id: openerMaker
        QsMenuOpener {
            readonly property var rows: root.entriesOf(children)
            onRowsChanged: later.restart()
        }
    }
    // closed: the submenus' openers go, on the next turn (a chosen item is triggered after
    // the menu closes)
    onVisibleChanged: if (!visible && !reopening)
        drop.restart()
    onHandleChanged: drop.restart()
    Timer {
        id: drop
        interval: 0
        onTriggered: {
            if (root.visible || root.reopening)
                return;
            root.openers.forEach(o => o.destroy());
            root.openers = [];
        }
    }

    parentWindow: anchorItem ? anchorItem.QsWindow.window : null
    kind: "tray"
    // a taskbar on the left or the right (BarLayout.side): beside it, as BarPopup
    property string side: BarLayout.side
    anchor.edges: side === "left" ? Edges.Top | Edges.Right : side === "right" ? Edges.Top | Edges.Left : above ? Edges.Top : Edges.Bottom
    anchor.gravity: side === "left" ? Edges.Bottom | Edges.Right : side === "right" ? Edges.Bottom | Edges.Left : above ? Edges.Top : Edges.Bottom
}
