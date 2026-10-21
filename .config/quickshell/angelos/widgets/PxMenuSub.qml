pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// A submenu of a PxMenu: hangs beside the entry it opened from, to the other side at the
// screen's edge. Made by PxMenu.cascade() when first needed and kept for the next time.
// Entries that come later (a DBus submenu's arrive once it is opened) reach it through
// PxMenu.refresh(): it shows once it has any, and is put up again when it grows.
PopupWindow {
    id: sub

    property var menu: null                 // the PxMenu
    property int level: 1
    property var prevWin: null              // the window it hangs off: the menu or the submenu before
    property Item anchorItem: null
    property var entry: null                // the entry it opened from (PxMenu.refresh finds it again)
    property bool wanted: false             // asked open: shown once it has entries
    property bool kb: false                 // opened from the keyboard: its first entry lit
    property bool switching: false
    readonly property alias list: menuList

    function hide() {
        wanted = false;
        refit.stop();
        switching = true;
        visible = false;
        switching = false;
    }
    function openFor(item, kids, kbd, it) {
        wanted = true;
        entry = it || null;
        kb = !!kbd;
        switching = true;
        anchorItem = item;
        place();
        menuList.items = kids;
        menuList.current = -1;
        visible = false;
        visible = kids.length > 0;
        switching = false;
        if (kb)
            menuList.current = menuList.step(1);
    }
    // its entries read again (PxMenu.refresh), off the entry's row as it is now
    function reload(item, kids) {
        if (!wanted)
            return;
        if (item && item !== anchorItem) {
            anchorItem = item;
            place();
        }
        menuList.items = kids;
        if (visible === (kids.length > 0))
            return;
        if (visible)
            menu.collapse(level + 1);
        switching = true;
        visible = kids.length > 0;
        switching = false;
        if (visible && kb && menuList.current < 0)
            menuList.current = menuList.step(1);
    }
    // anchored to the window the entry stands in, not to the entry: a row rebuilt under an open
    // submenu would take its anchor (and its parent window) with it
    function place() {
        if (!anchorItem)
            return;
        const p = anchorItem.mapToItem(null, 0, 0);
        // the entry's whole width, overlapped by two art pixels on whichever side it opens
        anchor.rect.x = Math.round(p.x) + Theme.u * 2;
        anchor.rect.y = Math.round(p.y) - Theme.u * 2;
        anchor.rect.width = Math.max(1, anchorItem.width - Theme.u * 4);
    }
    // grown or shrunk while shown: put up again, or niri keeps it where its old size put it (#49)
    onImplicitWidthChanged: if (visible && !switching)
        refit.restart()
    onImplicitHeightChanged: if (visible && !switching)
        refit.restart()
    Timer {
        id: refit
        interval: 30
        onTriggered: {
            if (!sub.visible)
                return;
            const open = sub.menu.subs.length > sub.level && sub.menu.subs[sub.level].wanted ? sub.menu.subs[sub.level].entry : null;
            sub.menu.collapse(sub.level + 1);
            sub.switching = true;
            sub.visible = false;
            sub.switching = false;
            Qt.callLater(() => {
                if (!sub.wanted || sub.visible || !sub.menu.visible)
                    return;
                sub.switching = true;
                sub.visible = true;
                sub.switching = false;
                sub.menu.reopenSub(menuList, open);
            });
        }
    }
    // Qt dismisses only the topmost popup on an outside click. Without closing the menu, that
    // first click merely removes the submenu and a second is needed.
    onVisibleChanged: {
        if (visible)
            menuList.forceActiveFocus();
        else if (!switching && menu && menu.visible)
            menu.close();
    }

    anchor.window: prevWin
    anchor.rect.height: 1
    anchor.edges: Edges.Top | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.FlipX | PopupAdjustment.SlideX | PopupAdjustment.SlideY // no room either side: slide in, never off the screen
    grabFocus: !Shell.demo
    color: "transparent"
    implicitWidth: menuList.width + Theme.u * 3
    implicitHeight: menuList.height + Theme.u * 3
    visible: false

    BackgroundEffect.blurRegion: Config.appearance.blur ? blurRegion : null
    // the box's own size, bound (as PxMenu's): a kept submenu window shows lists of every size
    Region {
        id: blurRegion
        x: menuList.x
        y: menuList.y
        width: menuList.width
        height: menuList.height
    }

    PxMenuList {
        id: menuList
        menu: sub.menu
        level: sub.level
        look: sub.menu ? sub.menu.look : "classic"
        maxHeight: sub.menu ? sub.menu.maxHeight : 0
    }

    RightClickGuard {}
}
