pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Mission Control (services/Mission, Mod+W), like a Mac's: the windows of the monitor's desk come
// out of their places into a grid without overlap, its desks sit in a strip on top. A click on a
// window brings it up, a click on a desk goes there, a window dragged onto a desk moves there;
// Esc, Mod+W or a click on the empty space closes. Pictures of the windows come from angel-niri's
// snapshot-window (refreshed each second for the desk shown); without it, the app icons. Apps
// hidden from the stream (Privacy) show their icon and name only, never a picture or title.
Scope {
    LazyLoader {
        active: Mission.shown
        PanelWindow {
            id: win

            screen: Shell.screenByName(Mission.screenName) || Shell.focusedScreen
            readonly property string output: screen ? screen.name : ""
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            // takes input: the whole screen — a click on the empty space closes it
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            WlrLayershell.namespace: "angelos-mission"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            readonly property int u: Theme.u
            readonly property string dir: Quickshell.env("XDG_RUNTIME_DIR") + "/angel-niri/preview"
            property int tick: 0

            readonly property var desks: Niri.workspacesOn(output).slice().sort((a, b) => a.idx - b.idx)
            readonly property var desk: desks.find(d => d.is_active) || null
            readonly property string deskKey: desks.map(d => d.id).join(",")
            property var deskIds: []
            onDeskKeyChanged: deskIds = deskKey ? deskKey.split(",").map(Number) : []
            function windowsOf(d) {
                if (!d)
                    return [];
                // left to right as they stand, then top to bottom
                const key = w => {
                    const l = w.layout || {};
                    const p = l.tile_pos_in_workspace_view;
                    const s = l.pos_in_scrolling_layout;
                    return p ? [p[0], p[1]] : s ? [s[0] * 10000, s[1]] : [0, 0];
                };
                return Niri.windows.filter(w => w.workspace_id === d.id && !Minimize.isMinimized(w) && !Minimize.isAppHidden(w)).sort((a, b) => {
                    const ka = key(a), kb = key(b);
                    return ka[0] - kb[0] || ka[1] - kb[1];
                });
            }
            // the cards only change with the set of windows (a Repeater over a fresh array would
            // build every card again on each focus change)
            readonly property string idsKey: windowsOf(desk).map(w => w.id).join(",")
            property var ids: []
            onIdsKeyChanged: ids = idsKey ? idsKey.split(",").map(Number) : []
            function winById(id) {
                return Niri.windows.find(w => w.id === id) || null;
            }
            function hiddenFromStream(w) {
                return !!w && Privacy.hiddenNow.some(a => a.id === w.app_id);
            }
            function appName(w) {
                const e = w && w.app_id ? DesktopEntries.heuristicLookup(w.app_id) : null;
                return e ? e.name : (w && w.app_id ? w.app_id : "?");
            }
            function deskName(d) {
                const names = Config.workspaces.names || {};
                const own = names[d.output + ":" + d.idx] || d.name || "";
                if (own)
                    return own;
                // a desk of one full-screen window (the green button, like a Mac): its app
                const list = windowsOf(d);
                if (list.length === 1 && list[0].is_fullscreen)
                    return appName(list[0]);
                return list.length ? I18n.t("Стол ", "Desk ") + d.idx : I18n.t("Новый стол", "New desk");
            }

            // sizes laid out in `w`×`h` without overlap, each as large as it fits (at most `maxK`
            // of itself), rows centred; the column count that leaves them largest
            function grid(sizes, w, h, gap, maxK) {
                const top = maxK || 1;
                const n = sizes.length;
                if (!n || w <= 0 || h <= 0)
                    return [];
                let best = null;
                for (let c = 1; c <= n; c++) {
                    const r = Math.ceil(n / c);
                    const cw = (w - gap * (c - 1)) / c, ch = (h - gap * (r - 1)) / r;
                    if (cw <= 0 || ch <= 0)
                        continue;
                    let area = 0;
                    for (const s of sizes) {
                        const k = Math.min(cw / s[0], ch / s[1], top);
                        area += s[0] * s[1] * k * k;
                    }
                    if (!best || area > best.area)
                        best = {
                            "c": c,
                            "r": r,
                            "cw": cw,
                            "ch": ch,
                            "area": area
                        };
                }
                if (!best)
                    return [];
                const out = [];
                const y0 = (h - (best.r * best.ch + (best.r - 1) * gap)) / 2;
                for (let i = 0; i < n; i++) {
                    const row = Math.floor(i / best.c), col = i % best.c;
                    const inRow = Math.min(best.c, n - row * best.c);
                    const x0 = (w - (inRow * best.cw + (inRow - 1) * gap)) / 2;
                    const s = sizes[i];
                    const k = Math.min(best.cw / s[0], best.ch / s[1], top);
                    out.push({
                        "x": Math.round(x0 + col * (best.cw + gap) + (best.cw - s[0] * k) / 2),
                        "y": Math.round(y0 + row * (best.ch + gap) + (best.ch - s[1] * k) / 2),
                        "w": Math.round(s[0] * k),
                        "h": Math.round(s[1] * k)
                    });
                }
                return out;
            }
            function sizeOf(w) {
                const s = w && w.layout ? w.layout.tile_size : null;
                return s && s[0] > 0 && s[1] > 0 ? [s[0], s[1]] : [800, 600];
            }
            // the cards' room: under the desks, a title line under each card
            // never more than ~0.45 of a window: a card that nearly fills the screen loses the
            // sense of an overview (the owner, 25.10)
            readonly property var cells: grid(ids.map(id => sizeOf(winById(id))), stage.width, stage.height - u * 12, u * 16, 0.45)

            // pictures: every window of this monitor once as it opens, the desk shown each second
            function snap(list) {
                if (!Niri.nativeMinimize)
                    return;
                for (const w of list)
                    if (!hiddenFromStream(w))
                        Niri.action("SnapshotWindow", {
                            "id": w.id,
                            "path": dir + "/" + w.id + ".png"
                        });
                reload.restart();
            }
            Component.onCompleted: {
                snap(desks.reduce((all, d) => all.concat(windowsOf(d)), []));
                opening.start();
            }
            Timer {
                interval: 1000
                repeat: true
                running: Niri.nativeMinimize
                onTriggered: win.snap(win.windowsOf(win.desk))
            }
            Timer {
                id: reload
                interval: 300
                onTriggered: win.tick++
            }

            // 0: the windows where they stand, 1: laid out; back to 0 as it closes
            property real progress: 0
            NumberAnimation {
                id: opening
                target: win
                property: "progress"
                to: 1
                // soft: the windows glide out of their places and settle
                duration: Motion.ms(420)
                easing.type: Easing.OutQuint
            }
            SequentialAnimation {
                id: closing
                NumberAnimation {
                    target: win
                    property: "progress"
                    to: 0
                    duration: Motion.ms(280)
                    easing.type: Easing.InOutQuad
                }
                ScriptAction {
                    script: {
                        // the switch happens once the cards are gone: niri moving the view under
                        // cards still flying back looked like rubbish (the owner, 25.10)
                        if (win.after)
                            win.after();
                        Mission.close();
                    }
                }
            }
            // how it closes: "back" every card flies back to its window (Esc, Mod+W, the empty
            // space), "desk" they all fade where they are (a desk picked), "pick" the picked one
            // flies back and the rest fade
            property string leaving: ""
            property int picked: -1
            property var after: null
            function leave(how, then) {
                if (closing.running)
                    return;
                leaving = how || "back";
                after = then || null;
                opening.stop();
                closing.start();
            }
            function focusAndLeave(id) {
                picked = id;
                leave("pick", () => Niri.focusWindow(id));
            }
            // Mod+W again: closes the same way as Esc
            Connections {
                target: Mission
                function onLeaveAskedChanged() {
                    if (Mission.leaveAsked)
                        win.leave("back");
                }
            }

            // the keyboard: arrows pick a card, Enter brings it up
            property int sel: -1
            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: e => {
                    const n = win.ids.length;
                    if (e.key === Qt.Key_Escape)
                        win.leave();
                    else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && win.sel >= 0 && win.sel < n)
                        win.focusAndLeave(win.ids[win.sel]);
                    else if (n && (e.key === Qt.Key_Right || e.key === Qt.Key_Down || e.key === Qt.Key_Tab))
                        win.sel = (win.sel + 1) % n;
                    else if (n && (e.key === Qt.Key_Left || e.key === Qt.Key_Up || e.key === Qt.Key_Backtab))
                        win.sel = (win.sel - 1 + n) % n;
                    else
                        return;
                    e.accepted = true;
                }
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha("#000000", 0.78 * win.progress)
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: win.leave()
            }

            // ---- the desks ----
            readonly property real deskW: Math.round(Math.min(width * 0.12, u * 110))
            readonly property real deskH: Math.round(deskW * height / Math.max(1, width))
            property int dropDesk: -1          // the desk under a dragged card (-2: the "+")
            // angel-niri's Desktop keeps no empty desk at the end: a new one comes from "+" (a click
            // goes there, a window dropped on it goes along); the last desk empty, it is there
            readonly property bool plus: Niri.nativeMinimize && WindowConfig.floatAll && desks.length > 0 && windowsOf(desks[desks.length - 1]).length > 0
            function openDesk(windowId) {
                const a = {
                    "output": win.output
                };
                if (windowId !== undefined)
                    a.window = windowId;
                Niri.action("OpenSpareWorkspace", a);
            }
            function deskAt(x, y) {
                if (plusTile.visible) {
                    const p = plusTile.mapFromItem(win.contentItem, x, y);
                    if (p.x >= 0 && p.y >= 0 && p.x < plusTile.width && p.y < plusTile.height)
                        return -2;
                }
                for (let i = 0; i < deskRep.count; i++) {
                    const t = deskRep.itemAt(i);
                    const p = t.mapFromItem(win.contentItem, x, y);
                    if (p.x >= 0 && p.y >= 0 && p.x < t.width && p.y < t.height)
                        return t.modelData.id;
                }
                return -1;
            }
            Row {
                id: deskRow
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(win.u * 8 - (1 - win.progress) * (height + win.u * 8))
                spacing: win.u * 6
                Repeater {
                    id: deskRep
                    // by id: the workspace list is a fresh array on every niri event, and a Repeater
                    // over it built the tiles again under a click (it never landed)
                    model: win.deskIds
                    Item {
                        id: deskTile
                        required property int index
                        readonly property var modelData: win.desks[index] || ({
                                "id": -1,
                                "idx": 0,
                                "output": "",
                                "is_active": false
                            })
                        readonly property bool current: modelData.is_active
                        readonly property var list: win.windowsOf(modelData)
                        width: win.deskW
                        height: win.deskH + win.u * 10
                        PxBox {
                            id: deskBox
                            width: win.deskW
                            height: win.deskH
                            color: win.dropDesk === deskTile.modelData.id ? Theme.accent : Theme.face
                            edgeColor: deskTile.current ? Theme.accent : Theme.edge
                            readonly property var minis: win.grid(deskTile.list.map(w => win.sizeOf(w)), width - win.u * 6, height - win.u * 6, win.u * 2)
                            Repeater {
                                model: deskTile.list.length
                                Item {
                                    id: mini
                                    required property int index
                                    readonly property var w: deskTile.list[index] || null
                                    readonly property var cell: deskBox.minis[index] || {
                                        "x": 0,
                                        "y": 0,
                                        "w": 1,
                                        "h": 1
                                    }
                                    x: win.u * 3 + cell.x
                                    y: win.u * 3 + cell.y
                                    width: cell.w
                                    height: cell.h
                                    Image {
                                        id: miniShot
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: false
                                        cache: false
                                        smooth: true
                                        source: mini.w && Niri.nativeMinimize && win.tick > 0 && !win.hiddenFromStream(mini.w) ? "file://" + win.dir + "/" + mini.w.id + ".png?" + win.tick : ""
                                    }
                                    AppIcon {
                                        visible: miniShot.status !== Image.Ready
                                        anchors.centerIn: parent
                                        appId: mini.w ? mini.w.app_id || "" : ""
                                        size: Math.max(win.u * 4, Math.min(parent.width, parent.height) * 0.6)
                                    }
                                }
                            }
                            PxIcon {
                                visible: deskTile.list.length === 0
                                anchors.centerIn: parent
                                name: "plus"
                                pixel: win.u * 2
                                ink: Theme.textDim
                            }
                        }
                        PxText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: win.deskH + win.u * 2
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: win.deskName(deskTile.modelData)
                            color: "#ffffff"
                            font.bold: deskTile.current
                        }
                        MouseArea {
                            anchors.fill: deskBox
                            onClicked: {
                                const id = deskTile.modelData.id;
                                win.leave("desk", () => Niri.focusWorkspace(id));
                            }
                        }
                    }
                }
                Item {
                    id: plusTile
                    visible: win.plus
                    width: win.deskW
                    height: win.deskH + win.u * 10
                    PxBox {
                        id: plusBox
                        width: win.deskW
                        height: win.deskH
                        color: win.dropDesk === -2 || plusArea.containsMouse ? Theme.accent : Theme.face
                        edgeColor: Theme.edge
                        PxIcon {
                            anchors.centerIn: parent
                            name: "plus"
                            pixel: win.u * 2
                            ink: win.dropDesk === -2 || plusArea.containsMouse ? "#ffffff" : Theme.textDim
                        }
                    }
                    PxText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: win.deskH + win.u * 2
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: I18n.t("Новый стол", "New desk")
                        color: "#ffffff"
                    }
                    MouseArea {
                        id: plusArea
                        anchors.fill: plusBox
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.leave("desk", () => win.openDesk())
                    }
                }
            }

            // ---- the windows of the desk ----
            Item {
                id: stage
                x: win.u * 16
                y: deskRow.y + win.deskH + win.u * 24
                width: win.width - win.u * 32
                height: win.height - y - win.u * 16

                Repeater {
                    model: win.ids
                    Item {
                        id: card
                        required property int modelData
                        required property int index
                        readonly property var w: win.winById(modelData)
                        readonly property bool hidden: win.hiddenFromStream(w)
                        readonly property var cell: win.cells[index] || {
                            "x": 0,
                            "y": 0,
                            "w": 1,
                            "h": 1
                        }
                        // where the window stands on the screen, caught as the card appears
                        property var from: null
                        Component.onCompleted: {
                            const l = w && w.layout;
                            const p = l && l.tile_pos_in_workspace_view;
                            const s = win.sizeOf(w);
                            from = p ? {
                                "x": p[0] - stage.x,
                                "y": p[1] - stage.y,
                                "w": s[0],
                                "h": s[1]
                            } : {
                                "x": cell.x + cell.w * 0.1,
                                "y": cell.y + cell.h * 0.1,
                                "w": cell.w * 0.8,
                                "h": cell.h * 0.8
                            };
                        }
                        // fading out instead of flying back (see leaving)
                        readonly property bool fades: win.leaving === "desk" || win.leaving === "pick" && win.picked !== modelData
                        readonly property real t: fades ? 1 : win.progress
                        readonly property var f: from || cell
                        property real dx: 0
                        property real dy: 0
                        property bool dragging: false
                        x: Math.round(f.x + (cell.x - f.x) * t + dx)
                        y: Math.round(f.y + (cell.y - f.y) * t + dy)
                        width: Math.round(f.w + (cell.w - f.w) * t)
                        height: Math.round(f.h + (cell.h - f.h) * t)
                        z: dragging ? 10 : 0
                        opacity: fades ? win.progress : from ? 1 : t
                        // dragged, it shrinks around the pointer to about a desk's size, so the
                        // desks stay in sight
                        property point grab
                        transform: Scale {
                            origin.x: card.grab.x
                            origin.y: card.grab.y
                            xScale: card.dragScale
                            yScale: card.dragScale
                        }
                        property real dragScale: dragging ? Math.min(1, win.deskW * 1.2 / Math.max(1, width)) : 1
                        Behavior on dragScale {
                            NumberAnimation {
                                duration: Motion.ms(160)
                                easing.type: Easing.OutCubic
                            }
                        }

                        readonly property bool lit: pick.containsMouse || win.sel === index || dragging
                        PxBox {
                            anchors.fill: parent
                            anchors.margins: -win.u * 2
                            color: card.lit ? Theme.accent : "transparent"
                            outline: card.lit
                            flat: true
                        }
                        Image {
                            id: shot
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectFit
                            asynchronous: false
                            cache: false
                            smooth: true
                            source: card.w && Niri.nativeMinimize && win.tick > 0 && !card.hidden ? "file://" + win.dir + "/" + card.w.id + ".png?" + win.tick : ""
                        }
                        Rectangle {
                            anchors.fill: parent
                            visible: shot.status !== Image.Ready
                            color: Theme.face
                            AppIcon {
                                anchors.centerIn: parent
                                appId: card.w ? card.w.app_id || "" : ""
                                size: Math.max(win.u * 8, Math.min(parent.width, parent.height) * 0.3)
                            }
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: parent.height + win.u * 3
                            spacing: win.u * 2
                            opacity: win.progress
                            AppIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                appId: card.w ? card.w.app_id || "" : ""
                                size: win.u * 7
                            }
                            PxText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, Math.max(win.u * 30, card.width - win.u * 9))
                                elide: Text.ElideRight
                                color: "#ffffff"
                                text: card.hidden ? win.appName(card.w) : Niri.titleOf(card.w) || win.appName(card.w)
                            }
                        }
                        MouseArea {
                            id: pick
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            property point press
                            onPressed: m => {
                                press = mapToItem(win.contentItem, m.x, m.y);
                                card.grab = Qt.point(m.x, m.y);
                            }
                            onPositionChanged: m => {
                                if (!pressed)
                                    return;
                                const p = mapToItem(win.contentItem, m.x, m.y);
                                if (!card.dragging && Math.abs(p.x - press.x) + Math.abs(p.y - press.y) > win.u * 4)
                                    card.dragging = true;
                                if (card.dragging) {
                                    card.dx += p.x - press.x;
                                    card.dy += p.y - press.y;
                                    press = p;
                                    win.dropDesk = win.deskAt(p.x, p.y);
                                }
                            }
                            onReleased: m => {
                                if (card.dragging) {
                                    const to = win.dropDesk;
                                    card.dragging = false;
                                    card.dx = 0;
                                    card.dy = 0;
                                    win.dropDesk = -1;
                                    if (to === -2 && card.w)
                                        win.openDesk(card.modelData);
                                    else if (to >= 0 && card.w && to !== card.w.workspace_id)
                                        Niri.action("MoveWindowToWorkspace", {
                                            "window_id": card.modelData,
                                            "reference": {
                                                "Id": to
                                            },
                                            "focus": false
                                        });
                                    return;
                                }
                                if (m.button === Qt.MiddleButton)
                                    Niri.closeWindow(card.modelData);
                                else
                                    win.focusAndLeave(card.modelData);
                            }
                        }
                    }
                }
                PxText {
                    visible: win.ids.length === 0
                    anchors.centerIn: parent
                    color: "#ffffff"
                    opacity: win.progress
                    text: I18n.t("На этом столе нет окон", "No windows on this desk")
                }
            }
            RightClickGuard {}
        }
    }
}
