pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// Win98 task buttons for windows on this screen's active workspace (or all).
// Titles show while every button still gets a readable width; when the windows
// reach the lyrics or other widgets the row turns into icons, and when even the
// icons don't fit it scrolls (mouse wheel, arrows at the edges).
// The dock (`dock`): bare icons on the shelf that grow under the pointer and hop when
// their window opens or is clicked, a dot under the focused one.
Item {
    id: root

    required property string screenName
    property bool iconsOnly: false         // compact / island bars, or titles switched off
    property bool above: true              // the window menu opens above a bottom bar
    property bool dock: false              // the dock's icons (BarItem: style "dock")
    // the hell bar (BarItem): flat buttons with the one plate rule, the focused window's the
    // active plate, app icons in the circle's ramp
    property bool barInk: false
    // the pointer along the row, for the dock's magnification
    readonly property real pointerX: dockHover.hovered ? dockHover.point.position.x + flick.contentX : -1e6
    readonly property var ws: Niri.activeWorkspace(screenName)
    readonly property var list: Niri.sortedWindows(Config.bar.allWindows ? Niri.windows : Niri.windows.filter(w => ws && w.workspace_id === ws.id))
    readonly property int count: list.length
    readonly property int spacing: Theme.u * 2
    readonly property int iconWidth: height
    // a title button narrower than this shows two letters and an ellipsis — use icons instead
    readonly property int labelMin: Theme.u * Math.max(28, Config.bar.taskMinWidth)
    readonly property int maxW: Theme.u * Math.max(28, Config.bar.taskMinWidth, Config.bar.taskMaxWidth)
    readonly property real share: count ? (width - (count - 1) * spacing) / count : 0
    readonly property bool labels: !iconsOnly && share >= labelMin
    readonly property int buttonWidth: labels ? Math.min(maxW, Math.floor(share)) : iconWidth
    readonly property real rowWidth: count * buttonWidth + Math.max(0, count - 1) * spacing
    readonly property bool overflow: rowWidth > width + 0.5
    // as wide as the buttons want to be (Settings → Bar → "Windows" width: compact)
    readonly property real naturalWidth: count * (iconsOnly ? iconWidth : maxW) + Math.max(0, count - 1) * spacing

    clip: !dock || overflow
    HoverHandler {
        id: dockHover
        enabled: root.dock
    }

    function scrollBy(dx) {
        const max = Math.max(0, flick.contentWidth - flick.width);
        glide.stop();
        glide.to = Math.max(0, Math.min(max, flick.contentX + dx));
        glide.start();
    }
    // keep the focused window's button in view when the row scrolls
    function reveal() {
        if (!overflow)
            return;
        const i = list.findIndex(w => w.is_focused);
        if (i < 0)
            return;
        const x0 = i * (buttonWidth + spacing), x1 = x0 + buttonWidth;
        if (x0 < flick.contentX)
            scrollBy(x0 - flick.contentX - Theme.u * 8);
        else if (x1 > flick.contentX + flick.width)
            scrollBy(x1 - flick.contentX - flick.width + Theme.u * 8);
    }
    onListChanged: Qt.callLater(reveal)
    // the buttons that are there at start don't hop, the windows opened later do
    property bool ready: false
    Timer {
        interval: 1500
        running: true
        onTriggered: root.ready = true
    }
    onOverflowChanged: if (!overflow)
        flick.contentX = 0

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
        contentWidth: root.rowWidth
        contentHeight: height
        interactive: root.overflow
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        pixelAligned: true

        Row {
            id: row
            height: flick.height
            spacing: root.spacing

            Repeater {
                model: root.list
                PxButton {
                    id: btn
                    required property var modelData
                    required property int index
                    width: root.buttonWidth
                    height: row.height
                    flat: root.dock
                    barInk: root.barInk
                    checked: modelData.is_focused && !root.dock
                    // the dock: grows with the pointer near, up to 1.5×, from its foot
                    readonly property real centreX: index * (root.buttonWidth + root.spacing) + root.buttonWidth / 2
                    readonly property real near: root.dock ? Math.max(0, 1 - Math.abs(root.pointerX - centreX) / (root.buttonWidth * 2.4)) : 0
                    readonly property real grow: 1 + 0.5 * near * near
                    property real hop: 0
                    SequentialAnimation {
                        id: hopper
                        NumberAnimation {
                            target: btn
                            property: "hop"
                            to: Theme.u * 7
                            duration: Motion.ms(150)
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: btn
                            property: "hop"
                            to: 0
                            duration: Motion.ms(210)
                            easing.type: Easing.OutBounce
                        }
                    }
                    Component.onCompleted: if (root.dock && root.ready)
                        hopper.restart()
                    middleButton: true
                    onClicked: {
                        Niri.focusWindow(modelData.id);
                        if (root.dock)
                            hopper.restart();
                    }
                    onMiddleClicked: if (Config.bar.taskMiddleClose)
                        Niri.closeWindow(modelData.id)
                    onRightClicked: {
                        const mode = Config.bar.taskRightClick || "menu";
                        if (mode === "close")
                            Niri.closeWindow(modelData.id);
                        else if (mode === "menu")
                            menu.openFor(btn, modelData);
                    }

                    AppIcon {
                        id: ico
                        x: (root.labels ? Theme.u * 4 : (btn.width - width) / 2) + (btn.down && !root.dock && !root.barInk ? Theme.u : 0)
                        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                        anchors.verticalCenterOffset: (btn.down && !root.dock && !root.barInk ? Theme.u : 0) - (root.dock ? Theme.u + btn.hop : 0)
                        appId: btn.modelData.app_id || ""
                        size: root.labels ? Theme.u * 8 : Math.max(Theme.u * 8, btn.height - Theme.u * (root.dock ? 7 : 6))
                        tint: Config.bar.tintTasks && !btn.modelData.is_focused ? Config.bar.trayTint : "off"
                        hellBar: root.barInk
                        scale: btn.grow
                        transformOrigin: Item.Bottom
                        Behavior on scale {
                            enabled: root.dock
                            NumberAnimation {
                                duration: Motion.ms(90)
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                    // the dock: a dot under the focused window
                    Rectangle {
                        visible: root.dock && btn.modelData.is_focused
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: btn.height - Theme.u * 2
                        width: Theme.u * 2
                        height: Theme.u * 2
                        color: btn.modelData.is_urgent ? Theme.danger : Theme.accent
                    }
                    PxText {
                        visible: root.labels
                        anchors.left: ico.right
                        anchors.leftMargin: Theme.u * 3
                        anchors.right: parent.right
                        anchors.rightMargin: closeX.visible ? closeX.width + Theme.u * 4 : Theme.u * 4
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: btn.down && !root.barInk ? Theme.u : 0
                        text: Niri.titleOf(btn.modelData) || btn.modelData.app_id || "?"
                        elide: Text.ElideRight
                        font.bold: btn.modelData.is_focused
                        color: root.barInk ? (btn.modelData.is_urgent ? Theme.hellAccent : Theme.hellText) : btn.modelData.is_urgent ? Theme.danger : Theme.text
                    }
                    // the window's cobweb (services/Cobweb): its corner, under the ×
                    CobwebBadge {
                        ids: [btn.modelData.id]
                        hovered: btn.hovered
                        pixel: Math.max(1, Math.round(Theme.u / 2))
                        x: btn.width - width - (root.dock ? Theme.u * 2 : Theme.u)
                        y: root.dock ? Theme.u - btn.hop : Theme.u
                    }
                    // × on hover (Settings → Bar → Closing windows)
                    Rectangle {
                        id: closeX
                        visible: Config.bar.taskHoverClose && btn.hovered
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
                            onClicked: Niri.closeWindow(btn.modelData.id)
                        }
                    }
                }
            }
        }
    }

    // wheel scrolls the row sideways once it overflows
    WheelHandler {
        enabled: root.overflow
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
            visible: root.overflow && (modelData < 0 ? flick.contentX > 1 : flick.contentX < flick.contentWidth - flick.width - 1)
            compact: true
            icon: modelData < 0 ? "arrowLeft" : "arrowRight"
            iconPixel: Math.max(1, Theme.u - 1)
            width: Theme.u * 8
            height: root.height
            x: modelData < 0 ? 0 : root.width - width
            onClicked: root.scrollBy(modelData * Math.max(root.buttonWidth + root.spacing, flick.width * 0.6))
        }
    }
}
