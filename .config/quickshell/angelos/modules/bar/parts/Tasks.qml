pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Win98 task buttons for windows on this screen's active workspace (or all; in Desktop every
// window of this screen), one per app: an app's windows share a button, a click on it shows them
// (TaskPreview). Apps pinned to the taskbar (Config.bar.taskPinned) lead the row, with a button
// that starts them while none runs. In Desktop the buttons keep their places and are dragged
// into another order (Config.bar.taskOrder), as on Windows' taskbar.
// Resting the pointer on a button shows its windows' pictures; a click on the window in front
// minimizes it, as in Windows.
// Titles show while every button still gets a readable width; when the windows
// reach the lyrics or other widgets the row turns into icons, and when even the
// icons don't fit it scrolls (mouse wheel, arrows at the edges).
Item {
    id: root

    required property string screenName
    property bool iconsOnly: false         // a compact bar, or titles switched off
    property bool above: true              // the window menu opens above a bottom bar
    // a taskbar on the left or the right edge (BarItem): a column of icons, as wide as the bar,
    // scrolling up and down once there are more than fit
    property bool vertical: false
    readonly property int cellH: Math.min(width, Theme.u * 18)
    // the hell bar (BarItem): flat buttons with the one plate rule, the focused window's the
    // active plate, app icons in the circle's ramp
    property bool barInk: false
    readonly property var ws: Niri.activeWorkspace(screenName)
    // the windows of the desktop in front, and the ones minimized on this screen (dimmed, a click
    // brings one back — as Windows' taskbar keeps them); in Desktop every desk's of this screen;
    // not an app hidden whole (⌘H)
    readonly property var liveList: Niri.sortedWindows(Niri.windows.filter(w => !Minimize.isAppHidden(w) && (Config.bar.allWindows || (WindowConfig.floatAll ? Minimize.outputOf(w) === screenName : (ws && w.workspace_id === ws.id) || minimizedHere(w)))))
    // niri sends a window update on every step of a resize or a move: the buttons are built
    // again only when what they show changes (the order, the title, the focus, the alert)
    readonly property string listKey: JSON.stringify(liveList.map(w => [w.id, w.app_id, w.title, w.is_focused, w.is_urgent, w.workspace_id]))
    property var list: []
    onListKeyChanged: list = liveList
    function minimizedHere(w) {
        return Minimize.isMinimized(w) && Minimize.outputOf(w) === screenName;
    }
    function keyOf(w) {
        return w.app_id || "#" + w.id;
    }
    // the windows by app
    readonly property var byKey: {
        const m = {};
        for (const w of list)
            (m[keyOf(w)] = m[keyOf(w)] || []).push(w);
        return m;
    }
    readonly property var pinned: (Config.bar.taskPinned || []).filter(k => typeof k === "string" && k !== "")
    // Desktop: the buttons stay where they are — by when the app came, or as dragged; the Strip:
    // in the order of the windows on the desk
    readonly property bool stable: WindowConfig.floatAll
    // the buttons' apps in order: the pinned ones, then the running ones
    readonly property var keys: {
        const run = [];
        for (const w of stable ? list.slice().sort((a, b) => a.id - b.id) : list) {
            const k = keyOf(w);
            if (!run.includes(k) && !pinned.includes(k))
                run.push(k);
        }
        const out = pinned.concat(run);
        if (!stable)
            return out;
        const ord = Config.bar.taskOrder || [];
        const at = k => ord.includes(k) ? ord.indexOf(k) : 1e6 + out.indexOf(k);
        return out.slice().sort((a, b) => at(a) - at(b));
    }
    // the buttons' model: a button stays the same item while its app's windows change (a title,
    // the focus), so the pointer on it and a drag aren't lost
    ListModel {
        id: rows
    }
    function rowIndex(k) {
        for (let i = 0; i < rows.count; i++)
            if (rows.get(i).appKey === k)
                return i;
        return -1;
    }
    function sync() {
        const ks = keys;
        for (let i = rows.count - 1; i >= 0; i--)
            if (!ks.includes(rows.get(i).appKey))
                rows.remove(i);
        // the row as held while a drag goes on; in order once it is let go
        if (dragKey !== "")
            return;
        for (let i = 0; i < ks.length; i++) {
            const j = rowIndex(ks[i]);
            if (j < 0)
                rows.insert(i, {
                    "appKey": ks[i]
                });
            else if (j !== i)
                rows.move(j, i, 1);
        }
    }
    onKeysChanged: sync()
    readonly property int count: rows.count
    function launch(appId) {
        StartApps.launch(DesktopEntries.byId(appId) || DesktopEntries.heuristicLookup(appId));
    }
    function unpin(appId) {
        Config.bar.taskPinned = pinned.filter(k => k !== appId);
    }

    // ---- dragging a button along the row (Desktop) ----
    property string dragKey: ""
    property int dragFrom: -1           // its place as the drag began
    property real dragShift: 0          // the pointer's offset from its place now
    readonly property real step: (vertical ? cellH : buttonWidth) + spacing
    function startDrag(k) {
        preview.visible = false;
        dwell.stop();
        dragKey = k;
        dragFrom = rowIndex(k);
        dragShift = 0;
    }
    function dragTo(k, d) {
        const now = rowIndex(k);
        if (now < 0 || dragFrom < 0)
            return;
        const to = Math.max(0, Math.min(rows.count - 1, Math.round(dragFrom + d / step)));
        if (to !== now)
            rows.move(now, to, 1);
        dragShift = (dragFrom - to) * step + d;
    }
    function letGo() {
        if (dragKey === "")
            return;
        const ks = [];
        for (let i = 0; i < rows.count; i++)
            ks.push(rows.get(i).appKey);
        // apps closed meanwhile keep their places after the ones here
        Config.bar.taskOrder = ks.concat((Config.bar.taskOrder || []).filter(k => !ks.includes(k))).slice(0, 64);
        dragKey = "";
        dragShift = 0;
        sync();
    }
    // a click on a window: back if minimized, minimized if in front, else to the front
    function activate(w) {
        preview.visible = false;
        // a window rolled up into its title (angel-niri's Desktop) comes back whole
        if (w.is_shaded) {
            Niri.action("SetWindowFlags", {
                "id": w.id,
                "shaded": false
            });
            if (!Minimize.isMinimized(w)) {
                if (!w.is_focused)
                    Niri.focusWindow(w.id);
                return;
            }
        }
        if (Minimize.isMinimized(w))
            Minimize.restore(w.id);
        else if (w.is_focused)
            Minimize.request(w.id, "bar");
        else
            Niri.focusWindow(w.id);
    }
    // the pictures: after resting on a button a moment, at once while they already show
    property Item hoverBtn: null
    function hovering(btn, on) {
        if (on) {
            hoverBtn = btn;
            if (preview.visible && preview.anchorItem !== btn)
                showPreview(btn, false);
            else if (!preview.visible)
                dwell.restart();
        } else if (hoverBtn === btn) {
            hoverBtn = null;
            dwell.stop();
            leave.restart();
        }
    }
    function showPreview(btn, pin) {
        if (preview.anchorItem !== btn)
            preview.visible = false;
        preview.anchorItem = btn;
        preview.wins = btn.wins;
        preview.pinned = pin;
        preview.visible = true;
    }
    Timer {
        id: dwell
        interval: 450
        onTriggered: if (root.hoverBtn)
            root.showPreview(root.hoverBtn, false)
    }
    Timer {
        id: leave
        interval: 300
        onTriggered: if (!root.hoverBtn && !preview.hovered)
            preview.visible = false
    }
    TaskPreview {
        id: preview
        above: root.above
        onHoveredChanged: if (!hovered)
            leave.restart()
        onPicked: w => root.activate(w)
    }
    readonly property int spacing: Theme.u * 2
    readonly property int iconWidth: height
    // a title button narrower than this shows two letters and an ellipsis — use icons instead
    readonly property int labelMin: Theme.u * Math.max(28, Config.bar.taskMinWidth)
    readonly property int maxW: Theme.u * Math.max(28, Config.bar.taskMinWidth, Config.bar.taskMaxWidth)
    readonly property real share: count ? (width - (count - 1) * spacing) / count : 0
    readonly property bool labels: !iconsOnly && !vertical && share >= labelMin
    readonly property int buttonWidth: vertical ? width : labels ? Math.min(maxW, Math.floor(share)) : iconWidth
    readonly property real rowWidth: count * buttonWidth + Math.max(0, count - 1) * spacing
    readonly property real colHeight: count * cellH + Math.max(0, count - 1) * spacing
    readonly property bool overflow: vertical ? colHeight > height + 0.5 : rowWidth > width + 0.5
    // as wide as the buttons want to be (Settings → Bar → "Windows" width: compact)
    readonly property real naturalWidth: count * (iconsOnly ? iconWidth : maxW) + Math.max(0, count - 1) * spacing
    readonly property real naturalHeight: colHeight

    clip: true

    function scrollBy(dx) {
        if (vertical)
            return;
        const max = Math.max(0, flick.contentWidth - flick.width);
        glide.stop();
        glide.to = Math.max(0, Math.min(max, flick.contentX + dx));
        glide.start();
    }
    // keep the focused window's button in view when the row scrolls
    function reveal() {
        if (!overflow || vertical)
            return;
        const i = rowIndex(keys.find(k => (byKey[k] || []).some(w => w.is_focused)) || "");
        if (i < 0)
            return;
        const x0 = i * (buttonWidth + spacing), x1 = x0 + buttonWidth;
        if (x0 < flick.contentX)
            scrollBy(x0 - flick.contentX - Theme.u * 8);
        else if (x1 > flick.contentX + flick.width)
            scrollBy(x1 - flick.contentX - flick.width + Theme.u * 8);
    }
    onListChanged: Qt.callLater(reveal)
    Component.onCompleted: {
        list = liveList;
        sync();
    }
    onOverflowChanged: if (!overflow) {
        flick.contentX = 0;
        flick.contentY = 0;
    }

    NumberAnimation {
        id: glide
        target: flick
        property: "contentX"
        duration: Motion.ms(140)
        easing.type: Easing.OutCubic
    }

    WindowMenu {
        id: menu
        anchorItem: root
        above: root.above
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: root.vertical ? width : root.rowWidth
        contentHeight: root.vertical ? root.colHeight : height
        interactive: root.overflow
        flickableDirection: root.vertical ? Flickable.VerticalFlick : Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        pixelAligned: true

        // a row; upright, a column — each button at its index, gliding there while one is dragged
        Item {
            id: row
            width: flick.contentWidth
            height: flick.contentHeight

            Repeater {
                model: rows
                PxButton {
                    id: btn
                    // the app's windows; the one it stands for: in front, else the first. None: a
                    // pinned app not running — a click starts it
                    required property string appKey
                    required property int index
                    readonly property var wins: root.byKey[appKey] || []
                    readonly property var win: wins.find(w => w.is_focused) || wins[0] || null
                    readonly property bool ghost: !win
                    readonly property bool group: wins.length > 1
                    readonly property bool held: root.dragKey === appKey
                    x: root.vertical ? 0 : index * root.step
                    y: root.vertical ? index * root.step : 0
                    z: held ? 1 : 0
                    transform: Translate {
                        x: btn.held && !root.vertical ? root.dragShift : 0
                        y: btn.held && root.vertical ? root.dragShift : 0
                    }
                    Behavior on x {
                        enabled: root.dragKey !== "" && !btn.held
                        NumberAnimation {
                            duration: Motion.ms(120)
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on y {
                        enabled: root.dragKey !== "" && !btn.held
                        NumberAnimation {
                            duration: Motion.ms(120)
                            easing.type: Easing.OutCubic
                        }
                    }
                    width: root.buttonWidth
                    height: root.vertical ? root.cellH : flick.height
                    barInk: root.barInk
                    checked: !!win && win.is_focused
                    DragHandler {
                        enabled: root.stable
                        target: null
                        xAxis.enabled: !root.vertical
                        yAxis.enabled: root.vertical
                        onActiveChanged: active ? root.startDrag(btn.appKey) : root.letGo()
                        onTranslationChanged: if (active)
                            root.dragTo(btn.appKey, root.vertical ? translation.y : translation.x)
                    }
                    // a file or text dragged onto it: after a moment its window comes up, as in Windows
                    DropArea {
                        anchors.fill: parent
                        enabled: !btn.ghost
                        onEntered: raise.restart()
                        onExited: raise.stop()
                    }
                    Timer {
                        id: raise
                        interval: 500
                        onTriggered: if (btn.win)
                            Minimize.isMinimized(btn.win) ? Minimize.restore(btn.win.id) : Niri.focusWindow(btn.win.id)
                    }
                    // the pointer anywhere on the button, × included: the ×'s own MouseArea takes the
                    // hover from btn.hovered (a sibling), and hiding the × on that made it flicker
                    HoverHandler {
                        id: over
                        onHoveredChanged: if (!btn.ghost || !hovered)
                            root.hovering(btn, hovered)
                    }
                    middleButton: true
                    readonly property bool minimized: !ghost && wins.every(w => Minimize.isMinimized(w))
                    // where it is on the screen, for the pixel genie (services/Minimize.dockSlots,
                    // MacMinimizeFx): every window of the app lands here
                    function report() {
                        // its window's place from the layer-shell anchors, as BarLyrics.screenPoint()
                        const w = btn.QsWindow.window;
                        if (!w || !w.screen)
                            return;
                        const p = btn.mapToItem(null, btn.width / 2, btn.height / 2);
                        const a = w.anchors || {}, m = w.margins || {};
                        const sw = w.screen.width, sh = w.screen.height;
                        const wx = a.left ? (m.left || 0) : a.right ? sw - w.width - (m.right || 0) : (sw - w.width) / 2;
                        const wy = a.top ? (m.top || 0) : a.bottom ? sh - w.height - (m.bottom || 0) : (sh - w.height) / 2;
                        const at = [wx + p.x, wy + p.y, Math.min(btn.width, btn.height)];
                        for (const v of btn.wins)
                            Minimize.dockSlots[root.screenName + "|@w" + v.id] = at;
                    }
                    onXChanged: report()
                    onYChanged: report()
                    onWidthChanged: report()
                    onWinsChanged: report()
                    Component.onCompleted: report()
                    Connections {
                        target: flick
                        function onContentXChanged() {
                            btn.report();
                        }
                        function onContentYChanged() {
                            btn.report();
                        }
                    }
                    opacity: minimized ? 0.5 : 1
                    onClicked: {
                        if (ghost)
                            root.launch(appKey);
                        else if (group)
                            root.showPreview(btn, true);
                        else
                            root.activate(win);
                    }
                    onMiddleClicked: if (ghost)
                        root.launch(appKey)
                    else if (Config.bar.taskMiddleClose)
                        Niri.closeWindow(win.id)
                    onRightClicked: {
                        preview.visible = false;
                        // a pinned app not running: no window to act on, the click unpins it
                        if (ghost) {
                            root.unpin(appKey);
                            return;
                        }
                        const mode = Config.bar.taskRightClick || "menu";
                        if (mode === "close")
                            Niri.closeWindow(win.id);
                        else if (mode === "menu")
                            menu.openFor(btn, win);
                    }

                    AppIcon {
                        id: ico
                        x: (root.labels ? Theme.u * 4 : (btn.width - width) / 2) + (btn.down && !root.barInk ? Theme.u : 0)
                        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                        anchors.verticalCenterOffset: btn.down && !root.barInk ? Theme.u : 0
                        appId: btn.win ? btn.win.app_id || "" : btn.appKey
                        size: root.labels ? Theme.u * 8 : Math.max(Theme.u * 8, btn.height - Theme.u * 6)
                        tint: Config.bar.tintTasks && !btn.checked ? Config.bar.trayTint : "off"
                        hellBar: root.barInk
                    }
                    PxText {
                        visible: root.labels
                        anchors.left: ico.right
                        anchors.leftMargin: Theme.u * 3
                        anchors.right: parent.right
                        anchors.rightMargin: closeX.visible ? closeX.width + Theme.u * 4 : Theme.u * 4
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: btn.down && !root.barInk ? Theme.u : 0
                        readonly property var entry: btn.ghost ? DesktopEntries.byId(btn.appKey) || DesktopEntries.heuristicLookup(btn.appKey) : null
                        text: btn.win ? Niri.titleOf(btn.win) || btn.win.app_id || "?" : entry ? entry.name : btn.appKey
                        elide: Text.ElideRight
                        font.bold: btn.checked
                        readonly property bool urgent: !!btn.win && btn.win.is_urgent
                        color: root.barInk ? (urgent ? Theme.hellAccent : btn.ghost ? Theme.hellTextDim : Theme.hellText) : urgent ? Theme.danger : btn.ghost ? Theme.textDim : Theme.text
                    }
                    // the window's cobweb (services/Cobweb): its corner, under the ×
                    CobwebBadge {
                        ids: btn.wins.map(w => w.id)
                        hovered: over.hovered
                        pixel: Math.max(1, Math.round(Theme.u / 2))
                        x: btn.width - width - Theme.u
                        y: Theme.u
                    }
                    // × on hover (Settings → Bar → Closing windows)
                    Rectangle {
                        id: closeX
                        visible: Config.bar.taskHoverClose && over.hovered && !btn.group && !btn.ghost
                        readonly property int s: root.labels ? Theme.u * 9 : Theme.u * 7
                        width: s
                        height: s
                        x: btn.width - width - Theme.u * 2
                        y: root.labels ? (btn.height - height) / 2 : Theme.u * 2
                        color: xm.containsMouse ? Theme.danger : Qt.alpha(Theme.face, 0.85)
                        border.width: Math.max(1, Theme.u / 2)
                        border.color: Theme.edge
                        PxIcon {
                            anchors.centerIn: parent
                            name: "close"
                            pixel: Math.max(1, Theme.u - 1)
                            ink: xm.containsMouse ? "#ffffff" : Theme.text
                        }
                        MouseArea {
                            id: xm
                            anchors.fill: parent
                            anchors.margins: -Theme.u
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Niri.closeWindow(btn.win.id)
                        }
                    }
                    // how many windows the app has, in the corner
                    PxText {
                        visible: btn.group
                        x: btn.width - width - Theme.u * 2
                        y: btn.height - height - Theme.u
                        text: btn.wins.length
                        kind: "tiny"
                        font.bold: true
                        color: root.barInk ? Theme.hellText : Theme.text
                    }
                }
            }
        }
    }

    // wheel scrolls the row sideways once it overflows
    WheelHandler {
        enabled: root.overflow && !root.vertical
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => {
            const d = e.pixelDelta.x !== 0 ? -e.pixelDelta.x : e.pixelDelta.y !== 0 ? -e.pixelDelta.y : -(e.angleDelta.y || e.angleDelta.x) / 120 * (root.buttonWidth + root.spacing);
            root.scrollBy(d);
        }
    }

    // edge arrows while there is more to see on that side
    Repeater {
        model: [-1, 1]
        PxButton {
            required property int modelData
            visible: root.overflow && !root.vertical && (modelData < 0 ? flick.contentX > 1 : flick.contentX < flick.contentWidth - flick.width - 1)
            compact: true
            icon: modelData < 0 ? "arrowLeft" : "arrowRight"
            Accessible.name: modelData < 0 ? I18n.t("Окна левее", "Windows to the left") : I18n.t("Окна правее", "Windows to the right")
            iconPixel: Math.max(1, Theme.u - 1)
            width: Theme.u * 8
            height: root.height
            x: modelData < 0 ? 0 : root.width - width
            onClicked: root.scrollBy(modelData * Math.max(root.buttonWidth + root.spacing, flick.width * 0.6))
        }
    }
}
