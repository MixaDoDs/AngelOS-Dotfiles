pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// The Golden Gate Dock: a glass slab floating over the bottom of the screen with the apps
// (MacDockModel), a small dot under each one that runs, its name in a bubble above the one under
// the pointer, a divider, Downloads and the Trash — in MacTahoe's icons drawn like macOS
// (DockIcons) when they are there. Click: bring the app's windows to the front (its next window
// if it is in front already) or start it — it bounces until its window comes; right click: the
// Dock menu (its windows, its .desktop actions, Keep in Dock, Quit). Settings: size,
// magnification and how big, hiding (Config.mac.dock*). Input on the Dock only, blur on the slab.
//
// Magnification as on a Mac: each icon grows by its distance from the pointer, measured in the
// Dock at rest (so sizes never feed back into themselves); the grown row is laid out so the spot
// under the pointer stays under it — the Dock widens to both sides around the pointer and slides
// nowhere while you move along it. Growing and shrinking back are animated, moving is not.
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
    // the icon right under the pointer
    readonly property real big: magnify ? Math.max(icon, GoldenGate.px(Math.min(128, Config.mac.dockMagnifySize))) : icon
    // how far the bump reaches each way: about three icons, like macOS
    readonly property real reach: (icon + gap) * 3.2
    readonly property real headroom: big - icon + GoldenGate.px(44)   // grown icons and the name bubble
    readonly property bool autohide: Config.mac.dockAutohide
    readonly property bool menuHere: MacMenus.isOpen && MacMenus.statusKind.indexOf("dock") === 0 && MacMenus.screen === screenName
    // hidden (autohide) unless the pointer came to the bottom edge or a Dock menu is open
    readonly property bool shown: !autohide || hover.hovered || menuHere
    // the slab slides down out of sight when hidden
    property real drop: shown ? 0 : slabH + margin + GoldenGate.px(4)
    Behavior on drop {
        NumberAnimation {
            duration: Motion.ms(220)
            easing.type: Easing.OutCubic
        }
    }

    // ---- what is in it: the apps, the divider, Downloads, the Trash ----
    readonly property var items: MacDockModel.apps.concat([
        {
            "kind": "divider",
            "id": "@divider"
        },
        {
            "kind": "downloads",
            "id": "@downloads",
            "name": I18n.t("Загрузки", "Downloads"),
            "icon": "folder-download",
            "windows": []
        },
        {
            "kind": "trash",
            "id": "@trash",
            "name": I18n.t("Корзина", "Trash"),
            "icon": MacDockModel.trashFull ? "user-trash-full" : "user-trash",
            "windows": []
        }
    ])
    readonly property real dividerW: GoldenGate.px(1) + gap
    // the Dock at rest: each item's width, the row's width and where it starts
    readonly property var rest: items.map(it => it.kind === "divider" ? dividerW : icon)
    readonly property real restW: rest.reduce((a, w) => a + w, 0) + gap * Math.max(0, items.length - 1)
    readonly property real restLeft: Math.round((width - restW) / 2)

    // ---- magnification ----
    property real pointer: -1               // the pointer's x over the Dock (window coordinates)
    readonly property bool zooming: magnify && pointer >= 0 && (hover.hovered || menuHere)
    // (animated even with Motion off: growing and shrinking back are how the magnification
    // answers the pointer, not decoration — without them the Dock snaps)
    property real zoom: zooming ? 1 : 0     // 0 at rest .. 1 grown; the pointer's last x is kept while it shrinks
    Behavior on zoom {
        NumberAnimation {
            duration: win.zooming ? 140 : 260
            easing.type: Easing.OutCubic
        }
    }
    function bump(d) {
        return d >= 1 ? 0 : (Math.cos(d * Math.PI) + 1) / 2;
    }
    // sizes and places of the items now: {sizes, xs, left, width, tallest}
    readonly property var layout: {
        const n = items.length;
        const sizes = [];
        const u = pointer - restLeft;           // the pointer in the Dock at rest
        let c = 0;
        for (let i = 0; i < n; i++) {
            const w = rest[i];
            const g = zoom > 0 && items[i].kind !== "divider" ? bump(Math.abs(u - (c + w / 2)) / reach) * zoom : 0;
            sizes.push(w + (big - icon) * g);
            c += w + gap;
        }
        // each item owns its width and half a gap each side; the pointer keeps its share of the
        // item it is over, in the grown row as at rest
        let at = u;
        if (zoom > 0) {
            let b = -gap / 2, gr = -gap / 2;
            at = u;
            for (let i = 0; i < n; i++) {
                const bw = rest[i] + gap, gw = sizes[i] + gap;
                if (u < b + bw) {
                    at = u < b ? u - b + gr : gr + (u - b) / bw * gw;
                    break;
                }
                b += bw;
                gr += gw;
                if (i === n - 1)
                    at = gr + (u - b);
            }
        }
        const grownW = sizes.reduce((a, w) => a + w, 0) + gap * Math.max(0, n - 1);
        let left = zoom > 0 ? pointer - at : restLeft;
        left = grownW < width ? Math.max(0, Math.min(width - grownW, left)) : (width - grownW) / 2;
        const xs = [];
        let x = left;
        for (let i = 0; i < n; i++) {
            xs.push(x);
            x += sizes[i] + gap;
        }
        return {
            "sizes": sizes,
            "xs": xs,
            "left": left,
            "width": grownW,
            "tallest": Math.max(icon, ...sizes)
        };
    }
    // the slab's bottom edge (window coordinates): icons stand on it, a pad above
    readonly property real floor: headroom + slabH + drop

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
        item: win.shown ? zone : edge
    }
    BackgroundEffect.blurRegion: Config.appearance.blur && win.shown ? blurRegion : null
    Region {
        id: blurRegion
        item: slab
        radius: slab.radius
    }

    Item {
        id: stage
        anchors.fill: parent

        // the pointer anywhere over the Dock: the slab, the grown icons, the strip under it
        HoverHandler {
            id: hover
            onPointChanged: if (hovered)
                win.pointer = point.position.x
        }

        // where the Dock takes the pointer: over the slab and the grown icons, down to the
        // screen's edge (a pointer pushed against the edge still magnifies, like macOS)
        Item {
            id: zone
            x: slab.x
            width: slab.width
            y: win.floor - win.slabH - (win.layout.tallest - win.icon)
            height: win.height - y
        }
        // the 2 px along the bottom under the Dock that bring it back when hidden
        Item {
            id: edge
            x: win.restLeft - win.pad
            width: win.restW + win.pad * 2
            height: GoldenGate.px(2)
            anchors.bottom: parent.bottom
        }

        MacGlass {
            id: slab
            x: Math.round(win.layout.left - win.pad)
            width: Math.round(win.layout.width + win.pad * 2)
            height: win.slabH
            y: win.floor - win.slabH
            radius: Math.round(win.slabH * 0.36)
            shadowSize: GoldenGate.px(24)
            shadowY: GoldenGate.px(4)
        }

        Repeater {
            model: win.items
            Loader {
                id: slot
                required property var modelData
                required property int index
                x: win.layout.xs[index] || 0
                sourceComponent: modelData.kind === "divider" ? divider : dockIcon
                Component {
                    id: divider
                    Item {
                        width: win.dividerW
                        height: win.icon
                        y: win.floor - win.pad - height
                        Rectangle {
                            anchors.centerIn: parent
                            width: GoldenGate.px(1)
                            height: parent.height * 0.82
                            color: GoldenGate.separator
                        }
                    }
                }
                Component {
                    id: dockIcon
                    DockIcon {
                        item: slot.modelData
                        size: win.layout.sizes[slot.index] || win.icon
                        y: win.floor - win.pad - size
                    }
                }
            }
        }
    }

    component DockIcon: Item {
        id: cell
        property var item
        property real size: win.icon
        readonly property bool hovered: mouse.containsMouse
        readonly property bool bouncing: !!MacDockModel.bouncing[item.id]
        readonly property string mac: DockIcons.forItem(item)
        width: size
        height: size

        Item {
            id: art
            anchors.fill: parent
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

            // MacTahoe's icon (DockIcons), else the theme's; else drawn here, in the squircle
            // every Mac icon has: System Settings, Apps, Downloads, the Trash — and an app whose
            // icon the theme doesn't have (its initial)
            readonly property bool drawn: !cell.mac && (cell.item.kind !== "app" || appIcon.status === Image.Error || appIcon.source.toString() === "")
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
                visible: !cell.mac && (cell.item.kind === "settings" || cell.item.kind === "apps")
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
                // drawn once at the grown size (twice that for sharpness), scaled down at rest
                sourceSize: Qt.size(Math.ceil(win.big) * 2, Math.ceil(win.big) * 2)
                smooth: true
                mipmap: true
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                source: {
                    if (cell.mac)
                        return cell.mac;
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
            y: -height - GoldenGate.px(8)
            MacText {
                id: tip
                anchors.centerIn: parent
                text: cell.item.name || ""
            }
        }
        // the icon and the strip under it down to the screen's edge (a pointer pushed against the
        // edge still hits it, like macOS); half the gap each side, so no gap is dead
        MouseArea {
            id: mouse
            x: -win.gap / 2
            width: parent.width + win.gap
            height: win.height - cell.y
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: m => {
                const it = cell.item;
                if (m.button === Qt.RightButton) {
                    // above the icon (grown, it stays so while the menu is open), in the screen's coordinates
                    const p = cell.mapToItem(null, cell.width / 2, 0);
                    MacMenus.openDock(win.screenName, it, p.x, win.modelData.height - win.height + p.y - GoldenGate.px(8));
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
