pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// angelOS's pixel context menu: one engine for every pixel menu (services/MenuLook). A menu is
// a row of everyday actions as signed icons (`quick`) over a list of plain entries (`items`):
//   {label, short, icon, hint, keys, separator, checkable, checked, enabled, keepOpen, run,
//    choices, children}
//   short     the caption under its icon in the quick row (else the label)
//   keys      a shortcut, ["Mod", "T"] or "Mod+T", shown on the right in one format
//   checked   a bool or a function (read live: the tick follows the setting while open);
//             the entry keeps its icon, the tick goes on the right
//   enabled   a bool or a function; false greys it out
//   keepOpen  the menu stays open after `run` (toggles, steppers)
//   choices   a few small buttons on the row (or under the icon) instead of a submenu:
//             [{label, checked, keepOpen, run}] — the desks 1 2 3 4, a widget's S M L
//   children  a list, or a function building it as it opens: a submenu beside the entry —
//             the tray's apps' own menus only (angelOS's menus have none). A function may give
//             nothing yet: the submenu shows once refresh() finds entries (the tray's DBus menus)
// Open it with popup(items, title, x, y) or show(x, y) (x, y in parentWindow, or in anchor.item
// when a menu anchors itself to an item instead); close() closes it with its submenus.
// It does in one place what each menu did its own way: the reopen on the next turn
// (Wayland), one popup at a time (PopupManager), RightClickGuard, the same keyboard
// (PxMenuList), submenus opening on hover after 160 ms and flipping at the screen's edge.
// A level taller than most of the screen scrolls; a shown level that changes size is put up
// again to fit (refit). Made once per screen and kept: show() only moves it.
PopupWindow {
    id: root

    property var parentWindow: null
    property string kind: ""                // desktop | widget | panel | task | tray | halo
    property string look: MenuLook.lookFor(kind)
    property var items: []
    property var quick: []
    property real tileScale: 1
    property string title: ""
    property bool icons: true               // icons on the menu's own entries (submenus keep theirs)
    property bool pop: false                // a little pop as it opens
    property int minWidth: MenuLook.minWidth
    property int maxWidth: MenuLook.maxWidth
    // a level taller than this scrolls: most of the screen, so it can slide but never off it
    readonly property int maxHeight: parentWindow && parentWindow.screen ? Math.floor(parentWindow.screen.height * 0.8 / Theme.u) * Theme.u : 0
    property string panelId: ""             // a bar popup's name: signs it in with PopupManager
    readonly property string outputName: parentWindow && parentWindow.screen ? parentWindow.screen.name : ""
    property alias header: list.header      // the menu's own parts over its entries
    property alias footer: list.footer      // …and under them
    signal dismissed                        // close() was called (an outside click hides it without)

    function popup(entries, heading, x, y) {
        items = entries || [];
        title = heading || "";
        show(x, y);
    }
    // An open menu is hidden and shown again on the next turn of the event loop: shown in the
    // same event, the new surface kept the old position and jumped aside. Clicks while that
    // is pending only move the target, so a fast double right-click shows the menu once,
    // where it was asked for last.
    property bool reopening: false
    property bool refitting: false          // hidden only to be put up again: not a close
    function show(x, y) {
        refit.stop();
        refitting = false;
        collapse(1);
        list.current = -1;
        list.qcurrent = -1;
        anchor.rect.x = Math.round(x);
        anchor.rect.y = Math.round(y);
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
    function close() {
        reopening = false;
        refitting = false;
        refit.stop();
        collapse(1);
        visible = false;
        dismissed();
    }
    // an entry chosen (a click, Enter): its submenu, or its action (the menu closes first
    // unless the entry keeps it open)
    function activate(l, i, kb) {
        const it = l.items[i];
        if (!it || it.separator || !MenuLook.on(it.enabled, true))
            return;
        l.current = i;
        if (MenuLook.hasKids(it)) {
            cascade(l.level, l.rowAt(i), MenuLook.kidsOf(it), kb, it);
            return;
        }
        // a row of choices: its buttons choose (the keyboard: ←→ and Enter)
        if (it.choices && !it.run)
            return;
        runIt(it.run, it.keepOpen);
    }
    // one of the icons in the quick row (`j`: one of its choices; -1: the icon itself — with
    // choices, the keyboard steps to the next one)
    function activateQuick(l, i, j) {
        const it = l.quick[i];
        if (!it || !MenuLook.on(it.enabled, true))
            return;
        const ch = it.choices ? Array.from(it.choices) : [];
        if (ch.length) {
            const at = ch.findIndex(c => MenuLook.on(c.checked, false));
            const c = ch[j >= 0 ? j : (at + 1) % ch.length];
            return runIt(c.run, c.keepOpen || it.keepOpen);
        }
        runIt(it.run, it.keepOpen);
    }
    // a row's choice `j`
    function runChoice(l, i, j) {
        const it = l.items[i];
        const c = it && it.choices ? it.choices[j] : null;
        if (!c || !MenuLook.on(it.enabled, true))
            return;
        l.current = i;
        runIt(c.run, c.keepOpen || it.keepOpen);
    }
    function runIt(fn, keepOpen) {
        if (keepOpen) {
            if (fn)
                fn();
            return;
        }
        close();
        if (fn)
            fn();
    }
    // the submenu of the menu's own entry i, the keyboard in it (scripting: Ipc's desktopMenu)
    function openChild(i) {
        cascade(0, list.rowAt(i), MenuLook.kidsOf(items[i]), true, items[i]);
    }
    // a submenu one level under `level`, beside `anchorItem` (an entry, or any item in that
    // level: the desktop's quick tiles); `entry`, the entry it opens from, lets refresh() read
    // it again (and lets it open before its entries have come)
    function cascade(level, anchorItem, kids, kb, entry) {
        if (!anchorItem || !kids || (kids.length === 0 && !entry))
            return;
        const s = subAt(level + 1);
        collapse(level + 2);
        if (s.wanted && s.anchorItem === anchorItem) {
            if (kb && s.visible && s.list.current < 0)
                s.list.current = s.list.step(1);
            return;
        }
        s.openFor(anchorItem, kids, kb, entry);
    }
    // the open submenus read again, top down: their entries (a `children` function is asked
    // again) and the rows they hang off. For a menu whose entries change while it is open (the
    // tray's DBus menus): its owner calls this when they do. The lit entries and the open
    // submenus stay where their entries are still there.
    function refresh() {
        for (let k = 0; k < subs.length && subs[k].wanted; k++) {
            const s = subs[k], up = k === 0 ? list : subs[k - 1].list;
            if (!s.entry)
                continue;
            const i = up.find(s.entry);
            if (i < 0 || !MenuLook.hasKids(up.items[i])) {
                collapse(k + 1);
                return;
            }
            s.entry = up.items[i];
            s.reload(up.rowAt(i), MenuLook.kidsOf(s.entry));
        }
    }
    // the submenu of entry `e` in level `l` again, after a refit closed it
    function reopenSub(l, e) {
        const i = e ? l.find(e) : -1;
        if (i >= 0 && MenuLook.hasKids(l.items[i]))
            cascade(l.level, l.rowAt(i), MenuLook.kidsOf(l.items[i]), false, l.items[i]);
    }
    // grown or shrunk while shown (entries that came late): put up again, or niri keeps it where
    // its old size put it, and a menu grown upward from a bottom bar hung below the screen (#49)
    onImplicitWidthChanged: if (visible && !reopening)
        refit.restart()
    onImplicitHeightChanged: if (visible && !reopening)
        refit.restart()
    Timer {
        id: refit
        interval: 30
        onTriggered: {
            if (!root.visible || root.reopening)
                return;
            const open = root.subs.length && root.subs[0].wanted ? root.subs[0].entry : null;
            root.refitting = true;
            root.reopening = true;
            root.collapse(1);
            root.visible = false;
            Qt.callLater(() => {
                // show() in between takes it over; a press on the bar (PopupManager) closes it
                const again = root.refitting;
                if (!root.reopening || (again && PopupManager.active !== root)) {
                    root.reopening = false;
                    root.refitting = false;
                    return;
                }
                root.reopening = false;
                root.anchor.updateAnchor();
                root.visible = true;
                root.refitting = false;
                if (again)
                    root.reopenSub(list, open);
            });
        }
    }
    // close the submenus from `level` down (1 = all of them)
    function collapse(level) {
        for (let i = subs.length; i >= Math.max(1, level); i--)
            subs[i - 1].hide();
    }
    // the pointer on an entry: it lights up, and after a short beat its submenu opens (or the
    // deeper ones close), like Windows. On its way into a submenu the pointer may cross other
    // entries: only where it rests counts
    function rowHovered(l, i) {
        l.current = i;
        hoverBeat.lvl = l;
        hoverBeat.idx = i;
        hoverBeat.restart();
    }
    Timer {
        id: hoverBeat
        property var lvl: null
        property int idx: -1
        interval: 160
        onTriggered: {
            const l = lvl, row = l ? l.rowAt(idx) : null;
            if (!row || !row.hovered)
                return;
            const it = l.items[idx];
            if (MenuLook.hasKids(it))
                root.cascade(l.level, row, MenuLook.kidsOf(it), false, it);
            else
                root.collapse(l.level + 1);
        }
    }

    // submenu windows, made when first needed and kept
    property var subs: []
    function subAt(level) {
        while (subs.length < level) {
            const prev = subs.length ? subs[subs.length - 1] : root;
            subs.push(subMaker.createObject(root, {
                "menu": root,
                "level": subs.length + 1,
                "prevWin": prev
            }));
        }
        return subs[level - 1];
    }
    Component {
        id: subMaker
        PxMenuSub {}
    }

    anchor.window: parentWindow
    anchor.rect.width: 1
    anchor.rect.height: 1
    // the menu starts one pixel past the pointer, so a second right-click on the
    // same spot lands under it (the menu moves there) instead of on its corner
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
    grabFocus: !Shell.demo
    color: "transparent"
    implicitWidth: list.width + Theme.u * 3
    implicitHeight: list.height + Theme.u * 3
    visible: false
    onVisibleChanged: {
        if (visible) {
            if (pop && !refitting)
                list.popNow();
            list.forceActiveFocus();
            if (PopupManager.active && PopupManager.active !== root)
                PopupManager.close(PopupManager.active);
            PopupManager.active = root;
        } else {
            collapse(1);
            if (PopupManager.active === root && !refitting)
                PopupManager.active = null;
        }
    }
    Component.onCompleted: if (panelId !== "")
        PopupManager.registerPopup(root)
    Component.onDestruction: if (panelId !== "")
        PopupManager.unregisterPopup(root)

    BackgroundEffect.blurRegion: Config.appearance.blur ? blurRegion : null
    Region {
        id: blurRegion
        item: list
    }

    PxMenuList {
        id: list
        menu: root
        level: 0
        items: root.items
        quick: root.quick
        tileScale: root.tileScale
        title: root.title
        look: root.look
        icons: root.icons
        minWidth: root.minWidth
        maxWidth: root.maxWidth
        maxHeight: root.maxHeight
    }

    RightClickGuard {}
}
