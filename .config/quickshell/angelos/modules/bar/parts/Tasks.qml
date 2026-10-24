pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Win98 task buttons for windows on this screen's active workspace (or all; in Desktop always
// all), one per app: an app's windows share a button, a click on it shows them (TaskPreview).
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
    // brings one back — as Windows' taskbar keeps them); not an app hidden whole (⌘H)
    readonly property var liveList: Niri.sortedWindows(Niri.windows.filter(w => !Minimize.isAppHidden(w) && (Config.bar.allWindows || WindowConfig.floatAll || (ws && w.workspace_id === ws.id) || minimizedHere(w))))
    // niri sends a window update on every step of a resize or a move: the buttons are built
    // again only when what they show changes (the order, the title, the focus, the alert)
    readonly property string listKey: JSON.stringify(liveList.map(w => [w.id, w.app_id, w.title, w.is_focused, w.is_urgent, w.workspace_id]))
    property var list: []
    onListKeyChanged: list = liveList
    Component.onCompleted: list = liveList
    function minimizedHere(w) {
        return Minimize.isMinimized(w) && Minimize.outputOf(w) === screenName;
    }
    // the windows by app, in the order their first window comes
    readonly property var groups: {
        const out = [], at = {};
        for (const w of list) {
            const k = w.app_id || "#" + w.id;
            if (at[k] === undefined) {
                at[k] = out.length;
                out.push([]);
            }
            out[at[k]].push(w);
        }
        return out;
    }
    readonly property int count: groups.length
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
        const i = groups.findIndex(g => g.some(w => w.is_focused));
        if (i < 0)
            return;
        const x0 = i * (buttonWidth + spacing), x1 = x0 + buttonWidth;
        if (x0 < flick.contentX)
            scrollBy(x0 - flick.contentX - Theme.u * 8);
        else if (x1 > flick.contentX + flick.width)
            scrollBy(x1 - flick.contentX - flick.width + Theme.u * 8);
    }
    onListChanged: Qt.callLater(reveal)
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

        // a row; upright, a column (Grid of one column)
        Grid {
            id: row
            columns: root.vertical ? 1 : Math.max(1, root.count)
            spacing: root.spacing

            Repeater {
                model: root.groups
                PxButton {
                    id: btn
                    // the app's windows; the one it stands for: in front, else the first
                    required property var modelData
                    readonly property var wins: modelData
                    readonly property var win: wins.find(w => w.is_focused) || wins[0]
                    readonly property bool group: wins.length > 1
                    width: root.buttonWidth
                    height: root.vertical ? root.cellH : flick.height
                    barInk: root.barInk
                    checked: win.is_focused
                    // the pointer anywhere on the button, × included: the ×'s own MouseArea takes the
                    // hover from btn.hovered (a sibling), and hiding the × on that made it flicker
                    HoverHandler {
                        id: over
                        onHoveredChanged: root.hovering(btn, hovered)
                    }
                    middleButton: true
                    readonly property bool minimized: wins.every(w => Minimize.isMinimized(w))
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
                    opacity: minimized ? 0.5 : 1
                    onClicked: {
                        if (group)
                            root.showPreview(btn, true);
                        else
                            root.activate(win);
                    }
                    onMiddleClicked: if (Config.bar.taskMiddleClose)
                        Niri.closeWindow(win.id)
                    onRightClicked: {
                        preview.visible = false;
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
                        appId: btn.win.app_id || ""
                        size: root.labels ? Theme.u * 8 : Math.max(Theme.u * 8, btn.height - Theme.u * 6)
                        tint: Config.bar.tintTasks && !btn.win.is_focused ? Config.bar.trayTint : "off"
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
                        text: Niri.titleOf(btn.win) || btn.win.app_id || "?"
                        elide: Text.ElideRight
                        font.bold: btn.win.is_focused
                        color: root.barInk ? (btn.win.is_urgent ? Theme.hellAccent : Theme.hellText) : btn.win.is_urgent ? Theme.danger : Theme.text
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
                        visible: Config.bar.taskHoverClose && over.hovered && !btn.group
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
