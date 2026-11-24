pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// serp-skin: Serpantinum's dock — a flat slab at the bottom, every app on a tile of its own
// (surface0, radius 0.28 of the size, icon inset 0.14), the hovered one grows to 120% and lifts,
// its neighbours step aside. Under a tile: one window focused = an accent pill, else a dot per
// window (the first accent when focused). The apps: Serp.cfg.dockApps, else the taskbar's pins
// (Config.bar.taskPinned) — then the running ones that aren't pinned, after a line.
// Click: show the app (or start it); click its focused window: minimize; middle: a new one;
// right: its windows to pick. Autohide: comes up when the pointer touches the bottom edge.
PanelWindow {
    id: win

    required property var modelData
    readonly property string screenName: modelData.name

    readonly property int size: Serp.px(Serp.cfg.dockSize)
    readonly property int spacing: Serp.px(8)
    readonly property int pad: Serp.px(10)
    readonly property int margin: Serp.px(8)
    readonly property int slabH: size + pad * 2
    readonly property bool autohide: Serp.cfg.dockAutohide
    readonly property bool fullscreen: Shell.fullscreenOn(screenName)
    property bool hover: false
    readonly property bool shown: !fullscreen && (!autohide || hover || menu.visible)

    // ---- the apps ----
    readonly property var pins: (Serp.cfg.dockApps && Serp.cfg.dockApps.length ? Serp.cfg.dockApps : Config.bar.taskPinned || [])
    function idOf(w) {
        const e = DesktopEntries.heuristicLookup(w.app_id);
        return e ? e.id : w.app_id || "#" + w.id;
    }
    readonly property var wins: Niri.windows.filter(w => !Minimize.isAppHidden(w))
    readonly property var winsByApp: {
        const m = {};
        for (const w of wins) {
            const pin = pins.find(p => p === w.app_id || p === idOf(w));
            const k = pin || idOf(w);
            (m[k] = m[k] || []).push(w);
        }
        return m;
    }
    readonly property var running: Serp.cfg.dockRunning ? Object.keys(winsByApp).filter(k => !pins.includes(k)) : []
    readonly property var items: pins.map(id => ({
                "id": id,
                "pinned": true
            })).concat(running.length ? [
            {
                "id": "|",
                "pinned": false
            }
        ] : []).concat(running.map(id => ({
                "id": id,
                "pinned": false
            })))

    function launch(id) {
        StartApps.launch(DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id));
    }
    function activate(id) {
        const ws = winsByApp[id] || [];
        if (!ws.length)
            return launch(id);
        const focused = ws.find(w => w.is_focused);
        if (focused && !Minimize.isMinimized(focused))
            return Minimize.request(focused.id, "bar");
        // the next of its windows after the focused one, minimized ones come back
        const w = ws.find(x => Minimize.isMinimized(x)) || ws[0];
        if (Minimize.isMinimized(w))
            Minimize.restore(w.id, false, screenName);
        else
            Niri.focusWindow(w.id);
    }

    screen: modelData
    anchors {
        bottom: true
        left: true
        right: true
    }
    // room above the slab for the lifted icon, the name and the menu (the mask passes it through).
    // One height always: grown when the menu opened, the surface was remade a size larger and the
    // dock jumped a frame or two (and the hover under the pointer flickered with it)
    implicitHeight: slabH + margin * 2 + Serp.px(48) + Serp.px(420)
    exclusiveZone: Shell.dev || autohide ? 0 : slabH + margin
    exclusionMode: Shell.dev ? ExclusionMode.Ignore : ExclusionMode.Normal
    onExclusiveZoneChanged: Minimize.dockZone[screenName] = exclusiveZone
    Component.onCompleted: {
        Minimize.dockZone[screenName] = exclusiveZone;
        Minimize.dockEdge[screenName] = "bottom";
    }
    color: "transparent"
    WlrLayershell.namespace: "angelos-serpdock"
    WlrLayershell.layer: WlrLayer.Top
    ZoneReport {
        win: win
        key: "serpdock"
    }
    // only the slab takes the pointer (and the edge strip while hidden)
    mask: Region {
        item: win.shown ? slab : edgeStrip
        Region {
            item: menu.visible ? menu : null
        }
    }
    BackgroundEffect.blurRegion: Serp.blurOn && win.shown ? blurRegion : null
    Region {
        id: blurRegion
        item: slab
        radius: slab.radius
    }

    Item {
        id: edgeStrip
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: slab.width
        height: Serp.px(4)
    }
    HoverHandler {
        id: hh
        onHoveredChanged: {
            if (hovered) {
                leave.stop();
                win.hover = true;
            } else
                leave.restart();
        }
    }
    Timer {
        id: leave
        interval: 600
        onTriggered: win.hover = false
    }

    SerpBackdrop {
        id: glassBack
        screenName: win.screenName
    }
    SGlass {
        id: slab
        backdrop: glassBack
        readonly property real slide: win.shown ? 0 : height + win.margin + Serp.px(6)
        anchors.horizontalCenter: parent.horizontalCenter
        y: win.height - height - win.margin + slide
        width: row.width + win.pad * 2
        height: win.slabH
        radius: Math.min(Serp.px(18), Serp.radius * 1.6)
        Behavior on y {
            NumberAnimation {
                duration: win.shown ? 420 : 200
                easing.type: win.shown ? Easing.OutBack : Easing.InQuad
                easing.overshoot: 1.1
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: Serp.normal
                easing.type: Easing.OutCubic
            }
        }

        Row {
            id: row
            x: win.pad
            anchors.verticalCenter: parent.verticalCenter
            spacing: win.spacing
            property int hovered: -1

            Repeater {
                model: win.items
                Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool sep: modelData.id === "|"
                    readonly property var ws: sep ? [] : win.winsByApp[modelData.id] || []
                    readonly property var entry: sep ? null : DesktopEntries.byId(modelData.id) || DesktopEntries.heuristicLookup(modelData.id)
                    readonly property bool isHover: row.hovered === index
                    readonly property int dist: row.hovered < 0 ? 99 : Math.abs(row.hovered - index)
                    readonly property real grow: !Serp.cfg.dockMagnify ? 1 : isHover ? 1.2 : dist === 1 ? 1.06 : 1
                    width: sep ? 1 : win.size
                    height: win.size

                    // the line between pinned and running
                    Rectangle {
                        visible: cell.sep
                        anchors.centerIn: parent
                        width: 1
                        height: win.size / 2
                        color: Qt.alpha(Serp.surface2, 0.7)
                    }

                    Item {
                        id: tile
                        visible: !cell.sep
                        width: win.size
                        height: win.size
                        // neighbours step aside from the grown one
                        x: row.hovered < 0 || cell.isHover || !Serp.cfg.dockMagnify ? 0 : (cell.index < row.hovered ? -1 : 1) * Math.min(Serp.px(10), win.size * 0.13) / cell.dist
                        y: cell.isHover && Serp.cfg.dockMagnify ? -Serp.px(5) : 0
                        scale: cell.grow * (tma.pressed ? 0.94 : 1)
                        transformOrigin: Item.Bottom
                        Behavior on x {
                            NumberAnimation {
                                duration: Serp.normal
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on y {
                            NumberAnimation {
                                duration: Serp.normal
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: Serp.normal
                                easing.type: Easing.OutCubic
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: win.size * 0.28
                            // without the glass the slab is the base colour and surface0 nearly the same
                            // in the wallpaper's palette: the tiles vanished into it. Then a tile is the
                            // base lit by the text colour, lighter than the slab in any palette
                            color: Serp.glassOn ? (tma.containsMouse ? Qt.lighter(Serp.surface0, 1.12) : Serp.surface0) : Qt.tint(Serp.base, Qt.alpha(Serp.text, tma.containsMouse ? 0.17 : 0.10))
                            border.width: Serp.glassOn ? 0 : 1
                            border.color: Qt.alpha(Serp.text, 0.07)
                            Behavior on color {
                                ColorAnimation {
                                    duration: Serp.quick
                                }
                            }
                        }
                        AppIcon {
                            anchors.fill: parent
                            anchors.margins: win.size * 0.14
                            appId: cell.modelData.id
                            size: width
                        }
                        // the place minimized windows of this app fly to (services/Minimize)
                        function report() {
                            const w = tile.QsWindow.window;
                            if (!w || !w.screen)
                                return;
                            const p = tile.mapToItem(null, tile.width / 2, tile.height / 2);
                            const at = [(w.screen.width - w.width) / 2 + p.x, w.screen.height - w.height + p.y, tile.width];
                            for (const v of cell.ws)
                                Minimize.dockSlots[win.screenName + "|@w" + v.id] = at;
                        }
                        Connections {
                            target: Minimize
                            function onSlotsWanted(output) {
                                if (output === win.screenName)
                                    tile.report();
                            }
                        }
                        Component.onCompleted: report()
                    }

                    // the windows: a pill when one is focused, else dots
                    Row {
                        id: dots
                        visible: !cell.sep && cell.ws.length > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: win.size + Serp.px(4)
                        spacing: Serp.px(3)
                        readonly property bool focused: cell.ws.some(w => w.is_focused)
                        Repeater {
                            model: dots.focused && cell.ws.length === 1 ? 1 : Math.min(3, cell.ws.length)
                            Rectangle {
                                required property int index
                                width: dots.focused && cell.ws.length === 1 ? Serp.px(14) : Serp.px(3.5)
                                height: Serp.px(3.5)
                                radius: height / 2
                                color: index === 0 && dots.focused ? Serp.accent : index === 0 ? Serp.subtext0 : Serp.surface2
                            }
                        }
                    }

                    MouseArea {
                        id: tma
                        enabled: !cell.sep
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: {
                            if (containsMouse)
                                row.hovered = cell.index;
                            else if (row.hovered === cell.index)
                                row.hovered = -1;
                        }
                        onClicked: m => {
                            if (m.button === Qt.MiddleButton)
                                win.launch(cell.modelData.id);
                            else if (m.button === Qt.RightButton) {
                                menu.app = cell.modelData.id;
                                menu.pinned = cell.modelData.pinned;
                                menu.anchorX = slab.x + row.x + cell.x + cell.width / 2;
                                menu.visible = true;
                            } else
                                win.activate(cell.modelData.id);
                        }
                    }
                    // the name over the hovered tile
                    Rectangle {
                        visible: cell.isHover && !cell.sep && !menu.visible
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: -height - Serp.px(14)
                        width: tip.implicitWidth + Serp.px(14)
                        height: Serp.px(22)
                        radius: Serp.radiusSmall
                        color: Serp.base
                        border.width: 1
                        border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
                        SText {
                            id: tip
                            anchors.centerIn: parent
                            text: cell.entry ? cell.entry.name : cell.modelData.id
                            size: Serp.px(11)
                        }
                    }
                }
            }
        }
    }

    // while the menu is open, a click anywhere but the menu and the dock closes it: a see-through
    // window over the screen that takes the pointer everywhere else (the dock's own window takes it
    // only on the slab and the menu, so a click on the desktop never reached it)
    LazyLoader {
        active: menu.visible
        PanelWindow {
            screen: win.modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "angelos-serpdock-catch"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            // the dock window stands at the bottom: its items' places on this screen
            readonly property real top: height - win.height
            mask: Region {
                item: catcher
                Region {
                    x: menu.x
                    y: top + menu.y
                    width: menu.width
                    height: menu.height
                    intersection: Intersection.Subtract
                }
                Region {
                    x: slab.x
                    y: top + slab.y
                    width: slab.width
                    height: slab.height
                    intersection: Intersection.Subtract
                }
            }
            MouseArea {
                id: catcher
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: menu.visible = false
            }
        }
    }

    // the right-click menu: the app's windows, a new window, pin / unpin, close all
    Rectangle {
        id: menu
        property string app: ""
        property bool pinned: false
        property real anchorX: 0
        visible: false
        readonly property var ws: win.winsByApp[app] || []
        width: Serp.px(230)
        height: menuCol.implicitHeight + Serp.px(12)
        x: Math.max(Serp.px(8), Math.min(win.width - width - Serp.px(8), anchorX - width / 2))
        y: slab.y - height - Serp.px(8)
        radius: Serp.radius
        color: Serp.base
        border.width: 1
        border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
        // the pointer leaving the dock area closes it
        onVisibleChanged: if (visible)
            closeTimer.stop()
        Timer {
            id: closeTimer
            interval: 900
            onTriggered: menu.visible = false
        }
        HoverHandler {
            onHoveredChanged: hovered ? closeTimer.stop() : closeTimer.restart()
        }
        Column {
            id: menuCol
            x: Serp.px(6)
            y: Serp.px(6)
            width: parent.width - Serp.px(12)
            spacing: Serp.px(2)
            component Item_: SButton {
                id: mi
                property string icon
                property string label
                width: menuCol.width
                implicitHeight: Serp.px(30)
                // left-aligned inside the button's centred box: a row as wide as the item less its
                // margins, at 0 (the old −width/2 shift counted the centring twice and threw the
                // labels out to the left of the menu)
                Row {
                    width: mi.width - Serp.px(24)
                    spacing: Serp.px(8)
                    SIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: mi.icon
                        size: Serp.px(14)
                    }
                    SText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: mi.width - Serp.px(24) - Serp.px(14) - Serp.px(8)
                        text: mi.label
                        size: Serp.px(12)
                    }
                }
            }
            Repeater {
                model: menu.ws
                Item_ {
                    required property var modelData
                    icon: Minimize.isMinimized(modelData) ? "minimize-2" : modelData.is_focused ? "circle-dot" : "app-window"
                    label: Niri.titleOf(modelData) || modelData.app_id
                    onClicked: {
                        menu.visible = false;
                        if (Minimize.isMinimized(modelData))
                            Minimize.restore(modelData.id, false, win.screenName);
                        else
                            Niri.focusWindow(modelData.id);
                    }
                }
            }
            Rectangle {
                visible: menu.ws.length > 0
                width: menuCol.width
                height: 1
                color: Serp.line
            }
            Item_ {
                icon: "plus"
                label: "Новое окно"
                onClicked: {
                    menu.visible = false;
                    win.launch(menu.app);
                }
            }
            Item_ {
                icon: menu.pinned ? "x" : "star"
                label: menu.pinned ? "Открепить" : "Закрепить"
                onClicked: {
                    menu.visible = false;
                    const list = win.pins.slice();
                    Serp.cfg.dockApps = menu.pinned ? list.filter(p => p !== menu.app) : list.concat([menu.app]);
                }
            }
            Item_ {
                visible: menu.ws.length > 0
                icon: "circle-x"
                label: menu.ws.length > 1 ? "Закрыть все окна" : "Закрыть"
                onClicked: {
                    menu.visible = false;
                    for (const w of menu.ws)
                        Niri.closeWindow(w.id);
                }
            }
        }
    }

    RightClickGuard {}
}
