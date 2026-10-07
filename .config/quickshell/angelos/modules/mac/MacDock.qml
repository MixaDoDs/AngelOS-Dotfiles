pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// The Golden Gate Dock: a glass slab floating over the bottom of the screen with the apps
// (MacDockModel), a small dot under each one that runs, its name in a bubble above the one under
// the pointer, a divider, the minimized windows (services/Minimize: a snapshot each, its app's
// icon in the corner; a click brings it back), Downloads and the Trash — in MacTahoe's icons
// drawn like macOS (DockIcons) when they are there. Click: bring the app's windows to the front
// (its next window if it is in front already; its last minimized one if that is all it has) or
// start it — it bounces until its window comes; right click: the Dock menu (its windows, its
// .desktop actions, Keep in Dock, Quit). Settings: size, magnification and how big, hiding
// (Config.mac.dock*). Input on the Dock only, blur on the slab.
//
// Magnification as on a Mac: each icon grows by its distance from the pointer, measured in the
// Dock at rest (so sizes never feed back into themselves); the grown row is laid out so the spot
// under the pointer stays under it — the Dock widens to both sides around the pointer and slides
// nowhere while you move along it. Growing and shrinking back are animated, moving is not.
//
// On the left or the right (Config.mac.dockPosition, GoldenGate.dockEdge) it is the same Dock laid
// along that edge: the stage is drawn as for the bottom and turned (`turn`, a matrix: the floor goes
// to the edge, the row runs downwards); what must stay upright inside — the icons, the name
// bubbles — is turned back (`upright`). The pointer comes through the same transform, so every
// measure below stays in the stage's terms: "above" is away from the edge.
//
// Dragging, as on a Mac: hold an app and move it — the others make room where it would go, let go
// and the order is kept (Config.mac.dockApps; an app that only ran is kept from then on). Pulled
// well above the Dock a kept app says "Remove from Dock": let go there and it goes in a puff (one
// that runs stays, no longer kept). The right part (the minimized windows, Downloads, the Trash)
// doesn't move. The icons are a ListModel synced in place by id, so a window opening or the focus
// moving never rebuilds them — not under a held icon either.
PanelWindow {
    id: win

    required property var modelData
    readonly property string screenName: modelData.name
    // the edge it stands on; the stage's length along it and its depth across it
    readonly property string dockSide: GoldenGate.dockEdge
    readonly property bool vertical: dockSide !== "bottom"
    readonly property real along: vertical ? height : width
    readonly property real thick: headroom + slabH + margin
    // stage → window: the bottom as it is; the left: turned a quarter clockwise (the floor to the
    // left edge); the right: mirrored on the diagonal (the floor to the right edge, the row down)
    readonly property matrix4x4 turn: dockSide === "left" ? Qt.matrix4x4(0, -1, 0, thick, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) : dockSide === "right" ? Qt.matrix4x4(0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) : Qt.matrix4x4()
    // the inverse, about the middle of an item w × h: what stands upright on the screen
    function upright(w, h) {
        const cx = w / 2, cy = h / 2;
        if (dockSide === "left")
            return Qt.matrix4x4(0, 1, 0, cx - cy, -1, 0, 0, cx + cy, 0, 0, 1, 0, 0, 0, 0, 1);
        if (dockSide === "right")
            return Qt.matrix4x4(0, 1, 0, cx - cy, 1, 0, 0, cy - cx, 0, 0, 1, 0, 0, 0, 0, 1);
        return Qt.matrix4x4();
    }
    // a point of the stage on the screen (screen px): the window stands at the screen's bottom,
    // on its left or right edge
    function toScreen(item, x, y) {
        const p = item.mapToItem(null, x, y);
        return Qt.point(dockSide === "right" ? modelData.width - width + p.x : p.x, modelData.height - height + p.y);
    }
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
    readonly property real headroom: big - icon + GoldenGate.px(44) + dragRoom   // grown icons and the name bubble
    // room above for an app pulled out of the Dock ("Remove from Dock" over it, the puff). Always
    // there (the window is clear and takes no input outside the Dock, `mask`): a window that grew
    // while the pointer was held got the pointer in its old coordinates for a while and lost it
    readonly property real dragRoom: GoldenGate.px(260)
    readonly property bool autohide: Config.mac.dockAutohide
    readonly property bool menuHere: MacMenus.isOpen && MacMenus.statusKind.indexOf("dock") === 0 && MacMenus.screen === screenName
    // hidden (autohide) unless the pointer came to the bottom edge or a Dock menu is open
    readonly property bool shown: !autohide || hover.hovered || menuHere || dragging
    // the slab slides down out of sight when hidden
    property real drop: shown ? 0 : slabH + margin + GoldenGate.px(4)
    Behavior on drop {
        NumberAnimation {
            duration: Motion.ms(220)
            easing.type: Easing.OutCubic
        }
    }

    // ---- what is in it: the apps, the divider, the minimized windows, Downloads, the Trash ----
    readonly property var items: MacDockModel.apps.concat([
        {
            "kind": "divider",
            "id": "@divider"
        }
    ], MacDockModel.minimized, [
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
    // id -> index in items; the delegates are rows of `rows` (one per id), kept and moved in place
    readonly property var byKey: {
        const m = {};
        items.forEach((it, i) => m[it.id] = i);
        return m;
    }
    ListModel {
        id: rows
    }
    onItemsChanged: syncRows()
    function syncRows() {
        const keys = items.map(it => it.id);
        for (let i = rows.count - 1; i >= 0; i--)
            if (keys.indexOf(rows.get(i).key) < 0)
                rows.remove(i);
        for (let i = 0; i < keys.length; i++) {
            let j = -1;
            for (let k = i; k < rows.count; k++)
                if (rows.get(k).key === keys[i]) {
                    j = k;
                    break;
                }
            if (j < 0)
                rows.insert(i, {
                    "key": keys[i]
                });
            else if (j !== i)
                rows.move(j, i, 1);
        }
        // the held app is gone (it quit and wasn't kept): the drag ends
        if (dragKey && keys.indexOf(dragKey) < 0)
            endDrag();
    }

    // ---- dragging an app (MacDockModel.setOrder / setKept) ----
    property string dragKey: ""             // the app held, "" none
    property real dragX: 0                  // the pointer, in the stage's coordinates
    property real dragY: 0
    property bool settling: false           // let go: it glides into its place, then the order is written
    property bool settleHome: false         // ... its place as it was (pulled out: not moved)
    property bool suppressClick: false      // the release of a drag is no click
    readonly property bool dragging: dragKey !== ""
    readonly property int dragIndex: dragging && byKey[dragKey] !== undefined ? byKey[dragKey] : -1
    readonly property var dragItem: dragIndex >= 0 ? items[dragIndex] : null
    // the apps lead the Dock: the part that can be put in order (the divider closes it)
    readonly property int appCount: Math.max(0, items.findIndex(it => it.kind === "divider"))
    // a dropped app is kept, so it never lands after the apps that only run
    readonly property int dropLimit: dragItem ? items.slice(0, appCount).filter(it => it.kept && it.id !== dragKey).length : 0
    // well above the Dock: let go there and a kept app goes out of it; the place of one that will be
    // gone (not running) closes at once
    readonly property bool dragAbove: dragging && !settling && dragY < floor - slabH - icon * 0.9
    readonly property bool dragRemoves: dragAbove && !!dragItem && dragItem.kept
    readonly property bool dragVanishes: dragRemoves && !(dragItem.kind === "app" && dragItem.windows && dragItem.windows.length)
    // where among the other apps it would go: the Dock at rest is a row of equal places (measured
    // with every item in it, as it stands while one is held inside — not from restLeft, which
    // follows the order this decides)
    readonly property real fullLeft: Math.round((along - items.reduce((a, it) => a + (it.kind === "divider" ? dividerW : icon), 0) - gap * Math.max(0, items.length - 1)) / 2)
    readonly property int dropAt: {
        if (!dragItem)
            return -1;
        const k = Math.round((dragX - fullLeft - icon / 2) / (icon + gap));
        return Math.max(0, Math.min(dropLimit, k));
    }
    // the items in the order they stand now (indices into items)
    readonly property var order: {
        const idx = items.map((_, i) => i);
        if (dragIndex < 0 || settleHome || (dragAbove && !dragVanishes))
            return idx;
        const others = idx.filter(i => i !== dragIndex);
        if (dragVanishes)
            return others;
        others.splice(dropAt, 0, dragIndex);
        return others;
    }
    function startDrag(key) {
        MacMenus.close();
        dragKey = key;
        settling = false;
        settleHome = false;
        suppressClick = true;
    }
    function letGo() {
        if (!dragItem) {
            endDrag();
            return;
        }
        if (dragRemoves) {
            if (dragVanishes) {
                poof(dragX, dragY);
                const k = dragKey;
                endDrag();
                MacDockModel.setKept(k, false);
                return;
            }
            // it runs: no longer kept, it goes back among the running ones
            MacDockModel.setKept(dragKey, false);
            settleHome = true;
        } else if (dragAbove) {
            settleHome = true;          // an app that only runs, pulled out: back to its place
        }
        settling = true;
        settleTimer.restart();
    }
    function endDrag() {
        settleTimer.stop();
        dragKey = "";
        settling = false;
        settleHome = false;
    }
    Timer {
        id: settleTimer
        interval: Motion.ms(200) + 20
        onTriggered: {
            if (!win.settleHome && win.dragItem) {
                const ids = win.order.filter(i => i < win.appCount).map(i => win.items[i]).filter(it => it.kept || it.id === win.dragKey).map(it => it.id);
                MacDockModel.setOrder(ids);
            }
            win.endDrag();
        }
    }
    // the puff an app leaves the Dock in
    property var poofs: []
    property int _poofN: 0
    function poof(x, y) {
        if (Motion.ms(100) <= 0)
            return;
        _poofN++;
        poofs = poofs.concat([{
                "key": _poofN,
                "x": x,
                "fromBottom": thick - y           // the window shrinks back meanwhile
            }]);
    }

    // the Dock at rest: each item's width (in the order they stand), the row's width and where it starts
    readonly property var rest: order.map(i => items[i].kind === "divider" ? dividerW : icon)
    readonly property real restW: rest.reduce((a, w) => a + w, 0) + gap * Math.max(0, order.length - 1)
    readonly property real restLeft: Math.round((along - restW) / 2)

    // ---- magnification ----
    property real pointer: -1               // the pointer's x over the Dock (window coordinates)
    readonly property bool zooming: magnify && pointer >= 0 && (hover.hovered || menuHere) && !dragging
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
    // sizes and places of the items now: {sizes, xs, left, width, tallest}, by index into items
    // (worked out in the order they stand: `order`; one taken out of it has its own place)
    readonly property var layout: {
        const n = order.length;
        const sizes = [];
        const u = pointer - restLeft;           // the pointer in the Dock at rest
        let c = 0;
        for (let i = 0; i < n; i++) {
            const w = rest[i];
            const g = zoom > 0 && items[order[i]].kind !== "divider" ? bump(Math.abs(u - (c + w / 2)) / reach) * zoom : 0;
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
        left = grownW < along ? Math.max(0, Math.min(along - grownW, left)) : (along - grownW) / 2;
        const xs = items.map(() => 0);
        const byItem = items.map(() => icon);
        let x = left;
        for (let i = 0; i < n; i++) {
            xs[order[i]] = x;
            byItem[order[i]] = sizes[i];
            x += sizes[i] + gap;
        }
        return {
            "sizes": byItem,
            "xs": xs,
            "left": left,
            "width": grownW,
            "tallest": Math.max(icon, ...sizes)
        };
    }
    // the slab's bottom edge (window coordinates): icons stand on it, a pad above
    readonly property real floor: headroom + slabH + drop

    screen: modelData
    // along the whole edge (on the left and right: between the menu bar and the bottom)
    anchors.bottom: true
    anchors.left: dockSide !== "right"
    anchors.right: dockSide !== "left"
    anchors.top: vertical
    implicitWidth: vertical ? thick : modelData.width
    implicitHeight: vertical ? modelData.height : thick
    exclusiveZone: autohide ? 0 : slabH + margin
    // services/Minimize works out where a tiled window stands from the zone the Dock keeps
    onExclusiveZoneChanged: Minimize.dockZone[screenName] = exclusiveZone
    onDockSideChanged: Minimize.dockEdge[screenName] = dockSide
    Component.onCompleted: {
        Minimize.dockZone[screenName] = exclusiveZone;
        Minimize.dockEdge[screenName] = dockSide;
        syncRows();
    }
    exclusionMode: Shell.dev ? ExclusionMode.Ignore : ExclusionMode.Normal
    color: "transparent"
    WlrLayershell.namespace: "angelos-macdock"
    WlrLayershell.layer: WlrLayer.Top
    // the edge it keeps from windows, for the screenshot selector (services/Zones)
    ZoneReport {
        win: win
        key: "macdock"
    }
    // a rectangle of the stage in the window: Region { item } takes an item's geometry as it is,
    // not turned with the stage
    function winRect(x, y, w, h) {
        if (dockSide === "left")
            return [thick - y - h, x, h, w];
        if (dockSide === "right")
            return [y, x, h, w];
        return [x, y, w, h];
    }
    readonly property var inputRect: shown ? winRect(zone.x, zone.y, zone.width, zone.height) : winRect(edge.x, edge.y, edge.width, edge.height)
    readonly property var slabRect: winRect(slab.x, slab.y, slab.width, slab.height)
    mask: Region {
        x: win.inputRect[0]
        y: win.inputRect[1]
        width: win.inputRect[2]
        height: win.inputRect[3]
    }
    BackgroundEffect.blurRegion: GoldenGate.blurOn && win.shown ? blurRegion : null
    Region {
        id: blurRegion
        x: win.slabRect[0]
        y: win.slabRect[1]
        width: win.slabRect[2]
        height: win.slabRect[3]
        radius: slab.radius
    }

    Item {
        id: stage
        width: win.along
        height: win.thick
        transform: Matrix4x4 {
            matrix: win.turn
        }

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
            height: win.thick - y
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
            model: rows
            Loader {
                id: slot
                required property string key
                readonly property int pos: win.byKey[key] !== undefined ? win.byKey[key] : -1
                readonly property var modelData: pos >= 0 ? win.items[pos] : ({
                        "kind": "divider",
                        "id": key
                    })
                // the held app follows the pointer (its middle under it); let go, it glides home
                readonly property bool held: win.dragKey === key
                readonly property bool follows: held && !win.settling
                z: held ? 2 : 0
                x: follows ? win.dragX - win.icon / 2 : (win.layout.xs[pos] || 0)
                y: follows ? win.dragY - win.icon / 2 - (win.floor - win.pad - win.icon) : 0
                // the others make room smoothly while one is held (only then: the magnification moves
                // them every frame and must not lag)
                Behavior on x {
                    enabled: win.dragging && !slot.follows
                    NumberAnimation {
                        duration: Motion.ms(200)
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    enabled: win.dragging && !slot.follows
                    NumberAnimation {
                        duration: Motion.ms(200)
                        easing.type: Easing.OutCubic
                    }
                }
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
                        held: slot.held
                        size: win.layout.sizes[slot.pos] || win.icon
                        y: win.floor - win.pad - size
                    }
                }
            }
        }

        Repeater {
            model: win.poofs
            Poof {}
        }
    }

    component Poof: Item {
        id: puff
        required property var modelData
        x: modelData.x
        y: win.thick - modelData.fromBottom
        property real t: 0
        NumberAnimation on t {
            from: 0
            to: 1
            duration: Motion.ms(420)
            easing.type: Easing.OutQuad
            onFinished: win.poofs = win.poofs.filter(p => p.key !== puff.modelData.key)
        }
        // a little cloud: a few soft puffs growing apart and fading
        Repeater {
            model: [[0, 0, 1], [-0.55, -0.25, 0.75], [0.55, -0.3, 0.8], [-0.3, 0.4, 0.7], [0.35, 0.38, 0.65], [0, -0.6, 0.6]]
            Rectangle {
                required property var modelData
                readonly property real r: win.icon * 0.32 * modelData[2] * (0.6 + puff.t * 0.9)
                x: modelData[0] * win.icon * 0.55 * (0.5 + puff.t) - r
                y: modelData[1] * win.icon * 0.55 * (0.5 + puff.t) - r
                width: r * 2
                height: r * 2
                radius: r
                color: GoldenGate.dark ? Qt.rgba(0.92, 0.92, 0.95, 1) : Qt.rgba(1, 1, 1, 1)
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.12)
                opacity: (1 - puff.t) * 0.9
            }
        }
    }

    component DockIcon: Item {
        id: cell
        property var item
        property real size: win.icon
        property bool held: false               // being dragged (MacDock's drag)
        // the apps can be put in order and pulled out; the right part stays
        readonly property bool draggable: item.kind === "app" || item.kind === "apps" || item.kind === "settings"
        readonly property bool hovered: mouse.containsMouse
        readonly property bool bouncing: !!MacDockModel.bouncing[item.id]
        readonly property string mac: DockIcons.forItem(item)
        readonly property bool isWin: item.kind === "window"
        width: size
        height: size

        // where it is, for the minimize flight (services/Minimize.dockSlots, MacMinimizeFx): a
        // minimized window's snapshot lands here; Downloads is where one goes before its own
        // place is there. Written, not bound — the magnification moves it every frame.
        // (and a running app's icon: where its windows fly when the app hides, ⌘H)
        readonly property bool reports: isWin || item.kind === "downloads" || item.kind === "app"
        function report() {
            if (!reports || !cell.parent)
                return;
            const p = win.toScreen(cell, cell.width / 2, cell.height / 2);
            const at = [p.x, p.y, cell.width];
            if (item.kind === "app") {
                for (const w of item.windows || [])
                    Minimize.dockSlots[win.screenName + "|@app:" + w.app_id] = at;
                return;
            }
            Minimize.dockSlots[win.screenName + "|" + item.id] = at;
        }
        onSizeChanged: report()
        onYChanged: report()
        // a running app's windows come and go: their app ids are its keys
        readonly property int windowCount: item && item.windows ? item.windows.length : 0
        onWindowCountChanged: report()
        Component.onCompleted: Qt.callLater(report)
        Connections {
            target: win
            enabled: cell.reports
            function onLayoutChanged() {
                cell.report();
            }
        }

        Item {
            id: art
            anchors.fill: parent
            // a snapshot in flight to (or out of) this place: the place stays empty meanwhile
            opacity: cell.isWin && Minimize.flying.indexOf(cell.item.wid) >= 0 ? 0 : 1
            property real hop: 0
            // upright on the screen, then the hop (away from the edge)
            transform: [
                Matrix4x4 {
                    matrix: win.upright(art.width, art.height)
                },
                Translate {
                    y: -art.hop
                }
            ]
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
            readonly property bool drawn: !cell.mac && !appIcon.badge && (cell.item.kind !== "app" && !cell.isWin || appIcon.status === Image.Error || appIcon.source.toString() === "")
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
                    visible: cell.item.kind === "app" || cell.isWin
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
            // a minimized window: its snapshot, the app's icon (appIcon) small in the corner
            Item {
                visible: cell.isWin && shot.status === Image.Ready
                anchors.fill: parent
                anchors.margins: parent.width * 0.06
                Rectangle {
                    anchors.centerIn: shot
                    width: shot.paintedWidth + 2
                    height: shot.paintedHeight + 2
                    radius: GoldenGate.px(4)
                    color: Qt.rgba(0, 0, 0, 0.18)
                }
                Image {
                    id: shot
                    anchors.fill: parent
                    source: cell.isWin ? cell.item.shot || "" : ""
                    sourceSize: Qt.size(Math.ceil(win.big) * 2, Math.ceil(win.big) * 2)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    asynchronous: true
                }
            }
            Image {
                id: appIcon
                readonly property bool badge: cell.isWin && shot.status === Image.Ready
                visible: !art.drawn
                width: badge ? parent.width * 0.42 : parent.width
                height: width
                anchors.right: parent.right
                anchors.bottom: parent.bottom
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
                    if (cell.item.kind !== "app" && !cell.isWin || !n)
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
        // the name above it; while it is held over the place it would leave the Dock: "Remove"
        MacGlass {
            id: bubble
            visible: cell.held ? win.dragRemoves : cell.hovered && !win.dragging && !(MacMenus.isOpen && MacMenus.screen === win.screenName)
            radius: GoldenGate.px(9)
            shadowSize: GoldenGate.px(10)
            shadowY: GoldenGate.px(2)
            width: tip.implicitWidth + GoldenGate.px(20)
            height: GoldenGate.px(26)
            anchors.horizontalCenter: parent.horizontalCenter
            // its middle as far from the icon as its upright depth needs
            y: -(win.vertical ? width : height) / 2 - GoldenGate.px(8) - height / 2
            transform: Matrix4x4 {
                matrix: win.upright(bubble.width, bubble.height)
            }
            MacText {
                id: tip
                anchors.centerIn: parent
                text: cell.held ? I18n.t("Убрать из Dock", "Remove from Dock") : cell.item.name || ""
            }
        }
        // the icon and the strip under it down to the screen's edge (a pointer pushed against the
        // edge still hits it, like macOS); half the gap each side, so no gap is dead
        MouseArea {
            id: mouse
            x: -win.gap / 2
            width: parent.width + win.gap
            height: win.thick - cell.y
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            preventStealing: true
            // held and moved a little: the drag (MacDock.startDrag); the pointer is followed in
            // the stage's coordinates — the icon itself moves under it
            property real pressX: 0
            property real pressY: 0
            onPressed: m => {
                win.suppressClick = false;
                const p = mapToItem(stage, m.x, m.y);
                pressX = p.x;
                pressY = p.y;
            }
            onPositionChanged: m => {
                if (!pressed || !(pressedButtons & Qt.LeftButton))
                    return;
                const p = mapToItem(stage, m.x, m.y);
                // the right part doesn't move; pulled and let go it is no click either
                if (!cell.draggable) {
                    if (Math.hypot(p.x - pressX, p.y - pressY) > GoldenGate.px(6))
                        win.suppressClick = true;
                    return;
                }
                if (!win.dragging && !win.settling && Math.hypot(p.x - pressX, p.y - pressY) > GoldenGate.px(6))
                    win.startDrag(cell.item.id);
                if (win.dragKey === cell.item.id && !win.settling) {
                    win.dragX = p.x;
                    win.dragY = p.y;
                }
            }
            onReleased: m => {
                if (win.dragKey === cell.item.id && !win.settling)
                    win.letGo();
            }
            onCanceled: if (win.dragKey === cell.item.id && !win.settling)
                win.endDrag()
            onClicked: m => {
                if (win.suppressClick) {
                    win.suppressClick = false;
                    return;
                }
                const it = cell.item;
                // above the icon (grown, it stays so while the menu is open), in the screen's
                // coordinates; beside it for a Dock on the left or right (its near edge, its middle)
                const p = win.toScreen(cell, cell.width / 2, -GoldenGate.px(8));
                const ax = p.x;
                const ay = win.vertical ? win.toScreen(cell, cell.width / 2, cell.height / 2).y : p.y;
                if (m.button === Qt.RightButton) {
                    MacMenus.openDock(win.screenName, it, ax, ay, win.dockSide);
                    return;
                }
                // Downloads: its stack (MacStack) — a second click closes it
                if (it.kind === "downloads") {
                    MacMenus.openStack(win.screenName, it, ax, ay, win.dockSide);
                    return;
                }
                MacMenus.close();
                if (it.kind === "trash")
                    MacDockModel.openTrash();
                else
                    MacDockModel.open(it, win.screenName);
            }
        }
    }

    RightClickGuard {}
}
