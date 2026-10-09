pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.workspace

// Hearts (or the Y2K star / CD, Config.workspaces.sprite): filled = active,
// lavender = has windows, hollow = empty.
Item {
    id: root

    required property string screenName
    readonly property var list: Niri.workspacesOn(screenName)
    // the hell bar (BarItem): the active desk is the accent (a state), a desk with windows the
    // sprite tone, an empty one only its outline; app icons in the circle's ramp
    property bool barInk: false
    // a taskbar on the left or the right edge (BarItem): the hearts in a column, no name badge
    // beside them (it would run off the bar)
    property bool vertical: false

    // the badge only takes room while it is shown: the slot opens, then closes again
    readonly property real badgeWidth: Math.min(Theme.u * 64, badgeMetrics.advanceWidth("✧ " + flashText) + Theme.u * 10)
    property real slot: 0
    implicitWidth: row.implicitWidth + slot
    implicitHeight: row.implicitHeight
    // the active cell before the switch: the animation starts there (niri updates
    // the workspace list before it reports the activation)
    readonly property int activeIndex: list.findIndex(w => w.is_active)
    property int currentIndex: -1
    property int previousIndex: -1
    onActiveIndexChanged: {
        previousIndex = currentIndex;
        currentIndex = activeIndex;
    }
    Component.onCompleted: currentIndex = activeIndex
    FontMetrics {
        id: badgeMetrics
        font: badgeText.font
    }

    Grid {
        id: row
        columns: root.vertical ? 1 : Math.max(1, root.list.length)
        spacing: Theme.u * 2

        // model = the count, not the list: niri rebuilds the list on every switch and
        // a list model would recreate every heart (no layout yet when the animation
        // measures them, no smooth scale on the old heart)
        Repeater {
            id: cells
            model: root.list.length
            Item {
                id: cell
                required property int index
                readonly property var modelData: root.list[index] || ({})
                readonly property bool active: modelData.is_active
                // looks inactive while the animation is still flying here
                readonly property bool lit: active && anim.hiddenIndex !== index
                readonly property alias heartItem: heart
                readonly property var wins: Niri.sortedWindows(Niri.windowsOn(modelData.id))
                readonly property bool occupied: wins.length > 0
                readonly property string style: Config.bar.workspaceStyle
                readonly property bool showIcons: style !== "hearts" && occupied
                readonly property bool showHeart: style !== "icons" || !occupied
                readonly property var icons: wins.slice(0, Math.max(1, Config.bar.workspaceIcons))
                width: (showHeart ? heart.width : 0) + (showIcons ? iconRow.width + (showHeart ? Theme.u * 2 : 0) : 0) + Theme.u * 4
                height: Math.max(heart.height, Theme.u * 9) + Theme.u * 4

                // active workspace gets a soft plate when icons are shown
                Rectangle {
                    visible: cell.showIcons
                    anchors.fill: parent
                    anchors.topMargin: Theme.u
                    anchors.bottomMargin: Theme.u
                    color: root.barInk ? (cell.lit ? Theme.hellBarActive : mouse.containsMouse ? Theme.hellBarHover : "transparent") : cell.lit ? Qt.alpha(Theme.accent, 0.28) : mouse.containsMouse ? Qt.alpha(Theme.accent, 0.12) : "transparent"
                    border.width: cell.lit && !root.barInk ? Math.max(1, Theme.u / 2) : 0
                    border.color: Theme.accent
                }
                Row {
                    id: iconRow
                    visible: cell.showIcons
                    anchors.verticalCenter: parent.verticalCenter
                    x: (cell.showHeart ? heart.x + heart.width + Theme.u * 2 : Theme.u * 2)
                    spacing: Theme.u
                    Repeater {
                        model: cell.showIcons ? cell.icons : []
                        AppIcon {
                            required property var modelData
                            appId: modelData.app_id || ""
                            size: Theme.u * 8
                            opacity: cell.lit || root.barInk ? 1 : 0.7
                            tint: Config.bar.tintTasks && !cell.lit ? Config.bar.trayTint : "off"
                            hellBar: root.barInk
                        }
                    }
                    PxText {
                        visible: cell.wins.length > cell.icons.length
                        anchors.verticalCenter: parent.verticalCenter
                        text: "+" + (cell.wins.length - cell.icons.length)
                        kind: "tiny"
                        dim: true
                    }
                }

                WsSprite {
                    id: heart
                    visible: cell.showHeart
                    x: Theme.u * 2
                    anchors.verticalCenter: parent.verticalCenter
                    pixel: Theme.u
                    lit: cell.lit
                    hollow: !cell.lit && !cell.occupied
                    tone: root.barInk ? (cell.modelData.is_urgent ? Theme.hellAccent : Theme.hellSprite) : cell.modelData.is_urgent ? Theme.danger : Theme.accent4
                    fill: root.barInk ? (cell.modelData.is_urgent || cell.lit ? Theme.hellAccent : Theme.hellSprite) : cell.modelData.is_urgent ? Theme.danger : cell.lit ? Theme.accent : Theme.accent4
                    barInk: root.barInk
                    opacity: cell.lit || mouse.containsMouse || root.barInk ? 1 : 0.75
                    scale: cell.lit ? 1.0 : 0.8
                    Behavior on scale {
                        NumberAnimation {
                            duration: Motion.ms(Theme.fast)
                            easing.type: Easing.OutBack
                        }
                    }
                    SequentialAnimation on opacity {
                        running: cell.modelData.is_urgent && !Motion.still
                        alwaysRunToEnd: true
                        loops: Animation.Infinite
                        PropertyAction {
                            value: 1
                        }
                        PauseAnimation {
                            duration: Motion.ms(300)
                        }
                        PropertyAction {
                            value: 0.3
                        }
                        PauseAnimation {
                            duration: Motion.ms(300)
                        }
                    }
                }
                PxText {
                    visible: !!cell.modelData.name
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: heart.bottom
                    text: cell.modelData.name || ""
                    kind: "tiny"
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // on the focused screen through angelOS (animated transitions)
                    onClicked: cell.modelData.output === Niri.focusedOutput ? WorkspaceAnim.go(String(cell.modelData.idx)) : Niri.focusWorkspace(cell.modelData.id)
                }
            }
        }
    }

    Connections {
        target: Shell
        function onHeartDemo(from, to) {
            if (from >= 0 && to >= 0 && from < root.list.length && to < root.list.length)
                anim.play(from, to);
        }
    }
    WsAnimator {
        id: anim
        x: row.x
        y: row.y
        width: row.width
        height: row.height
        z: 5
        style: Config.workspaces.heartAnim
        sprite: Config.workspaces.sprite
        heart: Config.bar.workspaceStyle !== "icons"
        plate: Config.bar.workspaceStyle !== "hearts"
        cellRect: i => {
            row.forceLayout();
            const c = cells.itemAt(i);
            return c ? c.mapToItem(anim, 0, 0, c.width, c.height) : Qt.rect(0, 0, 0, 0);
        }
        heartRect: i => {
            row.forceLayout();
            const c = cells.itemAt(i);
            return c && c.heartItem.visible ? c.heartItem.mapToItem(anim, 0, 0, c.heartItem.width, c.heartItem.height) : (c ? c.mapToItem(anim, 0, 0, c.width, c.height) : Qt.rect(0, 0, 0, 0));
        }
    }

    // "bar" popup mode: the workspace name pops out next to the hearts, on top of the bar
    property string flashText: ""
    Connections {
        target: Niri
        function onWorkspaceActivated(ws, focused) {
            if (ws.output !== root.screenName)
                return;
            anim.play(root.previousIndex, root.list.findIndex(w => w.id === ws.id));
            if (Config.workspaces.popupMode !== "bar" || root.vertical)
                return;
            const names = Config.workspaces.names || {};
            root.flashText = names[ws.output + ":" + ws.idx] || ws.name || String(ws.idx);
            flash.restart();
        }
    }
    PxBox {
        id: badge
        z: 10
        visible: opacity > 0
        opacity: 0
        x: row.width + Theme.u * 3
        anchors.verticalCenter: parent.verticalCenter
        width: root.badgeWidth
        height: Theme.u * 11
        color: root.barInk ? Theme.hellAccent : Theme.accent
        PxText {
            id: badgeText
            anchors.centerIn: parent
            width: parent.width - Theme.u * 6
            text: "✧ " + root.flashText
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            color: root.barInk ? Theme.hellPlate : Theme.selectText
            font.bold: true
        }
    }
    SequentialAnimation {
        id: flash
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "slot"
                to: root.badgeWidth + Theme.u * 6
                duration: Motion.ms(120)
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: badge
                property: "opacity"
                from: 0
                to: 1
                duration: Motion.ms(120)
            }
        }
        PauseAnimation {
            duration: Motion.ms(Math.max(250, Config.workspaces.popupMs))
        }
        ParallelAnimation {
            NumberAnimation {
                target: badge
                property: "opacity"
                to: 0
                duration: Motion.ms(140)
            }
            NumberAnimation {
                target: root
                property: "slot"
                to: 0
                duration: Motion.ms(180)
                easing.type: Easing.InCubic
            }
        }
    }

    MouseArea {
        // wheel anywhere on the row switches workspaces
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: w => root.screenName === Niri.focusedOutput ? WorkspaceAnim.go(w.angleDelta.y > 0 ? "up" : "down") : Niri.action(w.angleDelta.y > 0 ? "FocusWorkspaceUp" : "FocusWorkspaceDown", {})
    }
}
