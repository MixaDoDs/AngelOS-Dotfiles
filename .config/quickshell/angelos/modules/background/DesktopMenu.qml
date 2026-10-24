pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// Right-click menu of the wallpaper and of a desktop widget (openWidget): the shared pixel
// menu (widgets/PxMenu) — the everyday actions as signed icons on top, a short list under
// them, «Настроить меню» last. What each holds: services/DeskMenu (Settings → Right-click
// menu). Heaven's and hell's own looks of the wallpaper's menu are RadialMenu: openAt() hands
// over to it.
PxMenu {
    id: root

    property var radial: null               // RadialMenu of the same screen
    readonly property bool overlayStyle: DeskMenu.overlay && !!radial
    readonly property real k: ({
            "compact": 0.85,
            "large": 1.25
        })[Config.desktop.menuSize] || 1
    readonly property string screenName: parentWindow && parentWindow.screen ? parentWindow.screen.name : ""

    // a desktop widget's own menu (openWidget): its uid; "" = the desktop's
    property string widgetUid: ""
    readonly property bool own: widgetUid !== ""
    // a window's menu (openWindow: a right click on its title bar in the stacking mode)
    property var win: null
    // built once as it opens: rebuilt on every change, the rows would lose the keyboard's place
    function build() {
        const m = DeskMenu.menu(win ? "task" : own ? "widget" : "desktop", {
            "screen": screenName,
            "uid": widgetUid,
            "win": win,
            "depthThings": own ? depthThings(widgetUid) : []
        });
        quick = m.quick;
        items = m.items;
    }
    function openWidget(uid, x, y) {
        win = null;
        widgetUid = uid;
        build();
        show(x, y);
    }
    function openWindow(w, x, y) {
        win = w;
        widgetUid = "";
        build();
        show(x, y);
    }
    function openAt(x, y) {
        win = null;
        widgetUid = "";
        Achievements.note("deskmenu.open", DeskMenu.style);
        if (overlayStyle) {
            if (visible)
                close();
            radial.openAt(x, y);
            return;
        }
        build();
        show(x, y);
    }
    onDismissed: if (radial && radial.visible)
        radial.close()

    // the scene's things the widget can stand behind, where it is (SceneWall.layersAt), 8 at most
    function depthThings(uid) {
        const f = DesktopWidgets.faces[uid];
        const wall = f && f.depth ? f.sceneWall : null;
        if (!wall)
            return [];
        return wall.layersAt(Qt.rect(f.x, f.y, f.width, f.height)).slice(0, 8);
    }

    kind: win ? "task" : own ? "widget" : "desktop"
    tileScale: k
    title: {
        if (win)
            return Niri.titleOf(win) || win.app_id || "";
        if (!own)
            return "";
        const w = DesktopWidgets.byUid(root.widgetUid);
        const info = w ? DesktopWidgets.typeInfo(w.type) : null;
        return info ? DesktopWidgets.titleOf(info) + " · " + info.label : "";
    }
    icons: Config.desktop.menuIcons !== false
    pop: Config.desktop.menuAnim !== false
    minWidth: Math.round(MenuLook.minWidth * k)

    footer: [
        Repeater {
            // QML menu components from plugins: on the desktop's menu, once switched on
            model: root.own || root.win ? [] : Plugins.menuComponents.filter(p => DeskMenu.pluginOn(p.id + ":menu"))
            Loader {
                required property var modelData
                width: parent ? parent.width : 0
                Component.onCompleted: setSource(Plugins.url(modelData, modelData.menuComponent), {
                    "plugin": Plugins.context(modelData),
                    "menu": root
                })
            }
        }
    ]
}
