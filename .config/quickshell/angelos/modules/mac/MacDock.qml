pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// The Golden Gate Dock: a glass slab floating over the bottom of the screen with the apps
// (MacDockModel), a small dot under each one that runs, its name in a bubble above the one under
// the pointer, a divider, Downloads and the Trash. Click: bring the app's windows to the front (its
// next window if it is in front already) or start it — it bounces until its window comes; right
// click: the Dock menu (its windows, its .desktop actions, Keep in Dock, Quit). Settings: size,
// magnification, hiding (Config.mac.dock*). Input and blur only on the slab.
PanelWindow {
    id: win

    required property var modelData
    readonly property string screenName: modelData.name
    readonly property real icon: GoldenGate.px(Math.max(32, Math.min(96, Config.mac.dockSize)))
    readonly property real gap: Math.round(icon * 0.1)          // between icons
    readonly property real pad: Math.round(icon * 0.14)         // inside the slab, around the icons
    readonly property real slabH: icon + pad * 2
    readonly property real margin: GoldenGate.px(5)            // from the screen's edge
    readonly property bool magnify: Config.mac.dockMagnify
    readonly property real grown: magnify ? icon * 0.75 : 0
    readonly property real headroom: Math.max(grown, GoldenGate.px(40))   // grown icons and the name bubble
    readonly property bool autohide: Config.mac.dockAutohide
    // hidden (autohide) unless the pointer came to the bottom edge or a Dock menu is open
    readonly property bool shown: !autohide || hover.hovered || edgeHover.hovered || (MacMenus.isOpen && MacMenus.statusKind.indexOf("dock") === 0 && MacMenus.screen === screenName)
    property real mouseX: -1

    screen: modelData
    anchors.bottom: true
    implicitWidth: modelData.width
    implicitHeight: headroom + slabH + margin
    exclusiveZone: autohide ? 0 : slabH + margin
    exclusionMode: Shell.dev ? ExclusionMode.Ignore : ExclusionMode.Normal
    color: "transparent"
    WlrLayershell.namespace: "angelos-macdock"
    WlrLayershell.layer: WlrLayer.Top
    mask: Region {
        item: win.shown ? slab : edge
    }
    BackgroundEffect.blurRegion: Config.appearance.blur && win.shown ? blurRegion : null
    Region {
        id: blurRegion
        item: slab
        radius: slab.radius
    }

    // the 2 px along the bottom that brings a hidden Dock back
    Item {
        id: edge
        width: parent.width
        height: GoldenGate.px(2)
        anchors.bottom: parent.bottom
        HoverHandler {
            id: edgeHover
        }
    }

    MacGlass {
        id: slab
        readonly property real want: row.width + win.pad * 2
        width: want
        height: win.slabH
        x: Math.round((win.width - width) / 2)
        y: win.headroom + (win.shown ? 0 : win.slabH + win.margin + GoldenGate.px(4))
        radius: Math.round(win.slabH * 0.36)
        shadowSize: GoldenGate.px(24)
        shadowY: GoldenGate.px(4)
        Behavior on y {
            NumberAnimation {
                duration: Motion.ms(220)
                easing.type: Easing.OutCubic
            }
        }
        HoverHandler {
            id: hover
            onPointChanged: win.mouseX = hovered ? point.position.x - win.pad : -1
            onHoveredChanged: if (!hovered)
                win.mouseX = -1
        }

        Row {
            id: row
            x: win.pad
            anchors.bottom: parent.bottom
            anchors.bottomMargin: win.pad
            spacing: win.gap

            Repeater {
                model: MacDockModel.apps
                DockIcon {
                    required property var modelData
                    item: modelData
                }
            }
            // the divider between the apps and the folders
            Item {
                width: GoldenGate.px(1) + win.gap
                height: win.icon
                Rectangle {
                    anchors.centerIn: parent
                    width: GoldenGate.px(1)
                    height: parent.height * 0.82
                    color: GoldenGate.separator
                }
            }
            DockIcon {
                item: ({
                        "kind": "downloads",
                        "id": "@downloads",
                        "name": I18n.t("Загрузки", "Downloads"),
                        "icon": "folder-download",
                        "windows": []
                    })
            }
            DockIcon {
                item: ({
                        "kind": "trash",
                        "id": "@trash",
                        "name": I18n.t("Корзина", "Trash"),
                        "icon": MacDockModel.trashFull ? "user-trash-full" : "user-trash",
                        "windows": []
                    })
            }
        }
    }

    component DockIcon: Item {
        id: cell
        property var item
        readonly property bool hovered: mouse.containsMouse
        readonly property bool bouncing: !!MacDockModel.bouncing[item.id]
        // magnification: grows by the pointer's distance, like macOS (a cosine bump)
        readonly property real centerX: x + width / 2
        readonly property real grow: {
            if (!win.magnify || win.mouseX < 0)
                return 0;
            const d = Math.abs(win.mouseX - centerX) / (win.icon * 2.6);
            return d >= 1 ? 0 : (Math.cos(d * Math.PI) + 1) / 2;
        }
        readonly property real size: win.icon + win.grown * grow
        width: size
        height: win.icon

        Item {
            id: art
            width: cell.size
            height: cell.size
            anchors.bottom: parent.bottom
            property real hop: 0
            transform: Translate {
                y: -art.hop
            }
            SequentialAnimation on hop {
                running: cell.bouncing
                loops: Animation.Infinite
                onRunningChanged: if (!running)
                    art.hop = 0
                NumberAnimation {
                    to: win.icon * 0.45
                    duration: Motion.ms(260)
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    to: 0
                    duration: Motion.ms(260)
                    easing.type: Easing.InQuad
                }
                PauseAnimation {
                    duration: Motion.ms(120)
                }
            }

            // drawn here, in the squircle every Mac icon has: System Settings, Apps, Downloads, the
            // Trash — and an app whose icon the theme doesn't have (its initial)
            readonly property bool drawn: cell.item.kind !== "app" || appIcon.status === Image.Error || appIcon.source.toString() === ""
            Rectangle {
                visible: art.drawn
                anchors.fill: parent
                anchors.margins: parent.width * 0.06
                radius: width * 0.225
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: cell.item.kind === "downloads" ? "#6cc4ff" : cell.item.kind === "trash" ? Qt.rgba(1, 1, 1, 0.55) : cell.item.kind === "apps" ? "#fdfdfd" : cell.item.kind === "settings" ? "#d8d8dc" : "#8e9bb0"
                    }
                    GradientStop {
                        position: 1
                        color: cell.item.kind === "downloads" ? "#1e8fff" : cell.item.kind === "trash" ? Qt.rgba(0.85, 0.85, 0.88, 0.55) : cell.item.kind === "apps" ? "#e4e4ea" : cell.item.kind === "settings" ? "#8e8e96" : "#5a667a"
                    }
                }
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.12)
                MacIcon {
                    visible: cell.item.kind === "downloads" || cell.item.kind === "trash"
                    anchors.centerIn: parent
                    name: cell.item.kind === "downloads" ? "download" : "trash-2"
                    size: parent.width * 0.56
                    stroke: 1.8
                    color: cell.item.kind === "downloads" ? "#ffffff" : "#4a4a52"
                }
                MacText {
                    visible: cell.item.kind === "app"
                    anchors.centerIn: parent
                    text: String(cell.item.name || "?").charAt(0).toUpperCase()
                    size: parent.width * 0.5
                    bold: true
                    color: "#ffffff"
                }
            }
            Rectangle {
                visible: cell.item.kind === "settings" || cell.item.kind === "apps"
                anchors.fill: parent
                anchors.margins: parent.width * 0.06
                radius: width * 0.225
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: cell.item.kind === "apps" ? "#fdfdfd" : "#d8d8dc"
                    }
                    GradientStop {
                        position: 1
                        color: cell.item.kind === "apps" ? "#e4e4ea" : "#8e8e96"
                    }
                }
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.12)
                MacIcon {
                    visible: cell.item.kind === "settings"
                    anchors.centerIn: parent
                    name: "settings"
                    size: parent.width * 0.68
                    stroke: 1.6
                    color: "#3a3a40"
                }
                Grid {
                    visible: cell.item.kind === "apps"
                    anchors.centerIn: parent
                    columns: 3
                    spacing: parent.width * 0.07
                    Repeater {
                        model: ["#ff5f57", "#febc2e", "#28c840", "#0a84ff", "#bf5af2", "#ff9f0a", "#64d2ff", "#ff375f", "#30d158"]
                        Rectangle {
                            required property string modelData
                            width: art.width * 0.14
                            height: width
                            radius: width * 0.3
                            color: modelData
                        }
                    }
                }
            }
            Image {
                id: appIcon
                visible: !art.drawn
                anchors.fill: parent
                sourceSize: Qt.size(Math.ceil(win.icon + win.grown) * 2, Math.ceil(win.icon + win.grown) * 2)
                smooth: true
                mipmap: true
                fillMode: Image.PreserveAspectFit
                source: {
                    const n = String(cell.item.icon || "");
                    if (cell.item.kind !== "app" || !n)
                        return "";
                    if (n.startsWith("/"))
                        return "file://" + n;
                    return Quickshell.iconPath(n, true) || Quickshell.iconPath(n.toLowerCase(), true) || "";
                }
            }
        }
        // running: a small dot under it
        Rectangle {
            visible: cell.item.windows && cell.item.windows.length > 0
            width: GoldenGate.px(4)
            height: width
            radius: width / 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: Math.max(GoldenGate.px(1), win.pad / 2 - width / 2)
            color: GoldenGate.dark ? Qt.rgba(1, 1, 1, 0.75) : Qt.rgba(0, 0, 0, 0.6)
        }
        // the name above it
        MacGlass {
            visible: cell.hovered && !(MacMenus.isOpen && MacMenus.screen === win.screenName)
            radius: GoldenGate.px(9)
            shadowSize: GoldenGate.px(10)
            shadowY: GoldenGate.px(2)
            width: tip.implicitWidth + GoldenGate.px(20)
            height: GoldenGate.px(26)
            anchors.horizontalCenter: parent.horizontalCenter
            y: -height - win.pad - GoldenGate.px(6) - win.grown * cell.grow
            MacText {
                id: tip
                anchors.centerIn: parent
                text: cell.item.name || ""
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: m => {
                const it = cell.item;
                if (m.button === Qt.RightButton) {
                    const p = cell.mapToItem(null, cell.width / 2, 0);
                    MacMenus.openDock(win.screenName, it, p.x, win.height - win.slabH - win.margin - GoldenGate.px(8));
                    return;
                }
                MacMenus.close();
                if (it.kind === "downloads")
                    MacDockModel.openDownloads();
                else if (it.kind === "trash")
                    MacDockModel.openTrash();
                else
                    MacDockModel.open(it);
            }
        }
    }

    RightClickGuard {}
}
