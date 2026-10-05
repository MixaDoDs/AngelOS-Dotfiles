pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import QtTest
import qs.config
import qs.services
import qs.widgets

// angelOS title bars over floating windows (Settings → Windows → Decorations). niri
// draws no title bars and asks apps not to draw their own (prefer-no-csd), so a floating
// kitty, a Qt app or a game launcher had nothing to grab, close or maximize. Each gets a
// bar like the angelOS settings window's — icon, title, ♡ ✦, maximize and close — on a
// layer above it: drag it to move the window, double-click to maximize. Apps that draw
// their own (browsers, GTK4, Steam…) are skipped: GoldenGate.decorSkip (Config.mac.decorSkip in the
// Golden Gate skin, Config.decor.skip in the others).
// The bar sits right above the window (inside its top edge when there is no room), hides
// where another floating window covers it, in the overview, under fullscreen and while
// a workspace switch slides past. In hell (Theme.hell) it is obsidian and blackletter. In the
// Golden Gate skin it is a Mac's: the traffic lights on the left (close; minimize — to the Dock,
// services/Minimize; full screen), the title in the middle, double-click to zoom.
// The bars live in a ListModel keyed by window id, not in a JS array: every focus change
// and every step of a move rebuilt an array model, the bar being held was destroyed and
// the drag let go at once. While held, the bar follows the pointer itself and niri moves
// the window after it (move-floating-window, by the pointer's steps).
Variants {
    model: GoldenGate.titlebars ? Shell.screens : []

    PanelWindow {
        id: win

        required property var modelData
        readonly property string screenName: modelData.name
        readonly property var ws: Niri.activeWorkspace(screenName)
        // the Golden Gate skin: a Mac's title bar (traffic lights, the title in the middle)
        readonly property bool mac: GoldenGate.on && !Theme.hell
        readonly property int barH: mac ? GoldenGate.px(30) : Theme.sizeBody + Theme.u * 7
        // where a title bar may begin: under the skin's menu bar
        readonly property int topLimit: mac ? GoldenGate.barHeight : 0

        function skipped(appId) {
            const id = String(appId || "").toLowerCase();
            if (!id)
                return true;
            for (const s of GoldenGate.decorSkip) {
                const k = String(s).toLowerCase();
                if (k.endsWith("*") ? id.startsWith(k.slice(0, -1)) : id === k)
                    return true;
            }
            return false;
        }
        // the floating windows of this screen's workspace, lowest first (niri stacks
        // floating windows by focus: the last focused on top)
        readonly property var floating: !ws || Niri.overviewOpen || Shell.fullscreenOn(screenName) ? [] : Niri.windows.filter(w => w.workspace_id === ws.id && w.is_floating && w.layout && w.layout.tile_pos_in_workspace_view && w.layout.tile_size).sort((a, b) => {
            const ta = a.focus_timestamp ? a.focus_timestamp.secs * 1e9 + a.focus_timestamp.nanos : 0;
            const tb = b.focus_timestamp ? b.focus_timestamp.secs * 1e9 + b.focus_timestamp.nanos : 0;
            return ta - tb;
        })
        // one bar per window that wants one, where it goes and whether something covers it
        readonly property var bars: {
            const out = [];
            const list = floating;
            for (let i = 0; i < list.length; i++) {
                const w = list[i];
                if (skipped(w.app_id))
                    continue;
                const [x, y] = w.layout.tile_pos_in_workspace_view;
                const [tw] = w.layout.tile_size;
                const inside = y - barH < 0;
                // the Golden Gate skin: no room above the window (the menu bar, the screen's top) —
                // no title bar at all, never one laid over the app's own top (its menus, toolbar)
                if (mac && y - barH < topLimit)
                    continue;
                const r = {
                    "x": Math.round(x),
                    "y": Math.round(inside ? y : y - barH),
                    "w": Math.round(tw),
                    "h": barH
                };
                let covered = false;
                for (let j = i + 1; j < list.length && !covered; j++) {
                    const o = list[j], [ox, oy] = o.layout.tile_pos_in_workspace_view, [ow, oh] = o.layout.tile_size;
                    covered = r.x < ox + ow && ox < r.x + r.w && r.y < oy + oh && oy < r.y + r.h;
                }
                if (!covered)
                    out.push(Object.assign(r, {
                        "win": w,
                        "inside": inside
                    }));
            }
            return out;
        }

        readonly property var barMap: {
            const m = {};
            for (const b of bars)
                m[b.win.id] = b;
            return m;
        }

        // ---- the bar being dragged ----
        property int dragId: -1                  // its window, while the mouse holds it
        property var dragFrom: null              // where the bar was when it was grabbed
        property real dragX: 0                   // how far the pointer has gone since
        property real dragY: 0

        // the model: one row per window id; rows come and go, they are never rebuilt
        ListModel {
            id: barModel
        }
        function sync() {
            const want = switching ? [] : bars.map(b => b.win.id);
            if (dragId >= 0 && !want.includes(dragId))
                want.push(dragId);
            for (let i = barModel.count - 1; i >= 0; i--)
                if (!want.includes(barModel.get(i).wid))
                    barModel.remove(i);
            for (const id of want) {
                let found = false;
                for (let i = 0; i < barModel.count && !found; i++)
                    found = barModel.get(i).wid === id;
                if (!found)
                    barModel.append({
                        "wid": id
                    });
            }
        }
        onSwitchingChanged: Qt.callLater(sync)
        onDragIdChanged: Qt.callLater(sync)

        // the model follows; what it shows goes to `qs -c angelos ipc call angelos decor`
        onBarsChanged: {
            Qt.callLater(sync);
            const m = Object.assign({}, Shell.decor);
            m[screenName] = bars.map(b => ({
                        "id": b.win.id,
                        "app": b.win.app_id,
                        "x": b.x,
                        "y": b.y,
                        "w": b.w,
                        "inside": b.inside
                    }));
            Shell.decor = m;
        }
        // a workspace slides by: the windows move with niri's animation, the bars would not
        property bool switching: false
        Connections {
            target: Niri
            function onWorkspaceActivated(w, focused) {
                if (w && w.output === win.screenName) {
                    win.switching = true;
                    settle.restart();
                }
            }
        }
        Timer {
            id: settle
            interval: 420
            onTriggered: win.switching = false
        }

        screen: modelData
        visible: (bars.length > 0 || dragId >= 0) && !Shell.locked
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "angelos-decor"
        WlrLayershell.layer: WlrLayer.Top
        // input only on the bars: one Region per bar (each bar carries its own)
        property var hitList: []
        function rebuildHits() {
            const out = [];
            for (let i = 0; i < repeater.count; i++) {
                const it = repeater.itemAt(i);
                if (it)
                    out.push(it.hit);
            }
            hitList = out;
        }
        mask: Region {
            regions: win.hitList
        }

        Repeater {
            id: repeater
            model: barModel
            onItemAdded: Qt.callLater(win.rebuildHits)
            onItemRemoved: Qt.callLater(win.rebuildHits)

            Item {
                id: bar
                required property int wid
                readonly property bool held: win.dragId === wid
                // the latest from niri; while held, what it was when grabbed
                readonly property var info: win.barMap[wid] || (held ? win.dragFrom : null) || null
                readonly property var w: info ? info.win : ({
                        "id": wid,
                        "title": "",
                        "app_id": "",
                        "is_focused": false
                    })
                readonly property bool active: !!w.is_focused
                readonly property bool hell: Theme.hell
                readonly property Region hit: Region {
                    item: bar
                }
                visible: !!info
                x: held && win.dragFrom ? win.dragFrom.x + win.dragX : info ? info.x : 0
                y: held && win.dragFrom ? win.dragFrom.y + win.dragY : info ? info.y : 0
                width: info ? info.w : 0
                height: info ? info.h : win.barH

                PxBox {
                    visible: !win.mac
                    anchors.fill: parent
                    hell: bar.hell
                    color: bar.hell ? (bar.active ? Theme.mix(Theme.hellFaceAlt, Theme.hellBlood, 0.35) : Theme.hellFace) : bar.active || bar.held ? Theme.menuHeader : Theme.faceAlt
                    shadow: false
                }
                // a Mac's title bar: the window's own colour, the top corners round like niri's
                // window below it (templates/niri-mac.kdl squares that one's top corners)
                Rectangle {
                    visible: win.mac
                    anchors.fill: parent
                    topLeftRadius: bar.info && bar.info.inside ? 0 : GoldenGate.windowRadius
                    topRightRadius: topLeftRadius
                    color: GoldenGate.windowBg
                    MacText {
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, parent.width - GoldenGate.px(160))
                        horizontalAlignment: Text.AlignHCenter
                        text: Niri.titleOf(bar.w) || bar.w.app_id || ""
                        semibold: true
                        color: bar.active ? GoldenGate.label : GoldenGate.secondaryLabel
                    }
                }

                // drag: the bar goes with the pointer, niri moves the window after it;
                // double-click: maximize; middle click: close; a click focuses it
                MouseArea {
                    id: drag
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    preventStealing: true
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    property point from              // the press, in the layer's own coordinates
                    property bool moving: false
                    property real sentX: 0           // how far niri has been told to move it
                    property real sentY: 0
                    onPressed: m => {
                        if (m.button !== Qt.LeftButton)
                            return;
                        from = mapToItem(null, m.x, m.y);
                        moving = false;
                        sentX = 0;
                        sentY = 0;
                        win.dragX = 0;
                        win.dragY = 0;
                        win.dragFrom = Object.assign({}, bar.info);
                        win.dragId = bar.wid;
                        if (!bar.w.is_focused)
                            Niri.focusWindow(bar.wid);
                    }
                    onPositionChanged: m => {
                        if (!pressed || win.dragId !== bar.wid)
                            return;
                        const p = mapToItem(null, m.x, m.y);
                        const dx = p.x - from.x, dy = p.y - from.y;
                        // a click stays a click: it moves only past a few pixels
                        if (!moving && Math.abs(dx) + Math.abs(dy) < Theme.u * 3)
                            return;
                        moving = true;
                        win.dragX = dx;
                        win.dragY = dy;
                        if (!throttle.running)
                            throttle.start();
                    }
                    function finish() {
                        throttle.flush();
                        letGo.restart();
                    }
                    onReleased: finish()
                    onCanceled: finish()
                    onClicked: m => {
                        if (m.button === Qt.MiddleButton)
                            Niri.closeWindow(bar.wid);
                    }
                    onDoubleClicked: m => {
                        if (m.button === Qt.LeftButton)
                            Niri.maximizeWindow(bar.wid);
                    }
                    Timer {
                        id: throttle
                        interval: 16
                        function flush() {
                            stop();
                            const dx = Math.round(win.dragX - drag.sentX), dy = Math.round(win.dragY - drag.sentY);
                            if (!dx && !dy)
                                return;
                            drag.sentX += dx;
                            drag.sentY += dy;
                            Niri.action("MoveFloatingWindow", {
                                "id": bar.wid,
                                "x": {
                                    "AdjustFixed": dx
                                },
                                "y": {
                                    "AdjustFixed": dy
                                }
                            });
                        }
                        onTriggered: flush()
                    }
                    // dev/owner (`angelos decorDrag ID DX DY MS`): the same drag, replayed with
                    // test events at scene positions (the bar moves under the pointer)
                    TestEvent {
                        id: sim
                    }
                    Timer {
                        id: replay
                        property var path: []
                        interval: 16
                        repeat: true
                        onTriggered: {
                            const p = path.shift();
                            const l = drag.mapFromItem(null, p.x, p.y);
                            if (p.up)
                                sim.mouseRelease(drag, l.x, l.y, Qt.LeftButton, Qt.NoModifier, -1);
                            else
                                sim.mouseMove(drag, l.x, l.y, -1, Qt.LeftButton, Qt.NoModifier);
                            if (!path.length)
                                stop();
                        }
                    }
                    Connections {
                        target: Shell
                        enabled: Shell.dev || Owner.enabled
                        function onDecorDrag(id, ddx, ddy, ms) {
                            if (id !== bar.wid)
                                return;
                            const x0 = Theme.u * 30, y0 = bar.height / 2;
                            const s0 = drag.mapToItem(null, x0, y0);
                            const n = Math.max(2, Math.round(ms / 16));
                            sim.mousePress(drag, x0, y0, Qt.LeftButton, Qt.NoModifier, -1);
                            const path = [];
                            for (let i = 1; i <= n; i++)
                                path.push({
                                    "x": s0.x + ddx * i / n,
                                    "y": s0.y + ddy * i / n
                                });
                            path.push({
                                "x": s0.x + ddx,
                                "y": s0.y + ddy,
                                "up": true
                            });
                            replay.path = path;
                            replay.start();
                        }
                    }
                    // let go: niri's own position takes over once its last move has landed
                    Timer {
                        id: letGo
                        interval: 160
                        onTriggered: if (!drag.pressed && win.dragId === bar.wid) {
                            win.dragId = -1;
                            win.dragFrom = null;
                        }
                    }
                }

                // the traffic lights: close, minimize (services/Minimize: niri has none of its own),
                // full screen; their glyphs under the pointer
                Row {
                    id: lights
                    visible: win.mac
                    z: 2
                    x: GoldenGate.px(13)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: GoldenGate.px(9)
                    HoverHandler {
                        id: lightsHover
                    }
                    Repeater {
                        model: [["close", 0], ["minimize", 1], ["full", 2]]
                        Rectangle {
                            id: light
                            required property var modelData
                            readonly property bool usable: true
                            // 14 pt as on macOS 26/27 (12 before Tahoe), 9 between them
                            width: GoldenGate.px(14)
                            height: width
                            radius: width / 2
                            color: !bar.active || !usable ? (GoldenGate.dark ? "#4a4a4d" : "#d1d1d6") : GoldenGate.lights[modelData[1]]
                            border.width: 1
                            border.color: Qt.rgba(0, 0, 0, 0.14)
                            // Golden Gate's glass on the lights: a highlight in the upper half
                            Rectangle {
                                visible: bar.active && light.usable
                                x: parent.width * 0.2
                                y: parent.height * 0.08
                                width: parent.width * 0.6
                                height: parent.height * 0.42
                                radius: height / 2
                                color: Qt.rgba(1, 1, 1, 0.35)
                            }
                            MacIcon {
                                visible: lightsHover.hovered && light.usable
                                anchors.centerIn: parent
                                name: light.modelData[0] === "close" ? "x" : light.modelData[0] === "minimize" ? "minus" : "maximize-2"
                                size: parent.width * 0.7
                                stroke: 3
                                color: Qt.rgba(0, 0, 0, 0.55)
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: light.usable
                                onClicked: {
                                    if (light.modelData[0] === "close")
                                        Niri.closeWindow(bar.wid);
                                    else if (light.modelData[0] === "minimize")
                                        Minimize.request(bar.wid, "decor");
                                    else
                                        Niri.fullscreenWindow(bar.wid);
                                }
                            }
                        }
                    }
                }

                Row {
                    visible: !win.mac
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.u * 3
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.u * 3
                    AppIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        appId: bar.w.app_id || ""
                        size: Theme.sizeBody
                    }
                    PxText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, bar.width - buttons.width - Theme.u * 14 - Theme.sizeBody)
                        elide: Text.ElideRight
                        text: Niri.titleOf(bar.w) || bar.w.app_id || ""
                        readonly property bool gothic: bar.hell && Theme.latin(text)
                        font.family: gothic ? Theme.fontHell : Theme.fontBody
                        font.pixelSize: gothic ? Theme.hellPx(Theme.fs) : Theme.sizeBody
                        color: bar.hell ? Theme.hellFlame : bar.active ? Theme.text : Theme.textDim
                    }
                }

                Row {
                    id: buttons
                    visible: !win.mac
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.u * 2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.u * 2

                    Row {
                        visible: bar.width > Theme.u * 120
                        spacing: Theme.u
                        anchors.verticalCenter: parent.verticalCenter
                        rightPadding: Theme.u * 2
                        PxIcon {
                            name: bar.hell ? "fire" : "heartSmall"
                            fill: bar.hell ? Theme.hellEmber : "#ffffff"
                            fill3: Theme.hellFlame
                            ink: Qt.alpha(bar.hell ? Theme.hellEdge : Theme.edge, 0.7)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        PxIcon {
                            name: "sparkle"
                            fill: "#ffffff"
                            light: bar.hell ? Theme.hellGold : Theme.accent3
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Repeater {
                        model: [
                            {
                                "id": "max",
                                "icon": "maximize"
                            },
                            {
                                "id": "close",
                                "icon": "close"
                            }
                        ]
                        Item {
                            id: tb
                            required property var modelData
                            width: bar.height - Theme.u * 4
                            height: width
                            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                            PxBox {
                                anchors.fill: parent
                                sunken: tbMouse.pressed
                                hell: bar.hell
                                color: tbMouse.containsMouse && tb.modelData.id === "close" ? (bar.hell ? Theme.hellBlood : Theme.danger) : tbMouse.containsMouse ? (bar.hell ? Theme.hellFaceAlt : Theme.mix(Theme.face, Theme.accent, 0.25)) : bar.hell ? Theme.hellFace : Theme.face
                            }
                            PxIcon {
                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: tbMouse.pressed ? Theme.u : 0
                                name: tb.modelData.icon
                                pixel: Math.max(1, Math.floor(Theme.u * 0.5))
                                ink: tbMouse.containsMouse && tb.modelData.id === "close" ? "#ffffff" : bar.hell ? Theme.hellText : (Theme.dark ? Theme.text : Theme.edge)
                            }
                            MouseArea {
                                id: tbMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (tb.modelData.id === "close")
                                        Niri.closeWindow(bar.wid);
                                    else
                                        Niri.maximizeWindow(bar.wid);
                                }
                            }
                        }
                    }
                }
            }
        }

        RightClickGuard {}
    }
}
