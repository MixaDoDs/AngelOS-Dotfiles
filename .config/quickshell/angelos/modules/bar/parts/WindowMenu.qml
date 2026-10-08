pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Right-click menu of a window button: fullscreen / float / move to another
// workspace or monitor, close, close every window of the app, end the process.
PopupWindow {
    id: root

    required property Item anchorItem
    property bool above: true
    property var win: null                 // niri window object
    property string panelId: "window-menu"
    readonly property string outputName: anchorItem && anchorItem.QsWindow.window && anchorItem.QsWindow.window.screen ? anchorItem.QsWindow.window.screen.name : ""
    readonly property var ws: win ? Niri.workspaceById(win.workspace_id) : null
    readonly property var siblings: win ? Niri.windows.filter(w => w.app_id && w.app_id === win.app_id) : []
    readonly property var otherOutputs: Niri.workspaces.map(w => w.output).filter((o, i, a) => o && a.indexOf(o) === i && (!root.ws || o !== root.ws.output))
    Component.onCompleted: PopupManager.registerPopup(root)
    Component.onDestruction: PopupManager.unregisterPopup(root)

    // an open menu is shown again on the next turn of the loop (in the same event
    // it kept the old position); clicks while that is pending only move the target
    property bool reopening: false
    function openFor(item, w) {
        win = w;
        const p = item.mapToItem(anchorItem, 0, 0);
        anchor.rect.x = p.x;
        anchor.rect.y = above ? p.y : p.y + item.height;
        anchor.rect.width = item.width;
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
    function run(fn) {
        const w = win;
        reopening = false;
        visible = false;
        if (w)
            fn(w);
    }

    anchor.item: anchorItem
    anchor.rect.height: 1
    anchor.edges: above ? Edges.Top | Edges.Left : Edges.Bottom | Edges.Left
    anchor.gravity: above ? Edges.Top | Edges.Right : Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
    grabFocus: !Shell.demo
    visible: false
    color: "transparent"
    implicitWidth: frame.width + Theme.u * 3
    implicitHeight: frame.height + Theme.u * 3
    onVisibleChanged: {
        if (visible) {
            if (PopupManager.active && PopupManager.active !== root)
                PopupManager.close(PopupManager.active);
            PopupManager.active = root;
        } else if (PopupManager.active === root)
            PopupManager.active = null;
    }
    BackgroundEffect.blurRegion: Config.appearance.blur ? blurRegion : null
    Region {
        id: blurRegion
        item: frame
    }

    PxBox {
        id: frame
        width: Math.min(Theme.u * 190, Math.max(Theme.u * 150, ...column.children.map(c => c.implicitWidth || 0))) + inset * 2
        height: column.implicitHeight + inset * 2
        color: Qt.alpha(Theme.menuSurface, Theme.panelAlpha)
        shadow: Config.appearance.shadows
        focus: true
        Keys.onEscapePressed: root.visible = false

        Column {
            id: column
            width: parent.width - frame.inset * 2

            Row {
                width: parent.width
                height: Theme.u * 16
                spacing: Theme.u * 4
                leftPadding: Theme.u * 5
                AppIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    appId: root.win ? root.win.app_id || "" : ""
                    size: Theme.u * 9
                }
                PxText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: column.width - Theme.u * 24
                    text: root.win ? Niri.titleOf(root.win) || root.win.app_id || "?" : ""
                    elide: Text.ElideRight
                    font.bold: true
                }
            }
            PxMenuItem {
                separator: true
            }
            PxMenuItem {
                text: I18n.t("Во весь экран", "Fullscreen")
                icon: "maximize"
                onTriggered: root.run(w => Niri.fullscreenWindow(w.id))
            }
            PxMenuItem {
                text: I18n.t("Развернуть до краёв", "Maximize to edges")
                icon: "width"
                visible: Config.windows && Config.windows.floatButtons === true
                height: visible ? implicitHeight : 0
                onTriggered: root.run(w => Niri.maximizeWindow(w.id))
            }
            PxMenuItem {
                text: root.win && root.win.is_floating ? I18n.t("Вернуть в сетку", "Back to tiling") : I18n.t("Сделать плавающим", "Make floating")
                icon: "layers"
                visible: Config.windows && Config.windows.floatButtons === true
                height: visible ? implicitHeight : 0
                onTriggered: root.run(w => Niri.toggleFloating(w.id))
            }
            // move to workspace N of the same output
            Item {
                visible: !!root.ws
                width: parent.width
                height: visible ? moveRow.height + Theme.u * 4 : 0
                PxText {
                    id: moveLabel
                    x: Theme.u * 5
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("На стол", "To desk")
                    dim: true
                }
                Row {
                    id: moveRow
                    anchors.left: moveLabel.right
                    anchors.leftMargin: Theme.u * 4
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.u * 2
                    Repeater {
                        model: root.ws ? Math.min(9, Math.max(Niri.workspacesOn(root.ws.output).length, root.ws.idx + 1)) : 0
                        PxButton {
                            required property int index
                            compact: true
                            width: Theme.u * 11
                            text: String(index + 1)
                            checked: !!root.ws && root.ws.idx === index + 1
                            onClicked: root.run(w => Niri.moveWindowToWorkspace(w.id, index + 1))
                        }
                    }
                }
            }
            Repeater {
                model: root.otherOutputs
                PxMenuItem {
                    required property string modelData
                    text: I18n.t("На монитор ", "To monitor ") + modelData
                    icon: "monitor"
                    onTriggered: root.run(w => Niri.moveWindowToMonitor(w.id, modelData))
                }
            }
            // the cobweb (services/Cobweb): the shake's quick-time event without shaking — or,
            // when it is only on the button, just swept away
            PxMenuItem {
                text: I18n.t("Стряхнуть паутину", "Shake the web off")
                icon: "spider"
                visible: !!root.win && (Cobweb.rev, Cobweb.alive(root.win.id) > 0)
                height: visible ? implicitHeight : 0
                onTriggered: root.run(w => Cobweb.inside && Cobweb.rectOf(w.id) ? Cobweb.startQte(w.id) : Cobweb.sweep(w.id))
            }
            PxMenuItem {
                separator: true
            }
            PxMenuItem {
                text: I18n.t("Закрыть", "Close")
                icon: "close"
                hint: Config.bar.taskMiddleClose ? I18n.t("средняя кнопка", "middle click") : ""
                onTriggered: root.run(w => Niri.closeWindow(w.id))
            }
            PxMenuItem {
                visible: root.siblings.length > 1
                height: visible ? implicitHeight : 0
                text: I18n.t("Закрыть все окна: ", "Close all windows: ") + root.siblings.length
                icon: "close"
                onTriggered: root.run(() => root.siblings.forEach(w => Niri.closeWindow(w.id)))
            }
            // not for angelOS's own windows: their pid is the shell itself
            PxMenuItem {
                visible: !!root.win && !!root.win.pid && root.win.pid !== Shell.pid && Shell.pid > 0
                height: visible ? implicitHeight : 0
                text: I18n.t("Завершить процесс", "End task")
                hint: root.win && root.win.pid ? "pid " + root.win.pid : ""
                icon: "warn"
                onTriggered: root.run(w => Shell.exec(["kill", String(w.pid)]))
            }
        }
    }

    RightClickGuard {}
}
