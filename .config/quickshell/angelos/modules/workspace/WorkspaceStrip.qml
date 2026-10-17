pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Vertical heart strip on the right edge (niri workspaces are vertical).
PanelWindow {
    id: win

    required property string screenName
    property int serial: 0
    property bool shown: false
    readonly property var list: Niri.workspacesOn(screenName)

    onSerialChanged: {
        if (!Config.workspaces.indicator)
            return;
        shown = true;
        hideTimer.restart();
        // the strip was hidden: play once it has slid in far enough to be seen
        Qt.callLater(() => anim.play(win.previousIndex, win.activeIndex));
    }
    readonly property int activeIndex: list.findIndex(w => w.is_active)
    property int currentIndex: -1
    property int previousIndex: -1
    onActiveIndexChanged: {
        previousIndex = currentIndex;
        currentIndex = activeIndex;
    }
    Component.onCompleted: currentIndex = activeIndex

    // linger: shown goes false a beat before the slide-out starts, which unmapped the strip
    // for a few frames before it slid away (#87)
    visible: shown || slide.running || linger.running
    anchors.right: true
    implicitWidth: box.width + Theme.u * 8
    implicitHeight: box.height + Theme.u * 6
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "angelos-workspace"
    WlrLayershell.layer: WlrLayer.Overlay

    BackgroundEffect.blurRegion: Config.appearance.blur ? blurRegion : null
    Region {
        id: blurRegion
        item: box
    }

    Timer {
        id: hideTimer
        interval: Math.max(400, Config.workspaces.popupMs)
        onTriggered: {
            linger.restart();
            win.shown = false;
        }
    }
    Timer {
        id: linger
        interval: Motion.ms(Theme.normal) + 100
    }

    PxBox {
        id: box
        anchors.verticalCenter: parent.verticalCenter
        x: win.shown ? Theme.u * 2 : win.implicitWidth
        width: col.implicitWidth + inset * 2 + Theme.u * 6
        height: col.implicitHeight + inset * 2 + Theme.u * 6
        color: Theme.panel
        shadow: Config.appearance.shadows
        Behavior on x {
            NumberAnimation {
                id: slide
                duration: Motion.ms(Theme.normal)
                easing.type: Easing.OutBack
            }
        }

        Column {
            id: col
            anchors.centerIn: parent
            spacing: Theme.u * 3
            Repeater {
                id: cells
                model: win.list.length
                Item {
                    id: cell
                    required property int index
                    readonly property var modelData: win.list[index] || ({})
                    readonly property bool lit: modelData.is_active && anim.hiddenIndex !== index
                    width: Theme.u * 14
                    height: Theme.u * 12
                    Rectangle {
                        anchors.fill: parent
                        visible: cell.lit
                        color: Qt.alpha(Theme.accent, 0.25)
                    }
                    WsSprite {
                        anchors.centerIn: parent
                        lit: cell.lit
                        hollow: !cell.lit && Niri.windowsOn(cell.modelData.id).length === 0
                    }
                }
            }
        }
        WsAnimator {
            id: anim
            anchors.fill: col
            vertical: true
            style: Config.workspaces.heartAnim
            sprite: Config.workspaces.sprite
            cellRect: i => {
                col.forceLayout();
                const c = cells.itemAt(i);
                return c ? c.mapToItem(anim, 0, 0, c.width, c.height) : Qt.rect(0, 0, 0, 0);
            }
        }
    }

    RightClickGuard {}
}
