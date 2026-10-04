pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Where the open Golden Gate menu is drawn: a transparent overlay over one screen while a menu
// is open (MacMenus). The menu bar is cut out of it, so the bar keeps working under it — another
// title under the pointer opens its menu, a click on the same title closes it. A click anywhere
// else closes the menu. Submenus cascade to the right (to the left at the screen's edge); the
// keyboard walks them: ↑↓, → into a submenu or to the next menu, ← back, Enter, Esc, a letter.
// A tray icon's menu (MacMenus.menu.tray) is read through QsMenuOpener level by level.
PanelWindow {
    id: win

    required property var modelData
    readonly property string screenName: modelData.name
    readonly property bool open: MacMenus.isOpen && MacMenus.screen === screenName
    property var levels: []          // [{items, handle, x, y}]

    screen: modelData
    visible: open
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "angelos-macmenu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? (Shell.dev ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None
    // takes input: everywhere but the menu bar (a click outside a menu closes it)
    mask: Region {
        item: fullArea
        Region {
            item: barArea
            intersection: Intersection.Subtract
        }
    }
    BackgroundEffect.blurRegion: Config.appearance.blur ? blur : null
    Region {
        id: blur
        Region {
            item: rep.count > 0 && rep.itemAt(0) ? rep.itemAt(0).view : null
            radius: GoldenGate.menuRadius
        }
        Region {
            item: rep.count > 1 && rep.itemAt(1) ? rep.itemAt(1).view : null
            radius: GoldenGate.menuRadius
        }
        Region {
            item: rep.count > 2 && rep.itemAt(2) ? rep.itemAt(2).view : null
            radius: GoldenGate.menuRadius
        }
        Region {
            item: rep.count > 3 && rep.itemAt(3) ? rep.itemAt(3).view : null
            radius: GoldenGate.menuRadius
        }
    }

    Item {
        id: fullArea
        anchors.fill: parent
    }
    Item {
        id: barArea
        width: parent.width
        height: GoldenGate.barHeight
    }

    // the menu (re)opened: one level, its items — the app may refresh a submenu before it shows
    readonly property var menu: open ? MacMenus.menu : null
    readonly property string menuKey: open && menu ? screenName + "|" + MacMenus.index + "|" + (menu.id || "tray") : ""
    onMenuKeyChanged: reset()
    // the same menu with new items (Undo became available, a submenu refreshed): update in place,
    // the open submenus stay open
    onMenuChanged: if (menu && levels.length && menuKey !== "")
        refreshLevels()
    function reset() {
        for (const l of levels)
            if (l.owner)
                AppMenu.closed(l.owner);
        if (!menu) {
            levels = [];
            return;
        }
        if (menu.owner)
            AppMenu.opened(menu.owner);
        levels = [
            {
                "items": menu.items || [],
                "handle": menu.tray || null,
                "y": GoldenGate.barHeight + GoldenGate.px(3),
                "owner": menu.owner || null
            }
        ];
        Qt.callLater(() => {
            const v = rep.itemAt(0);
            if (v && MacMenus.fromKeyboard)
                v.view.move(1);
            keys.forceActiveFocus();
        });
    }
    function refreshLevels() {
        const out = [];
        let items = menu.items || [];
        for (let i = 0; i < levels.length; i++) {
            const l = levels[i];
            if (i > 0) {
                const sub = items.find(it => it.id === l.itemId);
                if (!sub || sub.type !== "submenu")
                    break;
                items = sub.children || [];
            }
            out.push(Object.assign({}, l, {
                "items": items
            }));
        }
        levels = out;
    }

    function openSub(level, item, rowY) {
        const next = levels[level + 1];
        if (item && item.type === "submenu" && next && next.itemId === item.id) {
            // already open: only what hangs off it closes
            for (const l of levels.slice(level + 2))
                if (l.owner)
                    AppMenu.closed(l.owner);
            if (levels.length > level + 2)
                levels = levels.slice(0, level + 2);
            return;
        }
        const deeper = levels.slice(0, level + 1);
        for (const l of levels.slice(level + 1))
            if (l.owner)
                AppMenu.closed(l.owner);
        if (item && item.type === "submenu" && item.enabled !== false) {
            const parent = rep.itemAt(level);
            const owner = item.act && item.act.kind === "app" ? item : null;
            if (owner)
                AppMenu.opened(owner);
            deeper.push({
                "items": item.children || [],
                "handle": item.entry || null,
                "parentLevel": level,
                "itemId": item.id,
                "rowY": rowY,
                "owner": owner
            });
        }
        if (deeper.length !== levels.length || deeper[deeper.length - 1] !== levels[levels.length - 1])
            levels = deeper;
    }
    function activate(item) {
        if (!item || item.enabled === false)
            return;
        if (item.type === "submenu")
            return;
        if (item.type === "switch" || item.keepOpen) {
            AppMenu.trigger(item);
            return;
        }
        MacMenus.activate(item);
    }

    // ---- a tray icon's menu: QsMenuEntry → item ----
    function trayItems(values) {
        const out = [];
        for (let i = 0; i < values.length; i++) {
            const e = values[i];
            if (!e)
                continue;
            if (e.isSeparator) {
                out.push({
                    "id": "t" + i,
                    "type": "separator"
                });
                continue;
            }
            out.push({
                "id": "t" + i,
                "label": String(e.text || "").replace(/_(?!_)/, ""),
                "enabled": e.enabled,
                "type": e.hasChildren ? "submenu" : "item",
                "toggle": e.buttonType !== QsMenuButtonType.None ? "check" : "",
                "checked": e.checkState === Qt.Checked,
                "keys": [],
                "children": [],
                "entry": e.hasChildren ? e : null,
                "act": {
                    "kind": "fn",
                    "fn": () => e.triggered()
                }
            });
        }
        return out;
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: MacMenus.close()
    }

    Repeater {
        id: rep
        model: win.levels

        Item {
            id: level
            required property var modelData
            required property int index
            readonly property alias view: view
            readonly property var parentItem: modelData.parentLevel !== undefined ? rep.itemAt(modelData.parentLevel) : null
            QsMenuOpener {
                id: opener
                menu: level.modelData.handle
            }
            readonly property var items: level.modelData.handle ? win.trayItems(opener.children ? opener.children.values : []) : level.modelData.items
            readonly property real wantX: {
                if (!parentItem) {
                    const x0 = MacMenus.bottom >= 0 ? MacMenus.x - view.width / 2 : MacMenus.alignRight ? MacMenus.x - view.width : MacMenus.top >= 0 ? MacMenus.x : MacMenus.x - GoldenGate.px(2);
                    return Math.max(GoldenGate.px(4), Math.min(win.width - view.width - GoldenGate.px(4), x0));
                }
                const right = parentItem.x + parentItem.view.width - GoldenGate.px(4);
                return right + view.width <= win.width - GoldenGate.px(4) ? right : Math.max(GoldenGate.px(4), parentItem.x - view.width + GoldenGate.px(4));
            }
            readonly property real wantY: parentItem ? Math.max(GoldenGate.barHeight, Math.min(win.height - view.height - GoldenGate.px(4), parentItem.y + level.modelData.rowY - view.pad)) : MacMenus.bottom >= 0 ? Math.max(GoldenGate.barHeight, MacMenus.bottom - view.height) : MacMenus.top >= 0 ? Math.max(GoldenGate.barHeight, Math.min(win.height - view.height - GoldenGate.px(4), MacMenus.top)) : level.modelData.y
            x: wantX
            y: wantY
            width: view.width
            height: view.height

            MacMenuView {
                id: view
                width: implicitWidth
                height: implicitHeight
                items: level.items
                maxWidth: Math.min(GoldenGate.px(520), win.width - GoldenGate.px(16))
                onHovered: (i, it, rowY) => win.openSub(level.index, it, rowY)
                onActivated: it => win.activate(it)
                // a click inside a menu never closes it
                MouseArea {
                    z: -1
                    anchors.fill: parent
                }
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.ms(90)
                    }
                }
            }
        }
    }

    // the keyboard
    Item {
        id: keys
        focus: true
        Keys.onPressed: e => {
            const lv = rep.itemAt(rep.count - 1);
            if (!lv) {
                if (e.key === Qt.Key_Escape)
                    MacMenus.close();
                return;
            }
            const v = lv.view;
            const cur = v.items[v.current];
            switch (e.key) {
            case Qt.Key_Down:
                v.move(1);
                break;
            case Qt.Key_Up:
                v.move(-1);
                break;
            case Qt.Key_Right:
                if (cur && cur.type === "submenu") {
                    win.openSub(rep.count - 1, cur, v.rowY(v.current));
                    Qt.callLater(() => {
                        const n = rep.itemAt(rep.count - 1);
                        if (n && n !== lv)
                            n.view.move(1);
                    });
                } else
                    MacMenus.step(1);
                break;
            case Qt.Key_Left:
                if (rep.count > 1)
                    win.levels = win.levels.slice(0, -1);
                else
                    MacMenus.step(-1);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                if (cur && cur.type === "submenu")
                    win.openSub(rep.count - 1, cur, v.rowY(v.current));
                else
                    win.activate(cur);
                break;
            case Qt.Key_Escape:
                if (rep.count > 1)
                    win.levels = win.levels.slice(0, -1);
                else
                    MacMenus.close();
                break;
            default:
                if (e.text && e.text.trim() !== "")
                    v.jump(e.text);
                else
                    return;
            }
            e.accepted = true;
        }
    }

    RightClickGuard {}
}
