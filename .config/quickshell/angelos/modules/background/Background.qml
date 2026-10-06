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
//   angelos-wallpaper — the picture, the desktop widgets' faces and the demon's broken
//                       glass (ScreenCracks); niri keeps it
//                       in the backdrop (layer-rule place-within-backdrop): it
//                       does not slide with workspaces and shows once in the
//                       overview, but gets no input
//   angelos-desktop   — transparent, drawn inside every workspace: the widgets'
//                       input copies (invisible unless a button in them is used,
//                       see DesktopWidgetHost), the right-click menu and the
//                       sparkle trail
Variants {
    model: Shell.screens

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
                Repeater {
                    model: DesktopWidgets.uidsFor(scope.modelData.name)
                    DesktopWidgetHost {
                        required property string modelData
                        role: "face"
                        uid: modelData
                        screenName: scope.modelData.name
                        area: faceArea
                        backdrop: wallpaper
                    }
                }
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
            // the menu opens where the right button went down (ContextClick: B2)
            ContextClick {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton | Qt.LeftButton
                hoverEnabled: win.sparkles
                onPositionChanged: m => {
                    if (win.sparkles)
                        trail.spawn(m.x, m.y);
                }
                // Golden Gate: Finder's desktop menu in the skin's glass (MacMenus)
                onMenu: (x, y) => GoldenGate.on ? MacMenus.openDesktop(win.modelData.name, x, y) : menu.openAt(x, y)
                onOtherClicked: {
                    menu.close();
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
                        onContextMenu: (x, y) => menu.openAt(x, y)
                    }
                }
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

            // the ring look of the same menu (Settings → Right-click menu)
            RadialMenu {
                id: ring
                parentWindow: win
                listMenu: menu
            }

            RightClickGuard {}
        }
    }
}
