pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Right-click menu of a window button: fullscreen / float / move to another
// workspace or monitor, close, close every window of the app, end the process.
// The shared pixel menu (widgets/PxMenu) in the "task" look.
PxMenu {
    id: root

    required property Item anchorItem
    property bool above: true
    property var win: null                 // niri window object
    readonly property var ws: win ? Niri.workspaceById(win.workspace_id) : null
    readonly property var siblings: win ? Niri.windows.filter(w => w.app_id && w.app_id === win.app_id) : []
    readonly property var otherOutputs: Niri.workspaces.map(w => w.output).filter((o, i, a) => o && a.indexOf(o) === i && (!root.ws || o !== root.ws.output))

    function openFor(item, w) {
        win = w;
        // the bar's window coordinates: PxMenu anchors to parentWindow
        const p = item.mapToItem(null, 0, 0);
        // a taskbar on the left or the right: beside the button, from its top down
        anchor.rect.width = side ? 1 : item.width;
        anchor.rect.height = side ? item.height : 1;
        // the entries as they are now: a live list would rebuild its rows (and lose an open
        // submenu) whenever any window changes
        popup(entries(), "", side === "left" ? p.x + item.width + Theme.u * 2 : side === "right" ? p.x - Theme.u * 2 : p.x, side ? p.y : above ? p.y : p.y + item.height);
    }
    // an entry's action on the window the menu was opened for
    function act(fn) {
        return () => {
            if (root.win)
                fn(root.win);
        };
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

    function entries() {
        const cur = root.win;
        if (!cur)
            return [];
        const floatButtons = Config.windows && Config.windows.floatButtons === true;
        const out = [
            {
                "label": I18n.t("Во весь экран", "Fullscreen"),
                "icon": "maximize",
                "run": act(w => Niri.fullscreenWindow(w.id))
            }
        ];
        // the column width of this window, now (#53: Settings → Windows → Window widths
        // only sets it for windows opened later)
        if (!cur.is_floating)
            out.push({
                "label": I18n.t("Ширина", "Width"),
                "children": WindowConfig.choices.map(c => ({
                            "label": c.label,
                            "run": act(w => Quickshell.execDetached(["niri", "msg", "action", "set-window-width", "--id", String(w.id), WindowConfig.niriArg(c.value)]))
                        }))
            });
        if (floatButtons)
            out.push({
                "label": I18n.t("Развернуть до краёв", "Maximize to edges"),
                "icon": "width",
                "run": act(w => Niri.maximizeWindow(w.id))
            }, {
                "label": cur.is_floating ? I18n.t("Вернуть в сетку", "Back to tiling") : I18n.t("Сделать плавающим", "Make floating"),
                "icon": "layers",
                "run": act(w => Niri.toggleFloating(w.id))
            });
        // move to workspace N of the same output
        const ws = root.ws;
        if (ws) {
            const n = Math.min(9, Math.max(Niri.workspacesOn(ws.output).length, ws.idx + 1));
            const desks = [];
            for (let i = 1; i <= n; i++) {
                const idx = i;
                desks.push({
                    "label": String(idx),
                    "checkable": true,
                    "checked": ws.idx === idx,
                    "run": act(w => Niri.moveWindowToWorkspace(w.id, idx))
                });
            }
            out.push({
                "label": I18n.t("На стол", "To desk"),
                "children": desks
            });
        }
        for (const o of root.otherOutputs)
            out.push({
                "label": I18n.t("На монитор ", "To monitor ") + o,
                "icon": "monitor",
                "run": act(w => Niri.moveWindowToMonitor(w.id, o))
            });
        // the cobweb (services/Cobweb): the shake's quick-time event without shaking — or,
        // when it is only on the button, just swept away
        if (Cobweb.alive(cur.id) > 0)
            out.push({
                "label": I18n.t("Стряхнуть паутину", "Shake the web off"),
                "icon": "spider",
                "run": act(w => Cobweb.inside && Cobweb.rectOf(w.id) ? Cobweb.startQte(w.id) : Cobweb.sweep(w.id))
            });
        out.push({
            "separator": true
        });
        const back = Minimize.isMinimized(cur);
        out.push({
            "label": back ? I18n.t("Развернуть", "Restore") : I18n.t("Свернуть", "Minimize"),
            "icon": "minimize",
            "run": act(w => back ? Minimize.restore(w.id) : Minimize.request(w.id, "menu"))
        }, {
            "label": I18n.t("Закрыть", "Close"),
            "icon": "close",
            "hint": Config.bar.taskMiddleClose ? I18n.t("средняя кнопка", "middle click") : "",
            "run": act(w => Niri.closeWindow(w.id))
        });
        if (root.siblings.length > 1)
            out.push({
                "label": I18n.t("Закрыть все окна: ", "Close all windows: ") + root.siblings.length,
                "icon": "close",
                "run": () => root.siblings.forEach(w => Niri.closeWindow(w.id))
            });
        // not for angelOS's own windows: their pid is the shell itself
        if (cur.pid && cur.pid !== Shell.pid && Shell.pid > 0)
            out.push({
                "label": I18n.t("Завершить процесс", "End task"),
                "hint": "pid " + cur.pid,
                "icon": "warn",
                "run": act(w => Shell.exec(["kill", String(w.pid)]))
            });
        return out;
    }
}
