pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.modules.desktop
import qs.modules.mac
import qs.modules.y2k
import qs.widgets

// Two background-layer surfaces per screen:
//   angelos-wallpaper — the picture, the desktop widgets' faces, the release's name
//                       (ReleaseMark) and the demon's broken glass (ScreenCracks); niri keeps it
//                       in the backdrop (layer-rule place-within-backdrop): it
//                       does not slide with workspaces and shows once in the
//                       overview, but gets no input
//   angelos-desktop   — transparent, drawn inside every workspace: the widgets'
//                       input copies (invisible unless a button in them is used,
//                       see DesktopWidgetHost), the right-click menu and the
//                       sparkle trail
// and, under angel-niri while windows stand behind a layered wallpaper (services/SceneBehind),
// a bottom-layer one:
//   angelos-scene-behind — the scene's nearer layers once more over each such window (niri draws
//                       it under this layer), click-through
Variants {
    model: Shell.desktopHeld ? [] : Shell.screens

    Scope {
        id: scope
        required property var modelData

        PanelWindow {
            screen: scope.modelData
            color: Theme.desk
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "angelos-wallpaper"

            WallpaperView {
                id: wallpaper
                anchors.fill: parent
                screenName: scope.modelData.name
            }

            // the desktop widgets as you see them: pinned like the wallpaper
            Item {
                id: faceArea
                anchors.fill: parent
                // edit mode: the grid under the widgets, the dragged one's landing place over them
                DesktopGrid {
                    anchors.fill: parent
                    screenName: scope.modelData.name
                }
                // in a layered wallpaper the widgets stand between its layers (WidgetDepth):
                // their shadows on the layers behind them, the widgets, the nearer layers over them
                Repeater {
                    model: DesktopWidgets.uidsFor(scope.modelData.name)
                    Rectangle {
                        required property string modelData
                        readonly property Item face: DesktopWidgets.faces[modelData] || null
                        readonly property var depth: face ? face.depth : null
                        visible: !!depth && depth.shadowed
                        x: face ? face.x + depth.shift.x + depth.shadowOffset.x : 0
                        y: face ? face.y + depth.shift.y + depth.shadowOffset.y : 0
                        width: face ? face.width : 0
                        height: face ? face.height : 0
                        radius: face && face.mac ? DesktopWidgets.macRadius * face.zoom : 0
                        antialiasing: !!face && face.mac
                        color: depth ? depth.shade : "transparent"
                        opacity: face ? face.opacity : 0
                    }
                }
                Repeater {
                    model: DesktopWidgets.uidsFor(scope.modelData.name)
                    DesktopWidgetHost {
                        required property string modelData
                        role: "face"
                        uid: modelData
                        screenName: scope.modelData.name
                        area: faceArea
                        backdrop: wallpaper
                        sceneWall: wallpaper.sceneItem
                    }
                }
                Repeater {
                    model: DesktopWidgets.uidsFor(scope.modelData.name)
                    // over the frame, its own hard shadow and the one it casts on the scene
                    SceneFront {
                        required property string modelData
                        readonly property Item face: DesktopWidgets.faces[modelData] || null
                        readonly property var depth: face ? face.depth : null
                        readonly property int pad: Theme.u * 4
                        readonly property point reach: depth ? Qt.point(Math.max(pad, depth.shadowOffset.x), Math.max(pad, depth.shadowOffset.y)) : Qt.point(0, 0)
                        wall: depth ? depth.wall : null
                        plane: depth && depth.covered ? depth.plane : Infinity
                        area: face ? Qt.rect(face.x + depth.shift.x - pad, face.y + depth.shift.y - pad, face.width + pad + reach.x, face.height + pad + reach.y) : Qt.rect(0, 0, 0, 0)
                    }
                }
                DesktopGrid {
                    anchors.fill: parent
                    screenName: scope.modelData.name
                    ghost: true
                }
            }

            // «angelOS 3 · Principality», small, in a corner no widget covers
            ReleaseMark {
                anchors.fill: parent
                obstacles: faceArea
                screenName: scope.modelData.name
            }

            // her glass, where her fist landed: pinned like the wallpaper
            ScreenCracks {
                anchors.fill: parent
                screenName: scope.modelData.name
            }

            RightClickGuard {}
        }

        PanelWindow {
            id: win

            readonly property var modelData: scope.modelData
            screen: scope.modelData
            color: "transparent"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "angelos-desktop"

            // (not in Golden Gate: no glitter behind a Mac's pointer)
            readonly property bool sparkles: !GoldenGate.on && Config.y2k.sparkles && Heaven.has("fx.sparkles") && (!(Config.y2k.sparkleScreens || []).length || Config.y2k.sparkleScreens.includes(modelData.name)) && StreamMode.effectsOn(modelData.name)
            // where the pointer is, over the widgets too (Pointer: the demon's glass
            // clears up as it comes near)
            HoverHandler {
                onPointChanged: if (hovered)
                    Pointer.report("desk", win.modelData.name, point.position.x, point.position.y)
                onHoveredChanged: if (!hovered)
                    Pointer.left("desk", win.modelData.name)
            }
            // the menu opens where the right button went down (ContextClick: B2); the middle
            // button opens the ring, aimed while it is held
            ContextClick {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton | Qt.LeftButton | Qt.MiddleButton
                hoverEnabled: win.sparkles
                onPositionChanged: m => {
                    if (win.sparkles)
                        trail.spawn(m.x, m.y);
                    if (m.buttons & Qt.MiddleButton)
                        ring.aim(m.x, m.y);
                }
                onMiddlePressed: (x, y) => {
                    menu.close();
                    if (!GoldenGate.on)
                        ring.openRing(x, y);
                }
                onMiddleReleased: (x, y) => ring.release(x, y)
                // Golden Gate: Finder's desktop menu in the skin's glass (MacMenus)
                onMenu: (x, y) => GoldenGate.on ? MacMenus.openDesktop(win.modelData.name, x, y) : menu.openAt(x, y)
                onOtherClicked: m => {
                    // the middle button's ring stays: it closes by itself
                    if (m.button === Qt.MiddleButton)
                        return;
                    menu.close();
                    // a popup's grab ends only on clicks outside angelOS: the Halo's or the bar's menu too
                    PopupManager.barPressed();
                    DesktopWidgets.editMode = false;
                }
            }

            // Y2K glitter behind the pointer (Settings → Y2K), under the widgets
            SparkleTrail {
                id: trail
                anchors.fill: parent
                visible: win.sparkles
            }

            // the desktop widgets' input copies (built-in + plugins)
            Item {
                id: deskArea
                anchors.fill: parent
                // a switch the shell prepares waits for an input copy on show to be gone
                Connections {
                    target: deskArea.Window.window
                    enabled: DesktopWidgets.preparing
                    function onFrameSwapped() {
                        DesktopWidgets.framePresented(win.modelData.name);
                    }
                }
                Repeater {
                    model: DesktopWidgets.uidsFor(win.modelData.name)
                    DesktopWidgetHost {
                        required property string modelData
                        uid: modelData
                        screenName: win.modelData.name
                        area: deskArea
                        onInteractionStarted: menu.close()
                        onContextMenu: (x, y) => menu.openWidget(modelData, x, y)
                    }
                }
            }

            // «what's new» after an update to a big release, on the main screen
            ChangelogPaper {
                anchors.fill: parent
                screenName: win.modelData.name
            }

            DesktopMenu {
                id: menu
                parentWindow: win
                radial: ring
                Component.onCompleted: {
                    const m = Shell.desktopMenus;
                    m[win.modelData.name] = menu;
                    Shell.desktopMenus = m;
                }
            }
            Loader {
                active: win.modelData === Shell.screens[0]
                sourceComponent: TitleIcons {}
            }
            // the pixel skins' genie into the taskbar (Golden Gate has its own in MacDesktop)
            Loader {
                active: !GoldenGate.on && Minimize.flightMs > 0
                sourceComponent: MacMinimizeFx {
                    modelData: win.modelData
                }
            }
            // a right click on a window's title bar (angel-niri's stacking mode): its menu here
            Connections {
                target: Niri
                function onWindowMenuRequested(id, output, pos) {
                    const w = Niri.windows.find(x => x.id === id);
                    if (w && output === win.modelData.name)
                        menu.openWindow(w, pos[0], pos[1]);
                }
            }

            // the ring on the middle button, and the right-click menu's heaven's and hell's looks
            RadialMenu {
                id: ring
                parentWindow: win
            }

            // the surface is drawn inside every workspace, and its popups with it: an open menu
            // closes when the screen goes to another workspace (#99)
            readonly property int activeWsId: {
                const ws = Niri.activeWorkspace(modelData.name);
                return ws ? ws.id : -1;
            }
            onActiveWsIdChanged: menu.close()

            RightClickGuard {}
        }

        // edit mode's bar (the grid's cell, align all, done): over the windows, on the screen
        // edit mode was asked on only — the desktop under the windows would hide it
        PanelWindow {
            screen: scope.modelData
            visible: DesktopWidgets.editMode && DesktopWidgets.editScreen === scope.modelData.name
            anchors.top: true
            margins.top: Theme.u * 40
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "angelos-editbar"
            color: "transparent"
            implicitWidth: editBar.width + Theme.u * 3
            implicitHeight: editBar.height + Theme.u * 3
            EditBar {
                id: editBar
                screenName: scope.modelData.name
            }
            RightClickGuard {}
        }

        // the windows behind the scene (services/SceneBehind): its nearer layers over each of
        // them, the very pixels the wallpaper draws there, so only where a window is under them
        // do they show
        PanelWindow {
            id: front
            readonly property string name: scope.modelData.name
            readonly property Item wall: wallpaper.sceneItem
            onWallChanged: SceneBehind.setWall(name, wall)
            Component.onCompleted: {
                SceneBehind.setWall(name, wall);
                refresh();
            }
            // the windows' ids, kept as they are while only their places change, so a moved
            // window's layers are not made again
            property var ids: []
            function refresh() {
                const now = SceneBehind.windowsOn(name).map(x => x.id);
                if (JSON.stringify(now) !== JSON.stringify(ids))
                    ids = now;
            }
            Connections {
                target: Niri
                function onWindowsChanged() {
                    front.refresh();
                }
                function onWorkspacesChanged() {
                    front.refresh();
                }
            }
            Connections {
                target: SceneBehind
                function onAppsChanged() {
                    front.refresh();
                }
                function onOnChanged() {
                    front.refresh();
                }
            }

            screen: scope.modelData
            visible: SceneBehind.on && !!wall && ids.length > 0
            color: "transparent"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "angelos-scene-behind"
            mask: Region {}

            Repeater {
                model: front.ids
                SceneFront {
                    required property var modelData
                    readonly property var info: SceneBehind.windowsOn(front.name).find(x => x.id === modelData) || null
                    readonly property string depth: info ? info.depth : ""
                    // behind a thing: just under its z; a scene without that thing takes it by itself
                    readonly property var thing: front.wall && depth.startsWith("behind:") ? front.wall.layers.find(l => l.id === depth.slice(7)) || null : null
                    wall: info ? front.wall : null
                    area: info ? info.rect : Qt.rect(0, 0, 0, 0)
                    plane: !info || !front.wall ? Infinity : thing ? thing.z - 0.5 : front.wall.planeFor(info.rect, depth === "deep" ? 0.45 : 0.2)
                }
            }
        }
    }
}
